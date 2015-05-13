// 定義ファイルに従ってストリームを読む
// いまのところ個々の読み込みは512MBまで

#include <iostream>
#include <vector>
#include <stack>
#include <map>
#include <memory>
#include <sstream>
#include <fstream>
#include <algorithm>
#include <regex>
#include <cctype>

#include "luabinder.hpp"

#define ERR cerr << "# c++ error (l." << dec << __LINE__ << ") "
#define NULL_RETURN(x, ret) do{if ((x) == nullptr){ERR << "NULL ptr" << endl;return (ret);}} while (0)

using std::vector;
using std::stack;
using std::map;
using std::pair;
using std::string;
using std::shared_ptr;
using std::istringstream;
using std::stringstream;
using std::ifstream;
using std::ofstream;
using std::to_string;
using std::stoi;
using std::make_shared;
using std::cout;
using std::cin;
using std::cerr;
using std::endl;
using std::hex;
using std::dec;
using std::min;

// バッファダンプ
bool dump_line(const unsigned char* buf, unsigned int offset, unsigned int byte_size)
{
	for (unsigned int i = 0; i < byte_size; ++i)
	{
		printf("%02x ", buf[offset + i]);
	}
	return true;
}

bool dump_line_by_char(const unsigned char* buf, unsigned int offset, unsigned int byte_size)
{
	for (unsigned int i = 0; i < byte_size; ++i)
	{
		if (isalpha(buf[offset + i]))
			putchar(buf[offset + i]);
		else
			putchar('.');
	}
	return true;
}

bool dump(const unsigned char* buf, unsigned int offset, unsigned int byte_size)
{
	printf("     offset    | +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F | 0123456789ABCDEF\n");

	unsigned int cur = offset;
	unsigned int end = offset + byte_size;
	for (; cur + 16 <= end; cur += 16)
	{
		printf("     0x%08x| ", cur);
		dump_line(buf, cur, 16);
		printf("| ");
		dump_line_by_char(buf, cur, 16);
		putchar('\n');
	}

	if (cur < end)
	{
		printf("     0x%08x| ", cur);
		dump_line(buf, cur, byte_size % 16);

		for (unsigned int i = 0; i < 16 - (byte_size % 16); ++i)
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
class Bitstream
{
protected:
	shared_ptr<unsigned char> buf_;
	unsigned int   size_;
	unsigned int   cur_byte_;
	unsigned int   cur_bit_;

public:

	Bitstream() :buf_(nullptr), size_(0), cur_bit_(0), cur_byte_(0){}
	virtual ~Bitstream(){}

	virtual const shared_ptr<unsigned char> buf() const { return buf_; }
	virtual unsigned int size()     const { return size_; }
	virtual unsigned int cur_byte() const { return cur_byte_; }
	virtual unsigned int cur_bit()  const { return cur_bit_; }

	virtual bool reset_buf(shared_ptr<unsigned char> buf_, unsigned int size)
	{
		buf_ = buf_;
		size_ = size;
		cur_byte_ = 0;
		cur_bit_ = 0;
		return true;
	}

	virtual bool check_eos() const
	{
		if (cur_byte_ == size_)
		{
			cout << "[EOS]" << endl;
			return true;
		}
		return false;
	}

	virtual bool check_length(unsigned int bit_length) const
	{
		unsigned int next_byte = cur_byte_ + (cur_bit_ + bit_length) / 8;
		if (size_ < next_byte)
		{
			ERR << "overrun size 0x" << hex << size_ << " <= next 0x" << next_byte << endl;
			return false;
		}
		return true;
	}

	virtual bool cut_bit() 
	{
		if (cur_bit_ != 0)
		{
			++cur_byte_;
			cur_bit_ = 0;
		}
		return true;
	}

	virtual bool bit_advance(unsigned int bit_length)
	{
		if (!check_length(bit_length))
			return false;

		cur_byte_ += (cur_bit_ + bit_length) / 8;
		cur_bit_ = (cur_bit_ + bit_length) % 8;

		return true;
	}

	virtual bool read_bit(unsigned int bit_length, unsigned int* ret_value)
	{
		if (!check_length(bit_length))
			return false;

		if (bit_length > 32)
		{
			ERR << "read bit length > 32" << endl;
			return false;
		}

		*ret_value = 0;
		unsigned int already_read = 0;

		// 先頭の中途半端なビットを読んでから、残りをバイトストリームとして読む
		// read_lengthが現在のバイトに収まるならビット読み出しまでで終了
		if (cur_bit_ + bit_length < 8)
		{
			*ret_value = buf_.get()[cur_byte_];
			*ret_value >>= 8 - (cur_bit_ + bit_length); // 下位ビットを合わせる
			*ret_value &= ((1 << bit_length) - 1); // 上位ビットを捨てる
			bit_advance(bit_length);
			return true;
		}
		else
		{
			unsigned int remained_bit = 8 - cur_bit_;
			*ret_value = buf_.get()[cur_byte_] & ((1 << remained_bit) - 1);
			bit_advance(remained_bit);
			already_read += remained_bit;
		}

		while (bit_length > already_read)
		{
			if (bit_length - already_read < 8)
			{
				*ret_value <<= (bit_length - already_read);
				*ret_value |= buf_.get()[cur_byte_] >> (8 - (bit_length - already_read));
				bit_advance(bit_length - already_read);
				break;
			}
			else
			{
				*ret_value <<= 8;
				*ret_value |= buf_.get()[cur_byte_];
				bit_advance(8);
				already_read += 8;
			}
		}

		return true;
	}
	
	virtual bool read_string(unsigned int byte_length, string* ret_str)
	{
		char* p = reinterpret_cast<char*>(&buf().get()[cur_byte_]);

		// 面倒なので文字列はバイトストリームになっていなければエラー
		if ((!check_length(byte_length)
		||  (cur_bit_ != 0))
		||  (!bit_advance(8 * byte_length)))
		{
			ERR << "read_string error" << endl;
			return false;
		}

		ret_str->assign(p, byte_length);

		return true;
	}
};

class FileBitstream : public Bitstream
{
private:

	// 一度に読み込むサイズ5MB
	// static const unsigned int BUF_SIZE = 5 * 1024 * 1024;
	enum{ BUF_SIZE = 5 * 1024 * 1024 };

	string file_name_;

	ifstream ifs_;
	unsigned int file_size_;
	unsigned int file_offset_;
	unsigned int file_bufferd_size_;

public:
	
	FileBitstream()
		:file_offset_(0), file_bufferd_size_(0), file_size_(0), Bitstream()
	{
		buf_ = shared_ptr<unsigned char>(new unsigned char[BUF_SIZE]);
	}

	FileBitstream(const string& file_name)
		:file_offset_(0), file_bufferd_size_(0), file_size_(0), Bitstream()
	{
		buf_ = shared_ptr<unsigned char>(new unsigned char[BUF_SIZE]);
		open(file_name);
	}

	virtual ~FileBitstream(){}

	virtual unsigned int cur_byte()          const{ return Bitstream::cur_byte() + file_offset_; }
	virtual unsigned int buf_cur_byte()      const{ return Bitstream::cur_byte(); };
	virtual unsigned int file_size()         const{ return file_size_; };
	virtual unsigned int file_offset()       const{ return file_offset_; };
	virtual unsigned int file_bufferd_size() const{ return file_bufferd_size_; };

	virtual bool open(const string& file_name_)
	{
		if (ifs_)
			ifs_.close();

		ifs_.open(file_name_, ifstream::binary);
		if (!ifs_)
		{
			ERR << "open read file [" << file_name_ << "]" << endl;
			return false;
		}

		ifs_.seekg(0, ifstream::end);
		file_size_ = static_cast<int>(ifs_.tellg());
		ifs_.seekg(0, ifstream::beg);

		check_load_stream(0, BUF_SIZE);
		return true;
	}

	virtual bool close()
	{
		if (ifs_)
			ifs_.close();
		return true;
	}

	virtual bool check_length(unsigned int bit_length) const
	{
		unsigned int next_byte = cur_byte_ + (cur_bit_ + bit_length) / 8;
		if (file_size_ < next_byte)
		{
			ERR << "overrun size 0x" << hex << size_ << " <= next 0x" << next_byte << endl;
			return false;
		}
		return true;
	}

	virtual bool check_load_stream(unsigned int file_offset, unsigned int size)
	{
		// 後方シークはもっとoffsetを手前にしたほうがうまくいくはず
		// とりあえず処理を同じにする
		if (file_offset < file_offset_)
		{
			file_offset_ = file_offset;
		
			ifs_.seekg(file_offset_);
			file_bufferd_size_ = min<unsigned int>(BUF_SIZE, file_size_ - file_offset_);
			ifs_.read((char*)buf_.get(), file_bufferd_size_);

			reset_buf(buf_, file_bufferd_size_);
		}
		else if (file_offset_ + file_bufferd_size_ < file_offset + cur_byte_ + size)
		{
			file_offset_ = file_offset;
		
			ifs_.seekg(file_offset_);
			file_bufferd_size_ = min<unsigned int>(BUF_SIZE, file_size_ - file_offset_);
			ifs_.read((char*)buf_.get(), file_bufferd_size_);

			reset_buf(buf_, file_bufferd_size_);
		}

		return true;
	}

	virtual bool seek(unsigned int file_offset)
	{
		return check_load_stream(file_offset, BUF_SIZE);
	}
	
	virtual bool bit_advance(unsigned int bit_length)
	{
		check_load_stream(file_offset_ + cur_byte_, (bit_length + 7) / 8);
		return Bitstream::bit_advance(bit_length);
	}
		
	virtual bool read_bit(unsigned int bit_length, unsigned int* ret_value)
	{
		check_load_stream(file_offset_ + cur_byte_, (bit_length + 7) / 8);
		return Bitstream::read_bit(bit_length, ret_value);
	}
};

class LuaGlue
{
private:
	FileBitstream bitstream;
	bool printf_on;

public:
	LuaGlue():printf_on(true){}
	~LuaGlue(){}

	unsigned int cur_byte()  { return bitstream.cur_byte(); }
	unsigned int cur_bit()   { return bitstream.cur_bit(); }
	unsigned int file_size() { return bitstream.file_size(); }

	void enable_print(bool enable)
	{
		printf_on = enable;
	}

	bool open(string filename)
	{
		return bitstream.open(filename);
	}

	bool dump_byte_line(unsigned int byte_size)
	{
		if (bitstream.cur_byte() + byte_size > bitstream.file_size())
		{
			ERR << "file size over" << endl;
			return false;
		}
		return ::dump_line(bitstream.buf().get(), bitstream.buf_cur_byte(), byte_size);
	}

	bool dump_byte(unsigned int byte_size)
	{
		if (bitstream.cur_byte() + byte_size > bitstream.file_size())
		{
			ERR << "file size over" << endl;
			// return false;

			byte_size = std::min<unsigned int>(byte_size, bitstream.file_size() - bitstream.cur_byte());
		}
		return ::dump(bitstream.buf().get(), bitstream.buf_cur_byte(), byte_size);
	}

	bool dump_byte()
	{
		return dump_byte(0xff);
	}

	unsigned int read_bit(string name, unsigned int bit_length)
	{
		unsigned int prev_byte = bitstream.cur_byte();
		unsigned int prev_bit = bitstream.cur_bit();

		if (bit_length > 32)
		{
			bitstream.bit_advance(bit_length);

			if (printf_on)
			{
				unsigned int dump_len = std::min<unsigned int>(16, bit_length / 8);

				printf(" ofs=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | ",
					prev_byte, prev_bit, bit_length / 8, bit_length % 8, name.c_str());
				::dump_line(bitstream.buf().get(), prev_byte, dump_len);

				if (16 > dump_len)
					putchar('\n');
				else
					printf(" ...\n");
			}

			return 0;
		}
		else
		{
			unsigned int v;
			if (!bitstream.read_bit(bit_length, &v))
			{
				return 0;
			}

			if (printf_on)
			{
				printf(" ofs=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | val=0x%-8x (%d)\n",
					prev_byte, prev_bit, bit_length / 8, bit_length % 8, name.c_str(), v, v);
			}

			return v;
		}
	}

	unsigned int read_byte(string name, unsigned int byte_length)
	{
		return read_bit(name, 8 * byte_length);
	}

	string read_string(string name, unsigned int byte_length)
	{
		unsigned int prev_byte = bitstream.cur_byte();
		unsigned int prev_bit = bitstream.cur_bit();

		// 面倒なので文字列はバイトストリームになっていなければエラー
		string str;
		if (!bitstream.read_string(byte_length, &str))
		{
			return 0;
		}
		if (printf_on)
		{
			printf(" ofs=0x%08x(+%d)| siz=0x%08x(+0)| %-40s | str=\"%s\"\n",
				prev_byte, prev_bit, byte_length, name.c_str(), str.c_str());
		}
		
		return str;
	}

	unsigned int compare_bit(string name, unsigned int bit_length, unsigned int compvalue)
	{
		unsigned int value = read_bit(name, bit_length);
		if (value != compvalue)
		{
			printf("# compare value: 0x%08x(%d) != 0x%08x(%d)\n",
				value, value, compvalue, compvalue);
		}
		return value;
	}

	unsigned int compare_byte(string name, unsigned int byte_length, unsigned int compvalue)
	{
		return compare_bit(name, 8 * byte_length, compvalue);
	}

	string compare_string(string name, unsigned int byte_length, string comp_str)
	{
		string str = read_string(name, byte_length);
		if (str != comp_str)
		{
			printf("# compare string: \"%s\" != \"%s\"\n", str.c_str(), comp_str.c_str());
		}
		return str;
	}

	bool search_byte(unsigned char byte)
	{
		unsigned int prev_byte = bitstream.cur_byte();
		bitstream.cut_bit();

		unsigned int val;
		for (unsigned int i = 0; true; ++i)
		{
			if (!bitstream.read_bit(8, &val))
			{
				break;
			}

			if (val == byte)
			{
				if (printf_on)
				{
					printf(" ofs=0x%08x    | search '0x%02x' found. offset:0x%x\n", 
						prev_byte, byte, i);
				}
				return true;
			}
		}

		ERR << "# can not find byte:0x" << hex << byte << endl;
		return false;
	}

	bool seek(unsigned int offset)
	{
		return bitstream.seek(offset);
	}

	// ファイル名に応じて読み込んだデータを出力して
	// 暫定で毎回ファイルを開く
	// bool output_byte(ofstream& file_name, unsigned int byte_offset, unsigned int byte_size)
	bool output_byte(string file_name, unsigned int byte_size)
	{
		ofstream ofs;

		static vector<string> names;
		std::ios::openmode mode;
		if (find(names.begin(), names.end(), file_name) == names.end())
		{
			mode = std::ios::binary | std::ios::out;
			names.push_back(file_name);
		}
		else
		{
			mode = std::ios::binary | std::ios::app;
		}

		ofs.open(file_name, mode);
		if (!ofs)
		{
			ERR << "file open error:" << file_name << endl;
			return false;
		}
		
		bitstream.check_load_stream(bitstream.cur_byte(), byte_size);

		char* p = reinterpret_cast<char*>(bitstream.buf().get());
		ofs.write(&p[bitstream.buf_cur_byte()], byte_size);
		if (ofs.fail())
		{
			ERR << "ofs error" << endl;
			return false;
		}

		ofs.close();
		if (ofs.fail())
			return false;

		stringstream ss;
		ss << " >> " << file_name;
		read_byte(ss.str(), byte_size);
		return true;
	}

public:
	static unsigned int reverse_endian_16(unsigned int value)
	{
		return ((value >> 8) & 0xff) | ((value << 8) & 0xff00);
	}

	static unsigned int reverse_endian_32(unsigned int value)
	{
		return ((value >> 24) & 0xff) | ((value >> 8) & 0xff00)
			| ((value << 8) & 0xff0000) | ((value << 24) & 0xff000000);
	}

};


shared_ptr<rf::LuaBinder> init_lua()
{
	auto lua = make_shared<rf::LuaBinder>();

	lua->def("reverse_16", LuaGlue::reverse_endian_16);
	lua->def("reverse_32", LuaGlue::reverse_endian_32);

	// クラスバインド
	//オーバーロードがある場合とかは明示する
	lua->def_class<LuaGlue>("Bitstream")->
		def("open",          &LuaGlue::open).
		def("enable_print",  &LuaGlue::enable_print).
		def("file_size",     &LuaGlue::file_size).
		def("seek",          &LuaGlue::seek).
		def("search",        &LuaGlue::search_byte).
		def("dump",          (bool(LuaGlue::*)()) &LuaGlue::dump_byte).
		def("cur_bit",       &LuaGlue::cur_bit).
		def("cur_byte",      &LuaGlue::cur_byte).
		def("read_bit",      &LuaGlue::read_bit).
		def("read_byte",     &LuaGlue::read_byte).
		def("read_string",   &LuaGlue::read_string).
		def("comp_bit",      &LuaGlue::compare_bit).
		def("comp_byte",     &LuaGlue::compare_byte).
		def("comp_str",      &LuaGlue::compare_string).
		def("out_byte",      &LuaGlue::output_byte);

		if (!lua->dostring("_G.argv = {}"))
		{
			ERR << "lua.dostring err" << endl;
		}

	return lua;
}

int main(int argc, char** argv)
{
	string lua_file_name = "script/default.lua";

	// lua初期化
	auto lua = init_lua();

	// 引数適用
	int flag = 1;
	int lua_arg_count = 0;
	for (int i = 1; i < argc; ++i)
	{
		cout << "###" << argv[i] << endl;
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
			flag = 3;
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
				cout << ss.str() << endl;
				if (!lua->dostring(ss.str()))
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
			case 3:
			default:
			{
				cout <<
					"a.out [--stream|-s filename] [--lua|-l filename] [--help]\n"
					"\n"
					"--lua :start with file mode\n"
					"--arg :set argument of define file\n"
					"----------------------------------------------------" << endl;
				return 0;
			}
		}
	}

	// lua実行
	// -インタプリタモード
	// -ファイルモード(引数でファイル名を指定した場合)
	if (lua_file_name == "")
	{
		cout << "q:quit" << endl;
		for (;;)
		{
			cout << ">" << std::flush;
			string str;
			std::getline(cin, str);
			if (str == "q")
				break;

			if (!lua->dostring(str))
			{
				ERR << "lua.dostring err" << endl;
			}
		};
	}
	else
	{
		#if 1
			if (!lua->dofile(lua_file_name))
			{
				ERR << "lua.dofile err" << endl;
			}

			// windowsのために入力待ちする
			cout << "press any key.." << endl;
			getchar();
		#else
			string s;
			for (;;)
			{
				if (!lua->dofile(lua_file_name))
				{
					ERR << "lua.dofile err" << endl;
				}

				cout << "r:reload, q:quit" << endl;
				std::cin >> s;
				if (s[0] != 'r')
					break;
			};
		#endif
	}

	return 0;
}

