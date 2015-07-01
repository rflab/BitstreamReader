#include "bitstream.h"

#include <iostream>
#include <string>
#include <array>
#include <memory>
#include <sstream>

// コンパイラ依存
#if defined(_MSC_VER) && (_MSC_VER >= 1800)
#elif defined(__GNUC__) && __cplusplus >= 201300L // __GNUC_PREREQ(4, 9)
#else
#endif

// using
using std::string;
using std::unique_ptr;
using std::streambuf;
using std::ios;
using std::stoi;
using std::cerr;
using std::endl;
using std::hex;
using std::dec;
using namespace rf;

// macro
//#define FAIL(...) __VA_ARGS__
#define FAIL(...) ::rf::fail((__VA_ARGS__), __LINE__, __FUNCTION__, #__VA_ARGS__)
#define ERR cerr << "# c++ error. L" << dec << __LINE__ << " " << __FUNCTION__ << ": "
#define OUTPUT_POS "at 0x" << hex << byte_pos() <<  "(+" << bit_pos() << ')'

inline bool fail(bool b, int line, const std::string &fn, const std::string &exp)
{
	if (!b)
		std::cerr << "# c++ L." << dec
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
	return p != false;
}

// メンバ変数にstreambufを同期する
bool Bitstream::sync()
{
	// リングバッファの場合のように、必ずしもstreambuf上のいちとbyte_posは同じにならない
	// return byte_pos_ == buf_->pubseekpos(byte_pos_);
	buf_->pubseekpos(byte_pos_);
	return true;
}

Bitstream::Bitstream()
	: size_(0), bit_pos_(0), byte_pos_(0)
{
}

// このBitstreamの現在サイズ
int Bitstream::size() const
{
	return size_;
}

// 読み取りヘッダのビット位置
int Bitstream::bit_pos() const
{
	return bit_pos_;
}

// 読み取りヘッダのバイト位置
int Bitstream::byte_pos() const
{
	return byte_pos_;
}

// 読み込み対象のstreambufを設定する
// サイズの扱いをもっとねらないとだめだかなぁ
//template<typename Deleter>
bool Bitstream::assign(unique_ptr<streambuf>&& buf, int size)
{
	buf_ = std::move(buf);
	byte_pos_ = 0;
	bit_pos_ = 0;
	size_ = size;

	return sync();
}

// ストリームにデータを追記する
bool Bitstream::write_byte_string(const char *buf, int size)
{
	if (FAIL(size >= 0))
	{
		ERR << "write size error, size=" << hex << size << " " << OUTPUT_POS << endl;
		return false;
	}

	buf_->sputn(buf, size);
	size_ += size;

	return true;
}

// ストリームに１バイト追記する
bool Bitstream::put_char(char c)
{
	++size_;
	return c == buf_->sputc(c);
}

// ビット単位でストリーム内か判定
bool Bitstream::check_bit(int bit) const
{
	if (!((0 <= bit) && ((bit + 7) / 8 <= size_)))
		return false;
	return true;
}

// バイト単位でストリーム内か判定
bool Bitstream::check_byte(int byte) const
{
	if (!((0 <= byte) && (byte <= size_)))
		return false;
	return true;
}

// ビット単位で現在位置＋offsetがストリーム内か判定
bool Bitstream::check_offset_bit(int offset) const
{
	if (!(check_bit(byte_pos_ * 8 + bit_pos_ + offset)))
		return false;
	return true;
}

// バイト単位で現在位置＋offsetがストリーム内か判定
bool Bitstream::check_offset_byte(int offset) const
{
	if (!(check_byte(byte_pos_ + offset)))
		return false;
	return true;
}

// 読み込みヘッダを移動
bool Bitstream::seekpos(int byte, int bit)
{
	if (FAIL(check_byte(byte)))
	{
		ERR << "byte=" << hex << byte << " " << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL((0 >= bit) && (bit < 8)))
	{
		ERR << "bit=" << hex << bit << " " << OUTPUT_POS << endl;
		return false;
	}


	byte_pos_ = byte;
	bit_pos_ = bit;

	return sync();
}

// ビット単位で読み込みヘッダを移動
bool Bitstream::seekpos_bit(int offset)
{
	if (FAIL(check_bit(offset)))
	{
		ERR << "offset=" << hex << offset << " " << OUTPUT_POS << endl;
		return false;
	}

	byte_pos_ = offset / 8;
	bit_pos_ = offset % 8;

	return sync();
}

// バイト単位で読み込みヘッダを移動
bool Bitstream::seekpos_byte(int offset)
{
	if (FAIL(seekpos(offset, 0)))
	{
		ERR << "offset=" << hex << offset << " " << OUTPUT_POS << endl;
		return false;
	}
	return true;
}

// 読み込みヘッダを移動
bool Bitstream::seekoff(int byte, int bit)
{
	if (FAIL(check_bit(byte * 8 + bit)))
	{
		ERR << "byte=" << hex << byte << " bit=" << bit << " " << OUTPUT_POS << endl;
		return false;
	}

	byte_pos_ += byte;
	bit_pos_ += bit;

	return sync();
}

// ビット単位で読み込みヘッダを移動
bool Bitstream::seekoff_bit(int offset)
{
	if (FAIL(check_offset_bit(offset)))
	{
		ERR << "offset=" << hex << offset << " " << OUTPUT_POS << endl;
		return false;
	}

	byte_pos_ += (bit_pos_ + offset) / 8;
	bit_pos_ = (bit_pos_ + offset) % 8; // & 0x07;

	return sync();
}

// バイト単位で読み込みヘッダを移動
bool Bitstream::seekoff_byte(int offset)
{
	if (FAIL((bit_pos_ & 0x7) == 0))
	{
		ERR << "bit_pos_ is not aligned. " << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL(check_offset_byte(offset)))
	{
		ERR << "offset=" << hex << offset << " " << OUTPUT_POS << endl;
		return false;
	}

	byte_pos_ += offset;

	return sync();
}

// ビット単位で読み込み
bool Bitstream::read_bit(int size, uint32_t &ret_value)
{
	if (FAIL(0 <= size && size <= 32))
	{
		ERR << "read bit > 32. size=" << hex << size << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL(check_offset_bit(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		return false;
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
bool Bitstream::read_byte(int size, uint32_t &ret_value)
{
	if (FAIL(0 <= size && size <= 4))
	{
		ERR << "read byte > 4. size=" << hex << size << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL(check_offset_byte(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		return false;
	}

	return read_bit(size * 8, ret_value);
}

// 指数ゴロムとしてビット単位で読み込み
bool Bitstream::read_expgolomb(uint32_t &ret_value, int &ret_size)
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
		if (FAIL(read_bit(1, v)))
			return false;

		if (v == 1)
		{
			if (FAIL(read_bit(count, v)))
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
bool Bitstream::read_string(int max_length, string &ret_str)
{
	if (FAIL(check_offset_byte(max_length)))
	{
		ERR << "max_length=" << hex << max_length << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL(bit_pos_ == 0))
	{
		ERR << "bit_pos_ is not aligned" << OUTPUT_POS << endl;
		return false;
	}

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

	if (FAIL(seekoff_byte(ofs)))
		return false;

	return true;
}

// ビット単位で先読み
bool Bitstream::look_bit(int size, uint32_t &ret_val)
{
	if (FAIL(0 <= size && size <= 32))
	{
		ERR << "bit size > 32. size=" << hex << size << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL(check_offset_bit(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL(read_bit(size, ret_val)))
		return false;

	if (FAIL(seekoff_bit(-size)))
		return false;

	return true;
}

// バイト単位で先読み
bool Bitstream::look_byte(int size, uint32_t &ret_val)
{
	if (FAIL(0 <= size && size <= 4))
	{
		ERR << "look byte size > 4. size=" << hex << size << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL(check_offset_byte(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		return false;
	}

#if 0
	if (FAIL(bit_pos_ == 0))
	{
		ERR << "look byte bit_pos_ != 0. bit_pos_=" << hex << bit_pos_ << OUTPUT_POS << endl;
		return false;
	}

	char buf[4];
	ret_val = 0;
	buf_->sgetn(buf, size);
	for (int i = 0; i<size; ++i)
	{
		ret_val <<= 8;
		ret_val |= buf[i];
	}

	return sync();
#else

	if (FAIL(read_byte(size, ret_val)))
		return false;

	if (FAIL(seekoff_byte(-size)))
		return false;

	return true;
#endif

}

// 指数ゴロムで先読み
bool Bitstream::look_expgolomb(uint32_t &ret_val)
{
	int prev_byte = byte_pos_;
	int prev_bit = bit_pos_;
	int dummy_size;

	if (FAIL(read_expgolomb(ret_val, dummy_size)))
		return false;

	if (FAIL(seekoff(prev_byte, prev_bit)))
		return false;

	return true;
}

// 指定バッファの分だけ先読み
bool Bitstream::look_byte_string(char* address, int size)
{
	if (FAIL(0 <= size))
	{
		ERR << "look byte size < 0. size=" << hex << size << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL(bit_pos_ == 0))
	{
		ERR << "look byte bit_pos_ != 0. bit_pos_=" << hex << bit_pos_ << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL(check_offset_byte(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		return false;
	}

	buf_->sgetn(address, size);

	return sync();
}

// 特定の１バイトの値を検索
// 見つからなければファイル終端を返す
bool Bitstream::find_byte(char sc, int &ret_offset, bool advance, int end_offset = INT_MAX)
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
		if (FAIL(seekoff_byte(ofs)))
			return false;
		return true;
	}
	else
		return sync();
}

// 特定のバイト列を検索
// 見つからなければファイル終端を返す
bool Bitstream::find_byte_string(
	const char* address, int size, int &ret_offset, bool advance, int end_offset = INT_MAX)
{
	//char* contents = new char[size];
	char contents[256];
	if (FAIL(sizeof(contents) >= static_cast<size_t>(size)))
	{
		ERR << "too long search string. size=" << hex << size << OUTPUT_POS << endl;
		return false;
	}

	if (FAIL(valid_ptr(address)))
	{
		ERR << "invalid address address=" << hex << address << OUTPUT_POS << endl;
		return false;
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
				return seekpos_byte(size_);
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

//-----------------------------------------------------
// RingBuf
//-----------------------------------------------------
int RingBuf::overflow(int c) override
{
	setp(buf_.get(), buf_.get() + size_);
	return sputc(static_cast<char>(c));
}

int RingBuf::underflow() override
{
	setg(buf_.get(), buf_.get(), buf_.get() + size_);
	return buf_[0];
}

ios::pos_type RingBuf::seekoff(ios::off_type off, ios::seekdir way, ios::openmode) override
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

ios::pos_type RingBuf::seekpos(ios::pos_type pos, ios::openmode which) override
{
	return seekoff(pos, ios::beg, which);
}

RingBuf::RingBuf()
	: streambuf(), size_(0)
{
}

// リングバッファのサイズを指定する
bool RingBuf::reserve(int size)
{
	if (FAIL(0 <= size))
	{
		ERR << "buf size error. size=" << hex << size << endl;
		return false;
	}

	buf_ = unique_ptr<char[]>(new char[size]); //, std::default_delete<char[]>() );
	size_ = size;
	setp(buf_.get(), buf_.get() + size);
	setg(buf_.get(), buf_.get(), buf_.get() + size);
	return true;
}