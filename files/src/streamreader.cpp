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
#include <cctype>

#include "luabinder.hpp"

#define ERR cerr << "#ERROR(l." << __LINE__ << ") "

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
using std::make_shared;
using std::cout;
using std::cerr;
using std::endl;
using std::hex;
using std::dec;
using std::isdigit;
using std::stoi;
using std::min;


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

	shared_ptr<unsigned char> buf()      { return buf_; }
	const unsigned int&       size()     { return size_; }
	unsigned int&             cur_byte() { return cur_byte_; }
	unsigned int&             cur_bit()  { return cur_bit_; }

	virtual bool reset(shared_ptr<unsigned char> buf_, unsigned int size)
	{
		buf_ = buf_;
		size_ = size;
		cur_byte_ = 0;
		cur_bit_ = 0;
		return true;
	}

	virtual bool check_eos()
	{
		if (cur_byte_ == size_)
		{
			cout << "[EOS]" << endl;
			return true;
		}
		return false;
	}

	virtual bool check_length(unsigned int read_length) const
	{
		unsigned int next_byte = cur_byte_ + (cur_bit_ + read_length) / 8;
		if (size_ < next_byte)
		{
			ERR << "overrun size" << hex << size_ << " <= next" << next_byte << endl;
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

	virtual bool bit_advance(unsigned int length)
	{
		if (!check_length(length))
			return false;

		cur_byte_ += (cur_bit_ + length) / 8;
		cur_bit_ = (cur_bit_ + length) % 8;

		return true;
	}

	virtual bool bit_read(unsigned int read_length, unsigned int* ret_value)
	{
		if (!check_length(read_length))
			return false;

		if (read_length > 32)
		{
			ERR << "read bit length > 32" << endl;
			return false;
		}

		*ret_value = 0;
		unsigned int already_read = 0;

		// 先頭の中途半端なビットを読んでから、残りをバイトストリームとして読む
		// read_lengthが現在のバイトに収まるならビット読み出しまでで終了
		if (cur_bit_ + read_length < 8)
		{
			*ret_value = buf_.get()[cur_byte_];
			*ret_value >>= 8 - (cur_bit_ + read_length); // 下位ビットを合わせる
			*ret_value &= ((1 << read_length) - 1); // 上位ビットを捨てる
			bit_advance(read_length);
			return true;
		}
		else
		{
			unsigned int remained_bit = 8 - cur_bit_;
			*ret_value = buf_.get()[cur_byte_] & ((1 << remained_bit) - 1);
			bit_advance(remained_bit);
			already_read += remained_bit;
		}

		while (read_length > already_read)
		{
			if (read_length - already_read < 8)
			{
				*ret_value <<= (read_length - already_read);
				*ret_value |= buf_.get()[cur_byte_] >> (8 - (read_length - already_read));
				bit_advance(read_length - already_read);
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
};

class FileBitstream : public Bitstream
{
private:
	static const int BUF_SIZE = 1024 * 1024;
	string file_name_;

	ifstream ifs_;
	int file_size_;
	int read_size_;

	int cur_byte_;
	int file_offset_;

public:
	FileBitstream()
	{
		buf_ = shared_ptr<unsigned char>(new unsigned char[BUF_SIZE]);
	}
	FileBitstream(const string& file_name)
		:cur_byte_(0)
	{
		buf_ = shared_ptr<unsigned char>(new unsigned char[BUF_SIZE]);
		open(file_name);
	}
	virtual ~FileBitstream(){}

	virtual bool open(const string& file_name_)
	{
		ifs_.open(file_name_, ifstream::binary);
		if (!ifs_)
		{
			ERR << "open read file [" << file_name_ << "]" << endl;
			return false;
		}
		
		ifs_.seekg(0, ifstream::end);
		file_size_ = static_cast<int>(ifs_.tellg());
		ifs_.seekg(0, ifstream::beg);

		load(0);
		return true;
	}

	virtual bool load(int offset)
	{
		ifs_.seekg(offset);
		read_size_ = min(BUF_SIZE, file_size_ - offset);
		ifs_.read((char*)buf_.get(), read_size_);
		ifs_.close();

		reset(buf_, read_size_);
		return true;
	}
};

bool dump_line(const unsigned char* buf, unsigned int offset, unsigned int byte_size)
{
	for (unsigned int i = 0; i < byte_size; ++i)
	{
		printf("%02x ", buf[offset + i]);
	}

	return true;
}

bool dump(const unsigned char* buf, unsigned int offset, unsigned int byte_size)
{
	printf("     offset    | +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F\n");

	unsigned int i = 0;
	for (i = 0; i + 16 <= byte_size; i += 16)
	{
		printf("     0x%08x| ", offset + i);
		dump_line(buf, offset + i, 16);
		putchar('\n');
	}
	if (byte_size > i)
	{
		printf("     0x%08x| ", offset + i);
		dump_line(buf, offset + i, byte_size % 16);
		putchar('\n');
	}

	return true;
}

// for lua binder
static FileBitstream bitstream;

bool glue_stream_open(const char* filename)
{
	return bitstream.open(filename);
}

bool glue_dump_line(unsigned int byte_offset, unsigned int byte_size)
{
	return dump_line(bitstream.buf().get(), byte_offset, byte_size);
}

bool glue_dump(unsigned int byte_offset, unsigned int byte_size)
{
	return dump(bitstream.buf().get(), byte_offset, byte_size);
}

unsigned int glue_read_bit(const char* name, unsigned int bit_length, bool disp)
{
	if (bit_length >= 32)
	{
		unsigned int prev_byte = bitstream.cur_byte();
		bitstream.bit_advance(bit_length);

		if (disp)
		{
			unsigned int dump_len = std::min<unsigned int>(16, bit_length / 8);

			printf(" pos=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | ",
				bitstream.cur_byte(), bitstream.cur_bit(),
				bit_length / 8, bit_length % 8, name);
			dump_line(bitstream.buf().get(), prev_byte, dump_len);

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
		if (!bitstream.bit_read(bit_length, &v))
		{
			return 0;
		}

		if (disp)
		{
			printf(" pos=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | val=0x%-8x (%d)\n",
				bitstream.cur_byte(), bitstream.cur_bit(),
				bit_length / 8, bit_length % 8, name,
				v, v);
		}

		return v;
	}
}

unsigned int glue_read_byte(const char* name, unsigned int byte_length, bool disp)
{
	return glue_read_bit(name, 8*byte_length, disp);
}

bool glue_serch_byte(unsigned char byte)
{
	bitstream.cut_bit();

	unsigned int val;
	for (int i = 0; true; ++i)
	{
		if (!bitstream.bit_read(8, &val))
		{
			break;
		}

		if (val == byte)
		{
			return true;
		}
	}

	ERR << "can not find byte:0x" << hex << byte << endl;
	return false;
}

unsigned int glue_cur_byte()
{
	return bitstream.cur_byte();
}
unsigned int glue_cur_bit()
{
	return bitstream.cur_byte();
}

class Test
{
public:
	Test(){ cout << "constructor" << endl; }
	~Test(){ cout << "destructor" << endl; }
	int func(){ cout << "test member func" << endl; }
};

int main(int argc, char** argv)
{
	//interleter::Context ctx;
	string streamdef_file_name = "streamdef.txt";
	
	// 引数判定
	if (argc == 1)
	{
		cerr <<
			"----------------------------------------------------"
			"--deffile :set define file (default:streamdef.txt)"
			"--arg     :set argument of define file"
			"----------------------------------------------------" << endl;
	}
	else if (argc > 2)
	{
		stringstream ss;
		ss << "ropen " << argv[1] << endl;
		//	CommandString command(0, ss.str());
		//	command.execute(ctx);
	}

	if (argc >= 3)
	{
		int flag = 0;
		long long int arg_id = 0;
		for (int i = 2; i < 100; ++i)
		{
			if (string("--deffile") == argv[i])
			{
				flag = 1;
			}
			else if (string("--arg") == argv[i])
			{
				flag = 2;
			}
			else switch (flag)
			{
			case 1:
			{
				streamdef_file_name = argv[i];
			}
			case 2:
			{
				++arg_id;
				stringstream ss;
				ss << "$" << arg_id;
				// ctx.set_string(ss.str(), argv[i]);
			}
			default:
			{
				cout <<
					"a.out {tagfile} [--deffile]\n"
					"\n"
					"  --deffile : set stream definition file\n" << endl;
				return 0;
			}
			}
		}
	}

	rf::LuaManager lua;
	lua.def("open",     glue_stream_open);
	lua.def("dump",     glue_dump);
	lua.def("readbit",  glue_read_bit);
	lua.def("readbyte", glue_read_byte);
	lua.def("search",   glue_serch_byte);
	lua.def("cur_byte", glue_cur_byte);
	lua.def("cur_bit",  glue_cur_byte);

	// このままだとメンバ関数登録できないので↑見たいのが必要
	lua.def_class<Test>("testclass");

	for (;;)
	{
		if (!lua.dofile("test.lua"))
		{
			// エラーったらリロード
			ERR << "lua.dofile err r:reload, q:quit"  << endl;
		}

		cout << "r:reload, q:quit" << endl;
		string s;
		std::cin >> s;
		if (s[0] != 'r')
			break;
	};

	// for windows console
	cout << "wait input..";
	getchar();

	return 0;
}
