// 定義ファイルに従ってストリームを読む
// いまのところ個々の読み込みは512MBまで

#include <iostream>
#include <vector>
#include <map>
#include <memory>
#include <sstream>
#include <fstream>
#include <algorithm>
#include <cctype>

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

namespace util
{
	// とにかく一行ダンプ
	bool dump_line(const unsigned char* buf, unsigned int offset, unsigned int byte_size)
	{
		for (unsigned int i = 0; i < byte_size; ++i)
		{
			printf("%02x ", buf[offset + i]);
		}

		return true;
	}

	// 16バイト単位で綺麗にダンプ表示
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
	// ビッグエンディアン固定
	class Bitstream
	{
	private:
		shared_ptr<unsigned char> sbuf_;
		unsigned char* buf_;
		unsigned int   size_;
		unsigned int   cur_offset_;
		unsigned int   cur_bit_;

	public:

		Bitstream() :buf_(nullptr), size_(0), cur_bit_(0), cur_offset_(0){}

		const unsigned char* buf()       { return buf_; }
		const unsigned int&  size()      { return size_; }
		unsigned int&        cur_offset(){ return cur_offset_; }
		unsigned int&        cur_bit()   { return cur_bit_; }

		bool reset(shared_ptr<unsigned char> sbuf_, unsigned int size)
		{
			sbuf_ = sbuf_;
			buf_ = sbuf_.get();
			size_ = size;
			cur_offset_ = 0;
			cur_bit_ = 0;
			return true;
		}

		bool dump_line(unsigned int offset, unsigned int size)
		{
			return util::dump_line(buf_, offset, size);
		}

		bool dump(unsigned int offset, unsigned int size)
		{
			return util::dump(buf_, offset, size);
		}

		bool check_length(unsigned int read_length) const
		{
			unsigned int next_offset = cur_offset_ + (cur_bit_ + read_length) / 8;
			if (size_ < next_offset)
			{
				cout << "# ERROR over read " << std::hex << size_ << " <= " << next_offset << endl;
				return false;
			}
			return true;
		}

		bool cut_bit()
		{
			if (cur_bit_ != 0)
			{
				++cur_offset_;
				cur_bit_ = 0;
			}
			return true;
		}

		bool bit_advance(unsigned int length)
		{
			if (!check_length(length))
				return false;

			cur_offset_ += (length / 8);
			cur_bit_ = (cur_bit_ + length) % 8;

			if (cur_offset_ == size_)
			{
				cout << "[EOS]" << endl;
			}

			return true;
		}

		bool bit_read(unsigned int read_length, unsigned int* ret_value)
		{
			if (!check_length(read_length))
				return false;

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
}

struct CONTEXT;
class ICommand;

// 解析状況
struct CONTEXT
{
	struct RECORD
	{
		unsigned int offset;
		unsigned int bit;
		unsigned int bit_length;
		unsigned int value;
	};

	vector<shared_ptr<ICommand> > commands;
	unsigned int                  commands_ix;
	map<string, unsigned int>     label_map;
	map<string, RECORD>           record_map;
	util::Bitstream               stream;
	ifstream                      ifs;
	ofstream                      ofs;

	// とりあえずこれで値を拾う
	unsigned get_value(string str)
	{
		if (std::isdigit(str[0]))
		{
			return std::stoi(str, nullptr, 0);
		}
		else
		{
			if (record_map.find(str) == record_map.end())
			{
				cerr << "# ERROR ref name not found [" << str << "]" << endl;
				throw false;
			}
			return record_map[str].value;
		}
	}

	// とりあえずこれで値を拾う
	RECORD& get_record(string str)
	{
		if (record_map.find(str) == record_map.end())
		{
			cerr << "# ERROR ref name not found [" << str << "]" << endl;
			throw false;
		}
		return record_map[str];
	}
};


// 各種コマンドのインターフェース
class ICommand
{
public:
	virtual const string& err_str() = 0;
	virtual bool  execute(CONTEXT& ctx) = 0;
};

// 各種コマンドの基底クラス
class Command : public ICommand
{
protected:
	string name_;
public:
	virtual const string& err_str(){ return name_; }
};

// ファイル全部ctxのバッファに展開する
class CommandOpenReadFile : public Command
{
private:
	string file_name_;
	shared_ptr<unsigned char> buf;

public:
	CommandOpenReadFile(){}
	CommandOpenReadFile(string file_name)
	{
		file_name_ = file_name;
	}
	CommandOpenReadFile(istringstream& iss)
	{
		iss >> file_name_;
		name_ = string("load ") + file_name_;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		ctx.ifs.open(file_name_, ifstream::binary);
		if (!ctx.ifs){
			cout << "# ERROR open read file [" << file_name_ << "]" << endl;
			return false;
		}

		// ファイルサイズ
		ctx.ifs.seekg(0, ifstream::end);
		int stream_file_size = static_cast<int>(ctx.ifs.tellg());
		ctx.ifs.seekg(0, ifstream::beg);

		// 全部読み込み
		buf.reset(new unsigned char[stream_file_size]);
		ctx.ifs.read((char*)buf.get(), stream_file_size);
		ctx.ifs.close();

		// ビットストリームリセット
		ctx.stream.reset(buf, stream_file_size);

		return true;
	}
};


// 書き出し用ファイルを開く
class CommandOpenWriteFile : public Command
{
private:
	string file_name_;

public:
	CommandOpenWriteFile(){}
	CommandOpenWriteFile(istringstream& iss)
	{
		iss >> file_name_;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		ctx.ofs.open(file_name_, ifstream::binary);
		if (!ctx.ofs){
			cout << "# ERROR open write file [" << file_name_ << "]" << endl;
			return false;
		}
		return true;
	}
};

// 書き出す
class CommandWriteByte : public Command
{
private:
	string value_str_;

public:
	CommandWriteByte(){}
	CommandWriteByte(istringstream& iss)
	{
		iss >> value_str_;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		if (!ctx.ofs){
			cout << "# ERROR no write file for " << value_str_ << endl;
			return false;
		}

		// ????
		CONTEXT::RECORD& record = ctx.get_record(value_str_);
		unsigned char* buf = const_cast<unsigned char*>(ctx.stream.buf());
		ctx.ofs.write((char*)(&buf[record.offset]), record.bit_length / 8);

		return true;
	}
};

// ビット単位でストリームを読む
class CommandReadBit : public Command
{
protected:
	string length_str_;
	bool   rendian_;

public:
	CommandReadBit(){}
	CommandReadBit(CONTEXT& ctx, istringstream& iss, bool rendian = false)
		:
		rendian_(rendian)
	{
		iss >> name_ >> length_str_;
		ctx.record_map[name_];
	}

	bool read_value(CONTEXT& ctx, unsigned int bit_length)
	{
		printf(" pos=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | ",
			ctx.stream.cur_offset(), ctx.stream.cur_bit(), bit_length / 8, bit_length % 8, name_.c_str());

		ctx.record_map[name_].offset = ctx.stream.cur_offset();
		ctx.record_map[name_].bit = ctx.stream.cur_bit();
		ctx.record_map[name_].bit_length = bit_length;
		ctx.record_map[name_].value = 0;

		if (bit_length <= 32)
		{
			unsigned int value;

			if (!ctx.stream.bit_read(bit_length, &value))
			{
				cerr << "#ERROR bit_read [" << name_ << "]" << endl;
			}

			if (rendian_)
			{
				if (bit_length == 16)
				{
					value = util::reverse_endian_16(value);
				}
				else if (bit_length == 32)
				{
					value = util::reverse_endian_32(value);
				}
				else
				{
					cerr << "# ERROR need 16 or 32 bit to reverse endian" << endl;
					return false;
				}
			}

			printf("val=0x%-8x (%d)\n", value, value);
			ctx.record_map[name_].value = value;
		}
		else
		{
			printf("dat=");
			ctx.stream.dump_line(ctx.stream.cur_offset(), std::min(16, (int)(bit_length / 8)));
			if (bit_length / 8 <= 16)
				printf(" \n");
			else
				printf(" ...\n");

			if (!ctx.stream.bit_advance(bit_length))
			{
				cerr << "# ERROR bit_read " << name_ << "cur:" << ctx.stream.cur_offset() << ", read_length:" << bit_length << "bit" << endl;
				return false;
			}
		}

		return true;
	}
	virtual bool execute(CONTEXT& ctx)
	{
		return read_value(ctx, ctx.get_value(length_str_));
	}
};

// バイト単位でストリームを読む
class CommandReadByte : public CommandReadBit
{
public:
	CommandReadByte(){}
	CommandReadByte(CONTEXT& ctx, istringstream& iss, bool rendian = false)
		: CommandReadBit(ctx, iss, rendian){}

	virtual bool execute(CONTEXT& ctx)
	{
		// 8倍読み込む
		return read_value(ctx, 8 * ctx.get_value(length_str_));
	}
};

// bit単位で値を比較する
class CommandCompairBit : public CommandReadBit
{
protected:
	string compare_str_;

public:
	CommandCompairBit(){}
	CommandCompairBit(CONTEXT& ctx, istringstream& iss, bool rendian = false)
	{
		iss >> name_ >> length_str_ >> compare_str_;
		rendian_ = rendian;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		ctx.stream.cut_bit();
		read_value(ctx, ctx.get_value(length_str_));
		if (ctx.get_value(name_) != ctx.get_value(compare_str_))
		{
			printf("compair value is false. value:0x%x(%d), expected:0x%x(%d)\n",
				ctx.get_value(name_), ctx.get_value(name_), ctx.get_value(compare_str_), ctx.get_value(compare_str_));
		}

		return true;
	}
};
// バイト単位で値を比較する
class CommandCompairByte : public CommandCompairBit
{
public:
	CommandCompairByte(){}
	CommandCompairByte(CONTEXT& ctx, istringstream& iss, bool rendian = false)
		: CommandCompairBit(ctx, iss, rendian){}

	virtual bool execute(CONTEXT& ctx)
	{
		ctx.stream.cut_bit();
		read_value(ctx, 8 * ctx.get_value(length_str_));
		if (ctx.get_value(name_) != ctx.get_value(compare_str_))
		{
			printf("compair value is false. value:0x%x(%d), expected:0x%x(%d)\n",
				ctx.get_value(name_), ctx.get_value(name_), ctx.get_value(compare_str_), ctx.get_value(compare_str_));
		}

		return true;
	}
};

// 特定の1バイトが見つかるまで読み飛ばす
class CommandSearchByte : public CommandReadBit
{
	unsigned char byte_;
public:
	CommandSearchByte(){}
	CommandSearchByte(CONTEXT& ctx, istringstream& iss)
	{
		iss >> std::hex >> byte_;
	}
	virtual bool execute(CONTEXT& ctx)
	{
		// バイトシークのためbit削除
		ctx.stream.cut_bit();

		unsigned int val;
		for (int i = 0; true; ++i)
		{
			if (!ctx.stream.bit_read(8, &val))
			{
				cout << "can not find byte:0x" << std::hex << byte_ << endl;
				return false;
			}

			if (val == byte_)
			{
				return true;
			}
		}

		cout << "can not find byte:0x" << std::hex << byte_ << endl;
		return false;
	}
};

// 単発四則演算
class CommandCalc : public Command
{
private:
	string operand_;
	string command_;
	string ref_name_;

public:
	CommandCalc(){}
	CommandCalc(CONTEXT& ctx, string command, istringstream& iss)
	{
		command_ = command;
		iss >> ref_name_ >> operand_;
		if (command == "val")
		{
			if (ctx.record_map.find(ref_name_) != ctx.record_map.end())
			{
				cerr << "# ERROR value already exist [" << ref_name_ << "]" << endl;
			}
			ctx.record_map[command];
		}
		else if (ctx.record_map.find(ref_name_) == ctx.record_map.end())
		{
			cerr << "# ERROR ref name not found [" << ref_name_ << "]" << endl;
		}
	}

	virtual bool execute(CONTEXT& ctx)
	{
		if (command_ == "val")
			ctx.record_map[ref_name_];
		if (command_ == "mov")
			ctx.record_map[ref_name_].value = ctx.get_value(operand_);
		else if (command_ == "add")
			ctx.record_map[ref_name_].value += ctx.get_value(operand_);
		else if (command_ == "sub")
			ctx.record_map[ref_name_].value -= ctx.get_value(operand_);
		else if (command_ == "mul")
			ctx.record_map[ref_name_].value *= ctx.get_value(operand_);
		else if (command_ == "dev")
			ctx.record_map[ref_name_].value /= ctx.get_value(operand_);
		else if (command_ == "mod")
			ctx.record_map[ref_name_].value %= ctx.get_value(operand_);
		else if (command_ == "xor")
			ctx.record_map[ref_name_].value ^= ctx.get_value(operand_);
		else if (command_ == "r_shift")
			ctx.record_map[ref_name_].value >>= ctx.get_value(operand_);
		else if (command_ == "l_shift")
			ctx.record_map[ref_name_].value <<= ctx.get_value(operand_);

		return true;
	}
};

// 値を表示する
class CommandPrint : public Command
{
private:
	string str_;
	string line_;

public:
	CommandPrint(){}
	CommandPrint(CONTEXT& ctx, istringstream& iss, string line)
	{
		iss >> str_;
		if (str_[0] != '\"')
		{
			if (ctx.record_map.find(str_) == ctx.record_map.end())
			{
				cout << "# ERROR ref name not found [" << str_ << "]" << endl;
			}
		}
		else
		{
			line_ = line;
		}
	}

	virtual bool execute(CONTEXT& ctx)
	{
		if (str_[0] == '\"')
		{
			int first = line_.find_first_of('\"');
			int last = line_.find_last_of('\"');
			cout << line_.substr(first + 1, last - first - 1) << endl;
			return true;
		}
		else
		{
			if (ctx.record_map[str_].bit_length > 32)
			{
				cout << "     [dump " << str_ << "]" << endl;
				ctx.stream.dump(ctx.record_map[str_].offset,
					std::min(ctx.record_map[str_].bit_length / 8, (unsigned int)256));
			}
			else
			{
				printf("     %s: 0x%x (%d)\n", str_.c_str(), ctx.get_value(str_), ctx.get_value(str_));
			}
			return true;
		}
	}
};

// データダンプ
class CommandDump : public Command
{
private:
	unsigned int offset_;
	unsigned int size_;

public:
	CommandDump(){}
	CommandDump(istringstream& iss)
	{
		iss >> offset_ >> size_;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		cout << "     [dump address:0x" << std::hex << offset_ << ", size:0x" << size_ << "]" << endl;
		ctx.stream.dump(offset_, std::min(size_, (unsigned int)256));
		return true;
	}
};


// Equal判定でジャンプする
class CommandJumpIfEqual : public Command
{
private:
	string   label_;
	string   ref_name_;
	unsigned int value_;

public:
	CommandJumpIfEqual(){}
	CommandJumpIfEqual(CONTEXT& ctx, istringstream& iss)
	{
		iss >> label_ >> ref_name_ >> value_;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		if (ctx.get_value(ref_name_) == value_)
		{
			ctx.commands_ix = ctx.label_map[label_] - 1;
		}
		return true;
	}
};

// Not Equal判定でジャンプする
class CommandJumpIfNotEqual : public Command
{
private:
	string   label_;
	string   ref_name_;
	unsigned int value_;

public:
	CommandJumpIfNotEqual(){}
	CommandJumpIfNotEqual(CONTEXT& ctx, istringstream& iss)
	{
		iss >> label_ >> ref_name_ >> value_;
	}

	virtual bool execute(CONTEXT& ctx)
	{
		if (ctx.get_value(ref_name_) != value_)
		{
			ctx.commands_ix = ctx.label_map[label_] - 1;
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
	int i = 0;

	try
	{
		for (int i = 0; i < 100000; ++i)
		{
			if (!def_fs || !std::getline(def_fs, line))
				break;

			iss.str(line);
			iss.clear();
			iss >> command;

			if ((command[0] == '/')
				|| (iss.eof() == true))
			{
				continue;
			}
			else if ((command == "val")
			||       (command == "mov")
			||       (command == "add")
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
			else if (command == "label")
			{
				string label;
				iss >> label;
				ctx.label_map[label] = ctx.commands.size();
			}
			else if (command == "j")
			{
				// ジャンプ
			}
			else if (command == "je")
			{
				ctx.commands.push_back(std::make_shared<CommandJumpIfEqual>(ctx, iss));
			}
			else if (command == "jne")
			{
				ctx.commands.push_back(std::make_shared<CommandJumpIfNotEqual>(ctx, iss));
			}
			else if (command == "b")
			{
				ctx.commands.push_back(std::make_shared<CommandReadBit>(ctx, iss, false));
			}
			else if (command == "B")
			{
				ctx.commands.push_back(std::make_shared<CommandReadByte>(ctx, iss, false));
			}
			else if (command == "cb")
			{
				ctx.commands.push_back(std::make_shared<CommandCompairBit>(ctx, iss, false));
			}
			else if (command == "cB")
			{
				ctx.commands.push_back(std::make_shared<CommandCompairByte>(ctx, iss, false));
			}
			else if (command == "bl")
			{
				ctx.commands.push_back(std::make_shared<CommandReadBit>(ctx, iss, true));
			}
			else if (command == "Bl")
			{
				ctx.commands.push_back(std::make_shared<CommandReadByte>(ctx, iss, true));
			}
			else if (command == "cbl")
			{
				ctx.commands.push_back(std::make_shared<CommandCompairBit>(ctx, iss, true));
			}
			else if (command == "cBl")
			{
				ctx.commands.push_back(std::make_shared<CommandCompairByte>(ctx, iss, true));
			}
			else if (command == "search")
			{
				ctx.commands.push_back(std::make_shared<CommandSearchByte>(ctx, iss));
			}
			else if (command == "print")
			{
				ctx.commands.push_back(std::make_shared<CommandPrint>(ctx, iss, line));
				continue;
			}
			else if (command == "dump")
			{
				ctx.commands.push_back(std::make_shared<CommandDump>(iss));
			}
			else if (command == "ropen")
			{
				ctx.commands.push_back(std::make_shared<CommandOpenReadFile>(iss));
			}
			else if (command == "wopen")
			{
				ctx.commands.push_back(std::make_shared<CommandOpenWriteFile>(iss));
			}
			else if (command == "write")
			{
				ctx.commands.push_back(std::make_shared<CommandWriteByte>(iss));
			}
			//else if (command == "include")
			//{
			//	ctx.commands.push_back(std::make_shared<CommandIncludeFile>(iss));
			//}
			else
			{
				cerr << "# ERROR command not found [" << line << "]" << endl;
			}

			if (iss.fail() == true || iss.eof() == false)	// 文字列の最後まで処理したかチェックを行う。
			{
				cerr << "# ERROR fail commands read [" << line << "]" << endl;
			}
		}
	}
	catch (...)
	{
		cout << line << endl;
	}

	return true;
}

// 
int main(int argc, char** argv)
{
	CONTEXT ctx;
	string streamdef_file_name = "streamdef.txt";

	// 引数判定
	if (argc >= 2)
	{
		cout << argv[1] << endl;
		CommandOpenReadFile file_open_command(argv[1]);
		file_open_command.execute(ctx);
	}
	if (argc >= 3)
	{
		int flag = 0;
		for (int i = 2; i < 100; ++i)
		{
			if (string("--deffile") == argv[i])
			{
				flag = 1;
			}
			else switch (flag)
			{
				case 1:
					streamdef_file_name = argv[i];
				default:
					cout <<
						"a.out {targetfile} [--deffile]\n"
						"\n"
						"  --deffile : set stream definition file\n" << endl;
					return 0;
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
	try
	{
		for (ctx.commands_ix = 0; ctx.commands_ix < ctx.commands.size(); ctx.commands_ix++)
		{
			if (!ctx.commands[ctx.commands_ix]->execute(ctx))
			{
				cerr << "# ERROR comand exec " << ctx.commands[ctx.commands_ix]->err_str() << endl;
			}
		}

	}
	catch (...)
	{
		cout << "exception catch at ix:" << ctx.commands_ix << " " << endl;
	}

	if (ctx.stream.size() != ctx.stream.cur_offset())
	{
		cout << "data remained. stream_size:" << ctx.stream.size() << ", read_ofs:" << ctx.stream.cur_offset() << endl;
	}

	string dummy;
	cout << "wait input..";
	std::cin >> dummy;

	return 0;
}
