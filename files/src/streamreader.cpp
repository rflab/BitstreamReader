// ビットストリームクラスをバインドしてLuaを起動する
// 引数がなければscript/default.luaを起動する
// $> / a.out test.wav

#include <stdint.h>
#include <iostream>
#include <iomanip>
#include <vector>
#include <array>
#include <stack>
#include <map>
#include <memory>
#include <utility>
//#include <thread>
//#include <future>
#include <sstream>
#include <fstream>
#include <algorithm>
#include <regex>
#include <cctype>
#include <cstring>

#include "luabinder.hpp"

// config、デバッグ、環境依存
//#define FAILED(...) __VA_ARGS__
#define FAILED(...) ::rf::failed((__VA_ARGS__), __LINE__, __FUNCTION__, #__VA_ARGS__)
#define ERR cerr << "# c++ error. L" << dec << __LINE__ << " " << __FUNCTION__ << ": "
#ifdef _MSC_VER
#else
#define nullptr NULL
#define final
#define throw(x)
#define make_unique make_shared
#define unique_ptr shared_ptr
#endif

namespace rf
{
	using std::vector;
	using std::stack;
	using std::array;
	using std::map;
	using std::pair;
	using std::tuple;
	using std::string;
	using std::unique_ptr;
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
	using std::make_unique;
	using std::make_tuple;
	using std::tie;
	using std::cout;
	using std::cin;
	using std::cerr;
	using std::endl;
	using std::hex;
	using std::dec;
	using std::min;

	inline bool failed(bool b, int line, const std::string &fn, const std::string &exp)
	{
		if (!b)
			std::cerr << "# c++ L." << std::dec
			<< line << " " << fn << ": failed [ " << exp << " ]" << std::endl;
		return !b;
	}

	inline static bool valid_ptr(const void *p)
	{
		return p != nullptr;
	}

	template<class T>
	inline static bool valid_ptr(const unique_ptr<T> p)
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
		static map<string, unique_ptr<ofstream> > ofs_map_;

		FileManager(){}
		FileManager(const FileManager &){}
		FileManager &operator=(const FileManager &){ return *this; }

		~FileManager()
		{
#if 1
			for (auto it = ofs_map_.begin(); it != ofs_map_.end(); ++it)
			{
				it->second->close();
				if (it->second->fail())
				{
					ERR << it->first << "close fail" << endl;
				}
			}
#else
			for (auto c : ofs_map_)
			{
				c.second->close();
				if (c.second->fail())
				{
					ERR << c.first << "close fail" << endl;
				}
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

		// 指定したバイト列を指定したファイル名に出力、二度目以降は追記
		static bool write_to_file(const char* file_name, const char* address, int size)
		{
			if (FAILED(valid_ptr(address)))
				return false;

			auto it = ofs_map_.find(file_name);
			if (it == ofs_map_.end())
			{
				auto ofs = make_unique<ofstream>();
				ofs->open(file_name, ios::binary | ios::out);
				if (FAILED(!(!ofs)))
					return false;

				auto ins = ofs_map_.insert(std::make_pair(file_name, std::move(ofs)));
				if (FAILED(ins.second == true))
					return false;

				it = ins.first;
			}

			it->second->write(address, size);
			if (FAILED(!it->second->fail()))
			{
				ERR << "file write " << file_name << endl;
				return false;
			}
			return true;
		}

		// printfの出力先を変更する
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
	};

	map<string, unique_ptr<ofstream> > FileManager::ofs_map_;

	class Bitstream
	{
	private:

		unique_ptr<streambuf> buf_;
		int size_;
		int bit_pos_;
		int byte_pos_;

	protected:

		// メンバ変数にstreambufを同期する
		bool sync()
		{
			// リングバッファの場合のように、必ずしもstreambuf上のいちとbyte_posは同じにならない
			// return byte_pos_ == buf_->pubseekpos(byte_pos_);
			buf_->pubseekpos(byte_pos_);
			return true;
		}

	public:

		Bitstream() : size_(0), bit_pos_(0), byte_pos_(0){}

		// このBitstreamの現在サイズ
		int size() const { return size_; }

		// 読み取りヘッダのビット位置
		int bit_pos() const { return bit_pos_; }

		// 読み取りヘッダのバイト位置
		int byte_pos() const { return byte_pos_; }

		// 読み込み対象のstreambufを設定する
		// サイズの扱いをもっとねらないとだめだかなぁ
		//template<typename Deleter>
		bool assign(unique_ptr<streambuf>&& buf, int size)
		{
			buf_ = std::move(buf);
			byte_pos_ = 0;
			bit_pos_ = 0;
			size_ = size;

			return sync();
		}

		// ストリームにデータを追記する
		bool write_byte_string(const char *buf, int size)
		{
			if (FAILED(size >= 0))
				return false;

			buf_->sputn(buf, size);
			size_ += size;

			return true;
		}

		// ストリームに１バイト追記する
		bool put_char(char c)
		{
			++size_;
			return c == buf_->sputc(c);
		}

		// ビット単位でストリーム内か判定
		bool check_bit(int bit) const
		{
			if (!((0 <= bit) && ((bit + 7) / 8 <= size_)))
				return false;
			return true;
		}

		// バイト単位でストリーム内か判定
		bool check_byte(int byte) const
		{
			if (!((0 <= byte) && (byte <= size_)))
				return false;
			return true;
		}

		// ビット単位で現在位置＋offsetがストリーム内か判定
		bool check_offset_bit(int offset) const
		{
			if (!(check_bit(byte_pos_ * 8 + bit_pos_ + offset)))
				return false;
			return true;
		}

		// バイト単位で現在位置＋offsetがストリーム内か判定
		bool check_offset_byte(int offset) const
		{
			if (!(check_byte(byte_pos_ + offset)))
				return false;
			return true;
		}

		// 読み込みヘッダを移動
		bool seekpos(int byte, int bit)
		{
			if (FAILED(check_byte(byte)))
				return false;

			if (FAILED((0 >= bit) && (bit < 8)))
				return false;

			byte_pos_ = byte;
			bit_pos_ = bit;

			return sync();
		}

		// ビット単位で読み込みヘッダを移動
		bool seekpos_bit(int offset)
		{
			if (FAILED(check_bit(offset)))
				return false;

			byte_pos_ = offset / 8;
			bit_pos_ = offset % 8;

			return sync();
		}

		// バイト単位で読み込みヘッダを移動
		bool seekpos_byte(int offset)
		{
			return seekpos(offset, 0);
		}

		// 読み込みヘッダを移動
		bool seekoff(int byte, int bit)
		{
			if (FAILED(check_bit(byte * 8 + bit)))
				return false;

			byte_pos_ += byte;
			bit_pos_ += bit;

			return sync();
		}

		// ビット単位で読み込みヘッダを移動
		bool seekoff_bit(int offset)
		{
			if (FAILED(check_offset_bit(offset)))
				return false;

			byte_pos_ += (bit_pos_ + offset) / 8;
			if ((bit_pos_ + offset) < 0)
				--byte_pos_;

			bit_pos_ = (bit_pos_ + offset) & 0x07;

			return sync();
		}

		// バイト単位で読み込みヘッダを移動
		bool seekoff_byte(int offset)
		{
			if (FAILED((bit_pos_ & 0x7) == 0))
				return false;

			if (FAILED(check_offset_byte(offset)))
				return false;

			byte_pos_ += offset;

			return sync();
		}

		// ビット単位で読み込み
		bool read_bit(int size, uint32_t &ret_value)
		{
			if (FAILED(0 <= size && size <= 32))
			{
				ERR << "read bit > 32. size=" << hex << size << ", at "
					<< byte_pos_ << "(+" << bit_pos_ << ')' << endl;
				return false;
			}

			if (FAILED(check_offset_bit(size)))
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
				seekoff_bit(size);
				ret_value = value;
				return true;
			}
			else
			{
				int remained_bit = 8 - bit_pos_;
				value = buf_->sbumpc() & ((1 << remained_bit) - 1);
				seekoff_bit(remained_bit);
				already_read += remained_bit;
			}

			while (size > already_read)
			{
				if (size - already_read < 8)
				{
					value <<= (size - already_read);
					value |= buf_->sgetc() >> (8 - (size - already_read));
					seekoff_bit(size - already_read);
					break;
				}
				else
				{
					value <<= 8;
					value |= buf_->sbumpc();
					seekoff_bit(8);
					already_read += 8;
				}
			}

			ret_value = value;
			return true;
		}

		// バイト単位で読み込み
		bool read_byte(int size, uint32_t &ret_value)
		{
			if (FAILED(0 <= size && size <= 4))
			{
				ERR << "read byte > 4. size=" << hex << size << ", at "
					<< byte_pos_ << "(+" << bit_pos_ << ')' << endl;
				return false;
			}

			if (FAILED(check_offset_byte(size)))
				return false;

			return read_bit(size * 8, ret_value);
		}

		// 指数ゴロムとしてビット単位で読み込み
		bool read_expgolomb(uint32_t &ret_value, int &ret_size)
		{
			uint32_t v = 0;
			read_bit(1, v);
			if (v == 1)
			{
				ret_value = 0;
				ret_size = 1;
				return true;
			}

			int count = 1;
			for (;;)
			{
				if (FAILED(read_bit(1, v)))
					return false;

				if (v == 1)
				{
					if (FAILED(read_bit(count, v)))
					{
						return false;
					}
					else
					{
						ret_value = (v | (1 << count)) - 1;
						ret_size = 2 * count + 1;
						return true;
					}
				}

				++count;
			}
		}

		// 文字列として読み込み
		// NULL文字が先に見つかった場合はその分だけポインタを進める
		// NULL文字が見つからなかった場合は最大max_lengthの長さ文字列として終端にNULL文字を入れる
		bool read_string(int max_length, string &ret_str)
		{
			if (FAILED(check_offset_byte(max_length)))
				return false;

			if (FAILED(bit_pos_ == 0))
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

			if (FAILED(seekoff_byte(ofs)))
				return false;

			return true;
		}

		// ビット単位で先読み
		bool look_bit(int size, uint32_t &ret_val)
		{
			if (FAILED(0 <= size && size <= 32))
			{
				ERR << "bit size > 32. size=" << hex << size << ", at "
					<< byte_pos_ << "(+" << bit_pos_ << ')' << endl;
				return false;
			}

			if (FAILED(check_offset_bit(size)))
				return false;

			if (FAILED(read_bit(size, ret_val)))
				return false;

			if (FAILED(seekoff_bit(-size)))
				return false;

			return true;
		}

		// バイト単位で先読み
		bool look_byte(int size, uint32_t &ret_val)
		{
			if (FAILED(0 <= size && size <= 4))
			{
				ERR << "look byte size > 4. size=" << hex << size << ", at "
					<< byte_pos_ << "(+" << bit_pos_ << ')' << endl;
				return false;
			}

			if (FAILED(check_offset_byte(size)))
				return false;

			if (FAILED(read_byte(size, ret_val)))
				return false;

			if (FAILED(seekoff_byte(-size)))
				return false;

			return true;
		}

		// 指数ゴロムで先読み
		bool look_expgolomb(uint32_t &ret_val)
		{
			int prev_byte = byte_pos_;
			int prev_bit  = bit_pos_;
			int dummy_size;

			if (FAILED(read_expgolomb(ret_val, dummy_size)))
				return false;

			if (FAILED(seekoff(prev_byte, prev_bit)))
				return false;

			return true;
		}

		// 指定バッファの分だけ先読み
		bool look_byte_string(char* address, int size)
		{
			if (FAILED(0 <= size))
			{
				ERR << "look byte size < 0. size = " << hex << size << ", at "
					<< byte_pos_ << "(+" << bit_pos_ << ')' << endl;
				return false;
			}

			if (FAILED(check_offset_byte(size)))
				return false;

			buf_->sgetn(address, size);

			return sync();
		}

		// 特定の１バイトの値を検索
		// 見つからなければファイル終端を返す
		bool find_byte(char sc, int &ret_offset, bool advance)
		{
			int ofs = 0;
			int c;
			for (; byte_pos_ + ofs < size_; ++ofs)
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
				bit_pos_ = 0;
				if (FAILED(seekoff_byte(ofs)))
					return false;
				return true;
			}
			else
				return sync();
		}

		// 特定のバイト列を検索
		// 見つからなければファイル終端を返す
		bool find_byte_string(const char* address, int size, int &ret_offset, bool advance)
		{
			//char* contents = new char[size];
			char contents[256];
			if (FAILED(sizeof(contents) >= static_cast<size_t>(size)))
			{
				ERR << "too long search string. size = " << hex << size << ", at "
					<< byte_pos_ << "(+" << bit_pos_ << ')' << endl;
				return false;
			}

			if (FAILED(valid_ptr(address)))
				return false;

			int offset = 0;
			int prev_byte_pos = byte_pos_;
			for (;;)
			{
				if (FAILED(find_byte(address[0], offset, true)))
				{
					seekpos_byte(prev_byte_pos);
					return false;
				}

				// 終端
				if ((byte_pos_ >= size_)
					|| (!check_offset_byte(size)))
				{
					ret_offset = size_ - prev_byte_pos;
					if (!advance)
						return seekpos_byte(prev_byte_pos);
					else
						return seekpos_byte(size_);
				}

				// 一致
				// 不一致は1バイト進める
				look_byte_string(contents, size);
				if (std::memcmp(contents, address, static_cast<size_t>(size)) == 0)
				{
					ret_offset = byte_pos_ - prev_byte_pos;
					if (!advance)
						return seekpos_byte(prev_byte_pos);
					else
						return true;
				}
				else
				{
					seekoff_byte(1);
				}
			}
		}
	};

	class RingBuf final : public streambuf
	{

	private:

		unique_ptr<char[]> buf_;
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
			return buf_[0];
		}

		ios::pos_type seekoff(ios::off_type off, ios::seekdir way, ios::openmode) override
		{
			char* pos;
			switch (way)
			{
			case ios::beg: pos = eback() + (off % size_); break;
			case ios::end: pos = egptr() + (off % size_); break;
			case ios::cur: default: pos = eback() + (((gptr() - eback()) + off) % size_); break;
			}

			setg(buf_.get(), pos, buf_.get() + size_);
			return pos - eback(); // 先頭を返す必要あり
		}

		ios::pos_type seekpos(ios::pos_type pos, ios::openmode which) override
		{
			return seekoff(pos, ios::beg, which);
		}

	public:

		RingBuf() : streambuf(), size_(0) {}

		// リングバッファのサイズを指定する
		bool reserve(int size)
		{
			if (FAILED(0 <= size))
				return false;

			buf_ = unique_ptr<char[]>(new char[size]);
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
		static bool transfer_to_file(const char* file_name, LuaGlueBitstream &stream, int size, bool advance = false)
		{
			if (FAILED(size >= 0))
				return false;

			char* buf = new char[static_cast<unsigned int>(size)];

			if (FAILED(stream.look_byte_string(buf, size)))
				throw LUA_RUNTIME_ERROR((stream.print_status(), "get data"));

			if (FAILED(FileManager::getInstance().write_to_file(file_name, buf, size)))
				throw LUA_RUNTIME_ERROR((stream.print_status(), "write data"));

			if (advance)
			{
				stringstream ss;
				ss << " >> " << file_name;
				stream.read_byte(ss.str().c_str(), size);
			}

			return true;
		}

	private:

		Bitstream bs_;
		bool printf_on_;
		bool little_endian_;
		enum { MAX_DUMP = 1024 };

	protected:

		LuaGlueBitstream()
			:printf_on_(true), little_endian_(false){}

		// streambufを設定
		// template<template<typename T> class D >
		// bool assign(unique_ptr<streambuf, D>&& b)
		bool assign(unique_ptr<streambuf>&& b, int size)
		{
			return bs_.assign(std::move(b), size);
		}

		// 指定バッファ分だけデータを先読み
		bool look_byte_string(char* address, int size)
		{
			return bs_.look_byte_string(address, size);
		}

		// 現在の状態を表示
		void print_status()
		{
			printf("print_status\n");
			printf("current pos = 0x%0x(+%x)\n", byte_pos(), bit_pos());
			seekpos_byte(byte_pos() - 127 < 0 ? 0 : byte_pos() - 127);
			dump(256);
		}
	public:

		// デストラクタ、このクラスは派生するので用意
		virtual ~LuaGlueBitstream(){}

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
		bool seekoff_bit(int offset) { return bs_.seekoff_bit(offset); }

		// 現在位置からファイルポインタ移動
		bool seekoff_byte(int offset) { return bs_.seekoff_byte(offset); }

		// 現在位置からファイルポインタ移動
		bool seekoff(int byte, int bit) { return bs_.seekoff(byte, bit); }

		// 先頭からファイルポインタ移動
		bool seekpos_bit(int byte) { return bs_.seekpos_bit(byte); }

		// 先頭からファイルポインタ移動
		bool seekpos_byte(int byte) { return bs_.seekpos_byte(byte); }

		// 先頭からファイルポインタ移動
		bool seekpos(int byte, int bit) { return bs_.seekpos(byte, bit); }

		// ビット単位で読み込み
		// 32bit以上は0を返す
		uint32_t read_bit(const char* name, int size) throw(...)
		{
			if (FAILED(size >= 0))
				throw LUA_RUNTIME_ERROR((print_status(), string("size < 0, size=") + to_string(size)));

			if (FAILED(bs_.check_offset_bit(size)))
				throw LUA_RUNTIME_ERROR((print_status(), string("overflow, size=") + to_string(size)));

			int prev_byte = byte_pos();
			int prev_bit = bit_pos();

			if (size > 32)
			{
				char buf[16];
				int dump_size = min<int>(16, (size + 7) / 8);
				bs_.look_byte_string(buf, dump_size);

				seekoff_bit(size);

				if (printf_on_ || (name[0] == '#'))
				{
					printf(" adr=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | ",
						prev_byte, prev_bit, size / 8, size % 8, name);
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
				bs_.read_bit(size, v);

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
						prev_byte, prev_bit, size / 8, size % 8, name, v, v,
						((size == 32 || size == 16) && little_endian_) ? ", \"little\"" : "");
				}

				return v;
			}
		}

		// バイト単位で読み込み
		// 32bit以上は0を返す
		uint32_t read_byte(const char* name, int size) throw(...)
		{
			if (FAILED(bs_.check_offset_byte(size)))
				throw LUA_RUNTIME_ERROR((print_status(), string("overflow, size=") + to_string(size)));
			return read_bit(name, 8 * size);
		}

		// バイト単位で文字列として読み込み
		// むちゃくちゃ長い文字列はまずい。
		string read_string(const char* name, int max_length) throw(...)
		{
			int prev_byte = bs_.byte_pos();
			int prev_bit = bs_.bit_pos();

			string str;
			if (FAILED(bs_.read_string(max_length, str)))
				throw LUA_RUNTIME_ERROR((print_status(), "read string"));

			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%08x(+%d)| siz=0x%08x(+0)| %-40s | str=\"%s\"\n",
					prev_byte, prev_bit, static_cast<unsigned int>(str.length()), name, str.c_str());
				if (max_length < static_cast<int>(str.length() - 1))
					ERR << "max_length > str.length() - 1 (" << str.length()
						<< " != " << max_length << ")" << endl;
			}

			return str;
		}

		// 指数ゴロムとして読み込み
		uint32_t read_expgolomb(const char* name) throw(...)
		{
			int prev_byte = bs_.byte_pos();
			int prev_bit = bs_.bit_pos();

			uint32_t v;
			int size;
			if (FAILED(bs_.read_expgolomb(v, size)))
				throw LUA_RUNTIME_ERROR((print_status(), "read expgolomb"));

			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | exp=0x%-8x (%d%s)\n",
					prev_byte, prev_bit, size / 8, size % 8, name, v, v,
					((size == 32 || size == 16) && little_endian_) ? ", \"little\"" : "");
			}

			return v;
		}

		// ビット単位で先読み
		uint32_t look_bit(int size) throw(...)
		{
			if (FAILED(bs_.check_offset_bit(size)))
				throw LUA_RUNTIME_ERROR((print_status(), string("overflow, size=") + to_string(size)));

			uint32_t val;
			if (FAILED(bs_.look_bit(size, val)))
				throw LUA_RUNTIME_ERROR((print_status(), "look_bit"));
			return val;
		}

		// バイト単位で先読み
		uint32_t look_byte(int size) throw(...)
		{
			if (FAILED(bs_.check_offset_byte(size)))
				throw LUA_RUNTIME_ERROR((print_status(), string("overflow, size=") + to_string(size)));

			uint32_t val;
			if (FAILED(bs_.look_byte(size, val)))
				throw LUA_RUNTIME_ERROR((print_status(), "look_byte"));
			return val;
		}

		// 指数ゴロムで先読み
		uint32_t look_expgolomb() throw(...)
		{
			uint32_t val;
			if (FAILED(bs_.look_expgolomb(val)))
				throw LUA_RUNTIME_ERROR((print_status(), "look_byte"));
			return val;
		}

		// ビット単位で比較
		bool compare_bit(const char* name, int size, uint32_t compvalue) throw(...)
		{
			if (FAILED(bs_.check_offset_bit(size)))
				throw LUA_RUNTIME_ERROR((print_status(), string("overflow, size=") + to_string(size)));

			uint32_t value = read_bit(name, size);
			if (value != compvalue)
			{
				printf("# compare value [%s] : 0x%08x(%d) != 0x%08x(%d)\n",
					name, value, value, compvalue, compvalue);

				return false;
			}
			return true;
		}

		// バイト単位で比較
		bool compare_byte(const char* name, int size, uint32_t compvalue) throw(...)
		{
			if (FAILED(bs_.check_offset_byte(size)))
				throw LUA_RUNTIME_ERROR((print_status(), "overflow"));

			return compare_bit(name, 8 * size, compvalue);
		}

		// バイト単位で文字列として比較
		bool compare_string(const char* name, int max_length, const char* comp_str) throw(...)
		{
			if (FAILED(bs_.check_offset_byte(max_length)))
				throw LUA_RUNTIME_ERROR((print_status(), string("overflow, size=") + to_string(max_length)));

			string str = read_string(name, max_length);
			if (str != comp_str)
			{
				printf("# compare string [%s]: \"%s\" != \"%s\"\n", name, str.c_str(), comp_str);
				return false;
			}
			return true;
		}

		// 指数ゴロムとして比較
		bool compare_expgolomb(const char* name, uint32_t compvalue) throw(...)
		{
			uint32_t value = read_expgolomb(name);
			if (value != compvalue)
			{
				printf("# compare value [%s] : 0x%08x(%d) != 0x%08x(%d)\n",
					name, value, value, compvalue, compvalue);

				return false;
			}
			return true;
		}

		// １バイトの一致を検索
		int find_byte(char c, bool advance) throw(...)
		{
			int prev_byte = bs_.byte_pos();
			int offset;

			if (FAILED(bs_.find_byte(c, offset, advance)))
			{
				printf("# can not find byte:0x%x\n", static_cast<uint8_t>(c));
				throw LUA_RUNTIME_ERROR((print_status(), "search fail"));
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
		int find_byte_string(const char* address, int size, bool advance) throw(...)
		{
			if (FAILED(valid_ptr(address)))
				return false;

			string s(address, size);
			int prev_byte = bs_.byte_pos();
			int offset;

			if (FAILED(bs_.find_byte_string(address, size, offset, advance)))
			{
				printf("# can not find byte string: %s\n", s.c_str());
				throw LUA_RUNTIME_ERROR((print_status(), "search fail"));
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
		bool write_byte_string(const char *buf, int size)
		{
			if (FAILED(valid_ptr(buf)))
				return false;

			if (FAILED(size >= 0))
				return false;

			return bs_.write_byte_string(buf, size);
		}

		bool put_char(char c)
		{
			return bs_.put_char(c);
		}

		// 別のストリームに転送
		// 現状オーバーヘッド多め
		bool transfer_byte(const char* name, LuaGlueBitstream &stream, int size, bool advance)
		{
			if (FAILED(bs_.check_offset_byte(size)))
				return false;

			char* buf = new char[static_cast<unsigned int>(size)];
			bs_.look_byte_string(buf, size);

			if (FAILED(stream.write_byte_string(buf, size)))
				return false;

			if (advance)
			{
				stringstream ss;
				ss << " >> transfer: " << name;
				read_byte(ss.str().c_str(), size);
			}

			return true;
		}

		// 現在位置からバイト表示
		bool dump_line(int max_size)
		{
			char buf[MAX_DUMP];

			int dump_len = std::min<int>(bs_.size() - bs_.byte_pos(), max_size);
			dump_len = std::min<int>(dump_len, sizeof(buf));

			bs_.look_byte_string(buf, dump_len);

			return dump_line(buf, 0, dump_len);
		}

		// 現在位置からバイト表示
		bool dump_as_string(int max_size)
		{
			char buf[MAX_DUMP];

			int dump_len = std::min<int>(bs_.size() - bs_.byte_pos(), max_size);
			dump_len = std::min<int>(dump_len, sizeof(buf));

			bs_.look_byte_string(buf, dump_len);

			return dump_as_string(buf, 0, dump_len);
		}

		// 現在位置からバイト表示
		bool dump(int max_size)
		{
			char buf[MAX_DUMP];

			int dump_len = std::min<int>(bs_.size() - bs_.byte_pos(), max_size);
			dump_len = std::min<int>(dump_len, sizeof(buf));

			bs_.look_byte_string(buf, dump_len);

			return dump(buf, byte_pos(), dump_len);
		}
	};

	class LuaGlueBufBitstream final : public LuaGlueBitstream
	{
	public:

		LuaGlueBufBitstream() :LuaGlueBitstream()
		{
			assign(make_unique<stringbuf>(), 0);
		}
	};

	class LuaGlueFifoBitstream final : public LuaGlueBitstream
	{
	public:

		LuaGlueFifoBitstream() :LuaGlueBitstream(){}
		LuaGlueFifoBitstream(int size) :LuaGlueBitstream(){ reserve(size); }

		// バッファを確保
		bool reserve(int size)
		{
			auto rb = make_unique<RingBuf>();

			if (FAILED(rb->reserve(size)))
				return false;

			if (FAILED(assign(std::move(rb), 0)))
				return false;

			return true;
		}
	};


	class LuaGlueFileBitstream final : public LuaGlueBitstream
	{
	public:

		LuaGlueFileBitstream() :LuaGlueBitstream(){}
		LuaGlueFileBitstream(const string& file_name, const string& mode = "rb") :LuaGlueBitstream(){ open(file_name, mode); }

		bool open(const string& file_name, const string& mode = "rb")
		{
			//auto del = [](filebuf* p){p->close(); delete p; };
			//unique_ptr<filebuf, decltype(del)> fb(new filebuf, del);

			auto fb = make_unique<filebuf>();
			ios::openmode m;

			if (mode.find('r') != string::npos)
				m = ios::in;
			else if (mode.find('w') != string::npos)
				m = ios::out | ios::trunc;
			else if (mode.find('a') != string::npos)
				m = (ios::out | ios::app);
			else
			{
				ERR << "file open mode" << mode << endl;
				return false;
			}


			if (mode.find('+') != string::npos)
				m |= (ios::in | ios::out);

			// テキストはほぼ処理しないのでbinary強制のほうがいいかも
			if (mode.find('b') != string::npos)
				m |= ios::binary;

			fb->open(file_name, m);

			int size = static_cast<int>(fb->pubseekoff(0, ios::end));
			if (size == EOF)
				size = 0;

			if (FAILED(assign(std::move(fb), size)))
				return false;

			return true;
		}
	};
}

using namespace std;
using namespace rf;

// Luaを初期化する
unique_ptr<LuaBinder> init_lua(int argc, char** argv)
{
	auto lua = make_unique<LuaBinder>();
	
	// 関数バインド
	lua->def("stdout_to_file",   FileManager::stdout_to_file);        // コンソール出力の出力先切り替え
	lua->def("write_to_file",    FileManager::write_to_file);         // 指定したバイト列をファイルに出力
	lua->def("transfer_to_file", LuaGlueBitstream::transfer_to_file); // 指定したストリームををファイルに出力
	lua->def("reverse_16",       reverse_endian_16);                  // 16ビットエンディアン変換
	lua->def("reverse_32",       reverse_endian_32);                  // 32ビットエンディアン変換

	// インターフェース
	lua->def_class<LuaGlueBitstream>("IBitstream")->
		def("size",             &LuaGlueBitstream::size).              // ファイルサイズ取得
		def("enable_print",     &LuaGlueBitstream::enable_print).      // 解析ログのON/OFF
		def("little_endian",    &LuaGlueBitstream::little_endian).     // ２バイト/４バイトの読み込み時はエンディアンを変換する
		def("seekpos_bit",      &LuaGlueBitstream::seekpos_bit).       // 先頭からファイルポインタ移動
		def("seekpos_byte",     &LuaGlueBitstream::seekpos_byte).      // 先頭からファイルポインタ移動
		def("seekpos",          &LuaGlueBitstream::seekpos).           // 先頭からファイルポインタ移動
		def("seekoff_bit",      &LuaGlueBitstream::seekoff_bit).       // 現在位置からファイルポインタ移動
		def("seekoff_byte",     &LuaGlueBitstream::seekoff_byte).      // 現在位置からファイルポインタ移動
		def("seekoff",          &LuaGlueBitstream::seekoff).           // 現在位置からファイルポインタ移動
		def("bit_pos",          &LuaGlueBitstream::bit_pos).           // 現在のビットオフセットを取得
		def("byte_pos",         &LuaGlueBitstream::byte_pos).          // 現在のバイトオフセットを取得
		def("read_bit",         &LuaGlueBitstream::read_bit).          // ビット単位で読み込み
		def("read_byte",        &LuaGlueBitstream::read_byte).         // バイト単位で読み込み
		def("read_string",      &LuaGlueBitstream::read_string).       // バイト単位で文字列として読み込み
		def("read_expgolomb",   &LuaGlueBitstream::read_expgolomb).    // 指数ゴロムとしてビットを読む
		def("comp_bit",         &LuaGlueBitstream::compare_bit).       // ビット単位で比較
		def("comp_byte",        &LuaGlueBitstream::compare_byte).      // バイト単位で比較
		def("comp_string",      &LuaGlueBitstream::compare_string).    // バイト単位で文字列として比較
		def("comp_expgolomb",   &LuaGlueBitstream::compare_expgolomb). // 指数ゴロムとして比較
		def("look_bit",         &LuaGlueBitstream::look_bit).          // ポインタを進めないでビット値を取得、4byteまで
		def("look_byte",        &LuaGlueBitstream::look_byte).         // ポインタを進めないでバイト値を取得、4byteまで
		def("look_expgolomb",   &LuaGlueBitstream::look_expgolomb).    // ポインタを進めないで指数ゴロム値を取得、4byteまで
		def("find_byte",        &LuaGlueBitstream::find_byte).         // １バイトの一致を検索
		def("find_byte_string", &LuaGlueBitstream::find_byte_string).  // 数バイト分の一致を検索
		def("transfer_byte",    &LuaGlueBitstream::transfer_byte).     // 部分ストリーム(Bitstream)を作成
		def("write",            &LuaGlueBitstream::write_byte_string). // ビットストリームの終端に書き込む
		def("put_char",         &LuaGlueBitstream::put_char).          // ビットストリームの終端に書き込む
		def("dump",
			(bool(LuaGlueBitstream::*)(int)) &LuaGlueBitstream::dump); // 現在位置からバイト表示

	// std::filebufによるビットストリームクラス
	lua->def_class<LuaGlueFileBitstream>("FileBitstream", "IBitstream")->
		def("new",     LuaBinder::constructor<LuaGlueFileBitstream(const string&, const string&)>()).
		def("open",    &LuaGlueFileBitstream::open); // ファイルオープン

	// std::stringbufによるビットストリームクラス
	lua->def_class<LuaGlueBufBitstream>("Buffer", "IBitstream")->
		def("new",     LuaBinder::constructor<LuaGlueBufBitstream()>());

	// FIFO（リングバッファ）によるビットストリームクラスクラス
	// ヘッド/テールの監視がなく挙動が特殊なのでメモリに余裕がある処理なら"Buffer"クラスを使ったほうが良い
	lua->def_class<LuaGlueFifoBitstream>("Fifo", "IBitstream")->
		def("new",     LuaBinder::constructor<LuaGlueFifoBitstream(int)>()).
		def("reserve", &LuaGlueFifoBitstream::reserve); // バッファを再確保、書き込み済みデータは破棄

	// Luaの環境を登録
#ifdef _MSC_VER
	if (FAILED(lua->dostring("_G.windows = true")))
	{
		ERR << "lua.dostring err" << endl;
	}
#endif

	// Luaにmain関数の引数を継承
	// argc
	{
		stringstream ss;
		ss << "_G.argc=" << argc;
		if (FAILED(lua->dostring(ss.str())))
		{
			ERR << "lua.dostring err" << endl;
		}
	}

	// argv
	{
		if (FAILED(lua->dostring("_G.argv = {}")))
		{
			ERR << "lua.dostring err" << endl;
		}

		for (int i = 0; i < argc; ++i)
		{
			// windowsの場合はパス名中の'\'がエスケープと認識されるので/に置換
			stringstream ss;
#ifdef _MSC_VER
			string s = std::regex_replace(argv[i], std::regex(R"(\\)"), "/");
			ss << "argv[" << i << "]=\"" << s << '\"';
#else
			ss << "argv[" << i << "]=\"" << argv[i] << '\"';
#endif

			if (FAILED(lua->dostring(ss.str())))
			{
				ERR << "lua.dostring err" << endl;
			}
		}
	}

	return lua;
}

void show_help()
{
	cout << "\n"
		"a.out [--lua|-l filename] [--help|-h]\n"
		"\n"
		"--lua  :start with file mode\n"
		"--help :show this help" << endl;
	return;
}

int main(int argc, char** argv)
{
	auto lua = init_lua(argc, argv);

	// windowsのドラッグアンドドロップに対応するため、
	// 実行ファイルのディレクトリ名を抽出する
	// ついでに'\\'を'/'に変換しておく
	string exe_path;
	string exe_dir;
	string lua_file_name = "script/default.lua";
	if (argc>0)
	{
#ifdef _MSC_VER
		exe_path = std::regex_replace(argv[0], std::regex(R"(\\)"), "/");
		std::smatch result;
		std::regex_search(exe_path, result, std::regex("(.*)/"));
		exe_dir = result.str();
#else
		exe_path = argv[0];
		exe_dir = "";
#endif
		stringstream ss;
		ss << "_G.__exec_dir__=\"" << exe_dir << '\"';
		if (FAILED(lua->dostring(ss.str())))
		{
			ERR << "lua.dostring err" << endl;
		}
	
		lua_file_name = exe_dir + "script/default.lua";
	}

	
	// C++側で引数を適用
	int flag = 0;
	for (int i = 0; i < argc; ++i)
	{
		if ((string("--lua") == argv[i])
			|| (string("-l") == argv[i]))
		{
			flag = 1;
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
			break;
		}
		case 1:
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

	// luaファイル実行(引数でファイル名を指定した場合)
	if (argc > 1)
	{
		for (;;)
		{
			if (FAILED(lua->dofile(lua_file_name)))
			{
				ERR << "lua.dofile err" << endl;
				cout << "r:retry" << endl;
				string str;
				std::getline(cin, str);
				if (str == "r")
				{
					continue;
				}
			}

			break;
		}
	}

	// luaコマンド実行
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

	return 0;
}