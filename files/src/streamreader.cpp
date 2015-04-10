// 定義ファイルに従ってストリームを読む
// 拡張する場合はCommandクラスの派生クラスを拡張してtload_streamdef_file関数でそれを生成するタグを指定する

#include <iostream>
#include <vector>
#include <memory>
#include <sstream>
#include <fstream>
#include <algorithm>

using std::vector;
using std::shared_ptr;
using std::make_shared;
using std::cout;
using std::cerr;
using std::endl;
using std::istringstream;
using std::ifstream;
using std::ofstream;
using std::string;
using std::getline;
using std::min;

// 一行バイトダンプ
bool DumpLine(const unsigned char* buf, unsigned int offset, unsigned int byte_size)
{
	for (unsigned int i = 0; i < byte_size; ++i)
	{
		printf("%02x ", buf[offset + i]);
	}

	return true;
}

// バイトダンプ
bool Dump(const unsigned char* buf, unsigned int offset, unsigned int byte_size)
{
	printf(" offset    | +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F\n");

	unsigned int i = 0;
	for (i = 0; i + 16 <= byte_size; i += 16)
	{
		printf(" 0x%08x| ", offset + i);
		DumpLine(buf, offset + i, 16);
		putchar('\n');
	}
	if (byte_size > i)
	{
		printf(" 0x%08x| ", offset + i);
		DumpLine(buf, offset + i, byte_size % 16);
		putchar('\n');
	}

	return true;
}

// 設定したバッファからビット単位でデータを読み出す
class Bitstream
{
private:
	shared_ptr<unsigned char> sbuf_;
	unsigned char* buf_;
	unsigned int   size_;
	unsigned int   cur_offset_;
	unsigned int   cur_bit_;

public:

	Bitstream():buf_(nullptr), size_(0), cur_bit_(0), cur_offset_(0){}

	unsigned int&        cur_offset(){return cur_offset_;}
	unsigned int&        cur_bit()   {return cur_bit_;}
	const unsigned char* buf()       {return buf_;}

	bool reset(shared_ptr<unsigned char> sbuf_, unsigned int size)
	{
		sbuf_       = sbuf_;
		buf_        = sbuf_.get();
		size_       = size;
		cur_offset_ = 0;
		cur_bit_    = 0;
		return true;
	}

	bool check_length(unsigned int read_length) const
	{
		if (size_ == cur_offset_)
		{
			cout << "EOS" << endl;
			return false;
		}
		if (size_ <= (cur_offset_ + (cur_bit_ + read_length) / 8))
		{
			cout << "# ERROR over read" << endl;
			return false;
		}
		return true;
	}

	bool bit_advance(unsigned int length)
	{
		if (!check_length(length))
			return false;

		cur_offset_ += (length / 8);
		cur_bit_    =  (cur_bit_ + length) % 8;
		return true;
	}

	bool bit_read(unsigned int read_length, unsigned int* ret_value)
	{
		if (!check_length(read_length))
		{
			return false;
		}
		if (read_length > 32)
		{
			cerr << "# ERROR read bit length > 32" << endl;
			return false;
		}
		
		// 先頭の中途半端なビットを読んでから、残りをバイトストリームとして読む
		unsigned int already_read = 0;
		*ret_value = 0;
		if (cur_bit_ != 0)
		{
			*ret_value = (buf_[cur_offset_] >> (8 - cur_bit_ - read_length)) &((1 << read_length) - 1);
			bit_advance(read_length);
			already_read += read_length;
		}

		while (read_length > already_read)
		{
			if (read_length - already_read < 8)
			{
				*ret_value <<= (read_length - already_read);
				*ret_value |= buf_[cur_offset_] >> (8 - (read_length - already_read));
				break;
			}
			else
			{
				*ret_value <<= 8;
				*ret_value |= buf_[cur_offset_];
				if (!bit_advance(8))
				{
					cerr << "#ERROR bit_advance" << endl;
					break;
				}
				already_read += 8;
			}
		}

		return true;
	}
};

struct CONTEXT;
class ICommand;

// 解析状況
struct CONTEXT
{
	vector<shared_ptr<ICommand> > script;
	unsigned int                  script_ix;
	Bitstream                     stream;
	ifstream                      stream_ifs;
};

// コマンドインターフェース
class ICommand
{
public:
	virtual const string& err_str() = 0;
	virtual bool fire(CONTEXT& ctx) = 0;
};

// コマンド基底クラス
class Command : public ICommand
{
protected:
	string name_;
public:
	virtual const string& err_str(){ return name_; }
};

// コマンド - ファイルオープン
class CommandOpenFile : public Command
{
private:
	string file_name_;
	shared_ptr<unsigned char> buf;

public:
	CommandOpenFile(){}
	CommandOpenFile(istringstream& iss_)
	{
		iss_ >> file_name_;
		name_ = string("load ") + file_name_;
	}

	virtual bool fire(CONTEXT& ctx)
	{
		// とりあえずファイル全部バッファに展開する
		ctx.stream_ifs.open(file_name_);
		if (!ctx.stream_ifs){
			cout << "# ERROR open file [" << file_name_ << "]" << endl;
			return false;
		}

		ctx.stream_ifs.seekg(0, ifstream::end);
		int stream_file_size = static_cast<int>(ctx.stream_ifs.tellg());
		ctx.stream_ifs.seekg(0, ifstream::beg);
		buf.reset(new unsigned char[stream_file_size]);
		ctx.stream_ifs.read(reinterpret_cast<char*>(buf.get()), stream_file_size); // ?
		ctx.stream_ifs.close();

		// ビットストリームリセット
		ctx.stream.reset(buf, stream_file_size);

		printf("\n<load file>\n");
		printf("   %s\n", file_name_.c_str());
		printf("\n<hex>\n");
		Dump(buf.get(), 0, min(stream_file_size, 256));
		printf("\n<report>\n");
		printf(" offset(bit)  | name                                     | value      (dec)\n");

		return true;
	}
};

// コマンド - ビットストリームとして読む
class CommandReadBit : public Command
{
private:
	unsigned int length_;
	unsigned int last_val_;

public:
	CommandReadBit(){}
	CommandReadBit(istringstream& iss_)
	{
		iss_ >> name_ >> length_;
	}

	unsigned int read_value(CONTEXT& ctx, unsigned int bit_length)
	{
		if (bit_length <= 32)
		{
			ctx.stream.bit_read(bit_length, &last_val_);
			printf(" 0x%08x(%d)| %-40s | 0x%-8x (%d)\n",
				ctx.stream.cur_offset(), ctx.stream.cur_bit(), name_.c_str(), last_val_, last_val_);
			return last_val_;
		}
		else
		{
			printf(" 0x%08x(%d)| %-40s | ", ctx.stream.cur_offset(), ctx.stream.cur_bit(), name_.c_str());
			DumpLine(ctx.stream.buf(), ctx.stream.cur_offset(), min(16, (int)(bit_length/8)));
			printf(" ...\n");
			ctx.stream.bit_advance(bit_length);
			return 0;
		}
		return 0;
	}
	virtual bool fire(CONTEXT& ctx)
	{
		last_val_ = read_value(ctx, length_);
		return true;
	}
};

// コマンド - バイトストリームとして読む
class CommandReadByte : public CommandReadBit
{
private:
	unsigned int length_;
	unsigned int last_val_;

public:
	CommandReadByte(){}
	CommandReadByte(istringstream& iss_)
	{
		iss_ >> name_ >> length_;
	}
		
	virtual bool fire(CONTEXT& ctx)
	{
		// 8倍読み込む
		last_val_ = CommandReadBit::read_value(ctx, 8 * length_);
		return true;
	}
};

// 定義ファイルのタグからコマンドを生成する
bool load_streamdef_file(CONTEXT& ctx, string& file_name)
{
	ifstream def_fs;
	def_fs.open(file_name);
	string line;
	string tag;
	istringstream iss;
	while (def_fs && getline(def_fs, line))
	{
		iss.str(line);
		iss.clear();
		iss >> tag;

		if ((tag[0] == '/')
		|| (iss.eof() == true))
		{
			continue;
		}
		else if (tag == "load")
		{
			ctx.script.push_back(std::make_shared<CommandOpenFile>(iss));
		}
		else if (tag == "b")
		{
			ctx.script.push_back(std::make_shared<CommandReadBit>(iss));
		}
		else if (tag == "B")
		{
			ctx.script.push_back(std::make_shared<CommandReadByte>(iss));
		}

		if (iss.fail() == true || iss.eof() == false)	// 文字列の最後まで処理したかチェックを行う。
		{
			cerr << "# ERROR script read [" << line << "]" << endl;
		}
	}

	return true;
}

// 
int main(int argc, char** argv)
{
	CONTEXT ctx;
	string streamdef_file_name = "deffile/streamdef.txt";

	// 引数判定
	if (argc >= 2)
	{
		int flag = 0;
		for (int i = 3; i < 100; ++i)
		{
			if (string("--deffile") == argv[i])
			{
				flag = 1;
			}
			if (string("--deffile") == argv[i])
			{
				flag = 2;
			}
			else if (string("--offset") == argv[i])
			{
				flag = 3;
			}
			else
			{
				switch (flag)
				{
				case 1:
					ctx.script.push_back(std::make_shared<CommandOpenFile>(istringstream(string(argv[i]))));
				case 2:
					streamdef_file_name = argv[i];
				default:
					cout << "a.out {targetfile} [--deffile|--offset]\n"
						"\n"
						"  --deffile : set stream definition file\n"
						"  --offset  : set start offset\n" << endl;
					return 0;
				}

				flag = 0;
			}
		}
	}

	// 最初の定義ファイルを読む
	if (!load_streamdef_file(ctx, streamdef_file_name))
	{
		cerr << "load_streamdef_file() error" << endl;
		return 0;
	}

	// 各種コマンド発火
	for (ctx.script_ix = 0; ctx.script_ix < ctx.script.size(); ctx.script_ix++)
	{
		//cerr << "Command " << ctx.script[ctx.script_ix]->err_str() << endl;

		if (!ctx.script[ctx.script_ix]->fire(ctx))
		{
			cerr << "# Command error" << ctx.script[ctx.script_ix]->err_str() << endl;
		}
	}

	return 0;
}
