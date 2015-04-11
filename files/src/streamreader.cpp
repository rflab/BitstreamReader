// 定義ファイルに従ってストリームを読む
// いまのところ個々の読み込みは512MBまで


#include <iostream>
#include <vector>
#include <map>
#include <memory>
#include <sstream>
#include <fstream>
#include <algorithm>

using std::vector;
using std::map;
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
bool dump_line(const unsigned char* buf, unsigned int offset, unsigned int byte_size)
{
	for (unsigned int i = 0; i < byte_size; ++i)
	{
		printf("%02x ", buf[offset + i]);
	}

	return true;
}

// バイトダンプ
bool dump(const unsigned char* buf, unsigned int offset, unsigned int byte_size)
{
	printf(" offset    | +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F\n");

	unsigned int i = 0;
	for (i = 0; i + 16 <= byte_size; i += 16)
	{
		printf(" 0x%08x| ", offset + i);
		dump_line(buf, offset + i, 16);
		putchar('\n');
	}
	if (byte_size > i)
	{
		printf(" 0x%08x| ", offset + i);
		dump_line(buf, offset + i, byte_size % 16);
		putchar('\n');
	}

	return true;
}

// エンディアン変換 - 16bit
inline unsigned int reverse_endian_16(unsigned int value)
{
	return ((value >> 8) & 0xff) | ((value << 8) & 0xff00);
}

// エンディアン変換 - 32bit
inline unsigned int reverse_endian_32(unsigned int value)
{
	return ((value >> 24) & 0xff) | ((value >> 8) & 0xff00)
		| ((value << 8) & 0xff0000) | ((value << 24) & 0xff000000);
}


// 設定したバッファからビット単位でデータを読み出す
// ビッグエンディアン
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

	const unsigned char* buf()       { return buf_; }
	const unsigned int&  size()      { return size_; }
	unsigned int&        cur_offset(){ return cur_offset_; }
	unsigned int&        cur_bit()   { return cur_bit_; }

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
		if (cur_offset_ == size_)
		{
			cout << "EOS" << endl;
		}

		return true;
	}
};

struct CONTEXT;
class ICommand;

// 解析状況
struct CONTEXT
{
	vector<shared_ptr<ICommand> > commands;
	map<string, unsigned int>     command_jump_label;
	unsigned int                  commands_ix;
	map<string, unsigned int>     value_map;
	Bitstream                     stream;
	ifstream                      stream_ifs;
};

// コマンドインターフェース
class ICommand
{
public:
	virtual const string& err_str() = 0;
	virtual bool execute(CONTEXT& ctx) = 0;
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

	virtual bool execute(CONTEXT& ctx)
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
		ctx.stream_ifs.read((char*)buf.get(), stream_file_size);
		ctx.stream_ifs.close();

		dump(buf.get(), 0, min(stream_file_size, 1024));

		// ビットストリームリセット
		ctx.stream.reset(buf, stream_file_size);

		printf("\n<load file>\n");
		printf("   %s\n", file_name_.c_str());
		printf("\n<hex>\n");
		dump(buf.get(), 0, min(stream_file_size, 1024));
		dump(buf.get(), 0x59c00, min(stream_file_size, 256));
		printf("\n<report>\n");
		printf(" offset(bit)   | len           | name                                     | value      (dec)\n");

		return true;
	}
};

// コマンド - ビットストリームとして読む
class CommandReadBit : public Command
{
protected:
	string option_;

private:
	unsigned int length_;

public:
	CommandReadBit(){}
	CommandReadBit(CONTEXT& ctx, istringstream& iss_)
	{
		iss_ >> name_ >> length_ >> option_;
		ctx.value_map[name_] = 0;
	}

	unsigned int read_value(CONTEXT& ctx, unsigned int bit_length)
	{
		unsigned int value;

		printf(" 0x%08x(+%d)| 0x%08x(+%d)| %-40s | ",
			ctx.stream.cur_offset(), ctx.stream.cur_bit(), bit_length / 8, bit_length % 8, name_.c_str());

		if (bit_length <= 32)
		{
			if (!ctx.stream.bit_read(bit_length, &value))
			{
				cerr << "#ERROR bit_read [" << name_ << "]"<< endl;
			}

			if (option_ == "le")
			{
				if (bit_length == 16)
				{
					value = reverse_endian_16(value);
				}
				else if (bit_length == 32)
				{
					value = reverse_endian_32(value);
				}
				else
				{
					cerr << "# ERROR need 16 or 32 bit to reverse endian" << endl;
				}
			}

			printf("0x%-8x (%d)\n", value, value);
			return value;
		}
		else
		{
			dump_line(ctx.stream.buf(), ctx.stream.cur_offset(), min(16, (int)(bit_length / 8)));
			printf(" ...\n");

			if (!ctx.stream.bit_advance(bit_length))
			{
				cerr << "# ERROR bit_read " << name_ << "cur:" << ctx.stream.cur_offset() << ", read_length:" << bit_length << "bit" << endl;
			}
			return 0;
		}
		return 0;
	}
	virtual bool execute(CONTEXT& ctx)
	{
		ctx.value_map[name_] = read_value(ctx, length_);
		return true;
	}
};

// コマンド - バイトストリームとして読む
class CommandReadByte : public CommandReadBit
{
private:
	unsigned int length_;

public:
	CommandReadByte(){}
	CommandReadByte(CONTEXT& ctx, istringstream& iss_)
	{
		iss_ >> name_ >> length_ >> option_;
		ctx.value_map[name_] = 0;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		// 8倍読み込む
		ctx.value_map[name_] = CommandReadBit::read_value(ctx, 8 * length_);
		return true;
	}
};

// コマンド - バイトストリームとして読む
class CommandReadBitRef : public CommandReadBit
{
private:
	string ref_name_;

public:
	CommandReadBitRef(){}
	CommandReadBitRef(CONTEXT& ctx, istringstream& iss_)
	{
		iss_ >> name_ >> ref_name_ >> option_;
		if (ctx.value_map.find(ref_name_) == ctx.value_map.end())
		{
			cerr << "# ERROR ref name not found [" << ref_name_ << "]" << endl;
		}
		ctx.value_map[name_] = 0;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		ctx.value_map[name_] = CommandReadBit::read_value(ctx, ctx.value_map[ref_name_]);
		return true;
	}
};

// コマンド - バイトストリームとして読む
class CommandReadByteRef : public CommandReadBit
{
private:
	string ref_name_;

public:
	CommandReadByteRef(){}
	CommandReadByteRef(CONTEXT& ctx, istringstream& iss_)
	{
		iss_ >> name_ >> ref_name_ >> option_;
		if (ctx.value_map.find(ref_name_) == ctx.value_map.end())
		{
			cerr << "# ERROR ref name not found [" << ref_name_ << "]" << endl;
		}
		ctx.value_map[name_] = 0;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		// 8倍読み込む
		ctx.value_map[name_] = CommandReadBit::read_value(ctx, 8 * ctx.value_map[ref_name_]);
		return true;
	}
};

// コマンド - 単発四則演算
class CommandCalc : public Command
{
private:
	int    operand_;
	string command_;
	string ref_name_;

public:
	CommandCalc(){}
	CommandCalc(CONTEXT& ctx, string command, istringstream& iss_)
	{
		command_ = command;
		iss_ >> ref_name_ >> operand_;
		if (command == "val")
		{
			if (ctx.value_map.find(ref_name_) != ctx.value_map.end())
			{
				cerr << "# ERROR value already exist [" << ref_name_ << "]" << endl;
			}
			ctx.value_map[command] = 0;
		}
		else if (ctx.value_map.find(ref_name_) == ctx.value_map.end())
		{
			cerr << "# ref name not found [" << ref_name_ << "]" << endl;
		}
	}

	virtual bool execute(CONTEXT& ctx)
	{
		if (command_ == "val")
			ctx.value_map[ref_name_] = operand_;
		if (command_ == "mov")
			ctx.value_map[ref_name_] = operand_;
		else if (command_ == "sum")
			ctx.value_map[ref_name_] += operand_;
		else if (command_ == "sub")
			ctx.value_map[ref_name_] -= operand_;
		else if (command_ == "mul")
			ctx.value_map[ref_name_] *= operand_;
		else if (command_ == "dev")
			ctx.value_map[ref_name_] /= operand_;
		else if (command_ == "mod")
			ctx.value_map[ref_name_] %= operand_;
		else if (command_ == "xor")
			ctx.value_map[ref_name_] ^= operand_;
		else if (command_ == "r_shift")
			ctx.value_map[ref_name_] >>= operand_;
		else if (command_ == "l_shift")
			ctx.value_map[ref_name_] <<= operand_;

		return true;
	}
};

// 値を表示する
class CommandPrint : public Command
{
private:
	string ref_name_;

public:
	CommandPrint(){}
	CommandPrint(CONTEXT& ctx, istringstream& iss_)
	{
		iss_ >> ref_name_;
		if (ctx.value_map.find("ref_name_") == ctx.value_map.end())
		{
			cout << "# ref name not found [" << ref_name_ << "]" << endl;
		}
	}

	virtual bool execute(CONTEXT& ctx)
	{
		cout << ref_name_ << " " << ctx.value_map[ref_name_] << endl;
		return true;
	}
};

// 文字列を表示する
class CommandStr : public Command
{
private:
	string str_;

public:
	CommandStr(){}
	CommandStr(CONTEXT& ctx, string str) :str_(str){}

	virtual bool execute(CONTEXT& ctx)
	{
		cout << str_ << endl;
		return true;
	}
};

// 値がそれになっていればジャンプする
class CommandJumpIfEqual : public Command
{
private:
	string   label_;
	string   ref_name_;
	unsigned int value_;

public:
	CommandJumpIfEqual(){}
	CommandJumpIfEqual(CONTEXT& ctx, istringstream& iss_)
	{
		iss_ >> label_ >> ref_name_ >> value_;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		if (ctx.value_map[ref_name_] == value_)
		{
			cout << "jump to " << label_ << endl;
			ctx.commands_ix = ctx.command_jump_label[label_] - 1;
		}
		return true;
	}
};




// 定義ファイルのタグからコマンドを生成する
bool load_streamdef_file(CONTEXT& ctx, string& file_name)
{
	ifstream def_fs;
	def_fs.open(file_name);
	string line;
	string command;
	istringstream iss;
	while (def_fs && getline(def_fs, line))
	{
		iss.str(line);
		iss.clear();
		iss >> command;

		if ((command[0] == '/')
		|| (iss.eof() == true))
		{
			continue;
		}
		else if (command == "label")
		{
			string label;
			iss >> label;
			ctx.command_jump_label[label] = ctx.commands.size();
		}
		else if (command == "j")
		{
			// ジャンプ
		}
		else if (command == "je")
		{
			ctx.commands.push_back(std::make_shared<CommandJumpIfEqual>(ctx, iss));
		}
		else if (command == "load")
		{
			ctx.commands.push_back(std::make_shared<CommandOpenFile>(iss));
		}
		else if (command == "b")
		{
			ctx.commands.push_back(std::make_shared<CommandReadBit>(ctx, iss));
		}
		else if (command == "B")
		{
			ctx.commands.push_back(std::make_shared<CommandReadByte>(ctx, iss));
		}
		else if (command == "rb")
		{
			ctx.commands.push_back(std::make_shared<CommandReadBitRef>(ctx, iss));
		}
		else if (command == "rB")
		{
			ctx.commands.push_back(std::make_shared<CommandReadByteRef>(ctx, iss));
		}
		else if ((command == "val")
		||       (command == "mov")
		||       (command == "sum")
		||       (command == "sub")
		||       (command == "mul")
		||       (command == "dev")
		||       (command == "mod")
		||       (command == "xor")
		||       (command == "r_shift")
		||       (command == "l_shift"))
		{
			ctx.commands.push_back(std::make_shared<CommandCalc>(ctx, command, iss));
		}
		else if (command == "print")
		{
			ctx.commands.push_back(std::make_shared<CommandPrint>(ctx, iss));
		}
		else if (command == "str")
		{
			ctx.commands.push_back(std::make_shared<CommandStr>(
				ctx, line.substr(line.find_first_not_of(" ", 4), string::npos)));
		}

		if (iss.fail() == true || iss.eof() == false)	// 文字列の最後まで処理したかチェックを行う。
		{
			cerr << "# ERROR fail commands read [" << line << "]" << endl;
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
					ctx.commands.push_back(std::make_shared<CommandOpenFile>(istringstream(string(argv[i]))));
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
	for (ctx.commands_ix = 0; ctx.commands_ix < ctx.commands.size(); ctx.commands_ix++)
	{
		//cerr << "Command " << ctx.commands[ctx.commands_ix]->err_str() << endl;

		if (!ctx.commands[ctx.commands_ix]->execute(ctx))
		{
			cerr << "# Command error" << ctx.commands[ctx.commands_ix]->err_str() << endl;
		}
	}

	if (ctx.stream.size() != ctx.stream.cur_offset())
	{
		cout << "data remained. stream_size:" << ctx.stream.size() << ", read_ofs:" << ctx.stream.cur_offset() << endl;
	}

	return 0;
}
