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

#define ERR cerr << "#ERROR" << __LINE__ << " "

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

namespace util
{
	// とにかく一行ダンプ
	bool dump_line(const unsigned char* buf, unsigned int offset, int byte_size)
	{
		for (int i = 0; i < byte_size; ++i)
		{
			printf("%02x ", buf[offset + i]);
		}

		return true;
	}

	// 16バイト単位で綺麗にダンプ表示
	bool dump(const unsigned char* buf, unsigned int offset, int byte_size)
	{
		printf("     offset    | +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F\n");

		int i = 0;
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

	// 設定したバッファからビット単位でデータを読み出す
	// ビッグエンディアン固定
	class Bitstream
	{
	private:
		shared_ptr<unsigned char> sbuf_;
		unsigned char* buf_;
		unsigned int   size_;
		unsigned int   cur_byte_;
		unsigned int   cur_bit_;

	public:

		Bitstream() :buf_(nullptr), size_(0), cur_bit_(0), cur_byte_(0){}

		const unsigned char* buf()       { return buf_; }
		const unsigned int&  size()      { return size_; }
		unsigned int&        cur_byte()  { return cur_byte_; }
		unsigned int&        cur_bit()   { return cur_bit_; }

		bool reset(shared_ptr<unsigned char> sbuf_, unsigned int size)
		{
			sbuf_ = sbuf_;
			buf_ = sbuf_.get();
			size_ = size;
			cur_byte_ = 0;
			cur_bit_ = 0;
			return true;
		}

		bool dump_line(unsigned int byte_offset, unsigned int byte_size)
		{
			return util::dump_line(buf_, byte_offset, byte_size);
		}

		bool dump(unsigned int byte_offset, unsigned int byte_size)
		{
			return util::dump(buf_, byte_offset, byte_size);
		}

		bool check_eos()
		{
			if (cur_byte_ == size_)
			{
				cout << "[EOS]" << endl;
				return true;
			}
			return false;
		}

		bool check_length(unsigned int read_length) const
		{
			unsigned int next_byte = cur_byte_ + (cur_bit_ + read_length) / 8;
			if (size_ < next_byte)
			{
				ERR << "overrun" << hex << size_ << " <= " << next_byte << endl;
				return false;
			}
			return true;
		}

		bool cut_bit()
		{
			if (cur_bit_ != 0)
			{
				++cur_byte_;
				cur_bit_ = 0;
			}
			return true;
		}

		bool bit_advance(unsigned int length)
		{
			if (!check_length(length))
				return false;

			cur_byte_ += (cur_bit_ + length) / 8;
			cur_bit_ = (cur_bit_ + length) % 8;

			return true;
		}

		bool bit_read(unsigned int read_length, unsigned int* ret_value)
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
				*ret_value = buf_[cur_byte_];
				*ret_value >>= 8 - (cur_bit_ + read_length); // 下位ビットを合わせる
				*ret_value &= ((1 << read_length) - 1); // 上位ビットを捨てる
				bit_advance(read_length);
				return true;
			}
			else
			{
				unsigned int remained_bit = 8 - cur_bit_;
				*ret_value = buf_[cur_byte_] & ((1 << remained_bit) - 1);
				bit_advance(remained_bit);
				already_read += remained_bit;
			}

			while (read_length > already_read)
			{
				if (read_length - already_read < 8)
				{
					*ret_value <<= (read_length - already_read);
					*ret_value |= buf_[cur_byte_] >> (8 - (read_length - already_read));
					bit_advance(read_length - already_read);
					break;
				}
				else
				{
					*ret_value <<= 8;
					*ret_value |= buf_[cur_byte_];
					bit_advance(8);
					already_read += 8;
				}
			}

			return true;
		}
	};
}

class Context;
class ICommand;

// 各種コマンドのインターフェース
class ICommand
{
public:
	virtual string err_str() = 0;
	virtual bool   execute(Context& ctx) = 0;
};

// 解析状況
class Context
{
public:
	struct REGION
	{
		unsigned int byte;
		unsigned int bit;
		unsigned int bit_length;
	};

private:

	map<string, int>              label_map;
	map<string, string>           string_map;
	map<string, REGION>           data_map;
	map<string, unsigned int>     value_map;
	stack<unsigned int>           value_stack;

	vector<shared_ptr<ICommand> > command_list;
	int                           command_ix;

	shared_ptr<util::Bitstream>   stream_;
	ifstream                      ifs_;
	ofstream                      ofs_;

public:
	// getter
	shared_ptr<util::Bitstream> get_stream(){ return stream_; };
	ifstream& get_ifs(){ return ifs_; };
	ofstream& get_ofs(){ return ofs_; };
	vector<shared_ptr<ICommand> >& get_command_list(){ return command_list; };
	int& get_command_ix(){ return command_ix; };
	stack<unsigned int>& get_stack(){ return value_stack; };

	// setter
	void set_stream(shared_ptr<util::Bitstream> stream){ stream_ = stream; };
	void set_command_ix(int ix){ command_ix = ix; };
	//void set_ifs(ifstream& ifs){ ifs_ = ifs; };
	//void set_ofs(ofstream& ofs){ ofs_ = ofs; };

	// コマンドリスト発火
	bool run() throw(...)
	{
		for (command_ix = 0; command_ix < static_cast<int>(command_list.size()); command_ix++)
		{
			if (!command_list[command_ix]->execute(*this))
			{
				ERR << "comand exec " << command_list[command_ix]->err_str() << endl;
			}
		}

		return true;
	}

	bool check_label(const string& key) const
	{
		if (data_map.find(key) != data_map.end())
		{
			return true;
		}
		else
		{
			ERR << "value not found" << "[" << key << "]" << endl;
			return false;
		}
	}
	bool check_string(const string& key) const
	{
		if (key[0] == '&')
		{
			if (string_map.find(key.substr(1)) != string_map.end())
			{
				return true;
			}
			else
			{
				ERR << "string not found" << "[" << key << "]" << endl;
				return false;
			}
		}
		else
		{
			return true;
		}
	}
	bool check_offset(const string& key) const
	{
		if (data_map.find(key) != data_map.end())
		{
			return true;
		}
		else
		{
			ERR << "data not found" << "[" << key << "]" << endl;
			return false;
		}
	}
	bool check_value(const string& key) const
	{
		if (std::isdigit(key[0]))
		{
			return true;
		}
		else if (value_map.find(key) != value_map.end())
		{
			return true;
		}
		else
		{
			ERR << "value not found" << "[" << key << "]" << endl;
			return false;
		}
	}

	int get_label(const string& key) const throw(...)
	{
		auto it = label_map.find(key);
		if (it != label_map.end())
		{
			return it->second;
		}
		else
		{
			ERR << "label not found" << "[" << key << "]" << endl;
			throw false;
		}
	}
	string get_string(const string& key) const throw(...)
	{
		if (key[0] == '&')
		{
			auto it = string_map.find(key.substr(1));
			if (it != string_map.end())
			{
				return it->second;
			}
			else
			{
				ERR << "string not found" << "[" << key << "]" << endl;
				throw false;
			}
		}
		else
		{
			return key;
		}
	}
	REGION get_last_data(const string& key) const throw(...)
	{
		auto it = data_map.find(key);
		if (it != data_map.end())
		{
			return it->second;
		}
		else
		{
			ERR << "label not found" << "[" << key << "]" << endl;
			return it->second;
		}
	}
	template<typename T = int>
	T get_value(const string& key) const throw(...)
	{
		if (isdigit(key[0]))
		{
			return static_cast<T>(stoi(key, nullptr, 0));
		}
		else
		{
			auto it = value_map.find(key);
			if (it != value_map.end())
			{
				return static_cast<T>(it->second);
			}
			else
			{
				ERR << "value not found" << "[" << key << "]" << endl;
				throw false;
			}
		}
	}

	bool set_label(string key, int ix) throw(...)
	{
		label_map[key] = ix;
	}
	bool set_string(string key, string str) throw(...)
	{
		string_map[key] = str;
	}
	bool set_last_data(string key, REGION& region) throw(...)
	{
		data_map[key] = region;
	}
	bool set_value(string key, unsigned int value) throw(...)
	{
		value_map[key] = value;
	}

	bool compare(const string& lhs, const string& comp, const string& rhs) const throw(...)
	{
		if (comp == "==")
			return get_value(lhs) == get_value(rhs);
		else if (comp == "!=")
			return get_value(lhs) != get_value(rhs);
		else if (comp == "<")
			return get_value(lhs) < get_value(rhs);
		else if (comp == ">")
			return get_value(lhs) > get_value(rhs);
		else if (comp == "<=")
			return get_value(lhs) <= get_value(rhs);
		else if (comp == ">=")
			return get_value(lhs) >= get_value(rhs);
		else
		{
			ERR << "comparison operator not found" << comp << endl;
			throw false;
		}
	}
	bool test(const string& exp) const throw(...)
	{
		string lhs, comp, rhs;
		string logic = "or";
		bool result = false;
		istringstream iss(exp);

		for (int i = 0; i < 100; ++i)
		{
			iss >> lhs >> comp >> rhs;
			if (iss.fail())
			{
				ERR << "test exp error [" << exp << "]" << endl;
				throw false;
			}

			if (logic == "and")
				result = (result && compare(lhs, comp, rhs));
			else if (logic == "or")
				result = (result || compare(lhs, comp, rhs));
			else
			{
				ERR << "exp logic error [" << exp << "]" << endl;
				throw false;
			}

			iss >> logic;
			if (iss.fail())
				break;
		}

		return result;
	}
	bool calc(const string& lhs, const string& rhs, const string& op)
	{
		if ((op == "mov" || op == "="))
			set_value(lhs, get_value(rhs));
		else if ((op == "add" || op == "+="))
			set_value(lhs, get_value(lhs) + get_value(rhs));
		else if ((op == "sub" || op == "-="))
			set_value(lhs, get_value(lhs) - get_value(rhs));
		else if ((op == "mul" || op == "*="))
			set_value(lhs, get_value(lhs) * get_value(rhs));
		else if ((op == "dev" || op == "/="))
			set_value(lhs, get_value(lhs) / get_value(rhs));
		else if ((op == "mod" || op == "%="))
			set_value(lhs, get_value(lhs) % get_value(rhs));
		else if ((op == "xor" || op == "^="))
			set_value(lhs, get_value(lhs) ^ get_value(rhs));
		else if ((op == "and" || op == "&="))
			set_value(lhs, get_value(lhs) & get_value(rhs));
		else if ((op == "or" || op == "|="))
			set_value(lhs, get_value(lhs) | get_value(rhs));
		else if ((op == "sar" || op == ">>="))
			set_value(lhs, get_value(lhs) >> get_value(rhs));
		else if ((op == "sal" || op == "<<="))
			set_value(lhs, get_value(lhs) << get_value(rhs));
		else if ((op == "shr" || op == ">>="))
			set_value(lhs, get_value(lhs) >> get_value(rhs));
		else if ((op == "shl" || op == "<<="))
			set_value(lhs, get_value(lhs) << get_value(rhs));
		else
		{
			ERR << "op not found." << lhs << " " << op << " " << rhs << endl;
			throw false;
		}

		// shr shlが未完成
		return true;
	}
	int expression(const string& exp)
	{
		// 逆ポーランド的な
		// get_stack().push ;


		return true;
	}

};


// 各種コマンドの基底クラス
class Command : public ICommand
{
protected:
	string command_line_;
	int    no_;

public:
	Command(){}
	Command(int no, const string& command_line) :no_(no), command_line_(command_line){}
	virtual string err_str()
	{
		stringstream ss;
		ss << "error no." << no_ << "[" << command_line_ << "]";
		return ss.str();
	}
};


// ビット単位でストリームを読む
class CommandRead : public Command
{
protected:
	string        command_;

	// union{}args;
	string        name_;
	string        length_str_;
	string        compare_str_;
	unsigned char serch_byte_;
	bool          r_endian_;

public:
	CommandRead(){}
	CommandRead(Context& ctx, int no, const string& command_line) throw(...)
		:Command(no, command_line)
	{
		istringstream iss(command_line);
		iss >> command_ >> name_ >> length_str_;
		ctx.set_value(name_, 0);

		if ((command_ == "cb") || (command_ == "cB")
			|| (command_ == "cBl") || (command_ == "cBl"))
		{
			iss >> compare_str_;
		}

		if (iss.fail() || iss.eof())
		{
			ERR << "read command fail/eof no." << no << "[" << command_line << "]" << endl;
			//throw false;
		}

		r_endian_ = ((command_ == "bl") || (command_ == "Bl")
			|| (command_ == "cBl") || (command_ == "cBl"));
	}

	bool read_value(Context& ctx, unsigned int bit_length, bool r_endian)
	{
		printf(" pos=0x%08x(+%d)| siz=0x%08x(+%d)| %-40s | ",
			ctx.get_stream()->cur_byte(), ctx.get_stream()->cur_bit(),
			bit_length / 8, bit_length % 8, name_.c_str());

		Context::REGION region;
		region.byte = ctx.get_stream()->cur_byte();
		region.bit = ctx.get_stream()->cur_bit();
		region.bit_length = bit_length;
		ctx.set_last_data(name_, region);

		if (bit_length <= 32)
		{
			unsigned int value;

			if (!ctx.get_stream()->bit_read(bit_length, &value))
			{
				cerr << "#ERROR bit_read [" << name_ << "]" << endl;
			}

			if (r_endian)
			{
				if (bit_length == 16)
				{
					value = ((value >> 8) & 0xff) | ((value << 8) & 0xff00);
				}
				else if (bit_length == 32)
				{
					value = ((value >> 24) & 0xff) | ((value >> 8) & 0xff00)
						| ((value << 8) & 0xff0000) | ((value << 24) & 0xff000000);
				}
				else
				{
					ERR << "need 16 or 32 bit to reverse endian" << endl;
					return false;
				}
			}

			printf("val=0x%-8x (%d)\n", value, value);
			ctx.set_value(name_, value);
		}
		else
		{
			printf("dat=");
			ctx.get_stream()->dump_line(ctx.get_stream()->cur_byte(), std::min(16, (int)(bit_length / 8)));
			if (bit_length / 8 <= 16)
				printf(" \n");
			else
				printf(" ...\n");

			if (!ctx.get_stream()->bit_advance(bit_length))
			{
				ERR << "bit_read " << name_ << "cur:" << ctx.get_stream()->cur_byte() << ", read_length:" << bit_length << "bit" << endl;
				return false;
			}
		}

		ctx.get_stream()->check_eos();
		return true;
	}
	virtual bool execute(Context& ctx)
	{
		if ((command_ == "b")
			|| (command_ == "bl"))
		{
			return read_value(ctx, ctx.get_value(length_str_), r_endian_);
		}
		else if ((command_ == "B")
			|| (command_ == "Bl"))
		{
			return read_value(ctx, 8 * ctx.get_value(length_str_), r_endian_);
		}
		else if ((command_ == "cb")
			|| (command_ == "cbl"))
		{
			ctx.get_stream()->cut_bit();
			read_value(ctx, ctx.get_value(length_str_), r_endian_);
			if (ctx.get_value(name_) != ctx.get_value(compare_str_))
			{
				printf("compare value is false. value:0x%x(%d), expected:0x%x(%d)\n",
					ctx.get_value(name_), ctx.get_value(name_),
					ctx.get_value(compare_str_), ctx.get_value(compare_str_));
			}
		}
		else if ((command_ == "cB")
			|| (command_ == "cBl"))
		{
			ctx.get_stream()->cut_bit();
			read_value(ctx, 8 * ctx.get_value(length_str_), r_endian_);
			if (ctx.get_value(name_) != ctx.get_value(compare_str_))
			{
				printf("compare value is false. value:0x%x(%d), expected:0x%x(%d)\n",
					ctx.get_value(name_), ctx.get_value(name_),
					ctx.get_value(compare_str_), ctx.get_value(compare_str_));
			}
			return true;
		}
		else if (command_ == "serch")
		{
			// バイトシークのためbit削除
			ctx.get_stream()->cut_bit();

			unsigned int val;
			for (int i = 0; true; ++i)
			{
				if (!ctx.get_stream()->bit_read(8, &val))
				{
					cout << "can not find byte:0x" << hex << serch_byte_ << endl;
					return false;
				}

				if (val == serch_byte_)
				{
					return true;
				}
			}

			cout << "can not find byte:0x" << hex << serch_byte_ << endl;
			return false;
		}
		else
		{
			ERR << "command not found [" << command_line_ << "]" << endl;
			// throw false;
		}

		return true;
	}
};

// ファイル全部ctxのバッファに展開する
class CommandString : public Command
{
private:
	string command_;
	string arg1_;
	string arg2_;
	string arg3_;
	string arg4_;

public:
	CommandString(){}
	CommandString(int no, const string& command_line) throw(...)
		:Command(no, command_line)
	{
		istringstream iss(command_line);
		iss >> command_;

		if ((command_ == "endif")
			|| (command_ == "return")
			|| (command_ == "next"))
		{
		}
		else if ((command_ == "ropen")
			|| (command_ == "str")
			|| (command_ == "call"))
		{
			iss >> arg1_;
		}
		else if ((command_ == "mov")
			|| (command_ == "add")
			|| (command_ == "sub")
			|| (command_ == "mul")
			|| (command_ == "dev")
			|| (command_ == "mod")
			|| (command_ == "xor")
			|| (command_ == "and")
			|| (command_ == "or")
			|| (command_ == "sar")
			|| (command_ == "sal")
			|| (command_ == "strset")
			|| (command_ == "strcat")
			|| (command_ == "shr")
			|| (command_ == "shl"))
		{
			iss >> arg1_ >> arg2_;
		}
		else if ((command_ == "if")
			|| (command_ == "elseif")
			|| (command_ == "while")
			|| (command_ == "exp"))
		{
			arg1_ = command_line.substr(static_cast<int>(iss.tellg()));
		}
		else if (command_ == "jif")
		{
			iss >> arg1_;
			arg2_ = command_line.substr(static_cast<int>(iss.tellg()));
		}
		else
		{
			ERR << "command not found [" << command_line_ << "]" << endl;
		}

		if (iss.fail() || !iss.eof())
		{
			ERR << "command_line fail/eof no." << no << "[" << command_line << "]" << endl;
			// throw false;
		}
	}

	virtual bool execute(Context& ctx)
	{
		if (command_ == "ropen")
		{
			ctx.get_ifs().open(arg1_, ifstream::binary);
			if (!ctx.get_ifs()){
				ERR << "open read file [" << arg1_ << "]" << endl;
				return false;
			}

			// ファイルサイズ
			ctx.get_ifs().seekg(0, ifstream::end);
			int file_size = static_cast<int>(ctx.get_ifs().tellg());
			ctx.get_ifs().seekg(0, ifstream::beg);

			// 全部読み込み
			shared_ptr<unsigned char> buf(new unsigned char[file_size]);
			ctx.get_ifs().read((char*)buf.get(), file_size);
			ctx.get_ifs().close();

			// ビットストリームリセット
			ctx.get_stream()->reset(buf, file_size);
		}
		else if (command_ == "wopen")
		{
			ctx.get_ofs().open(arg1_, ifstream::binary);
			if (!ctx.get_ofs())
			{
				ERR << "open write file [" << arg1_ << "]" << endl;
				return false;
			}
		}
		else if (command_ == "write")
		{
			if (!ctx.get_ofs())
			{
				ERR << "write " << arg1_ << endl;
				return false;
			}

			Context::REGION& region = ctx.get_last_data(arg1_);
			unsigned char* buf = const_cast<unsigned char*>(ctx.get_stream()->buf());
			ctx.get_ofs().write((char*)(&buf[region.byte]), region.bit_length / 8);
		}
		else if ((command_ == "mov")
			|| (command_ == "add")
			|| (command_ == "sub")
			|| (command_ == "mul")
			|| (command_ == "dev")
			|| (command_ == "mod")
			|| (command_ == "xor")
			|| (command_ == "and")
			|| (command_ == "or")
			|| (command_ == "sar")
			|| (command_ == "sal")
			|| (command_ == "shr")
			|| (command_ == "shl"))
		{
			ctx.calc(arg1_, arg2_, command_);
		}
		else if (command_ == "calc")
		{
			ctx.calc(arg1_, arg3_, arg2_);
		}
		else if (command_ == "exp")
		{
			ctx.expression(arg1_);
		}
		else if (command_ == "print")
		{
			if (arg1_[0] == '\"')
			{
				int first = arg1_.find_first_of('\"');
				int last = arg1_.find_last_of('\"');
				cout << arg1_.substr(first + 1, last - first - 1) << endl;
			}
			else
			{
				if (ctx.get_last_data(arg1_).bit_length > 32)
				{
					cout << "     [dump " << arg1_ << "]" << endl;
					ctx.get_stream()->dump(ctx.get_last_data(arg1_).byte,
						std::min(ctx.get_last_data(arg1_).bit_length / 8, (unsigned int)256));
				}
				else
				{
					printf("     %s: 0x%x (%d)\n", arg1_.c_str(), ctx.get_value(arg1_), ctx.get_value(arg1_));
				}
			}
		}
		else if (command_ == "dump")
		{
			cout << "     [dump address:0x" << hex << arg1_ << ", size:0x" << arg2_ << "]" << endl;
			ctx.get_stream()->dump(ctx.get_value(arg1_), std::min((unsigned int)ctx.get_value(arg2_), (unsigned int)256));
		}
		else if (command_ == "jif")
		{
			if (ctx.test(arg1_))
			{
				ctx.set_command_ix(ctx.get_label(arg1_));
			}
		}
		else if (command_ == "str")
		{
			ctx.set_string(arg1_, "");
		}
		else if (command_ == "strset")
		{
			ctx.set_string(arg1_, arg2_);
		}
		else if (command_ == "strcat")
		{
			ctx.set_string(ctx.get_string(arg1_), ctx.get_string(arg1_) + ctx.get_string(arg2_));
		}
		else
		{
			ERR << "command not found [" << command_line_ << "]" << endl;
			return false;
		}

		return true;
	}
};

class CommandFlowControl : public Command
{
private:
	string command_;
	string arg1_;
	string arg2_;
	int dest_ix;

public:
	CommandFlowControl(){}
	CommandFlowControl(int no, const string& command_line) throw(...)
		:Command(no, command_line)
	{
		istringstream iss(command_line);
		iss >> command_;

		if ((command_ == "endif")
			|| (command_ == "return")
			|| (command_ == "next"))
		{
		}
		else if (command_ == "jif")
		{
			iss >> arg1_;
			arg2_ = command_line.substr(static_cast<unsigned int>(iss.tellg()));
		}
		else if ((command_ == "if")
			|| (command_ == "while")
			|| (command_ == "call"))
		{
			arg1_ = command_line.substr(static_cast<unsigned int>(iss.tellg()));
		}
		else
		{
			ERR << "command not found " << err_str() << endl;
		}
	}
	
	virtual bool execute(Context& ctx)
	{
		if (command_ == "jif")
		{
			if (!ctx.test(arg2_))
			{
				ctx.set_command_ix(ctx.get_label(arg1_));
			}
		}
		else if ((command_ == "if")
		||       (command_ == "while"))
		{
			if (!ctx.test(arg1_))
			{
				ctx.set_command_ix(dest_ix);
			}
		}
		else if (command_ == "next")
		{
			ctx.set_command_ix(dest_ix);
		}
		else if (command_ == "endif")
		{
		}
		else if (command_ == "call")
		{
			ctx.get_stack().push(ctx.get_command_ix);
			ctx.set_command_ix(ctx.get_label(arg1_));
		}
		else if (command_ == "return")
		{
			int dest = ctx.get_stack().top();
			ctx.set_command_ix(dest);
			ctx.get_stack().pop();
		}
		else
		{
			ERR << "command not found" << err_str() << endl;
		}
	}

	// これを呼ばないとジャンプ先が確定できない
	// もうちょっと何とかしたい
	void set_dest_ix(int ix)
	{
		dest_ix = ix;
	}

	// これを呼ばないとジャンプ先が確定できない
	// もうちょっと何とかしたい
	const string& get_command_str() const
	{
		return command_;
	}
};

// 定義ファイルのタグからコマンドを生成する
bool load_streamdef_file(Context& ctx, string& file_name)
{
	ifstream def_fs;
	def_fs.open(file_name);
	string command_line;
	string command;
	istringstream iss;
	int i = 0;
	
	vector<shared_ptr<CommandFlowControl> > flow_command_list;

	try
	{
		for (int i = 0; i < 100000; ++i)
		{
			if (!def_fs || !std::getline(def_fs, command_line))
				break;

			iss.str(command_line);
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
				ctx.set_label(label, ctx.get_command_list().size());
			}
			else if ((command == "str")
				|| (command == "strset")
				|| (command == "strcat")
				|| (command == "val")
				|| (command == "mov")
				|| (command == "add")
				|| (command == "sub")
				|| (command == "mul")
				|| (command == "dev")
				|| (command == "mod")
				|| (command == "xor")
				|| (command == "and")
				|| (command == "or")
				|| (command == "sh|")
				|| (command == "shr")
				|| (command == "sa|")
				|| (command == "sar")
				|| (command == "calc")
				//||       (command == "include")
				|| (command == "print")
				|| (command == "dump")
				|| (command == "ropen")
				|| (command == "wopen"))
			{
				ctx.get_command_list().push_back(std::make_shared<CommandString>(i, command_line));
				continue;
			}
			else if ((command == "b")
				|| (command == "B")
				|| (command == "cb")
				|| (command == "cB")
				|| (command == "bl")
				|| (command == "Bl")
				|| (command == "cbl")
				|| (command == "cBl")
				|| (command == "search"))
			{
				ctx.get_command_list().push_back(std::make_shared<CommandRead>(ctx, i, command_line));
				continue;
			}
			else if ((command == "while")
				|| (command == "next")
				|| (command == "if")
				|| (command == "elseif")
				|| (command == "endif")
				|| (command == "call")
				|| (command == "return"))
			{
				shared_ptr<CommandFlowControl> command = std::make_shared<CommandFlowControl>(ctx, i, command_line);
				ctx.get_command_list().push_back(std::make_shared<CommandRead>(ctx, i, command_line));

				// あとでジャンプ先をを更新する
				flow_command_list.push_back(command);
			}
			else
			{
				ERR << "command not found. line." << i << " [" << command_line << "]" << endl;
			}

			if (iss.fail())
			{
				ERR << "fail in command_list. line." << i << " [" << command_line << "]" << endl;
			}
			if (iss.eof() == false)
			{
				ERR << "!eof in command_list. line." << i << " [" << command_line << "]" << endl;
			}
		}

		// ジャンプリスト更新
		for (auto it = flow_command_list.begin(); it != flow_command_list.end(); ++it)
		{
			int count = 0;
			if ((*it)->get_command_str() == "if")
			{
				for (auto it2 = it; it2 != flow_command_list.end();)
				{
					if ((*it2)->get_command_str() == "if")
					{
						++count;
					}
					else if ((*it2)->get_command_str() == "endif")
					{
						--count;
						if (count == 0)
						{ 
							break;
						}
					}
				}

			}
			else if 
			{
			}

			if 
		}
	}
	catch (...)
	{
		ERR << "catch exception no." << i << "[" << command_line << "]" << endl;
	}

	return true;
}

// 
int main(int argc, char** argv)
{
	Context ctx;
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
		CommandString command(0, ss.str());
		command.execute(ctx);
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
				ctx.set_string(ss.str(), argv[i]);
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

	// 最初の定義ファイルを読む
	if (!load_streamdef_file(ctx, streamdef_file_name))
	{
		ERR << "streamdef file load" << endl;
		return 0;
	}

	// 各種コマンド発火

	try
	{
		ctx.run();
	}
	catch (...)
	{
		cout << "exception catch" << endl;
	}

	if (ctx.get_stream()->size() != ctx.get_stream()->cur_byte())
	{
		cout << "data remained. stream_size:" << ctx.get_stream()->size()
			<< ", cur_byte:" << ctx.get_stream()->cur_byte() << endl;
	}

	// for windows console
	string dummy;
	cout << "wait input..";
	std::cin >> dummy;

	return 0;
}
