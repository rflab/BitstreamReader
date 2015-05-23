// 定義ファイルに従ってストリームを読む

#include <iostream>
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
#define nullptr NULL
#define final
#define throw(x)
#define FAILED(x) failed((x), __LINE__, __FUNCTION__, #x)
#define ERR cerr << "# c++ error. L" << dec << __LINE__ << " " << __FUNCTION__ << ": "
inline bool failed(bool b, int line, const std::string &fn, const std::string &msg)
{
	if (!b)
		std::cerr << "# c++ failed. L" << std::dec
			<< line << " " << fn << ": " << msg << std::endl;
	return !b;
}
static bool stdout_to_file(bool enable)
{
	static FILE* fp = nullptr;
	if (enable && fp == nullptr)
	{
		std::cout << "stdout to log.txt" << std::endl;

#ifdef _MSC_VER
		if (FAILED(freopen_s(&fp, "log.txt", "w", stdout) == 0))
			return false;
#else
		fp = freopen("log.txt", "w", stdout);
		if (FAILED(fp != NULL))
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
	using std::exception;
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

	inline static bool valid_ptr(const void *ptr)
	{
		return ptr != nullptr;
	}

	// バッファダンプ
	static bool dump_line(const unsigned char* buf, int offset, int size)
	{
		for (int i = 0; i < size; ++i)
		{
			printf("%02x ", buf[offset + i]);
		}
		return true;
	}

	static bool dump_line_by_char(const unsigned char* buf, int offset, int size)
	{
		for (int i = 0; i < size; ++i)
		{
			if (isalpha(buf[offset + i]))
				putchar(buf[offset + i]);
			else
				putchar('.');
		}
		return true;
	}

	static int reverse_endian_16(unsigned int value)
	{
		return ((value >> 8) & 0xff) | ((value << 8) & 0xff00);
	}

	static int reverse_endian_32(unsigned int value)
	{
		return ((value >> 24) & 0xff) | ((value >> 8) & 0xff00)
			| ((value << 8) & 0xff0000) | ((value << 24) & 0xff000000);
	}

	// file_offsetは暫定
	bool dump(const unsigned char* buf, int offset, int file_offset, int size)
	{
		printf("     offset    | +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F | 0123456789ABCDEF\n");

		int cur = offset;
		int end = offset + size;
		for (; cur + 16 <= end; cur += 16)
		{
			printf("     0x%08x| ", cur + file_offset);
			dump_line(buf, cur, 16);
			printf("| ");
			dump_line_by_char(buf, cur, 16);
			putchar('\n');
		}

		if (cur < end)
		{
			printf("     0x%08x| ", cur + file_offset);
			dump_line(buf, cur, size % 16);

			for (int i = 0; i < 16 - (size % 16); ++i)
			{
				printf("   ");
			}
			printf("| ");
			dump_line_by_char(buf, cur, end - cur);
			putchar('\n');
		}

		return true;
	}

	// 設定したバッファからビット単位でデータを読み出す
	// ビッグエンディアン固定
	// intの関係で256MBまで
	class Bitstream final
	{
	private:
		shared_ptr<unsigned char> buf_;
		int   size_;
		int   cur_byte_;
		int   cur_bit_;

	public:

		Bitstream() : size_(0), cur_byte_(0), cur_bit_(0){}//buf_ = make_shared<unsigned char>();}
		~Bitstream(){}

		shared_ptr<unsigned char> buf() { return buf_; }
		int size() const                { return size_; }
		int cur_byte() const            { return cur_byte_; }
		int cur_bit() const             { return cur_bit_; }

		bool seek_by_bit(int offset)
		{
			if (FAILED(size_ >= offset / 8 && offset >= 0))
				return false;

			cur_byte_ = offset / 8;
			cur_bit_ = offset % 8;
			return true;
		}

		bool seek_by_byte(int offset)
		{
			return  seek_by_bit(8*offset);
		}

		bool offset_by_bit(int offset)
		{
			if (FAILED(check_offset_by_bit(offset)))
				return false;

			cur_byte_ += (cur_bit_ + offset) / 8;
			cur_bit_ = ((cur_bit_ + offset) % 8) & 0x07;

			// マイナスはビットで桁下がりする
			if (offset < 0)
				--cur_byte_;

			return true;
		}

		bool assign(shared_ptr<unsigned char> buf, int size)
		{
			if (FAILED(size >= 0))
				return false;

			buf_ = buf;
			size_ = size;
			seek_by_bit(0);
			return true;
		}

		bool check_eos() const
		{
			if (cur_byte_ == size_)
			{
				cout << "[EOS]" << endl;
				return true;
			}
			return false;
		}

		bool check_offset_by_bit(int offset) const
		{
			int next_byte = cur_byte_ + (cur_bit_ + offset) / 8;
			if (size_ < next_byte || next_byte < 0)
			{
				ERR << "overrun size 0x" << hex << size_ << " <= next 0x" << next_byte << endl;
				return false;
			}
			return true;
		}

		void cut_bit()
		{
			if (cur_bit_ != 0)
			{
				++cur_byte_;
				cur_bit_ = 0;
			}
		}

		// 32bitまで
		bool read_by_bit(int size, int &ret_value)
		{
			if (FAILED(size >= 0 && 32 >= size))
			{
				ERR << "read bit size should be [0 < size < 32] but " << size << endl;
				return false;
			}

			if (FAILED(check_offset_by_bit(size)))
				return false;

			unsigned int value;
			int already_read = 0;

			// 先頭の中途半端なビットを読んでから、残りをバイトストリームとして読む
			// read_lengthが現在のバイトに収まるならビット読み出しまでで終了
			if (cur_bit_ + size < 8)
			{
				value = buf_.get()[cur_byte_];
				value >>= 8 - (cur_bit_ + size); // 下位ビットを合わせる
				value &= ((1 << size) - 1); // 上位ビットを捨てる
				offset_by_bit(size);
				ret_value = value;
				return true;
			}
			else
			{
				int remained_bit = 8 - cur_bit_;
				value = buf_.get()[cur_byte_] & ((1 << remained_bit) - 1);
				offset_by_bit(remained_bit);
				already_read += remained_bit;
			}

			while (size > already_read)
			{
				if (size - already_read < 8)
				{
					value <<= (size - already_read);
					value |= buf_.get()[cur_byte_] >> (8 - (size - already_read));
					offset_by_bit(size - already_read);
					break;
				}
				else
				{
					value <<= 8;
					value |= buf_.get()[cur_byte_];
					offset_by_bit(8);
					already_read += 8;
				}
			}

			ret_value = value;
			return true;
		}

		bool read_by_byte(int size, int &ret_value)
		{
			return read_by_bit(size, ret_value);
		}

		// NULL文字が先に見つかった場合はその分だけポインタを進める
		// NULL文字が見つからなかった場合は最大max_lengthの長さ文字列として終端にNULL文字を入れる
		bool read_by_string(int max_length, string &ret_str)
		{
			if (FAILED(check_offset_by_bit(8 * max_length)))
				return false;

			if (FAILED(cur_bit_ == 0))
			{
				ERR << "cur_bit is not 0." << endl;
				return false;
			}

			int length = 0;
			auto result = std::find(&buf_.get()[cur_byte_], &buf_.get()[cur_byte_ + max_length], (unsigned char)'\0');
			if (result != &buf_.get()[cur_byte_ + max_length])
				length = result - &buf_.get()[cur_byte_] + 1;
			else
				length = max_length;

			char* p = reinterpret_cast<char*>(&buf_.get()[cur_byte_]);
			ret_str.assign(p, length); // NULL文字含んでアサインする場合もある

			if (FAILED(offset_by_bit(8 * length)))
			{
				ERR << "read_by_string error" << endl;
				return false;
			}

			return true;
		}

		bool search_byte(char c, int &ret_offset, int start_offset = 0, bool advance = true)
		{

			// エラーチェック前に現在のbitを切り上げる
			cut_bit();

			if (FAILED(check_offset_by_bit(start_offset * 8)))
				return false;

			auto result = std::find(&buf_.get()[cur_byte_ + start_offset], &buf_.get()[size_], (unsigned char)c);
			if (FAILED(result != &buf_.get()[size_]))
			{
				return false;
			}

			ret_offset = result - &buf_.get()[cur_byte_];
			if (advance)
				cur_byte_ += ret_offset;

			return true;
		}

		bool search_byte_string(const char* address, int size, int &ret_offset)
		{
			if (FAILED(valid_ptr(address)))
				return false;

			int offset = 0;
			for (;;)
			{
				if (FAILED(search_byte(address[0], offset, offset, false)))
					return false;

				if (FAILED(cur_byte_ + offset + size <= size_))
					return false;

				if (std::memcmp(&buf_.get()[cur_byte_ + offset], address, size) == 0)
				{
					ret_offset = offset;
					cur_byte_ += offset;
					return true;
				}

				// 見つからなかったなら位置バイト先から再挑戦
				++offset;
			}
		}
	};


	class FileBitstream final
	{
	private:

		// 一度に読み込むサイズ5MB
		// static const int BUF_SIZE = 5 * 1024 * 1024;
		enum{ BUF_SIZE = 5 * 1024 * 1024 };

		Bitstream wa_; // work area
		string    file_name_;
		ifstream  ifs_;
		int       file_size_;
		int       file_offset_;
		int       file_bufferd_size_;

	public:

		FileBitstream()
			:file_name_(""), file_size_(0), file_offset_(0), file_bufferd_size_(0)
		{
			wa_.assign(
				shared_ptr<unsigned char>(new unsigned char[BUF_SIZE]), BUF_SIZE);
		}

		FileBitstream(const string& file_name)
			:file_size_(0), file_offset_(0), file_bufferd_size_(0)
		{
			wa_.assign(
				shared_ptr<unsigned char>(new unsigned char[BUF_SIZE]), BUF_SIZE);

			open(file_name);
		}

		~FileBitstream(){}

		Bitstream&   work_area()	          { return wa_; };
		int cur_byte()          const{ return wa_.cur_byte() + file_offset_; }
		int cur_bit()           const{ return wa_.cur_bit(); }
		int file_size()         const{ return file_size_; };
		int file_offset()       const{ return file_offset_; };
		int file_bufferd_size() const{ return file_bufferd_size_; };

		bool open(const string& file_name)
		{
			// 別ファイルを開く場合、あまり良くないけど許可する
			if (ifs_)
				ifs_.close();

			ifs_.open(file_name, std::ios::in | std::ios::binary);
			if (!ifs_)
			{
				ERR << "open read file [" << file_name << "]" << endl;
				return false;
			}

			file_name_ = file_name;

			ifs_.seekg(0, std::ios::end);
			file_size_ = static_cast<int>(ifs_.tellg());
			ifs_.seekg(0, std::ios::beg);

			return ifs_.good() && update_stream(0, BUF_SIZE);
		}

		bool close()
		{
			if (ifs_)
				ifs_.close();

			file_name_ = "";
			file_size_ = 0;
			file_offset_ = 0;
			file_bufferd_size_ = 0;

			return ifs_.good();
		}

		// 指定した範囲を含むようにファイルをバッファに展開する
		// 現在のバッファで十分ならなにもしない、
		// 現在のバッファで足りないカーソル位置をバッファ先頭になるように更新する
		bool update_stream(int file_offset, int size)
		{
			if (FAILED(size >= 0 && file_offset >= 0))
				return false;

			if (FAILED(size <= BUF_SIZE))
			{
				ERR << "too big data size ofs=" << file_offset << " siz=" << size << endl;
				return false;
			}

			// 後方シークはもっとoffsetを手前にしたほうがうまくいくはず
			// とりあえず処理を同じにする
			if ((file_offset < file_offset_)
				|| (file_offset_ + file_bufferd_size_ < file_offset + size))
			{
				file_offset_ = file_offset;

				ifs_.seekg(file_offset_, std::ios::beg);
				file_bufferd_size_ = min<int>(BUF_SIZE, file_size_ - file_offset_);
				ifs_.read(reinterpret_cast<char*>(wa_.buf().get()), file_bufferd_size_);

				wa_.assign(wa_.buf(), file_bufferd_size_);
				// cout << "# load stream cur=0x" << hex << file_offset << " siz=0x" << file_bufferd_size_ << endl;
			}

			return true;
		}

		// 
		bool seek(int byte)
		{
			if (FAILED(byte >= 0))
			{
				ERR << "seek arg error" << endl;
				return false;
			}

			if (FAILED(update_stream(byte, 0)))
				return false;

			//return wa_.seek_by_bit(8 * (byte - file_offset_) + bit);
			return wa_.seek_by_byte(byte - file_offset_);
		}

		bool offset_by_bit(int offset)
		{
			int next_byte = cur_byte() + ((cur_bit() + offset) / 8);
			if (cur_bit() + offset < 0)
				next_byte--;
			if (FAILED(update_stream(next_byte, 0)))
				return false;

			return wa_.offset_by_bit(
				((next_byte - cur_byte()) * 8) + (offset % 8));
		}

		bool read_by_bit(int size, int& ret_value)
		{
			update_stream(cur_byte(), (size + 7) / 8);
			return wa_.read_by_bit(size, ret_value);
		}

		bool read_by_string(int max_length, string& ret_str)
		{
			update_stream(cur_byte(), max_length);
			return wa_.read_by_string(max_length, ret_str);
		}

		bool search_byte(char c, int& ret_offset, int limit = 1024 * 1024)
		{
			int search_size = min<int>(limit, file_size_ - cur_byte());
			update_stream(cur_byte(), search_size);
			return wa_.search_byte(c, ret_offset);
		}

		bool search_byte_string(const char* address, int size, int& ret_offset, int limit = 1024 * 1024)
		{
			if (FAILED(valid_ptr(address)))
				return false;

			int search_size = min<int>(limit, file_size_ - cur_byte());
			update_stream(cur_byte(), search_size);
			return wa_.search_byte_string(address, size, ret_offset);
		}

	};

	class LuaGlueBitstream final
	{
	private:
		Bitstream bs_;
		bool      printf_on_;
		bool      little_endian_;
		map<string, shared_ptr<ofstream> > ofs_map_; // 暫定、出力ファイル名保存先

	public:
		LuaGlueBitstream() :printf_on_(true), little_endian_(false){}
		int cur_byte()                  { return bs_.cur_byte(); }
		int cur_bit()                   { return bs_.cur_bit(); }
		int size()                      { return bs_.size(); }
		void enable_print(bool enable)  { printf_on_ = enable; }
		void little_endian(bool enable_){ little_endian_ = enable_; }

		bool assign(shared_ptr<unsigned char> buf, int size)
		{
			if (FAILED(size >= 0))
			{
				ERR << "assign size error." << endl;
				return false;
			}

			return bs_.assign(buf, size);
		}

		bool dump_line(int byte_size)
		{
			if (FAILED(bs_.cur_byte() + byte_size <= bs_.size()))
			{
				ERR << "dump file size over" << endl;
				return false;
			}

			return ::rf::dump_line(bs_.buf().get(), bs_.cur_byte(), byte_size);
		}

		bool dump(int max_size)
		{
			max_size = std::min<int>(max_size, bs_.size() - bs_.cur_byte());
			return ::rf::dump(bs_.buf().get(), bs_.cur_byte(), 0, max_size);
		}


		int read_by_bit(string name, int size) throw(...)
		{
			int prev_byte = bs_.cur_byte();
			int prev_bit = bs_.cur_bit();

			if (size > 32)
			{
				if (FAILED(bs_.offset_by_bit(size)))
					throw LUA_RUNTIME_ERROR;

				if (printf_on_ || (name[0] == '#'))
				{
					int dump_len = std::min<int>(16, size / 8);

					printf(" adr=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | ",
						prev_byte, prev_bit, size / 8, size % 8, name.c_str());
					::rf::dump_line(bs_.buf().get(), prev_byte, dump_len);

					if (16 > dump_len)
						putchar('\n');
					else
						printf(" ...\n");
				}

				return 0;
			}
			else
			{
				int v;
				if (FAILED(bs_.read_by_bit(size, v)))
					throw LUA_RUNTIME_ERROR;

				if (little_endian_)
				{
					if (size == 32)
						v = reverse_endian_32(v);
					else if (size == 16)
						v = reverse_endian_16(v);
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

		int read_by_byte(string name, int size) throw(...)
		{
			return read_by_bit(name, 8 * size);
		}

		string read_by_string(string name, int max_length) throw(...)
		{
			int prev_byte = bs_.cur_byte();
			int prev_bit = bs_.cur_bit();

			// 面倒なので文字列はバイトストリームになっていなければエラー
			string str;
			if (FAILED(bs_.read_by_string(max_length, str)))
				throw LUA_RUNTIME_ERROR;

			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%08x(+%d)| siz=0x%08x(+0)| %-40s | str=\"%s\"\n",
					prev_byte, prev_bit, str.length(), name.c_str(), str.c_str());
			}

			return str;
		}

		int compare_by_bit(string name, int size, int compvalue) throw(...)
		{
			int value = read_by_bit(name, size);
			if (value != compvalue)
			{
				printf("# compare value: 0x%08x(%d) != 0x%08x(%d)\n",
					value, value, compvalue, compvalue);

				throw LUA_RUNTIME_ERROR;
			}
			return value;
		}

		int compare_by_byte(string name, int size, int compvalue) throw(...)
		{
			return compare_by_bit(name, 8 * size, compvalue);
		}

		string compare_by_string(string name, int max_length, string comp_str) throw(...)
		{
			string str = read_by_string(name, max_length);
			if (str != comp_str)
			{
				printf("# compare string: \"%s\" != \"%s\"\n", str.c_str(), comp_str.c_str());
				throw LUA_RUNTIME_ERROR;
			}
			return str;
		}

		int search_byte(char c) throw(...)
		{
			int offset;

			if (FAILED(bs_.search_byte(c, offset)))
			{
				printf("# can not find byte:0x%x\n", (unsigned char)c);
				throw LUA_RUNTIME_ERROR;
			}

			if (printf_on_)
			{
				printf(" adr=0x%08x(+0)| ofs=0x%08x(+0)| search '0x%02x' found.\n",
					bs_.cur_byte(), offset, (unsigned char)c);
			}

			return offset;
		}

		int search_byte_string(const char* address, int size) throw(...)
		{
			if (FAILED(valid_ptr(address)))
				return false;

			string s((char*)address, size);
			int offset;

			if (FAILED(bs_.search_byte_string(address, size, offset)))
			{
				printf("# can not find byte string: %s\n", s.c_str());
				throw LUA_RUNTIME_ERROR;
			}

			if (printf_on_)
			{
				printf(" adr=0x%08x(+0)| ofs=0x%08x(+0)| search [ ",
					bs_.cur_byte(), offset);
				for (int i = 0; i < size; ++i)
					printf("%02x ", (unsigned char)address[i]);
				printf("] (\"%s\") found.\n", s.c_str());
			}

			return offset;
		}

		bool seek(int byte)
		{
			return bs_.seek_by_byte(byte);
		}

		bool offset_by_bit(int offset)
		{
			return bs_.offset_by_bit(offset);
		}

		bool offset_by_byte(int offset)
		{
			return offset_by_bit(8 * offset);
		}

		// ファイル名に応じて読み込んだデータを出力して
		// 暫定で毎回ファイルを開く
		bool write(string file_name, const char* address, int size)
		{
			if (FAILED(valid_ptr(address)))
				return false;

			shared_ptr<ofstream> ofs;
			auto it = ofs_map_.find(file_name);
			if (it == ofs_map_.end())
			{
				ofs = make_shared<ofstream>();
				ofs_map_.insert(std::make_pair(file_name, ofs));

				std::ios::openmode mode = std::ios::binary | std::ios::out;
				ofs->open(file_name, mode);
				if (!ofs)
				{
					ERR << "file open error:" << file_name << endl;
					throw LUA_RUNTIME_ERROR;
				}
			}
			else
			{
				ofs = it->second;
			}

			ofs->write(address, size);
			if (ofs->fail())
			{
				ERR << "ofs error" << endl;
				throw LUA_RUNTIME_ERROR;
			}

			return true;
		}

		// ビットストリームからコピー
		// bool output_byte(ofstream& file_name, int byte_offset, int byte_size)
		bool copy_by_byte(string file_name, int size)
		{
			char* p = reinterpret_cast<char*>(bs_.buf().get());
			write(file_name, &p[bs_.cur_byte()], size);

			stringstream ss;
			ss << " >> " << file_name;
			read_by_byte(ss.str(), size);
			return true;
		}
	};

	class LuaGlueFileBitstream final
	{
	private:

		FileBitstream                      fs_;
		bool                               printf_on_;
		bool                               little_endian_;
		map<string, shared_ptr<ofstream> > ofs_map_; // 暫定、出力ファイル名保存先

	public:
		LuaGlueFileBitstream() :printf_on_(true), little_endian_(false){}

		~LuaGlueFileBitstream()
		{
			//for (auto c : ofs_map_)
			//{
			//	c.second.close();
			//	if (c.second.fail())
			//	{
			//		ERR << c.first << "close fail" << endl;
			//	}
			//}
			for (auto it = ofs_map_.begin(); it != ofs_map_.end(); ++it)
			{
				it->second->close();
				if (it->second->fail())
				{
					ERR << it->first << "close fail" << endl;
				}
			}
		}

		int cur_byte()                  { return fs_.cur_byte(); }
		int cur_bit()                   { return fs_.cur_bit(); }
		int file_size()                 { return fs_.file_size(); }
		void enable_print(bool enable)  { printf_on_ = enable; }
		void little_endian(bool enable_){ little_endian_ = enable_; }

		bool open(string filename)
		{
			return fs_.open(filename);
		}

		bool dump_line(int byte_size)
		{
			if (FAILED(fs_.cur_byte() + byte_size <= fs_.file_size()))
			{
				ERR << "dump file size over" << endl;
				return false;
			}

			auto wa = fs_.work_area();
			return ::rf::dump_line(wa.buf().get(), wa.cur_byte(), byte_size);
		}

		bool dump(int max_size)
		{
			max_size = std::min<int>(max_size, fs_.file_size() - fs_.cur_byte());
			auto wa = fs_.work_area();
			return ::rf::dump(wa.buf().get(), wa.cur_byte(), fs_.file_offset(), max_size);
		}


		int read_by_bit(string name, int size) throw(...)
		{
			int prev_byte = fs_.work_area().cur_byte();
			int prev_bit = fs_.work_area().cur_bit();

			if (size > 32)
			{
				if (FAILED(fs_.offset_by_bit(size)))
					throw LUA_RUNTIME_ERROR;

				if (printf_on_ || (name[0] == '#'))
				{
					int dump_len = std::min<int>(16, size / 8);

					printf(" adr=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | ",
						prev_byte, prev_bit, size / 8, size % 8, name.c_str());
					::rf::dump_line(fs_.work_area().buf().get(), prev_byte, dump_len);

					if (16 > dump_len)
						putchar('\n');
					else
						printf(" ...\n");
				}

				return 0;
			}
			else
			{
				int v;
				if (FAILED(fs_.read_by_bit(size, v)))
					throw LUA_RUNTIME_ERROR;

				if (little_endian_)
				{
					if (size == 32)
						v = reverse_endian_32(v);
					else if (size == 16)
						v = reverse_endian_16(v);
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

		int read_by_byte(string name, int size) throw(...)
		{
			return read_by_bit(name, 8 * size);
		}

		string read_by_string(string name, int max_length) throw(...)
		{
			int prev_byte = fs_.cur_byte();
			int prev_bit = fs_.cur_bit();

			// 面倒なので文字列はバイトストリームになっていなければエラー
			string str;
			if (FAILED(fs_.read_by_string(max_length, str)))
				throw LUA_RUNTIME_ERROR;

			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%08x(+%d)| siz=0x%08x(+0)| %-40s | str=\"%s\"\n",
					prev_byte, prev_bit, str.length(), name.c_str(), str.c_str());
			}

			return str;
		}

		int compare_by_bit(string name, int size, int compvalue) throw(...)
		{
			int value = read_by_bit(name, size);
			if (value != compvalue)
			{
				printf("# compare value: 0x%08x(%d) != 0x%08x(%d)\n",
					value, value, compvalue, compvalue);

				throw LUA_RUNTIME_ERROR;
			}
			return value;
		}

		int compare_by_byte(string name, int size, int compvalue) throw(...)
		{
			return compare_by_bit(name, 8 * size, compvalue);
		}

		string compare_by_string(string name, int max_length, string comp_str) throw(...)
		{
			string str = read_by_string(name, max_length);
			if (str != comp_str)
			{
				printf("# compare string: \"%s\" != \"%s\"\n", str.c_str(), comp_str.c_str());
				throw LUA_RUNTIME_ERROR;
			}
			return str;
		}

		int search_byte(char c) throw(...)
		{
			int offset;

			if (FAILED(fs_.search_byte(c, offset)))
			{
				printf("# can not find byte:0x%x\n", (unsigned char)c);
				throw LUA_RUNTIME_ERROR;
			}

			if (printf_on_)
			{
				printf(" adr=0x%08x(+0)| ofs=0x%08x(+0)| search '0x%02x' found.\n",
					fs_.cur_byte(), offset, (unsigned char)c);
			}

			return offset;
		}

		int search_byte_string(const char* address, int size) throw(...)
		{
			if (FAILED(valid_ptr(address)))
			{
				ERR << "invalid pointer." << endl;
				throw LUA_RUNTIME_ERROR;
			}

			string s((char*)address, size);
			int offset;

			if (FAILED(fs_.search_byte_string(address, size, offset)))
			{
				printf("# can not find byte string: %s\n", s.c_str());
				throw LUA_RUNTIME_ERROR;
			}

			if (printf_on_)
			{
				printf(" adr=0x%08x(+0)| ofs=0x%08x(+0)| search [ ",
					fs_.cur_byte(), offset);
				for (int i = 0; i < size; ++i)
					printf("%02x ", (unsigned char)address[i]);
				printf("] (\"%s\") found.\n", s.c_str());
			}

			return offset;
		}

		bool seek(int byte)
		{
			return fs_.seek(byte);
		}

		bool offset_by_bit(int offset)
		{
			return fs_.offset_by_bit(offset);
		}

		bool offset_by_byte(int offset)
		{
			return offset_by_bit(8 * offset);
		}

		// ファイル名に応じて読み込んだデータを出力して
		// 暫定で毎回ファイルを開く
		bool write(string file_name, const char* address, int size)
		{
			if (FAILED(valid_ptr(address)))
				return false;

			shared_ptr<ofstream> ofs;
			auto it = ofs_map_.find(file_name);
			if (it == ofs_map_.end())
			{
				ofs = make_shared<ofstream>();
				ofs_map_.insert(std::make_pair(file_name, ofs));

				std::ios::openmode mode = std::ios::binary | std::ios::out;
				ofs->open(file_name, mode);
				if (!ofs)
				{
					ERR << "file open error:" << file_name << endl;
					return false;
				}
			}
			else
			{
				ofs = it->second;
			}

			ofs->write(address, size);
			if (ofs->fail())
			{
				ERR << "ofs error" << endl;
				return false;
			}

			return true;
		}

		// ビットストリームからコピー
		// bool output_byte(ofstream& file_name, int byte_offset, int byte_size)
		bool copy_by_byte(string file_name, int size)
		{
			if (FAILED(fs_.update_stream(fs_.cur_byte(), size)))
				return false;

			char* p = reinterpret_cast<char*>(fs_.work_area().buf().get());
			write(file_name, &p[fs_.work_area().cur_byte()], size);

			stringstream ss;
			ss << " >> " << file_name;
			read_by_byte(ss.str(), size);
			return true;
		}

		bool sub_stream(LuaGlueBitstream &stream, int size)
		{
			auto sbuf = shared_ptr<unsigned char>(new unsigned char[size]);
			char* p = reinterpret_cast<char*>(fs_.work_area().buf().get());
			memcpy(sbuf.get(), &p[fs_.work_area().cur_byte()], size);

			return stream.assign(sbuf, size);
		}
	};

	shared_ptr<::rf::LuaBinder> init_lua()
	{
		auto lua = make_shared<rf::LuaBinder>();

		// 関数バインド
		lua->def("stdout_to_file", stdout_to_file);            // コンソール出力の出力先切り替え
		lua->def("reverse_16",     reverse_endian_16);         // 16ビットエンディアン変換
		lua->def("reverse_32",     reverse_endian_32);         // 32ビットエンディアン変換

		// クラスバインド
		lua->def_class<LuaGlueBitstream>("Bitstream")->
			def("file_size",             &LuaGlueBitstream::size).               // 解析ファイルサイズ取得
			def("enable_print",          &LuaGlueBitstream::enable_print).       // コンソール出力ON/OFF
			def("little_endian",         &LuaGlueBitstream::little_endian).      // ２バイト/４バイトの読み込み時はエンディアンを変換する
			def("seek",                  &LuaGlueBitstream::seek).               // 先頭からファイルポインタ移動
			def("offset_bit",            &LuaGlueBitstream::offset_by_bit).      // 現在位置からファイルポインタ移動
			def("offset_byte",           &LuaGlueBitstream::offset_by_byte).     // 現在位置からファイルポインタ移動
			def("dump",                  &LuaGlueBitstream::dump).               // 現在位置からバイト表示
			def("cur_bit",               &LuaGlueBitstream::cur_bit).            // 現在のビットオフセットを取得
			def("cur_byte",              &LuaGlueBitstream::cur_byte).           // 現在のバイトオフセットを取得
			def("read_bit",              &LuaGlueBitstream::read_by_bit).        // ビット単位で読み込み
			def("read_byte",             &LuaGlueBitstream::read_by_byte).       // バイト単位で読み込み
			def("read_string",           &LuaGlueBitstream::read_by_string).     // バイト単位で文字列として読み込み
			def("comp_bit",              &LuaGlueBitstream::compare_by_bit).     // ビット単位で比較
			def("comp_byte",             &LuaGlueBitstream::compare_by_byte).    // バイト単位で比較
			def("comp_string",           &LuaGlueBitstream::compare_by_string).  // バイト単位で文字列として比較
			def("search_byte",           &LuaGlueBitstream::search_byte).        // １バイトの一致を検索
			def("search_byte_string",    &LuaGlueBitstream::search_byte_string). // 数バイト分の一致を検索
			def("copy_byte",             &LuaGlueBitstream::copy_by_byte).       // ストリームからファイルに出力
			def("write",                 &LuaGlueBitstream::write);              // 指定したバイト列をファイルに出力

		lua->def_class<LuaGlueFileBitstream>("FileBitstream")->
			def("open",                  &LuaGlueFileBitstream::open).               // 解析ファイルオープン
			def("file_size",             &LuaGlueFileBitstream::file_size).          // 解析ファイルサイズ取得
			def("enable_print",          &LuaGlueFileBitstream::enable_print).       // コンソール出力ON/OFF
			def("little_endian",         &LuaGlueFileBitstream::little_endian).      // ２バイト/４バイトの読み込み時はエンディアンを変換する
			def("seek",                  &LuaGlueFileBitstream::seek).               // 先頭からファイルポインタ移動
			def("offset_bit",            &LuaGlueFileBitstream::offset_by_bit).      // 現在位置からファイルポインタ移動
			def("offset_byte",           &LuaGlueFileBitstream::offset_by_byte).     // 現在位置からファイルポインタ移動
			def("dump",                  &LuaGlueFileBitstream::dump).               // 現在位置からバイト表示
			def("cur_bit",               &LuaGlueFileBitstream::cur_bit).            // 現在のビットオフセットを取得
			def("cur_byte",              &LuaGlueFileBitstream::cur_byte).           // 現在のバイトオフセットを取得
			def("read_bit",              &LuaGlueFileBitstream::read_by_bit).        // ビット単位で読み込み
			def("read_byte",             &LuaGlueFileBitstream::read_by_byte).       // バイト単位で読み込み
			def("read_string",           &LuaGlueFileBitstream::read_by_string).     // バイト単位で文字列として読み込み
			def("comp_bit",              &LuaGlueFileBitstream::compare_by_bit).     // ビット単位で比較
			def("comp_byte",             &LuaGlueFileBitstream::compare_by_byte).    // バイト単位で比較
			def("comp_string",           &LuaGlueFileBitstream::compare_by_string).  // バイト単位で文字列として比較
			def("search_byte",           &LuaGlueFileBitstream::search_byte).        // １バイトの一致を検索
			def("search_byte_string",    &LuaGlueFileBitstream::search_byte_string). // 数バイト分の一致を検索
			def("copy_byte",             &LuaGlueFileBitstream::copy_by_byte).       // ストリームからファイルに出力
			def("write",                 &LuaGlueFileBitstream::write).              // 指定したバイト列をファイルに出力
			def("sub_stream",            &LuaGlueFileBitstream::sub_stream);         // 部分ストリームを作成

	
		if (FAILED(lua->dostring("_G.argv = {}")))
		{
			ERR << "lua.dostring err" << endl;
		}

		return lua;
	}
}

using namespace std;

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

	// lua初期化
	auto lua = rf::init_lua();

	// 引数適用
	int flag = 1;
	int lua_arg_count = 0;
	for (int i = 1; i < argc; ++i)
	{
		if ((string("--arg") == argv[i])
		||  (string("-a") == argv[i]))
		{
			flag = 1;
		}
		else if ((string("--lua") == argv[i])
		||	     (string("-l") == argv[i]))
		{
			flag = 2;
		}
		else if ((string("--help") == argv[i])
		||       (string("-h") == argv[i]))
		{
			show_help();
			return 0;
		}
		else switch (flag)
		{
			case 1:
			{
				lua_arg_count++;

				// \を/に置換
				string s = std::regex_replace(argv[i], std::regex(R"(\\)"), "/");
				stringstream ss;
				ss << "argv[" << lua_arg_count << "]=\"" << s << "\"" << endl;
				if (FAILED(lua->dostring(ss.str())))
				{
					ERR << "lua.dostring err" << endl;
				}
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

			if (FAILED(lua->dostring(str)))
			{
				ERR << "lua.dostring err" << endl;
			}
		};
	}
	else
	{
		if (FAILED(lua->dofile(lua_file_name)))
		{
			ERR << "lua.dofile err" << endl;
		}

		// windowsのために入力待ちする
		cout << "press any key.." << endl;
		getchar();
	}
	
	stdout_to_file(false);	// 一応
	return 0;
}

