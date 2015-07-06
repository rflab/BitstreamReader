// ビットストリームクラスをバインドしてLuaを起動する
// 引数がなければscript/default.luaを起動する
// $> / a.out test.wav

#include <stdint.h>
#include <iostream>
#include <iomanip>
#include <vector>
#include <array>
#include <map>
#include <memory>
#include <utility>
#include <sstream>
#include <fstream>
#include <algorithm>
#include <regex>
#include <cctype>
#include <cstring>

// Lua
#include "luabinder.hpp"

// SQLite
#include "sqlite3.h"

#if defined(_MSC_VER) && (_MSC_VER >= 1800)
#elif defined(__GNUC__) && __cplusplus >= 201300L // __GNUC_PREREQ(4, 9)
#define throw(x)
#else
// unsupported
#define nullptr NULL
#define final
#define throw(x)
#define make_unique make_shared
#define unique_ptr shared_ptr
#endif

//#define FAIL(...) __VA_ARGS__
#define FAIL(...) ::rf::fail((__VA_ARGS__), __LINE__, __FUNCTION__, #__VA_ARGS__)
#define ERR cerr << "# c++ error. L" << dec << __LINE__ << " " << __FUNCTION__ << ": "
#define FAIL_STR(msg) fail_msg(__LINE__, __FUNCTION__, msg)
#define OUTPUT_POS "at 0x" << hex << byte_pos() <<  "(+" << bit_pos() << ')'

namespace rf
{
	using std::vector;
	using std::array;
	using std::map;
	using std::string;
	using std::unique_ptr;
	using std::stringstream;
	using std::ofstream;
	using std::exception;
	using std::logic_error;
	using std::runtime_error;
	using std::to_string;
	using std::make_unique;
	using std::cout;
	using std::cin;
	using std::cerr;
	using std::endl;
	using std::hex;
	using std::dec;

	inline bool fail(bool b, int line, const std::string &fn, const std::string &exp)
	{
		if (!b)
			std::cerr << "# c++ L." << std::dec
			<< line << " " << fn << ": failed [ " << exp << " ]" << std::endl;
		return !b;
	}

	inline string fail_msg(int line, const std::string &fn, const string& msg)
	{
		stringstream ss;
		ss << "# c++ L." << std::dec
			<< line << " " << fn << " failed. [" << msg << "]" << std::endl;
		return ss.str();
	}

	inline static bool valid_ptr(const void *p)
	{
		return p != nullptr;
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
	// 指定アドレスをバイト列でダンプ
	static bool dump_bytes(const char* buf, int offset, int size)
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
	static bool dump_string(const char* buf, int offset, int size)
	{
		uint8_t c;
		for (int i = 0; i < size; ++i)
		{
			c = buf[offset + i];
			if (isgraph(c))
				putchar(c);
			else
				putchar('.');
		}
		return true;
	}

	// 指定アドレスをダンプ
	static bool dump(const char* buf, int offset, int size, int original_address)
	{
		// ヘッダ表示
		printf(
			"     offset    "
			"| +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F "
			"| 0123456789ABCDE\n");

		// データ表示
		int padding = original_address & 0xf;
		int write_lines = (size + padding + 15) / 16;
		int byte_print_pos = 0;
		int str_print_pos = 0;
		int byte_pos = 0;
		int str_pos = 0;
		uint8_t c;
		for (int cur_line = 0; cur_line < write_lines; ++cur_line)
		{
			// アドレス
			printf("     0x%08x| ", (original_address + byte_pos) & 0xfffffff0);

			// バイナリ
			for (int i = 0; i < 16; ++i)
			{
				if ((byte_print_pos < padding)
				|| (byte_print_pos >= size + offset + padding))
				{
					printf("   ");
				}
				else
				{
					c = buf[offset + byte_pos];
					printf("%02x ", c);
					++byte_pos;
				}

				++byte_print_pos;
			}
			
			printf("| ");

			// キャラクタ
			for (int i = 0; i < 16; ++i)
			{
				if ((str_print_pos < padding)
				||  (str_print_pos >= size + offset + padding))
				{
					printf(" ");
				}
				else
				{
					c = buf[offset + str_pos];
					if (isgraph(c))
						putchar(c);
					else
						putchar('.');
					++str_pos;
				}

				++str_print_pos;
			}

			putchar('\n');
		}
		return true;
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
			for (auto it = ofs_map_.begin(); it != ofs_map_.end(); ++it)
			{
				it->second->close();
				if (it->second->fail())
				{
					ERR << it->first << "close fail" << endl;
				}
			}

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
			if (FAIL(valid_ptr(address)))
				throw logic_error(FAIL_STR("invalid argument."));

			auto it = ofs_map_.find(file_name);
			if (it == ofs_map_.end())
			{
				auto ofs = make_unique<ofstream>();
				ofs->open(file_name, std::ios::binary | std::ios::out);
				if (FAIL(ofs != false))
					throw runtime_error(FAIL_STR("file open failed."));

				auto ins = ofs_map_.insert(std::make_pair(file_name, std::move(ofs)));
				if (FAIL(ins.second == true))
					throw runtime_error(FAIL_STR("file register failed."));

				it = ins.first;
			}

			it->second->write(address, size);
			if (FAIL(!it->second->fail()))
			{
				ERR << "file write " << file_name << endl;
				throw runtime_error(FAIL_STR("file write."));
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
				if (FAIL(freopen_s(&fp, "log.txt", "w", stdout) == 0))
					throw runtime_error(FAIL_STR("file open error."));

#else
				fp = freopen("log.txt", "w", stdout);
				if (FAIL(fp != NULL))
					throw runtime_error(FAIL_STR("file open error."));
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

		unique_ptr<std::streambuf> buf_;
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
		bool assign(unique_ptr<std::streambuf>&& buf, int size)
		{
			buf_ = std::move(buf);
			byte_pos_ = 0;
			bit_pos_ = 0;
			size_ = size;

			return sync();
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
			if (FAIL(check_byte(byte)))
			{
				ERR << "byte=" << hex << byte << " " << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			if (FAIL((0 >= bit) && (bit < 8)))
			{
				ERR << "bit=" << hex << bit << " " << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("out of range."));
			}

			byte_pos_ = byte;
			bit_pos_ = bit;

			return sync();
		}

		// ビット単位で読み込みヘッダを移動
		bool seekpos_bit(int offset)
		{
			if (FAIL(check_bit(offset)))
			{
				ERR << "offset=" << hex << offset << " " << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			byte_pos_ = offset / 8;
			bit_pos_ = offset % 8;

			return sync();
		}

		// バイト単位で読み込みヘッダを移動
		bool seekpos_byte(int offset)
		{
			if (FAIL(check_byte(offset)))
			{
				ERR << "byte=" << hex << offset << " " << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			return seekpos(offset, 0);
		}

		// 読み込みヘッダを移動
		bool seekoff(int byte, int bit)
		{
			if (FAIL(check_bit(byte * 8 + bit)))
			{
				ERR << "byte=" << hex << byte << " bit=" << bit << " " << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			byte_pos_ += byte;
			bit_pos_ += bit;

			return sync();
		}

		// ビット単位で読み込みヘッダを移動
		bool seekoff_bit(int offset)
		{
			if (FAIL(check_offset_bit(offset)))
			{
				ERR << "offset=" << hex << offset << " " << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			byte_pos_ += (bit_pos_ + offset) / 8;
			bit_pos_ = (bit_pos_ + offset) % 8; // & 0x07;

			return sync();
		}

		// バイト単位で読み込みヘッダを移動
		bool seekoff_byte(int offset)
		{
			if (FAIL(check_offset_byte(offset)))
			{
				ERR << "offset=" << hex << offset << " " << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR(" range error."));
			}

			byte_pos_ += offset;

			return sync();
		}

		// ビット単位で読み込み
		bool read_bit(int size, uint32_t &ret_value)
		{
			if (FAIL(0 <= size && size <= 32))
			{
				ERR << "read bit > 32. size=" << hex << size << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR(" range error."));
			}

			if (FAIL(check_offset_bit(size)))
			{
				ERR << "size=" << hex << size << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR(" range error."));
			}

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
			if (FAIL(0 <= size && size <= 4))
			{
				ERR << "read byte > 4. size=" << hex << size << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("out of range."));
			}

			if (FAIL(check_offset_byte(size)))
			{
				ERR << "size=" << hex << size << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

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
				read_bit(1, v);

				if (v == 1)
				{
					read_bit(count, v);

					ret_value = (v | (1 << count)) - 1;
					ret_size = 2 * count + 1;
					return true;
				}

				++count;
			}
		}

		// 文字列として読み込み
		// NULL文字が先に見つかった場合はその分だけ文字列にするがポインタは進む
		// NULL文字が見つからなかった場合は最大max_lengthの長さ文字列として終端にNULL文字を入れる
		bool read_string(int size, string &ret_str)
		{
			if (FAIL(check_offset_byte(size)))
			{
				ERR << "size=" << hex << size << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			if (FAIL(bit_pos_ == 0))
			{
				ERR << "bit_pos_ is not aligned"<< OUTPUT_POS << endl;
				// throw runtime_error(FAIL_STR("range error."));
			}

#if 1
			int ofs = 0;
			int c;
			stringstream ss;
			for (; ofs < size; ++ofs)
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
#else
			auto pa = make_unique<char[]>(size);
			buf_->sgetn(pa.get(), size);
			ret_str.assign(pa.get());
#endif

			return seekoff_byte(size);
		}

		// ビット単位で先読み
		bool look_bit(int size, uint32_t &ret_val)
		{
			if (FAIL(0 <= size && size <= 32))
			{
				ERR << "bit size > 32. size=" << hex << size << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("out of range"));
			}

			if (FAIL(check_offset_bit(size)))
			{
				ERR << "size=" << hex << size << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			read_bit(size, ret_val);
			return seekoff_bit(-size);
		}

		// バイト単位で先読み
		bool look_byte(int size, uint32_t &ret_val)
		{
			if (FAIL(0 <= size && size <= 4))
			{
				ERR << "look byte size > 4. size=" << hex << size << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("out of range"));
			}

			if (FAIL(check_offset_byte(size)))
			{
				ERR << "size=" << hex << size << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			read_byte(size, ret_val);
			return seekoff_byte(-size);
		}

		// 指数ゴロムで先読み
		bool look_expgolomb(uint32_t &ret_val)
		{
			int prev_byte = byte_pos_;
			int prev_bit  = bit_pos_;
			int dummy_size;
			read_expgolomb(ret_val, dummy_size);
			return seekoff(prev_byte, prev_bit);;
		}

		// 指定バッファの分だけ先読み
		bool look_byte_string(char* address, int size)
		{
			if (FAIL(0 <= size))
			{
				ERR << "look byte size < 0. size=" << hex << size << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("out of range"));
			}

			// if (FAIL(bit_pos_ == 0))
			// {
			// 	ERR << "look byte bit_pos_ != 0. bit_pos_=" << hex << bit_pos_ << OUTPUT_POS << endl;
			// 	throw runtime_error(FAIL_STR("range error."));
			// }

			if (FAIL(check_offset_byte(size)))
			{
				ERR << "size=" << hex << size << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			buf_->sgetn(address, size);

			return sync();
		}

		// 特定の１バイトの値を検索
		// 見つからなければファイル終端を返す
		bool find_byte(char sc, int &ret_offset, bool advance, int end_offset = INT_MAX)
		{
			int ofs = 0;
			int c;
			auto buf = buf_.get(); // パフォーマンス改善のためキャスト
			for (; byte_pos_ + ofs < size_; ++ofs)
			{
				//c = buf_->sbumpc(); operator -> が重かった
				c = buf->sbumpc();
				if (static_cast<char>(c) == sc)
				{
					break;
				}
				else if (c == EOF)
				{
					break;
				}
				else if (ofs >= end_offset)
				{
					break;
				}
			}

			ret_offset = ofs;
			if (advance)
			{
				bit_pos_ = 0;
				return seekoff_byte(ofs);
			}
			else
				return sync();
		}

		// 特定のバイト列を検索
		// 見つからなければファイル終端を返す
		bool find_byte_string(
			const char* address, int size, int &ret_offset,	bool advance, int end_offset = INT_MAX)
		{
			//char* contents = new char[size];
			char contents[256];
			if (FAIL(sizeof(contents) >= static_cast<size_t>(size)))
			{
				ERR << "too long search string. size=" << hex << size << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("out of range"));
			}

			if (FAIL(valid_ptr(address)))
			{
				ERR << "invalid address address=" << hex << address << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("invalid argument"));
			}

			int ofs = 0;
			int end_offset_remain = end_offset;
			int prev_byte_pos = byte_pos_;
			for (;;)
			{
				if (FAIL(find_byte(address[0], ofs, true, end_offset_remain)))
				{
					seekpos_byte(prev_byte_pos);
					return false;
				}

				// EOS
				if ((byte_pos_ >= size_)
					|| (!check_offset_byte(size)))
				{
					ret_offset = size_ - prev_byte_pos;
					if (!advance)
						return seekpos_byte(prev_byte_pos);
					else
						return seekpos_byte(size_);
				}

				// end_offset
				if (ofs >= end_offset_remain)
				{
					ret_offset = end_offset;
					if (!advance)
						return seekpos_byte(prev_byte_pos);
					else
						return seekpos_byte(end_offset);
				}
				else
				{
					end_offset_remain -= ofs;
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

		// ストリームにデータを書く
		// 辻褄を合わせるためにサイズを計算する
		bool write(const char *buf, int size)
		{
			if (FAIL(size >= 0))
				throw logic_error(FAIL_STR("size error."));

			size_ = std::max(byte_pos_ + size, size_);
			return buf_->sputn(buf, size) == size;
		}

		// ストリームに１バイト追記する
		bool put_char(char c)
		{
			size_ = std::max(byte_pos_ + 1, size_);
			return buf_->sputc(c) == c;
		}
	};

	class RingBuf final : public std::streambuf
	{

	private:

		unique_ptr<char[]> buf_; //shared_ptrとmake_sharedにdefineで変換したいので配列指定しない
		//unique_ptr<char> buf_;
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

		std::ios::pos_type seekoff(
			std::ios::off_type off, std::ios::seekdir way, std::ios::openmode) override
		{
			char* pos;
			switch (way)
			{
			case std::ios::beg: pos = eback() + (off % size_); break;
			case std::ios::end: pos = egptr() + (off % size_); break;
			case std::ios::cur: default: pos = eback() + (((gptr() - eback()) + off) % size_); break;
			}

			setg(buf_.get(), pos, buf_.get() + size_);
			return pos - eback(); // 先頭を返す必要あり
		}

		std::ios::pos_type seekpos(
			std::ios::pos_type pos, std::ios::openmode which) override
		{
			return seekoff(pos, std::ios::beg, which);
		}

	public:

		RingBuf() : std::streambuf(), size_(0) {}

		// リングバッファのサイズを指定する
		bool reserve(int size)
		{
			if (FAIL(0 <= size))
			{
				ERR << "buf size error. size=" << hex << size << endl;
				throw logic_error(FAIL_STR("out of range"));
			}

			buf_ = unique_ptr<char[]>(new char[size]); //, std::default_delete<char[]>() );
			size_ = size;
			setp(buf_.get(), buf_.get() + size);
			setg(buf_.get(), buf_.get(), buf_.get() + size);
			return true;
		}
	};

	class LuaGlueBitstream
	{
	public:

		// ストリームからファイルに転送
		// 現状オーバーヘッド多め
		static bool transfer_to_file(
			const char* file_name, LuaGlueBitstream &stream, int size, bool advance = false)
		{
			if (FAIL(size >= 0))
				throw runtime_error((stream.print_status(), "size"));

			char* buf = new char[static_cast<unsigned int>(size)];

			stream.bs_.look_byte_string(buf, size);
			FileManager::getInstance().write_to_file(file_name, buf, size);
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
		bool assign(unique_ptr<std::streambuf>&& b, int size)
		{
			return bs_.assign(std::move(b), size);
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
			if (FAIL(size >= 0))
				throw runtime_error((print_status(), string("size < 0, size=") + to_string(size)));

			if (FAIL(bs_.check_offset_bit(size)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));

			int prev_byte = byte_pos();
			int prev_bit = bit_pos();

			if (size > 32)
			{
				char buf[16];
				int dump_size = std::min<int>(16, (size + 7) / 8);
				bs_.look_byte_string(buf, dump_size);
				bs_.seekoff_bit(size);

				if (printf_on_ || (name[0] == '#'))
				{
					printf(" adr=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | ",
						prev_byte, prev_bit, size / 8, size % 8, name);
					rf::dump_bytes(buf, 0, dump_size);

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
			if (FAIL(bs_.check_offset_byte(size)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));
			return read_bit(name, 8 * size);
		}

		// バイト単位で文字列として読み込み
		// むちゃくちゃ長い文字列はまずい。
		string read_string(const char* name, int size) throw(...)
		{
			if (FAIL(bs_.check_offset_byte(size)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));

			int prev_byte = bs_.byte_pos();
			int prev_bit = bs_.bit_pos();

			string str;
			bs_.read_string(size, str);
			
			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%08x(+%d)| siz=0x%08x(+0)| %-40s | str=\"%s\"\n",
					prev_byte, prev_bit, static_cast<unsigned int>(str.length()), name, str.c_str());
				if (size < static_cast<int>(str.length() - 1))
					ERR << "size > str.length() - 1 (" << str.length()
					<< " != " << size << ")" << endl;
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
			bs_.read_expgolomb(v, size);
			
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
			if (FAIL(bs_.check_offset_bit(size)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));

			uint32_t val;
			bs_.look_bit(size, val);
			return val;
		}

		// バイト単位で先読み
		uint32_t look_byte(int size) throw(...)
		{
			if (FAIL(bs_.check_offset_byte(size)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));

			uint32_t val;
			bs_.look_byte(size, val);
			return val;
		}
		
#if 1
		string look_byte_string(int size) throw(...)
		{
			if (FAIL(bs_.check_offset_byte(size)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));

			auto buf = make_unique<char[]>(size);
			bs_.look_byte_string(buf.get(), size);

			return string(buf.get(), size);
		}
#else
		// 指定バッファ分だけデータを先読み
		bool look_byte_string(char* address, int size)
		{
			return bs_.look_byte_string(address, size);
		}
#endif
		// 指数ゴロムで先読み
		uint32_t look_expgolomb() throw(...)
		{
			uint32_t val;
			bs_.look_expgolomb(val);
			return val;
		}

		// ビット単位で比較
		bool compare_bit(const char* name, int size, uint32_t compvalue) throw(...)
		{
			if (FAIL(bs_.check_offset_bit(size)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));

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
			if (FAIL(bs_.check_offset_byte(size)))
				throw runtime_error((print_status(), "overflow"));

			return compare_bit(name, 8 * size, compvalue);
		}

		// バイト単位で文字列として比較
		bool compare_string(const char* name, int max_length, const char* comp_str) throw(...)
		{
			if (FAIL(bs_.check_offset_byte(max_length)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(max_length)));

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
		int find_byte(char c, bool advance, int end_offset) throw(...)
		{
			int prev_byte = bs_.byte_pos();
			int offset;

			if (bs_.find_byte(c, offset, advance, end_offset) == false)
			{
				printf("# can not find byte:0x%x\n", static_cast<uint8_t>(c));
				throw LUA_FALSE;
			}

			if (printf_on_)
			{
				printf(" adr=0x%08x(+0)| ofs=0x%08x(+0)| search '0x%02x' %s at adr=0x%08x.\n",
					bs_.byte_pos(), offset, static_cast<uint8_t>(c),
					offset + prev_byte == this->size() ? "not found [EOS]"
						: offset == end_offset ? "not found [end_offset]"
						: "found",
					offset + prev_byte);
			}

			return offset;
		}

		// 数バイト分の一致を検索
		int find_byte_string(const char* address, int size, bool advance, int end_offset) throw(...)
		{
			if (FAIL(valid_ptr(address)))
				throw logic_error((print_status(), "invalid address"));

			string s(address, size);
			int prev_byte = bs_.byte_pos();
			int offset;

			if (bs_.find_byte_string(address, size, offset, advance, end_offset) == false)
			{
				printf("# can not find byte string: %s\n", s.c_str());
				throw LUA_FALSE;
			}

			if (printf_on_)
			{
				printf(" adr=0x%08x(+0)| ofs=0x%08x(+0)| search [ ",
					byte_pos(), offset);
				for (int i = 0; i < size; ++i)
					printf("%02x ", static_cast<uint8_t>(address[i]));

				printf("] (\"%s\") %s at adr=0x%08x.\n",
					s.c_str(),
					offset + prev_byte == this->size() ? "not found [EOS]"
						: offset == end_offset ? "not found [end_offset]"
						: "found",
					offset + prev_byte);
			}

			return offset;
		}

		// ストリームに書き込み
		bool write(const char *buf, int size)
		{
			if (FAIL(valid_ptr(buf)))
			{
				ERR << "buf=" << hex << buf << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("invalid argument."));
			}

			if (FAIL(size >= 0))
			{
				ERR << "size=" << hex << size << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("invalid argument."));
			}

			return bs_.write(buf, size);
		}

		bool put_char(char c)
		{
			return bs_.put_char(c);
		}

		// ストリームに追記
		bool append(const char *buf, int size)
		{
			if (FAIL(valid_ptr(buf)))
			{
				ERR << "buf=" << hex << buf << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("invalid argument."));
			}
			
			if (FAIL(size >= 0))
			{
				ERR << "size=" << hex << size << OUTPUT_POS << endl;
				throw logic_error(FAIL_STR("invalid argument."));
			}
			
			int prev_byte = byte_pos();
			int prev_bit = bit_pos();

			bs_.seekpos(this->size(), 0);
			bs_.write(buf, size);
			return seekpos(prev_byte, prev_bit);
		}

		bool append_char(char c)
		{
			int prev_byte = byte_pos();
			int prev_bit = bit_pos();

			bs_.seekpos(size(), 0);
			bs_.put_char(c);
			return seekpos(prev_byte, prev_bit);
		}


		// 別のストリームに転送
		// 現状オーバーヘッド多め
		bool transfer_byte(const char* name, LuaGlueBitstream &stream, int size, bool advance)
		{
			if (FAIL(bs_.check_offset_byte(size)))
			{
				ERR << "size=" << hex << size << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			char* buf = new char[static_cast<unsigned int>(size)];
			bs_.look_byte_string(buf, size);
			stream.append(buf, size);
			
			if (advance)
			{
				stringstream ss;
				ss << " >> transfer: " << name;
				read_byte(ss.str().c_str(), size);
			}

			return true;
		}

		// 現在位置からバイト表示
		bool dump_bytes(int max_size)
		{
			int dump_len = std::min<int>(bs_.size() - bs_.byte_pos(), max_size);
			auto buf = make_unique<char[]>(dump_len);
			bs_.look_byte_string(buf.get(), dump_len);
			return rf::dump_bytes(buf.get(), 0, dump_len);
		}

		// 現在位置からバイト表示
		bool dump_string(int max_size)
		{
			int dump_len = std::min<int>(bs_.size() - bs_.byte_pos(), max_size);
			auto buf = make_unique<char[]>(dump_len);
			bs_.look_byte_string(buf.get(), dump_len);
			return rf::dump_string(buf.get(), 0, dump_len);
		}

		// 現在位置からバイト表示
		bool dump(int max_size)
		{
			int dump_len = std::min<int>(bs_.size() - bs_.byte_pos(), max_size);
			auto buf = make_unique<char[]>(dump_len);
			bs_.look_byte_string(buf.get(), dump_len);
			return rf::dump(buf.get(), 0, dump_len, byte_pos());
		}
	};

	class LuaGlueBufBitstream final : public LuaGlueBitstream
	{
	public:

		LuaGlueBufBitstream() :LuaGlueBitstream()
		{
			assign(make_unique<std::stringbuf>(), 0);
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
			rb->reserve(size);
			return assign(std::move(rb), 0);
		}
	};


	class LuaGlueFileBitstream final : public LuaGlueBitstream
	{
	public:

		LuaGlueFileBitstream() :LuaGlueBitstream(){}
		LuaGlueFileBitstream(const string& file_name, const string& mode = "rb")
			: LuaGlueBitstream(){ open(file_name, mode); }

		// fopenとちょっと違う
		// 'raw'はどれか一つ
		// "r" -> 読み込み
		// "w" -> 書き込み＋ファイル初期化
		// "a" -> 書き込み＋末尾追加追加
		// "+" -> リードライト
		// "b" -> バイナリモード
		bool open(const string& file_name, const string& mode = "ib")
		{
			//auto del = [](std::filebuf* p){p->close(); delete p; };
			//unique_ptr<std::filebuf, decltype(del)> fb(new std::filebuf, del);

			auto fb = make_unique<std::filebuf>();
			std::ios::openmode m;

			if (mode.find('r') != string::npos)
				m = std::ios::in;
			else if (mode.find('w') != string::npos)
				m = (std::ios::out | std::ios::trunc);
			else if (mode.find('a') != string::npos)
				m = (std::ios::out | std::ios::app);
			else
			{
				ERR << "file open mode" << mode << endl;
				throw logic_error(FAIL_STR("invalid argument."));
			}

			if (mode.find('+') != string::npos)
				m |= (std::ios::in | std::ios::out);
			
			if (mode.find('b') != string::npos)
				m |= std::ios::binary;

			fb->open(file_name, m);

			int size = static_cast<int>(fb->pubseekoff(0, std::ios::end));
			if (size == EOF)
				size = 0;

			return assign(std::move(fb), size);
		}
	};

	class SqliteWrapper final
	{
	private:
		
		string filename_;

		// unique_ptr<sqlite3> db_;
		sqlite3* db_;

		vector<sqlite3_stmt*> stmts_;
				
		bool close()
		{
			for (auto stmt : stmts_)
			{
				sqlite3_finalize(stmt);
			}

			int ret = sqlite3_close(db_);
			if (FAIL(ret == SQLITE_OK))
			{
				ERR << "close error." << endl;
				throw runtime_error(FAIL_STR("file close error."));
			}
			return true;
		}

		bool open(const string& filename)
		{
			int ret = sqlite3_open(filename.c_str(), &db_);
			if (FAIL(ret == SQLITE_OK))
			{
				ERR << "open error." << endl;
				throw runtime_error(FAIL_STR("file open error."));
			}

			//auto deleter = [](sqlite3* db){
			//	int e = sqlite3_close(db);
			//	if (e != SQLITE_OK){
			//		ERR << "close error." << endl;
			//	}
			//};
			//unique_ptr<sqlite3*> p(&db);
			//db_ = std::move(p);

			return true;
		}

		// 呼び出し拒否
		SqliteWrapper(){}

	public:

		bool exec(const string& sql)
		{
			// テーブルの作成
			char *msg = nullptr;
			int ret = sqlite3_exec(db_, sql.c_str(), NULL, NULL, &msg);
			if (FAIL(ret == SQLITE_OK))
			{
				ERR << sql << msg << endl;
				sqlite3_free(msg);
				throw runtime_error(FAIL_STR("sql exec failed."));
			}
			return true;
		}

		// 別のクラスにしたい
		int prepare(const string& sql)
		{
			sqlite3_stmt* stmt;

			// prepare, length=-1ならNULL文字検索, 最後のNULLはパース完了箇所が欲しければ
			int ret = sqlite3_prepare_v2(db_, sql.c_str(), sql.length(), &stmt, NULL);
			if (FAIL(ret == SQLITE_OK))
			{
				ERR << "prepare error:" << sqlite3_errmsg(db_) << endl;
				throw runtime_error("SQL prepare failed.");
			}
			//
			stmts_.push_back(stmt);
			return stmts_.size() - 1;
		}

		bool reset(int stmt_ix)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			sqlite3_reset(stmts_[stmt_ix]);
			return true;
		}

		int step(int stmt_ix)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}

			// SQLITE_ERROR：クエリが何らかの理由によりエラーとなった場合
			// SQLITE_ROW : クエリの結果が列として取れる場合
			// SQLITE_BUSY : クエリが未完の場合
			// SQLITE_DONE : クエリが完了時
			int ret;
			for (int i=0;i<10000;i++)
			{
				ret = sqlite3_step(stmts_[stmt_ix]);
				if (ret == SQLITE_DONE)
				{
					break;
				}
				else if (ret == SQLITE_ROW)
				{
					break;
				}
				else if (ret == SQLITE_BUSY)
				{
					cout << "busy" << endl;
				}
				else
				{
					ERR << "unknown result in sqlite3_step" << ret << endl;
					throw runtime_error(FAIL_STR("sql step error."));
				}
			}
			return ret;
		}

		bool bind_int(int stmt_ix, int sql_ix, int value)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			sqlite3_bind_int(stmts_[stmt_ix], sql_ix, value);
			return true;
		}

		bool bind_text(int stmt_ix, int sql_ix, const string &text)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			sqlite3_bind_text(stmts_[stmt_ix], sql_ix,
				text.c_str(), text.length(), SQLITE_TRANSIENT);
			return true;
		}

		bool bind_real(int stmt_ix, int sql_ix, double value)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			sqlite3_bind_double(stmts_[stmt_ix], sql_ix, value);
			return true;
		}

		bool bind_blob(int stmt_ix, int sql_ix, const void* blob, int size,
			void(*destructor)(void*))
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			sqlite3_bind_blob(stmts_[stmt_ix], sql_ix,
				blob, size, destructor);
			return true;
		}

		int column_count(int stmt_ix)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			return sqlite3_column_count(stmts_[stmt_ix]);
		}

		string column_name(int stmt_ix, int colmun)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			return sqlite3_column_name(stmts_[stmt_ix], colmun);
		}

		int column_type(int stmt_ix, int column)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			return sqlite3_column_type(stmts_[stmt_ix], column);
		}

		int column_int(int stmt_ix, int column)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			return sqlite3_column_int(stmts_[stmt_ix], column);
		}

		string column_text(int stmt_ix, int column)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			return reinterpret_cast<const char*>(
				sqlite3_column_text(stmts_[stmt_ix], column));
		}

		double column_real(int stmt_ix, int column)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			return sqlite3_column_double(stmts_[stmt_ix], column);
		}

		const void* column_blob(int stmt_ix, int column)
		{
			if (FAIL(stmt_ix < static_cast<int>(stmts_.size())))
			{
				ERR << "unprepared index, [" << stmt_ix << "]" << endl;
				throw runtime_error(FAIL_STR("unprepared index."));
			}
			return sqlite3_column_blob(stmts_[stmt_ix], column);
		}

		SqliteWrapper(const string& filename)
		{
			open(filename);
		}

		~SqliteWrapper()
		{
			close();
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
		def("size",               &LuaGlueBitstream::size).              // ファイルサイズ取得
		def("enable_print",       &LuaGlueBitstream::enable_print).      // 解析ログのON/OFF
		def("little_endian",      &LuaGlueBitstream::little_endian).     // ２バイト/４バイトの読み込み時はエンディアンを変換する
		def("seekpos_bit",        &LuaGlueBitstream::seekpos_bit).       // 先頭からファイルポインタ移動
		def("seekpos_byte",       &LuaGlueBitstream::seekpos_byte).      // 先頭からファイルポインタ移動
		def("seekpos",            &LuaGlueBitstream::seekpos).           // 先頭からファイルポインタ移動
		def("seekoff_bit",        &LuaGlueBitstream::seekoff_bit).       // 現在位置からファイルポインタ移動
		def("seekoff_byte",       &LuaGlueBitstream::seekoff_byte).      // 現在位置からファイルポインタ移動
		def("seekoff",            &LuaGlueBitstream::seekoff).           // 現在位置からファイルポインタ移動
		def("bit_pos",            &LuaGlueBitstream::bit_pos).           // 現在のビットオフセットを取得
		def("byte_pos",           &LuaGlueBitstream::byte_pos).          // 現在のバイトオフセットを取得
		def("read_bit",           &LuaGlueBitstream::read_bit).          // ビット単位で読み込み
		def("read_byte",          &LuaGlueBitstream::read_byte).         // バイト単位で読み込み
		def("read_string",        &LuaGlueBitstream::read_string).       // 文字列を読み込み
		def("read_expgolomb",     &LuaGlueBitstream::read_expgolomb).    // 指数ゴロムとしてビットを読む
		def("comp_bit",           &LuaGlueBitstream::compare_bit).       // ビット単位で比較
		def("comp_byte",          &LuaGlueBitstream::compare_byte).      // バイト単位で比較
		def("comp_string",        &LuaGlueBitstream::compare_string).    // 文字列を比較
		def("comp_expgolomb",     &LuaGlueBitstream::compare_expgolomb). // 指数ゴロムを比較
		def("look_bit",           &LuaGlueBitstream::look_bit).          // ポインタを進めないでビット値を取得、4byteまで
		def("look_byte",          &LuaGlueBitstream::look_byte).         // ポインタを進めないでバイト値を取得、4byteまで
		def("look_byte_string",   &LuaGlueBitstream::look_byte_string).  // ポインタを進めないで文字列を取得
		def("look_expgolomb",     &LuaGlueBitstream::look_expgolomb).    // ポインタを進めないで指数ゴロムを取得、4byteまで
		def("find_byte",          &LuaGlueBitstream::find_byte).         // １バイトの一致を検索
		def("find_byte_string",   &LuaGlueBitstream::find_byte_string).  // 数バイト分の一致を検索
		def("transfer_byte",      &LuaGlueBitstream::transfer_byte).     // 部分ストリーム(Bitstream)を作成
		def("write",              &LuaGlueBitstream::write).             // ビットストリームの終端に書き込む
		def("put_char",           &LuaGlueBitstream::put_char).          // ビットストリームの終端に書き込む
		def("append",             &LuaGlueBitstream::append).            // ビットストリームの終端に書き込む
		def("append_char",        &LuaGlueBitstream::append_char).       // ビットストリームの終端に書き込む
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

	// SQLiterラッパー
	lua->def_class<SqliteWrapper>("SQLite")->
		def("new",          LuaBinder::constructor<SqliteWrapper(const string&)>()).
		def("exec",         &SqliteWrapper::exec).
		def("prepare",      &SqliteWrapper::prepare).
		def("step",         &SqliteWrapper::step).
		def("reset",        &SqliteWrapper::reset).
		def("bind_int",     &SqliteWrapper::bind_int).
		def("bind_text",    &SqliteWrapper::bind_text).
		def("bind_real",    &SqliteWrapper::bind_real).
		def("column_name",  &SqliteWrapper::column_name).
		def("column_type",  &SqliteWrapper::column_type).
		def("column_count", &SqliteWrapper::column_count).
		def("column_int",   &SqliteWrapper::column_int).
		def("column_text",  &SqliteWrapper::column_text).
		def("column_real",  &SqliteWrapper::column_real);

	// // SQLite
	// lua->object<sqlite3*>("sqlite3");
	// lua->object<sqlite3_stmt*>("sqlite3_stmt");
	// lua->def("sqlite3_open",         sqlite3_open);
	// lua->def("sqlite3_close",        sqlite3_close);
	// lua->def("sqlite3_exec",         sqlite3_exec);
	// lua->def("sqlite3_prepare_v2",   sqlite3_prepare_v2);
	// lua->def("sqlite3_step",         sqlite3_step);
	// lua->def("sqlite3_reset",        sqlite3_reset);
	// lua->def("sqlite3_bind_int",     sqlite3_bind_int);
	// lua->def("sqlite3_bind_text",    sqlite3_bind_text);
	// lua->def("sqlite3_column_int",   sqlite3_column_int);
	// lua->def("sqlite3_column_text",  sqlite3_column_text);
	// lua->def("sqlite3_column_type",  sqlite3_column_text);
	// lua->def("sqlite3_column_count", sqlite3_column_count);
	lua->rawset("SQLITE_ROW",        SQLITE_ROW);
	lua->rawset("SQLITE_INTEGER",    SQLITE_INTEGER);
	lua->rawset("SQLITE_FLOAT",      SQLITE_FLOAT);
	lua->rawset("SQLITE_TEXT",       SQLITE_TEXT);
	lua->rawset("SQLITE_BLOB",       SQLITE_BLOB);
	lua->rawset("SQLITE_NULL",       SQLITE_NULL);

	// Luaの環境を登録
#ifdef _MSC_VER
	if (FAIL(lua->dostring("_G.windows = true")))
	{
		ERR << "lua.dostring err" << endl;
	}
#endif

	// Luaにmain関数の引数を継承
	// argc
	{
		stringstream ss;
		ss << "_G.argc=" << argc;
		if (FAIL(lua->dostring(ss.str())))
		{
			ERR << "lua.dostring err" << endl;
		}
	}

	// argv
	{
		if (FAIL(lua->dostring("_G.argv = {}")))
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

			if (FAIL(lua->dostring(ss.str())))
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
	
	for (int i=0;i< argc; i++)
	{
		cout << argv[i] << endl;
	}
	auto lua = init_lua(argc, argv);

	// windowsのドラッグアンドドロップに対応するため、
	// 実行ファイルのディレクトリ名を抽出する
	// ついでに'\\'を'/'に変換しておく
	string exe_path;
	string exe_dir;
	string lua_file_name = "script/default.lua";
	if (argc>0)
	{
#if defined(_MSC_VER) && (_MSC_VER >= 1800)
		exe_path = std::regex_replace(argv[0], std::regex(R"(\\)"), "/");
		std::smatch result;
		std::regex_search(exe_path, result, std::regex("(.*)/"));
		exe_dir = result.str();
#elif defined(__GNUC__) && __cplusplus >= 201300L
		exe_path = argv[0];
		std::smatch result;
		std::regex_search(exe_path, result, std::regex("(.*)/"));
		exe_dir = result.str();
#else
		exe_path = argv[0];
		exe_dir = "";
#endif
		stringstream ss;
		ss << "_G.__exec_dir__=\"" << exe_dir << '\"';
		if (FAIL(lua->dostring(ss.str())))
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
			if (FAIL(lua->dofile(lua_file_name)))
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

		if (FAIL(lua->dostring(str)))
		{
			ERR << "lua.dostring err" << endl;
		}
	};

	return 0;
}
