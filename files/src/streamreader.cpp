#include "rflib/bighead.h"
#include "rflib/bitstream.h"
#include "rflib/sqlwrapper.h"
#include "rflib/luabinder.hpp"

namespace rf
{
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

		// 暫定
		static void close_file(const char* file_name)
		{
			auto it = ofs_map_.find(file_name);
			if (it != ofs_map_.end())
			{
				it->second->close();
				ofs_map_.erase(it);
			}
		}

		// 指定したバイト列を指定したファイル名に出力、二度目以降は追記
		static void write_to_file(const char* file_name, const char* address, integer size)
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
		}

		// printfの出力先を変更する
		static void stdout_to_file(bool enable)
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
		}
	};

	map<string, unique_ptr<ofstream> > FileManager::ofs_map_;
	
	class LuaGlueBitstream
	{
	public:

		// ストリームからファイルに転送
		// 現状オーバーヘッド多め
		static void transfer_to_file(
			const char* file_name, LuaGlueBitstream &stream, integer size, bool advance = false)
		{
			if (FAIL(size >= 0))
				throw runtime_error((stream.print_status(), "size"));

			char* buf = new char[static_cast<int>(size)];

			stream.bs_.look_byte_string(buf, size);
			FileManager::getInstance().write_to_file(file_name, buf, size);
			if (advance)
			{
				stringstream ss;
				ss << " >> " << file_name;
				stream.read_bytes(ss.str().c_str(), size);
			}
		}

	private:

		Bitstream bs_;
		bool printf_on_;
		bool little_endian_;
		enum { MAX_DUMP = 1024 };

		// ちょっとどうだろう
		uinteger read_bits_unsafe(const char* name, integer size) throw(...)
		{
			uinteger v;
			integer prev_byte = byte_pos();
			integer prev_bit = bit_pos();

			v = bs_.read_bits(size);

			if (little_endian_)
			{
				if (size == 32)
					v = reverse_endian_32(static_cast<uint32_t>(v));
				else if (size == 16)
					v = reverse_endian_16(static_cast<uint16_t>(v));
			}

			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%010llx(+%lld)| siz=0x%010llx(+%lld)| %-40s | val=0x%-8x (%lld%s)\n",
					static_cast<unsigned long long>(prev_byte),
					static_cast<long long>(prev_bit),
					static_cast<unsigned long long>(size / 8),
					static_cast<long long>(size % 8),
					name,
					static_cast<unsigned long long>(v),
					static_cast<long long>(v),
					((size == 32 || size == 16) && little_endian_) ? ", \"little\"" : "");
			}

			return v;
		}

		// ちょっとどうだろう
		uinteger read_bytes_unsafe(const char* name, integer byte, integer bit) throw(...)
		{
			integer prev_byte = byte_pos();
			integer prev_bit = bit_pos();
			char buf[16];
			integer dump_size = std::min<integer>(16, byte);

			bs_.look_byte_string(buf, dump_size);
			bs_.seekoff(byte, bit);

			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%010llx(+%lld)| siz=0x%010llx(+%lld)| %-40s | ",
					static_cast<unsigned long long>(prev_byte),
					static_cast<long long>(prev_bit),
					static_cast<unsigned long long>(byte),
					static_cast<long long>(bit),
					name);
				rf::dump_bytes(buf, 0, dump_size);

				if (16 > byte)
					putchar('\n');
				else
					printf(" ...\n");
			}

			return 0;
		}

	protected:

		LuaGlueBitstream()
			:printf_on_(true), little_endian_(false){}

		// streambufを設定
		// template<template<typename T> class D >
		// bool assign(unique_ptr<streambuf, D>&& b)
		void assign(unique_ptr<std::streambuf>&& b, integer size)
		{
			bs_.assign(std::move(b), size);
		}

		// 現在の状態を表示
		void print_status()
		{
			printf("current pos = 0x%010llx(+%lld)\n",
				static_cast<unsigned long long>(byte_pos()),
				static_cast<unsigned long long>(bit_pos()));
			seekpos(byte_pos() - 127 < 0 ? 0 : byte_pos() - 127, 0);
			dump(256);
		}
	public:

		// デストラクタ、このクラスは派生するので用意
		virtual ~LuaGlueBitstream(){}

		// ストリームサイズ取得
		integer  size() { return bs_.size(); }

		// 現在のビットオフセットを取得
		integer  byte_pos() { return bs_.byte_pos(); }

		// 現在のバイトオフセットを取得
		integer  bit_pos() { return bs_.bit_pos(); }

		// コンソール出力ON/OFF
		void enable_print(bool enable) { printf_on_ = enable; }

		// ２バイト/４バイトの読み込み時はエンディアンを変換する
		void little_endian(bool enable_) { little_endian_ = enable_; }

		// 現在位置からファイルポインタ移動
		void seekoff(integer byte, integer bit) { bs_.seekoff(byte, bit); }

		// 先頭からファイルポインタ移動
		void seekpos(integer byte, integer bit) { bs_.seekpos(byte, bit); }

		// ビット単位で読み込み
		// 32/64bit以上はread_bytesをコール
		// integerサイズ以上は0を返す
		uinteger read_bits(const char* name, integer size) throw(...)
		{
			if (FAIL(size >= 0))
				throw runtime_error((print_status(), string(name) + " size < 0, size = " + to_string(size)));

			if (FAIL(bs_.check_off(0, size)))
				throw runtime_error((print_status(), string(name) + " overflow, size=" + to_string(size)));

			if (size > static_cast<integer>(sizeof(uinteger)*8))
			{
				// byteで読み込むがbit単位でシークする必要がある
				integer prev_byte = byte_pos();
				integer prev_bit = bit_pos();
				read_bytes_unsafe(name, size / 8, size % 8);
				seekpos(prev_byte + (size + prev_bit) / 8, (size + prev_bit) % 8);
				return 0;
			}
			else
			{
				return read_bits_unsafe(name, size);
			}
		}

		// バイト単位で読みとばし
		// 32/64bit以下ははread_bitsをコール
		// integerサイズ以上は0を返す
		uinteger read_bytes(const char* name, integer size) throw(...)
		{
			if (FAIL(bs_.check_off(size, 0)))
				throw runtime_error((print_status(), 
					string(name) + " overflow, size=" + to_string(size)));

			if (FAIL(bs_.bit_pos() == 0))
			{
				WARNING << " \"" << name << "\" bit_pos_ is not aligned. bit_pos_="
					<< hex << bit_pos() << " " << OUTPUT_POS << endl;
			}

			if (size > static_cast<integer>(sizeof(uinteger)))
			{
				return read_bytes_unsafe(name, size, 0);
			}
			else
			{
				return read_bits_unsafe(name, 8 * size);
			}
		}

		// バイト単位で文字列として読み込み
		// むちゃくちゃ長い文字列はまずい。
		string read_string(const char* name, integer size) throw(...)
		{
			if (FAIL(bs_.check_off(size, 0)))
				throw runtime_error((print_status(), string(name) + " overflow, size = " + to_string(size)));

			integer prev_byte = bs_.byte_pos();
			string str = bs_.read_string(size);

			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%010llx    | siz=0x00%08x    | %-40s | str=\"%s\"\n",
					static_cast<unsigned long long>(prev_byte),
					str.length(), name, str.c_str());
				if (size < static_cast<integer>(str.length() - 1))
					ERR << "size > str.length() - 1 (" << str.length()
					<< " != " << size << ")" << endl;
			}

			return str;
		}

		// 指数ゴロムとして読み込み
		uinteger read_expgolomb(const char* name) throw(...)
		{
			integer prev_byte = bs_.byte_pos();
			integer prev_bit = bs_.bit_pos();

			uinteger v;
			integer size;
			bs_.read_expgolomb(v, size);

			if (printf_on_ || (name[0] == '#'))
			{
				printf(" adr=0x%010llx(+%lld)| siz=0x%010llx(+%lld)| %-40s | exp=0x%-8x (%lld%s)\n",
					static_cast<unsigned long long>(prev_byte),
					static_cast<long long>(prev_bit),
					static_cast<unsigned long long>(size / 8),
					static_cast<long long>(size % 8),
					name,
					static_cast<unsigned long long>(v),
					static_cast<long long>(v),
					((size == 32 || size == 16) && little_endian_) ? ", \"little\"" : "");
			}

			return v;
		}

		// ビット単位で先読み
		uinteger look_bits(integer size) throw(...)
		{
			if (FAIL(bs_.check_off(size, 0)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));

			return bs_.look_bits(size);
		}

		// バイト単位で先読み
		uinteger look_bytes(integer size) throw(...)
		{
			if (FAIL(bs_.check_off(size, 0)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));

			return bs_.look_bytes(size);
		}

#if 1
		string look_byte_string(integer size) throw(...)
		{
			if (FAIL(bs_.check_off(size, 0)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));

			auto buf = make_unique<char[]>(static_cast<int>(size));
			bs_.look_byte_string(buf.get(), size);

			return string(buf.get(), static_cast<int>(size));
		}
#else
		// 指定バッファ分だけデータを先読み
		bool look_byte_string(char* address, integer size)
		{
			return bs_.look_byte_string(address, size);
		}
#endif
		// 指数ゴロムで先読み
		uinteger look_expgolomb() throw(...)
		{
			uinteger val;
			integer size;
			bs_.look_expgolomb(val, size);
			return val;
		}

		// ビット単位で比較
		bool compare_bits(const char* name, integer size, uinteger compvalue) throw(...)
		{
			if (FAIL(bs_.check_off(0, size)))
				throw runtime_error((print_status(), string("overflow, size=") + to_string(size)));

			uinteger value = read_bits(name, size);
			if (value != compvalue)
			{
				printf("# compare value [%s] : 0x%010llx(%lld) != 0x%010llx(%lld)\n",
					name,
					static_cast<unsigned long long>(value),
					static_cast<long long>(value),
					static_cast<unsigned long long>(compvalue),
					static_cast<long long>(compvalue));

				return false;
			}
			return true;
		}

		// バイト単位で比較
		bool compare_bytes(const char* name, integer size, uinteger compvalue) throw(...)
		{
			if (FAIL(bs_.check_off(size, 0)))
				throw runtime_error((print_status(), string(name) + " overflow"));

			return compare_bits(name, 8 * size, compvalue);
		}

		// バイト単位で文字列として比較
		bool compare_string(const char* name, integer max_length, const char* comp_str) throw(...)
		{
			if (FAIL(bs_.check_off(max_length, 0)))
				throw runtime_error((print_status(), string(name) + " overflow, size=" + to_string(max_length)));

			string str = read_string(name, max_length);
			if (str != comp_str)
			{
				printf("# compare string [%s]: \"%s\" != \"%s\"\n", name, str.c_str(), comp_str);
				return false;
			}
			return true;
		}

		// 指数ゴロムとして比較
		bool compare_expgolomb(const char* name, uinteger compvalue) throw(...)
		{
			uinteger value = read_expgolomb(name);
			if (value != compvalue)
			{
				printf("# compare value [%s] : 0x%010llx(%lld) != 0x%010llx(%lld)\n",
					name,
					static_cast<unsigned long long>(value),
					static_cast<long long>(value),
					static_cast<unsigned long long>(compvalue),
					static_cast<long long>(compvalue));

				return false;
			}
			return true;
		}

		// １バイトの一致を検索
		integer find_byte(char c, bool advance, integer end_offset) throw(...)
		{
			integer prev_byte = bs_.byte_pos();
			integer offset = bs_.find_byte(c, advance, end_offset);

			if (printf_on_)
			{
				printf(" adr=0x%010llx    | ofs=0x%010llx    | search '0x%02x' %s at adr=0x%010llx.\n",
					static_cast<unsigned long long>(bs_.byte_pos()),
					static_cast<unsigned long long>(offset),
					static_cast<uint8_t>(c),
					offset == end_offset ? "not found [end_offset]"
						: offset + prev_byte == this->size() ? "not found [EOS]"
						: "found",
					static_cast<unsigned long long>(offset + prev_byte));

				if ((offset == end_offset) || (offset == this->size()))
					printf("# can not find byte:0x%x\n", static_cast<uint8_t>(c));
			}

			return offset;
		}

		// 数バイト分の一致を検索
		integer find_byte_string(const char* address, integer size, bool advance, integer end_offset) throw(...)
		{
			if (FAIL(valid_ptr(address)))
				throw logic_error((print_status(), "invalid address"));

			string s(address, static_cast<int>(size));
			integer prev_byte = bs_.byte_pos();
			integer offset = bs_.find_byte_string(address, size, advance, end_offset);

			if (printf_on_)
			{
				printf(" adr=0x%010llx    | ofs=0x%010llx    | search [ ",
					static_cast<unsigned long long>(byte_pos()),
					static_cast<unsigned long long>(offset));
				for (integer i = 0; i < size; ++i)
					printf("%02x ", static_cast<uint8_t>(address[i]));

				printf("] (\"%s\") %s at adr=0x%010llx.\n",
					s.c_str(),
					offset == end_offset ? "not found [end_offset]"
						: offset + prev_byte == this->size() ? "not found [EOS]"
						: "found",
					static_cast<unsigned long long>(offset + prev_byte));

				if ((offset == end_offset) || (offset == this->size()))
				{
					printf("# can not find byte string. [");
					for (integer i = 0; i < size; ++i)
						printf("%02x ", static_cast<uint8_t>(address[i]));
					printf("] (\"%s\")\n", s.c_str());
				}
			}

			return offset;
		}

		// １バイトの一致を検索
		integer rfind_byte(char c, bool advance, integer end_offset) throw(...)
		{
			integer prev_byte = bs_.byte_pos();
			integer offset = bs_.rfind_byte(c, advance, end_offset);

			if (printf_on_)
			{
				printf(" adr=0x%010llx    | ofs=%-12lld  | search '0x%02x' %s at adr=0x%010llx.\n",
					static_cast<unsigned long long>(bs_.byte_pos()),
					static_cast<long long>(offset),
					static_cast<uint8_t>(c),
					offset + prev_byte == 0 ? "not found [pos=0]"
					: offset == end_offset ? "not found [end_offset]"
					: "found",
					static_cast<unsigned long long>(offset + prev_byte));

				if ((offset == end_offset) || (offset == this->size()))
					printf("# can not find byte:0x%x\n", static_cast<uint8_t>(c));
			}

			return offset;
		}

		// 数バイト分の一致を検索
		integer rfind_byte_string(const char* address, integer size, bool advance, integer end_offset) throw(...)
		{
			if (FAIL(valid_ptr(address)))
				throw logic_error((print_status(), "invalid address"));

			string s(address, static_cast<int>(size));
			integer prev_byte = bs_.byte_pos();
			integer offset = bs_.rfind_byte_string(address, size, advance, end_offset);

			if (printf_on_)
			{
				printf(" adr=0x%010llx    | ofs=%-12d  | search [ ",
					static_cast<unsigned long long>(byte_pos()),
					static_cast<unsigned long long>(offset));
				for (integer i = 0; i < size; ++i)
					printf("%02x ", static_cast<uint8_t>(address[i]));

				printf("] (\"%s\") %s at adr=0x%010llx.\n",
					s.c_str(),
					offset + prev_byte == 0 ? "not found [pos=0]"
					: offset == end_offset ? "not found [end_offset]"
					: "found",
					static_cast<unsigned long long>(offset + prev_byte));

				if ((offset == end_offset) || (offset == this->size()))
				{
					printf("# can not find byte string. [");
					for (integer i = 0; i < size; ++i)
						printf("%02x ", static_cast<uint8_t>(address[i]));
					printf("] (\"%s\")\n", s.c_str());
				}
			}

			return offset;
		}

		// ストリームに書き込み
		void write(const char *buf, integer size)
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

			bs_.write(buf, size);
		}

		void put_char(char c)
		{
			bs_.put_char(c);
		}

		// ストリームに追記
		void append(const char *buf, integer size)
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

			integer prev_byte = byte_pos();
			integer prev_bit = bit_pos();

			bs_.seekpos(this->size(), 0);
			bs_.write(buf, size);
			seekpos(prev_byte, prev_bit);
		}

		void append_char(char c)
		{
			integer prev_byte = byte_pos();
			integer prev_bit = bit_pos();

			bs_.seekpos(size(), 0);
			bs_.put_char(c);
			seekpos(prev_byte, prev_bit);
		}


		// 別のストリームに転送
		// 現状オーバーヘッド多め
		void transfer_byte(const char* name, LuaGlueBitstream &stream, integer size, bool advance)
		{
			if (FAIL(bs_.check_off(size, 0)))
			{
				ERR << "size=" << hex << size << OUTPUT_POS << endl;
				throw runtime_error(FAIL_STR("range error."));
			}

			char* buf = new char[static_cast<int>(size)];
			bs_.look_byte_string(buf, size);
			stream.append(buf, size);

			if (advance)
			{
				stringstream ss;
				ss << " >> transfer: " << name;
				read_bytes(ss.str().c_str(), size);
			}
		}

		// 現在位置からバイト表示
		void dump_bytes(integer max_size)
		{
			integer dump_len = std::min<integer>(bs_.size() - bs_.byte_pos(), max_size);
			auto buf = make_unique<char[]>(static_cast<int>(dump_len));
			bs_.look_byte_string(buf.get(), dump_len);
			rf::dump_bytes(buf.get(), 0, dump_len);
		}

		// 現在位置からバイト表示
		void dump_string(integer max_size)
		{
			integer dump_len = std::min<integer>(bs_.size() - bs_.byte_pos(), max_size);
			auto buf = make_unique<char[]>(static_cast<int>(dump_len));
			bs_.look_byte_string(buf.get(), dump_len);
			rf::dump_string(buf.get(), 0, dump_len);
		}

		// 現在位置からバイト表示
		void dump(integer max_size)
		{
			integer dump_len = std::min<integer>(bs_.size() - bs_.byte_pos(), max_size);
			auto buf = make_unique<char[]>(static_cast<int>(dump_len));
			bs_.look_byte_string(buf.get(), dump_len);
			rf::dump(buf.get(), 0, dump_len, byte_pos());
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
		LuaGlueFifoBitstream(integer size) :LuaGlueBitstream(){ reserve(size); }

		// バッファを確保
		void reserve(integer size)
		{
			auto rb = make_unique<RingBuf>();
			rb->reserve(size);
			assign(std::move(rb), 0);
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
		void open(const string& file_name, const string& mode = "ib")
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

			integer size = static_cast<integer>(fb->pubseekoff(0, std::ios::end));
			if (size == EOF)
				size = 0;

			assign(std::move(fb), size);
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
	lua->def("close_file",       FileManager::close_file);         // 指定したバイト列をファイルに出力
	lua->def("transfer_to_file", LuaGlueBitstream::transfer_to_file); // 指定したストリームををファイルに出力
	lua->def("reverse_16",       reverse_endian_16);                  // 16ビットエンディアン変換
	lua->def("reverse_32",       reverse_endian_32);                  // 32ビットエンディアン変換

	// インターフェース
	lua->def_class<LuaGlueBitstream>("IBitstream")->
		def("size",               &LuaGlueBitstream::size).              // ファイルサイズ取得
		def("enable_print",       &LuaGlueBitstream::enable_print).      // 解析ログのON/OFF
		def("little_endian",      &LuaGlueBitstream::little_endian).     // ２バイト/４バイトの読み込み時はエンディアンを変換する
		def("seekpos",            &LuaGlueBitstream::seekpos).           // 先頭からファイルポインタ移動
		def("seekoff",            &LuaGlueBitstream::seekoff).           // 現在位置からファイルポインタ移動
		def("bit_pos",            &LuaGlueBitstream::bit_pos).           // 現在のビットオフセットを取得
		def("byte_pos",           &LuaGlueBitstream::byte_pos).          // 現在のバイトオフセットを取得
		def("read_bit",           &LuaGlueBitstream::read_bits).         // ビット単位で読み込み
		def("read_byte",          &LuaGlueBitstream::read_bytes).        // バイト単位で読み込み
		def("read_string",        &LuaGlueBitstream::read_string).       // 文字列を読み込み
		def("read_expgolomb",     &LuaGlueBitstream::read_expgolomb).    // 指数ゴロムとしてビットを読む
		def("comp_bit",           &LuaGlueBitstream::compare_bits).      // ビット単位で比較
		def("comp_byte",          &LuaGlueBitstream::compare_bytes).     // バイト単位で比較
		def("comp_string",        &LuaGlueBitstream::compare_string).    // 文字列を比較
		def("comp_expgolomb",     &LuaGlueBitstream::compare_expgolomb). // 指数ゴロムを比較
		def("look_bit",           &LuaGlueBitstream::look_bits).         // ポインタを進めないでビット値を取得、4byteまで
		def("look_byte",          &LuaGlueBitstream::look_bytes).        // ポインタを進めないでバイト値を取得、4byteまで
		def("look_byte_string",   &LuaGlueBitstream::look_byte_string).  // ポインタを進めないで文字列を取得
		def("look_expgolomb",     &LuaGlueBitstream::look_expgolomb).    // ポインタを進めないで指数ゴロムを取得、4byteまで
		def("find_byte",          &LuaGlueBitstream::find_byte).         // １バイトの一致を検索
		def("find_byte_string",   &LuaGlueBitstream::find_byte_string).  // 数バイト分の一致を検索
		def("rfind_byte",         &LuaGlueBitstream::rfind_byte).        // １バイトの一致を終端から逆検索
		def("rfind_byte_string",  &LuaGlueBitstream::rfind_byte_string). // 数バイト分の一致を終端から逆検索
		def("transfer_byte",      &LuaGlueBitstream::transfer_byte).     // 部分ストリーム(Bitstream)を作成
		def("write",              &LuaGlueBitstream::write).             // ビットストリームの現在位置に書き込む
		def("put_char",           &LuaGlueBitstream::put_char).          // ビットストリームの現在位置に書き込む
		def("append",             &LuaGlueBitstream::append).            // ビットストリームの終端に書き込む
		def("append_char",        &LuaGlueBitstream::append_char).       // ビットストリームの終端に書き込む
		def("dump",
			(bool(LuaGlueBitstream::*)(integer)) &LuaGlueBitstream::dump); // 現在位置からバイト表示

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
		def("new",     LuaBinder::constructor<LuaGlueFifoBitstream(integer)>()).
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
	lua->setglobal("SQLITE_ROW",        SQLITE_ROW);
	lua->setglobal("SQLITE_INTEGER",    SQLITE_INTEGER);
	lua->setglobal("SQLITE_FLOAT",      SQLITE_FLOAT);
	lua->setglobal("SQLITE_TEXT",       SQLITE_TEXT);
	lua->setglobal("SQLITE_BLOB",       SQLITE_BLOB);
	lua->setglobal("SQLITE_NULL",       SQLITE_NULL);

	// Luaの環境を登録
#ifdef _MSC_VER
	if (FAIL(lua->dostring("_G.windows = true")))
	{
		ERR << "lua.dostring err" << endl;
	}
#else
	if (FAIL(lua->dostring("_G.windows = false")))
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
		"--lua  :start by file mode\n"
		"--help :show this help" << endl;
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
