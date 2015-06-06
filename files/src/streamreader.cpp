// 定義ファイルに従ってストリームを読む

#include <stdint.h>

#include <iostream>
#include <iomanip>
#include <vector>
#include <array>
#include <stack>
#include <map>
#include <memory>
#include <sstream>
#include <fstream>
#include <algorithm>
#include <regex>
#include <cctype>
#include <cstring>

#include "luabinder.hpp"

// config、デバッグ、環境依存

#define FAILED(msg, ...) ::rf::failed((__VA_ARGS__), __LINE__, __FUNCTION__, msg, #__VA_ARGS__)
#define ERR cerr << "# c++ error. L" << dec << __LINE__ << " " << __FUNCTION__ << ": "
#ifdef _MSC_VER
#else
	#define nullptr NULL
	#define final
	#define throw(x)
#endif

namespace rf{
	using std::vector;
	using std::stack;
	using std::array;
	using std::map;
	using std::pair;
	using std::tuple;
	using std::string;
	using std::shared_ptr;
	using std::istringstream;
	using std::stringstream;
	using std::ifstream;
	using std::ofstream;
	using std::streambuf;
	using std::stringbuf;
	using std::filebuf;
	using std::exception;
	using std::ios;
	using std::to_string;
	using std::stoi;
	using std::make_shared;
	using std::make_tuple;
	using std::tie;
	using std::cout;
	using std::cin;
	using std::cerr;
	using std::endl;
	using std::hex;
	using std::dec;
	using std::min;

	inline bool failed(bool b, int line, const std::string &fn, const std::string &msg, const std::string &exp)
	{
		if (!b)
			std::cerr << "# c++ failed " << msg << "! L."<< std::dec
			<< line << " " << fn << ": " << exp << std::endl;
		return !b;
	}

	inline static bool valid_ptr(const void *p)
	{
		return p != nullptr;
	}

	template<class T>
	inline static bool valid_ptr(const shared_ptr<T> p)
	{
		return !(!p);
	}

	inline static uint16_t reverse_endian_16(uint16_t value)
	{
		return ((value >> 8) & 0xff) | ((value << 8) & 0xff00);
	}

	inline static uint32_t reverse_endian_32(uint32_t value)
	{
		return ((value >> 24) & 0xff) | ((value >> 8) & 0xff00)
			| ((value << 8) & 0xff0000) | ((value << 24) & 0xff000000);
	}

	class FileManager final
	{
	private:

		//  出力ファイル名から保存先
		static map<string, shared_ptr<ofstream> > ofs_map_;

		FileManager(){}
		FileManager(const FileManager &){}
		FileManager &operator=(const FileManager &){}

		~FileManager()
		{
			#ifdef _MSC_VER
				for (auto c : ofs_map_)
				{
					c.second->close();
					if (c.second->fail())
					{
						ERR << c.first << "close fail" << endl;
					}
				}
			#else
				for (auto it = ofs_map_.begin(); it != ofs_map_.end(); ++it)
				{
					it->second->close();
					if (it->second->fail())
					{
						ERR << it->first << "close fail" << endl;
					}
			#endif

			stdout_to_file(false);	// 一応
		}

	public:
		static FileManager &getInstance()
		{
			static FileManager instance;
			return instance;
		}

		// 指定したバイト列をファイルに出力
		static bool write_to_file(string file_name, const char* address, int size)
		{
			if (FAILED("check ptr", valid_ptr(address)))
				return false;

			// ファイル名に応じて読み込んだデータを出力して
			// 暫定で毎回ファイルを開く
			shared_ptr<ofstream> ofs;
			auto it = ofs_map_.find(file_name);
			if (it == ofs_map_.end())
			{
				ofs = make_shared<ofstream>();
				ofs_map_.insert(std::make_pair(file_name, ofs));

				ios::openmode mode = ios::binary | ios::out;
				ofs->open(file_name, mode);
				if (FAILED("file open", !(!ofs)))
				{
					return false;
				}
			}
			else
			{
				ofs = it->second;
			}

			ofs->write(address, size);
			if (FAILED("file write", !ofs->fail()))
			{
				ERR << "file write " << file_name << endl;
				return false;
			}
			return true;
		}

		static bool stdout_to_file(bool enable)
		{
			static FILE* fp = nullptr;
			if (enable && fp == nullptr)
			{
				std::cout << "stdout to log.txt" << std::endl;

				#ifdef _MSC_VER
					if (FAILED("fopen", freopen_s(&fp, "log.txt", "w", stdout) == 0))
						return false;
				#else
					fp = freopen("log.txt", "w", stdout);
					if (FAILED("fopen", fp != NULL))
						return false;
				#endif
			}
			else if (fp != nullptr)
			{
				std::cout << "stdout to console" << std::endl;
				fclose(fp);
				fp = nullptr;
			}

			return true;
		}
	};

	map<string, shared_ptr<ofstream> > FileManager::ofs_map_;

	class Bitstream
	{
	private:

		shared_ptr<streambuf> buf_;
		int size_;
		int byte_pos_;
		int bit_pos_;

	protected:

		void cut_bit()
		{
			if (bit_pos_ != 0)
			{
				++byte_pos_;
				bit_pos_ = 0;
			}
		}

		bool sync()
		{
			return byte_pos_ == buf_->pubseekpos(byte_pos_);
		}

	public:

		Bitstream() : size_(0), byte_pos_(0), bit_pos_(0){}
		~Bitstream(){}

		shared_ptr<streambuf> buf() const { return buf_; }
		int size() const { return size_; }
		int byte_pos() const { return byte_pos_; }
		int bit_pos() const { return bit_pos_; }

		bool assign(shared_ptr<streambuf> buf)
		{
			buf_ = buf;
			byte_pos_ = 0;
			bit_pos_ = 0;
			size_ = static_cast<int>(buf->pubseekoff(0, ios::end));
			size_ = size_ == EOF ? 0 : size_;

			return sync();
		}

		bool write_by_buf(const char *buf, int size)
		{
			if (FAILED("check size", size >= 0))
				return false;

			buf_->sputn(buf, size);
			size_ += size;

			return true;
		}

		bool put_char(char c)
		{
			++size_;
			return c == buf_->sputc(c);
		}

		// 終端バイトはtrue
		bool check_by_bit(int bit) const
		{
			if (FAILED("check range", (0 <= bit) && ((bit + 7) / 8 <= size_)))
			{
				ERR << "overrun bit. pos 0x" << hex << bit/8 << endl;
				return false;
			}

			return true;
		}

		bool check_by_byte(int byte) const
		{
			if (FAILED("check range", (0 <= byte) && (byte <= size_)))
			{
				ERR << "overrun byte. pos 0x" << hex << byte << endl;
				return false;
			}
			return true;
		}

		bool check_offset_by_bit(int offset) const
		{
			if (FAILED("check range", check_by_bit(byte_pos_ * 8 + bit_pos_ + offset)))
			{
				return false;
			}
			return true;
		}

		bool check_offset_by_byte(int offset) const
		{
			if (FAILED("check", check_by_bit((byte_pos_ + offset) * 8 + bit_pos_)))
			{
				return false;
			}
			return true;
		}


		bool seekpos(int byte, int bit)
		{
			if (FAILED("check byte", check_by_byte(byte)))
				return false;

			if (FAILED("check bit", (0 >= bit) && (bit <= 8)))
				return false;

			byte_pos_ = byte;
			bit_pos_ = bit;

			return sync();
		}

		bool seekpos_by_bit(int offset)
		{
			if (FAILED("check offset", check_by_bit(offset)))
				return false;

			byte_pos_ = offset / 8;
			bit_pos_ = offset % 8;

			return sync();
		}

		bool seekpos_by_byte(int offset)
		{
			if (FAILED("check offset", check_by_byte(offset)))
				return false;

			byte_pos_ = offset;
			bit_pos_ = 0;

			return sync();
		}

		bool seek(int byte, int bit)
		{
			if (FAILED("check offset", check_by_bit(byte*8 + bit)))
				return false;

			byte_pos_ = byte;
			bit_pos_ = bit;

			return sync();
		}

		bool seekoff_by_bit(int offset)
		{
			if (FAILED("check offset", check_offset_by_bit(offset)))
				return false;

			byte_pos_ += (bit_pos_ + offset )/ 8;
			if ((bit_pos_ + offset) < 0)
				--byte_pos_;

			bit_pos_ = (bit_pos_ + offset) & 0x07;

			return sync();
		}

		bool seekoff_by_byte(int offset)
		{
			if (FAILED("check offset", check_offset_by_byte(offset)))
				return false;

			byte_pos_ += offset;

			return sync();
		}
		
		bool read_by_bit(int size, uint32_t &ret_value)
		{
			if (FAILED("check size", 0 <= size && size <= 32))
			{
				ERR << "read bit size should be [0, 32] but " << size << endl;
				return false;
			}

			if (FAILED("check remain size", check_offset_by_bit(size)))
				return false;

			uint32_t value;
			int already_read = 0;

			// 先頭の中途半端なビットを読んでから、残りをバイトストリームとして読む
			// read_lengthが現在のバイトに収まるならビット読み出しまでで終了
			if (bit_pos_ + size < 8)
			{
				value = static_cast<uint32_t>(buf_->sgetc());
				value >>= 8 - (bit_pos_ + size); // 下位ビットを合わせる
				value &= ((1 << size) - 1); // 上位ビットを捨てる
				seekoff_by_bit(size);
				ret_value = value;
				return true;
			}
			else
			{
				int remained_bit = 8 - bit_pos_;
				value = buf_->sbumpc() & ((1 << remained_bit) - 1);
				seekoff_by_bit(remained_bit);
				already_read += remained_bit;
			}

			while (size > already_read)
			{
				if (size - already_read < 8)
				{
					value <<= (size - already_read);
					value |= buf_->sgetc() >> (8 - (size - already_read));
					seekoff_by_bit(size - already_read);
					break;
				}
				else
				{
					value <<= 8;
					value |= buf_->sbumpc();
					seekoff_by_bit(8);
					already_read += 8;
				}
			}

			ret_value = value;
			return true;
		}

		bool read_by_byte(int size, uint32_t &ret_value)
		{
			if (FAILED("check size", 0 <= size && size <= 4))
			{
				ERR << "read byte size should be [0, 4] but " << size << endl;
				return false;
			}

			if (FAILED("check remain size", check_offset_by_byte(size)))
				return false;

			return read_by_bit(size*8, ret_value);
		}

		// 高オーバーヘッド
		bool read_by_expgolomb(uint32_t &ret_value, int &ret_size)
		{
			uint32_t v = 0;
			read_by_bit(1, v);
			if (v == 1)
			{
				ret_value = 0;
				ret_size = 1;
				return true;
			}

			int count = 1;
			for (;;)
			{
				if (FAILED("", read_by_bit(1, v)))
					return false;

				if (v == 1)
				{
					if (FAILED("read val", read_by_bit(count, v)))
					{
						return false;
					}
					else
					{
						ret_value = (v | (1<<count)) - 1;
						ret_size = 2*count + 1;
						return true;
					}
				}

				++count;
			}
		}

		// NULL文字が先に見つかった場合はその分だけポインタを進める
		// NULL文字が見つからなかった場合は最大max_lengthの長さ文字列として終端にNULL文字を入れる
		bool read_by_string(int max_length, string &ret_str)
		{
			if (FAILED("check length", check_offset_by_byte(max_length)))
				return false;

			if (FAILED("check remained bit", bit_pos_ == 0))
				return false;

			int ofs = 0;
			int c;
			stringstream ss;
			for (; ofs < max_length; ++ofs)
			{
				c = buf_->sbumpc();
				ss << static_cast<char>(c);
				if (static_cast<char>(c) == '\0')
				{ 
					break;
				}
				else if (c == EOF)
				{ 
					break;
				}
			}

			ret_str = ss.str();
			
			return seekoff_by_byte(ofs);
		}

		bool look_by_bit(int size, uint32_t &ret_val)
		{
			if (FAILED("check size", 0 <= size && size <= 32))
			{
				ERR << "look bit size should be [0, 32] but " << size << endl;
				return false;
			}

			if (FAILED("check remain size", check_offset_by_bit(size)))
				return false;

			read_by_bit(size, ret_val);

			return seekoff_by_bit(-size);
		}
		
		bool look_by_byte(int size, uint32_t &ret_val)
		{
			if (FAILED("check size", 0 <= size && size <= 4))
			{
				ERR << "look byte size should be [0, 4] but " << size << endl;
				return false;
			}

			if (FAILED("check offset", check_offset_by_byte(size)))
				return false;

			read_by_byte(size, ret_val);
			return seekoff_by_byte(-size);
		}

		bool look_by_buf(char* address, int size)
		{
			if (FAILED("check size", 0 <= size))
				return false;

			if (FAILED("check offset", check_offset_by_byte(size)))
				return false;

			buf_->sgetn(address, size);
			return sync();
		}

		// 見つからなければファイル終端を返す
		bool find_byte(char sc, int &ret_offset, bool advance = false)
		{
			int ofs = 0;
			int c;
			for (;; ++ofs)
			{
				c = buf_->sbumpc();
				if (static_cast<char>(c) == sc)
				{
					break;
				}
				else if (c == EOF)
				{
					break;
				}
			}

			ret_offset = ofs;
			if (advance)
			{
				cut_bit();
				return seekoff_by_byte(ofs);
			}
			else
				return sync();
		}

		bool find_byte_string(const char* address, int size, int &ret_offset, bool advance = false)
		{
			//char* contents = new char[size];
			char contents[256];
			if (FAILED("check max size", sizeof(contents) >= static_cast<size_t>(size)))
			{
				ERR << "too big search string" << endl;
				return false;
			}

			if (FAILED("", valid_ptr(address)))
				return false;

			int offset = 0;
			int prev_byte_pos = byte_pos_;
			for (;;)
			{
				if (FAILED("", find_byte(address[0], offset, true)))
				{
					seekpos_by_byte(prev_byte_pos);
					return false;
				}

				// 終端
				if ((byte_pos_ >= size_)
				||  (!check_offset_by_byte(size)))
				{
					break;
				}

				// 一致
				// 不一致は1バイト進める
				look_by_buf(contents, size);
				if (std::memcmp(contents, address, static_cast<size_t>(size)) == 0)
				{
					break;
				}
				else
				{
					seekoff_by_byte(1);
				}
			}

			ret_offset = byte_pos_ - prev_byte_pos;
			if (!advance)
				return seekpos_by_byte(prev_byte_pos);
			else
				return true;
		}
	};
	
	class RingBuf final : public streambuf
	{

	private:

		shared_ptr<char> buf_;
		int size_;

	protected:

		int overflow(int c) override
		{
			setp(buf_.get(), buf_.get() + size_);
			return sputc(static_cast<char>(c));
		}

		int underflow() override
		{
			setg(buf_.get(), buf_.get(), buf_.get() + size_);
			return buf_.get()[0];
		}

		//ios::pos_type seekoff(ios::off_type off, ios::seekdir way, ios::openmode) override
		//{
		//	#if 0
		//		return -1;
		//	#else
		//		char* pos;
		//		switch (way)
		//		{
		//			case ios::beg: pos = eback() + off; break;
		//			case ios::end: pos = egptr() + off - 1; break;
		//			case ios::cur: default: pos = gptr() + off; break;
		//		}
		//
		//		setg(buf_.get(), pos, buf_.get() + size_);
		//		return -1;
		//	#endif
		//}
		//
		//ios::pos_type seekpos(ios::pos_type pos, ios::openmode which) override
		//{
		//	#if 0
		//		return -1;
		//	#else
		//		return seekoff(pos, ios::beg, which);
		//	#endif
		//}

	public:
		RingBuf() :size_(0), streambuf() {}

		bool reserve(int size)
		{
			if (FAILED("check size", 0 <= size))
				return false;

			buf_ = shared_ptr<char>(new char[size]);
			size_ = size;
			setp(buf_.get(), buf_.get() + size);
			setg(buf_.get(), buf_.get(), buf_.get() + size);
			return true;
		}
	};

	class LuaGlueBitstream
	{
	public:

		// 指定アドレスをバイト列でダンプ
		static bool dump_line(const char* buf, int offset, int size)
		{
			uint8_t c;
			for (int i = 0; i < size; ++i)
			{
				c = buf[offset + i];
				printf("%02x ", (c));
			}
			return true;
		}

		// 指定アドレスを文字列でダンプ
		static bool dump_as_string(const char* buf, int offset, int size)
		{
			uint8_t c;
			for (int i = 0; i < size; ++i)
			{
				c = buf[offset + i];
				if (isalpha(c))
					putchar(c);
				else
					putchar('.');
			}
			return true;
		}

		// 指定アドレスをダンプ
		static bool dump(const char* buf, int print_offset, int size)
		{
			printf("     offset    | ");
			for (int i = 0; i < 16; ++i)
			{
				printf("+%x ", (i + print_offset) % 16);
			}
			printf("| ");
			for (int i = 0; i < 16; ++i)
			{
				printf("%x", (i + print_offset) % 16);
			}
			putchar('\n');

			int cur = 0;
			for (; cur + 16 <= size; cur += 16)
			{
				printf("     0x%08x| ", cur + print_offset);
				dump_line(buf, cur, 16);
				printf("| ");
				dump_as_string(buf, cur, 16);
				putchar('\n');
			}

			if (cur < size)
			{
				printf("     0x%08x| ", cur + print_offset);
				dump_line(buf, cur, size % 16);

				for (int i = 0; i < 16 - (size % 16); ++i)
				{
					printf("   ");
				}
				printf("| ");
				dump_as_string(buf, cur, size - cur);
				putchar('\n');
			}

			return true;
		}

		// ストリームからファイルに転送
		// 現状オーバーヘッド多め
		static bool transfer_to_file(string file_name, LuaGlueBitstream &stream, int size, bool advance = false)
		{
			char* buf = new char[static_cast<unsigned int>(size)];
			if (FAILED("get data", stream.look_by_buf(buf, size)))
				throw LUA_RUNTIME_ERROR("get data");

			if (FAILED("write data", FileManager::getInstance().write_to_file(file_name, buf, size)))
				throw LUA_RUNTIME_ERROR("write data");

			if (advance)
			{
				stringstream ss;
				ss << " >> " << file_name;
				stream.read_by_byte(ss.str(), size);
			}

			return true;
		}

	private:

		Bitstream bs_;
		bool printf_on_;
		bool little_endian_;

	protected:

		LuaGlueBitstream()
			:printf_on_(true), little_endian_(false){}

		bool assign(shared_ptr<streambuf> b)
		{
			return bs_.assign(b);
		}

		bool look_by_buf(char* address, int size)
		{
			return bs_.look_by_buf(address, size);
		}

	public:

		virtual ~LuaGlueBitstream()
		{
		}

		// ストリームサイズ取得
		int  size() { return bs_.size(); }

		// 現在のビットオフセットを取得
		int  byte_pos() { return bs_.byte_pos(); }

		// 現在のバイトオフセットを取得
		int  bit_pos() { return bs_.bit_pos(); }

		// コンソール出力ON/OFF
		void enable_print(bool enable) { printf_on_ = enable; }

		// ２バイト/４バイトの読み込み時はエンディアンを変換する
		void little_endian(bool enable_) { little_endian_ = enable_; }

		// 現在位置からファイルポインタ移動
		bool seekoff_by_bit(int offset) {return bs_.seekoff_by_bit(offset);}

		// 現在位置からファイルポインタ移動
		bool seekoff_by_byte(int offset) { return bs_.seekoff_by_byte(offset); }

		// 先頭からファイルポインタ移動
		bool seekpos_by_bit(int byte) { return bs_.seekpos_by_bit(byte); }

		// 先頭からファイルポインタ移動
		bool seekpos_by_byte(int byte) { return bs_.seekpos_by_byte(byte); }

		// 先頭からファイルポインタ移動
		bool seekpos(int byte, int bit) { return bs_.seekpos(byte, bit); }

		// ビット単位で読み込み
		// 32bit以上は0を返す
		uint32_t read_by_bit(string name, int size) throw(...)
		{
			if (FAILED("", bs_.check_offset_by_bit(size)))
				throw LUA_RUNTIME_ERROR("overflow");

			int prev_byte = byte_pos();
			int prev_bit = bit_pos();

			if (size > 32)
			{
				char buf[16];
				int dump_size = min<int>(16, (size+7)/8);
				bs_.look_by_buf(buf, dump_size);

				seekoff_by_bit(size);

				if (printf_on_ || (name[0] == '#'))
				{
					printf(" adr=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | ",
						prev_byte, prev_bit, size / 8, size % 8, name.c_str());
					dump_line(buf, 0, dump_size);

					if (16 > (size + 7) / 8)
						putchar('\n');
					else
						printf(" ...\n");
				}
				
				return 0;
			}
			else
			{
				uint32_t v;
				bs_.read_by_bit(size, v);
				
				if (little_endian_)
				{
					if (size == 32)
						v = reverse_endian_32(v);
					else if (size == 16)
						v = reverse_endian_16(static_cast<uint16_t>(v));
				}

				if (printf_on_ || (name[0] == '#'))
				{
					printf(" adr=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | val=0x%-8x (%d%s)\n",
						prev_byte, prev_bit, size / 8, size % 8, name.c_str(), v, v,
						((size == 32 || size == 16) && little_endian_) ? ", \"little\"" : "");
				}

				return v;
			}
		}

		// バイト単位で読み込み
		// 32bit以上は0を返す
		uint32_t read_by_byte(string name, int size) throw(...)
		{
			if (FAILED("", bs_.check_offset_by_byte(size)))
				throw LUA_RUNTIME_ERROR("overflow");

			return read_by_bit(name, 8 * size);
		}

		// バイト単位で文字列として読み込み
		// むちゃくちゃ長い文字列はまずい。
		string read_by_string(string name, int max_length) throw(...)
		{
			int prev_byte = bs_.byte_pos();
			int prev_bit = bs_.bit_pos();

			string str;
			if (FAILED("check", bs_.read_by_string(max_length, str)))
				throw LUA_RUNTIME_ERROR("read string");

			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%08x(+%d)| siz=0x%08x(+0)| %-40s | str=\"%s\"\n",
					prev_byte, prev_bit, static_cast<unsigned int>(str.length()), name.c_str(), str.c_str());
				if (max_length < static_cast<int>(str.length() - 1))
					ERR << "max_length > str.length() - 1 (" << str.length()
						<< " != "<< max_length << ")" << endl;
			}

			return str;
		}

		uint32_t read_by_expgolomb(string name) throw(...)
		{
			int prev_byte = bs_.byte_pos();
			int prev_bit = bs_.bit_pos();

			uint32_t v;
			int size;
			if (FAILED("", bs_.read_by_expgolomb(v, size)))
				throw LUA_RUNTIME_ERROR("read expgolomb");

			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | exp=0x%-8x (%d%s)\n",
					prev_byte, prev_bit, size / 8, size % 8, name.c_str(), v, v,
					((size == 32 || size == 16) && little_endian_) ? ", \"little\"" : "");
			}

			return v;
		}

		uint32_t look_by_bit(int size) throw(...)
		{
			if (FAILED("", bs_.check_offset_by_bit(size)))
				throw LUA_RUNTIME_ERROR("overflow");

			uint32_t val;
			if (FAILED("look_by_bit", bs_.look_by_bit(size, val)))
				throw LUA_RUNTIME_ERROR("look_by_bit");
			return val;
		}
		
		uint32_t look_by_byte(int size) throw(...)
		{
			if (FAILED("", bs_.check_offset_by_byte(size)))
				throw LUA_RUNTIME_ERROR("overflow");

			uint32_t val;
			if (FAILED("look_by_byte", bs_.look_by_byte(size, val)))
				throw LUA_RUNTIME_ERROR("look_by_byte");
			return val;
		}

		// ビット単位で比較
		uint32_t compare_by_bit(string name, int size, uint32_t compvalue) throw(...)
		{
			if (FAILED("", bs_.check_offset_by_bit(size)))
				throw LUA_RUNTIME_ERROR("overflow");

			uint32_t value = read_by_bit(name, size);
			if (value != compvalue)
			{
				printf("# compare value: 0x%08x(%d) != 0x%08x(%d)\n",
					value, value, compvalue, compvalue);

				throw LUA_RUNTIME_ERROR("compare fail");
			}
			return value;
		}

		// バイト単位で比較
		uint32_t compare_by_byte(string name, int size, uint32_t compvalue) throw(...)
		{
			if (FAILED("", bs_.check_offset_by_byte(size)))
				throw LUA_RUNTIME_ERROR("overflow");

			return compare_by_bit(name, 8 * size, compvalue);
		}

		// バイト単位で文字列として比較
		string compare_by_string(string name, int max_length, string comp_str) throw(...)
		{
			if (FAILED("", bs_.check_offset_by_byte(max_length)))
				throw LUA_RUNTIME_ERROR("overflow");

			string str = read_by_string(name, max_length);
			if (str != comp_str)
			{
				printf("# compare string: \"%s\" != \"%s\"\n", str.c_str(), comp_str.c_str());
				throw LUA_RUNTIME_ERROR("compare fail");
			}
			return str;
		}

		// １バイトの一致を検索
		int find_byte(char c, bool advance = false) throw(...)
		{
			int prev_byte = bs_.byte_pos();
			int offset;

			if (FAILED("check", bs_.find_byte(c, offset, advance)))
			{
				printf("# can not find byte:0x%x\n", static_cast<uint8_t>(c));
				throw LUA_RUNTIME_ERROR("search fail");
			}

			if (printf_on_)
			{
				printf(" adr=0x%08x(+0)| ofs=0x%08x(+0)| search '0x%02x' %s at adr=0x%08x.\n",
					bs_.byte_pos(), offset, static_cast<uint8_t>(c),
					offset + prev_byte == this->size() ? "not found [EOF]" : "found",
					offset + prev_byte);
			}

			return offset;
		}

		// 数バイト分の一致を検索
		int find_byte_string(const char* address, int size, bool advance = false) throw(...)
		{
			if (FAILED("check", valid_ptr(address)))
				return false;

			string s(address, size);
			int prev_byte = bs_.byte_pos();
			int offset;

			if (FAILED("check", bs_.find_byte_string(address, size, offset, advance)))
			{
				printf("# can not find byte string: %s\n", s.c_str());
				throw LUA_RUNTIME_ERROR("search fail");
			}

			if (printf_on_)
			{
				printf(" adr=0x%08x(+0)| ofs=0x%08x(+0)| search [ ",
					byte_pos(), offset);
				for (int i = 0; i < size; ++i)
					printf("%02x ", static_cast<uint8_t>(address[i]));
				
				printf("] (\"%s\") %s at adr=0x%08x.\n",
					s.c_str(),
					offset + prev_byte == this->size() ? "not found [EOF]" : "found",
					offset + prev_byte);
			}

			return offset;
		}

		// ストリームに追記
		bool write_by_buf(const char *buf, int size)
		{
			if (FAILED("check buf", valid_ptr(buf)))
				return false;

			if (FAILED("check", size >= 0))
				return false;

			return bs_.write_by_buf(buf, size);
		}

		bool put_char(char c)
		{
			return bs_.put_char(c);
		}
		
		// 別のストリームに転送
		// 現状オーバーヘッド多め
		bool transfer_by_byte(string name, LuaGlueBitstream &stream, int size, bool advance = false)
		{
			if (FAILED("", bs_.check_offset_by_byte(size)))
				return false;

			char* buf = new char[static_cast<unsigned int>(size)];
			bs_.look_by_buf(buf, size);
			
			if (FAILED("write", stream.write_by_buf(buf, size)))
				return false;
			
			if (advance)
			{
				stringstream ss;
				ss << " >> transfer: " << name;
				read_by_byte(ss.str(), size);
			}

			return true;
		}

		// 現在位置からバイト表示
		bool dump_line(int max_size)
		{
			char buf[128];

			int dump_len = std::min<int>(bs_.size() - bs_.byte_pos(), max_size);
			dump_len = std::min<int>(dump_len, sizeof(buf));

			bs_.look_by_buf(buf, dump_len);

			return dump_line(buf, 0, dump_len);
		}

		// 現在位置からバイト表示
		bool dump_as_string(int max_size)
		{
			char buf[128];

			int dump_len = std::min<int>(bs_.size() - bs_.byte_pos(), max_size);
			dump_len = std::min<int>(dump_len, sizeof(buf));

			bs_.look_by_buf(buf, dump_len);

			return dump_as_string(buf, 0, dump_len);
		}

		// 現在位置からバイト表示
		bool dump(int max_size)
		{
			char buf[128];

			int dump_len = std::min<int>(bs_.size() - bs_.byte_pos(), max_size);
			dump_len = std::min<int>(dump_len, sizeof(buf));

			bs_.look_by_buf(buf, dump_len);

			return dump(buf, byte_pos(), dump_len);
		}
	};

	class LuaGlueBufBitstream final : public LuaGlueBitstream
	{
	private:

		shared_ptr<stringbuf> sb_;

	public:

		LuaGlueBufBitstream() :LuaGlueBitstream(){
			sb_ = make_shared<stringbuf>();
			assign(sb_);
		}

		virtual ~LuaGlueBufBitstream(){}
	};

	class LuaGlueFifoBitstream final : public LuaGlueBitstream
	{
	private:

		shared_ptr<RingBuf> rb_;

	public:

		LuaGlueFifoBitstream() :LuaGlueBitstream(){}

		virtual ~LuaGlueFifoBitstream(){}

		bool reserve(int size)
		{
			rb_ = make_shared<RingBuf>();
			rb_->reserve(size);
			return assign(rb_);
		}

		int next_byte(char c)
		{
			return LuaGlueBitstream::find_byte(c, true);
		}

		int next_byte_string(const char* address, int size)
		{
			return LuaGlueBitstream::find_byte_string(address, size, true);
		}

		// 削除
		bool seekoff_by_bit(int offset) = delete;
		bool seekoff_by_byte(int offset) = delete;
		bool seekpos_by_bit(int byte) = delete;
		bool seekpos_by_byte(int byte) = delete;
		bool seekpos(int byte, int bit) = delete;
		uint32_t look_by_bit(int size) = delete;
		uint32_t look_by_byte(int size) = delete;
		int find_byte(char c, bool advance = false) = delete;
		int find_byte_string(const char* address, int size, bool advance = false) = delete;
	};


	class LuaGlueFileBitstream final : public LuaGlueBitstream
	{
	private:
		
		shared_ptr<filebuf> fb_;

	public:

		LuaGlueFileBitstream() :LuaGlueBitstream(){}

		virtual ~LuaGlueFileBitstream()
		{
			if (fb_)
				fb_->close();
		}

		bool open(string file_name, string openmode = "r")
		{
			if (fb_)
				fb_->close();

			fb_ = make_shared<filebuf>();

			// とりあえず
			if (openmode == "w")
				fb_->open(file_name, std::ios::out | std::ios::binary);
			else // if (openmode == "r")
				fb_->open(file_name, std::ios::in | std::ios::binary);

			return assign(fb_);
		}
	};
}

using namespace std;
using namespace rf;


shared_ptr<LuaBinder> init_lua()
{
	auto lua = make_shared<LuaBinder>();

	// 関数バインド
	lua->def("stdout_to_file",   FileManager::stdout_to_file);        // コンソール出力の出力先切り替え
	lua->def("write_to_file",    FileManager::write_to_file);         // 指定したバイト列をファイルに出力
	lua->def("transfer_to_file", LuaGlueBitstream::transfer_to_file); // 指定したストリームををファイルに出力
	lua->def("reverse_16",       reverse_endian_16);                  // 16ビットエンディアン変換
	lua->def("reverse_32",       reverse_endian_32);                  // 32ビットエンディアン変換

	// std::filebufによるビットストリームクラス
	lua->def_class<LuaGlueFileBitstream>("FileBitstream")->
		def("open",             &LuaGlueFileBitstream::open).                  // ファイルオープン
		def("size",             &LuaGlueFileBitstream::size).                  // ファイルサイズ取得
		def("enable_print",     &LuaGlueFileBitstream::enable_print).          // 解析ログのON/OFF
		def("little_endian",    &LuaGlueFileBitstream::little_endian).         // ２バイト/４バイトの読み込み時はエンディアンを変換する
		def("seekpos_bit",      &LuaGlueFileBitstream::seekpos_by_bit).        // 先頭からファイルポインタ移動
		def("seekpos_byte",     &LuaGlueFileBitstream::seekpos_by_byte).       // 先頭からファイルポインタ移動
		def("seekpos",          &LuaGlueFileBitstream::seekpos).               // 先頭からファイルポインタ移動
		def("seekoff_bit",      &LuaGlueFileBitstream::seekoff_by_bit).        // 現在位置からファイルポインタ移動
		def("seekoff_byte",     &LuaGlueFileBitstream::seekoff_by_byte).       // 現在位置からファイルポインタ移動
		def("bit_pos",          &LuaGlueFileBitstream::bit_pos).               // 現在のビットオフセットを取得
		def("byte_pos",         &LuaGlueFileBitstream::byte_pos).              // 現在のバイトオフセットを取得
		def("read_bit",         &LuaGlueFileBitstream::read_by_bit).           // ビット単位で読み込み
		def("read_byte",        &LuaGlueFileBitstream::read_by_byte).          // バイト単位で読み込み
		def("read_string",      &LuaGlueFileBitstream::read_by_string).        // バイト単位で文字列として読み込み
		def("read_expgolomb",   &LuaGlueFileBitstream::read_by_expgolomb).     // 指数ごロムとしてビットを読む
		def("comp_bit",         &LuaGlueFileBitstream::compare_by_bit).        // ビット単位で比較
		def("comp_byte",        &LuaGlueFileBitstream::compare_by_byte).       // バイト単位で比較
		def("comp_string",      &LuaGlueFileBitstream::compare_by_string).     // バイト単位で文字列として比較
		def("look_bit" ,        &LuaGlueFileBitstream::look_by_bit).           // ポインタを進めないで値を取得、4byteまで
		def("look_byte",        &LuaGlueFileBitstream::look_by_byte).          // ポインタを進めないで値を取得、4byteまで
		def("find_byte",        &LuaGlueFileBitstream::find_byte).             // １バイトの一致を検索
		def("find_byte_string", &LuaGlueFileBitstream::find_byte_string).      // 数バイト分の一致を検索
		def("transfer_byte",    &LuaGlueFileBitstream::transfer_by_byte).      // 別ストリームの終端に転送
		def("write",            &LuaGlueFileBitstream::write_by_buf).          // ビットストリームの終端に書き込む
		def("put_char",         &LuaGlueFileBitstream::put_char).              // ビットストリームの終端に書き込む
		def("dump",             
			(bool(LuaGlueFileBitstream::*)(int)) &LuaGlueFileBitstream::dump); // 現在位置からバイト表示

	// std::stringbufによるビットストリームクラス
	lua->def_class<LuaGlueBufBitstream>("Buffer")->
		def("size",             &LuaGlueBufBitstream::size).              // バッファサイズ取得
		def("enable_print",     &LuaGlueBufBitstream::enable_print).      // 解析ログのON/OFF
		def("little_endian",    &LuaGlueBufBitstream::little_endian).     // ２バイト/４バイトの読み込み時はエンディアンを変換する
		def("seekpos_bit",      &LuaGlueBufBitstream::seekpos_by_bit).    // 先頭からファイルポインタ移動
		def("seekpos_byte",     &LuaGlueBufBitstream::seekpos_by_byte).   // 先頭からファイルポインタ移動
		def("seekpos",          &LuaGlueBufBitstream::seekpos).           // 先頭からファイルポインタ移動
		def("seekoff_bit",      &LuaGlueBufBitstream::seekoff_by_bit).    // 現在位置からファイルポインタ移動
		def("seekoff_byte",     &LuaGlueBufBitstream::seekoff_by_byte).   // 現在位置からファイルポインタ移動
		def("bit_pos",          &LuaGlueBufBitstream::bit_pos).           // 現在のビットオフセットを取得
		def("byte_pos",         &LuaGlueBufBitstream::byte_pos).          // 現在のバイトオフセットを取得
		def("read_bit",         &LuaGlueBufBitstream::read_by_bit).       // ビット単位で読み込み
		def("read_byte",        &LuaGlueBufBitstream::read_by_byte).      // バイト単位で読み込み
		def("read_string",      &LuaGlueBufBitstream::read_by_string).    // バイト単位で文字列として読み込み
		def("read_expgolomb",   &LuaGlueBufBitstream::read_by_expgolomb). // 指数ごロムとしてビットを読む
		def("comp_bit",         &LuaGlueBufBitstream::compare_by_bit).    // ビット単位で比較
		def("comp_byte",        &LuaGlueBufBitstream::compare_by_byte).   // バイト単位で比較
		def("comp_string",      &LuaGlueBufBitstream::compare_by_string). // バイト単位で文字列として比較
		def("look_bit" ,        &LuaGlueBufBitstream::look_by_bit).       // ポインタを進めないで値を取得、4byteまで
		def("look_byte",        &LuaGlueBufBitstream::look_by_byte).      // ポインタを進めないで値を取得、4byteまで
		def("find_byte",        &LuaGlueBufBitstream::find_byte).         // １バイトの一致を検索
		def("find_byte_string", &LuaGlueBufBitstream::find_byte_string).  // 数バイト分の一致を検索
		def("transfer_byte",    &LuaGlueBufBitstream::transfer_by_byte).  // 部分ストリーム(Bitstream)を作成
		def("write",            &LuaGlueBufBitstream::write_by_buf).      // ビットストリームの終端に書き込む
		def("put_char",         &LuaGlueBufBitstream::put_char).          // ビットストリームの終端に書き込む
		def("dump",														         	     
			(bool(LuaGlueBufBitstream::*)(int)) &LuaGlueBufBitstream::dump); // 現在位置からバイト表示

	// FIFO（リングバッファ）によるビットストリームクラスクラス
	// シーク/ダンプ系の処理はできず、ヘッド/テールの監視もないので
	// メモリに余裕がある処理なら"Buffer"クラスを使ったほうが良い
	lua->def_class<LuaGlueFifoBitstream>("Fifo")->
		def("size",             &LuaGlueFifoBitstream::size).              // 書き込み済みサイズ取得
		def("reserve",          &LuaGlueFifoBitstream::reserve).           // バッファサイズ設定、使う前に必須
		def("enable_print",     &LuaGlueFifoBitstream::enable_print).      // コンソール出力ON/OFF
		def("little_endian",    &LuaGlueFifoBitstream::little_endian).     // ２バイト/４バイトの読み込み時はエンディアンを変換する
		def("bit_pos",          &LuaGlueFifoBitstream::bit_pos).           // 現在のビットオフセットを取得
		def("byte_pos",         &LuaGlueFifoBitstream::byte_pos).          // 現在のバイトオフセットを取得
		def("read_bit",         &LuaGlueFifoBitstream::read_by_bit).       // ビット単位で読み込み
		def("read_byte",        &LuaGlueFifoBitstream::read_by_byte).      // バイト単位で読み込み
		def("read_string",      &LuaGlueFifoBitstream::read_by_string).    // バイト単位で文字列として読み込み
		def("read_expgolomb",   &LuaGlueFifoBitstream::read_by_expgolomb). // 指数ごロムとしてビットを読む
		def("comp_bit",         &LuaGlueFifoBitstream::compare_by_bit).    // ビット単位で比較
		def("comp_byte",        &LuaGlueFifoBitstream::compare_by_byte).   // バイト単位で比較
		def("comp_string",      &LuaGlueFifoBitstream::compare_by_string). // バイト単位で文字列として比較
		def("next_byte",        &LuaGlueFifoBitstream::next_byte).         // １バイトの一致を検索
		def("next_byte_string", &LuaGlueFifoBitstream::next_byte_string).  // 数バイト分の一致を検索
		def("transfer_byte",    &LuaGlueFifoBitstream::transfer_by_byte).  // 部分ストリーム(Bitstream)を作成
		def("write",            &LuaGlueFifoBitstream::write_by_buf).      // ビットストリームの終端に書き込む
		def("put_char",         &LuaGlueFifoBitstream::put_char);          // ビットストリームの終端に書き込む

	if (FAILED("check", lua->dostring("_G.argv = {}")))
	{
		ERR << "lua.dostring err" << endl;
	}

	#ifdef _MSC_VER
		if (FAILED("check", lua->dostring("_G.windows = true")))
		{
			ERR << "lua.dostring err" << endl;
		}
	#endif

	return lua;
}

void show_help()
{
	cout << "\n"
		"a.out [--arg|-a args...] [--lua|-l filename] [--help|-h]\n"
		"\n"
		"--lua  :start with file mode\n"
		"--arg  :set argument of define file\n"
		"--help :show this help" << endl;
	return;
}

int main(int argc, char** argv)
{
	string lua_file_name = "script/default.lua";

	// パス情報を取得する
	string dir;
	string path;
	if (argc>0)
	{
		#ifdef r
			path = std::regex_replace(argv[0], std::regex(R"(\\)"), "/");
			std::smatch result;
			std::regex_search(path, result, std::regex("(.*)/"));
			dir = result.str();
		#else
			path = argv[0];
			dir = "";
		#endif
		lua_file_name = dir + "script/default.lua";
	}

	// lua初期化
	auto lua = init_lua();

	// 引数適用
	int flag = 0;
	int lua_arg_count = 0;
	for (int i = 0; i < argc; ++i)
	{
		// cout << "argv[" << i << "] = " << argv[i] << endl;

		if ((string("--arg") == argv[i])
			|| (string("-a") == argv[i]))
		{
			flag = 1;
		}
		else if ((string("--lua") == argv[i])
			|| (string("-l") == argv[i]))
		{
			flag = 2;
		}
		else if ((string("--help") == argv[i])
			|| (string("-h") == argv[i]))
		{
			show_help();
			return 0;
		}
		else switch (flag)
		{
			case 0:
			{
				// パス情報を設定して引き続き引数登録に移る
				stringstream ss;
				ss << "_G.__exec_dir__=\"" << dir << '\"';
				if (FAILED("check", lua->dostring(ss.str())))
				{
					ERR << "lua.dostring err" << endl;
				}

				flag = 1;

				// fall through
			}
			case 1:
			{
				// \を/に置換
				stringstream ss;
				#ifdef _MSC_VER
					string s = std::regex_replace(argv[i], std::regex(R"(\\)"), "/");
					ss << "argv[" << lua_arg_count << "]=\"" << s << "\"" << endl;
				#else
					ss << "argv[" << lua_arg_count << "]=\"" << argv[i] << "\"" << endl;
				#endif

				if (FAILED("check", lua->dostring(ss.str())))
				{
					ERR << "lua.dostring err" << endl;
				}
				lua_arg_count++;
				break;
			}
			case 2:
			{
				lua_file_name = argv[i];
				break;
			}
			default:
			{
				show_help();
				return 0;
			}
		}
	}

	// lua実行
	// -インタプリタモード
	// -ファイルモード(引数でファイル名を指定した場合)
	if (argc == 1)
	{
		cout << "q:quit" << endl;
		for (;;)
		{
			cout << ">" << std::flush;
			string str;
			std::getline(cin, str);
			if (str == "q")
				break;

			if (FAILED("check", lua->dostring(str)))
			{
				ERR << "lua.dostring err" << endl;
			}
		};
	}
	else
	{
		cout << lua_file_name << endl;
		if (FAILED("check", lua->dofile(lua_file_name)))
		{
			ERR << "lua.dofile err" << endl;
		}

		// windowsのために入力待ちする
		cout << "press enter key.." << endl;
		getchar();
	}

	return 0;
}
