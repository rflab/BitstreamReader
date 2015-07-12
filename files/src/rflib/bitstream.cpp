// ビットストリームクラス
#include "bitstream.h"

using namespace rf;

void Bitstream::sync()
{
	// リングバッファの場合のように、必ずしもstreambuf上のいちとbyte_posは同じにならない
	// return byte_pos_ == buf_->pubseekpos(byte_pos_);
	buf_->pubseekpos(byte_pos_);
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
int  Bitstream::byte_pos() const
{
	return byte_pos_;
}

// 読み込み対象のstreambufを設定する
// サイズの扱いをもっとねらないとだめだかなぁ
//template<typename Deleter>
void  Bitstream::assign(std::unique_ptr<std::streambuf>&& buf, int size)
{
	buf_ = std::move(buf);
	byte_pos_ = 0;
	bit_pos_ = 0;
	size_ = size;
	sync();
}

// ストリーム内か判定
bool  Bitstream::check_pos(int byte_pos) const
{
	if ((byte_pos < 0) || (size_ < byte_pos))
		return false;
	return true;
}

// ビット単位で現在位置＋offsetがストリーム内か判定
bool  Bitstream::check_offset_bit(int offset) const
{
	int byte_pos = byte_pos_ + (bit_pos_ + offset) / 8;
	if ((byte_pos < 0) || (size_ < byte_pos))
		return false;
	return true;
}

// バイト単位で現在位置＋offsetがストリーム内か判定
bool  Bitstream::check_offset_byte(int offset) const
{
	int byte_pos = byte_pos_ + offset;
	if ((byte_pos < 0) || (size_ < byte_pos))
		return false;
	return true;
}

// 読み込みヘッダを移動
void  Bitstream::seekpos(int byte, int bit)
{
	if (FAIL((0 >= bit) && (bit < 8)))
	{
		ERR << "bit=" << hex << bit << " " << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range."));
	}

	if (FAIL(check_pos(byte)))
	{
		ERR << "byte=" << hex << byte << " " << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	byte_pos_ = byte;
	bit_pos_ = bit;
	sync();
}

// ビット単位で読み込みヘッダを移動
void  Bitstream::seekoff_bit(int offset)
{
	if (FAIL(check_offset_bit(offset)))
	{
		ERR << "offset=" << hex << offset << " " << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	byte_pos_ += (bit_pos_ + offset) / 8;
	bit_pos_ = (bit_pos_ + offset) % 8; // & 0x07;
	sync();
}

// バイト単位で読み込みヘッダを移動
void  Bitstream::seekoff_byte(int offset)
{
	if (FAIL(check_offset_byte(offset)))
	{
		ERR << "offset=" << hex << offset << " " << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR(" range error."));
	}

	if (FAIL(bit_pos_ == 0))
	{
		WARNING << "bit_pos_ is not aligned. bit_pos_=" << hex << bit_pos_ << " " << OUTPUT_POS << endl;
	}

	byte_pos_ += offset;
	bit_pos_ = 0;
	sync();
}

// ビット単位で読み込み
unsigned int Bitstream::read_bit(int size)
{
	if (FAIL(0 <= size && size <= static_cast<int>(sizeof(unsigned int) * 8)))
	{
		ERR << "read bit range error. size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR(" range error."));
	}

	if (FAIL(check_offset_bit(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR(" range error."));
	}

	unsigned int value;
	int already_read = 0;

	// 先頭の中途半端なビットを読んでから、残りをバイトストリームとして読む
	// read_lengthが現在のバイトに収まるならビット読み出しまでで終了
	if (bit_pos_ + size < 8)
	{
		value = static_cast<unsigned int>(buf_->sgetc());
		value >>= 8 - (bit_pos_ + size); // 下位ビットを合わせる
		value &= ((1 << size) - 1); // 上位ビットを捨てる
		seekoff_bit(size);
		return value;
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

	return value;
}

// バイト単位で読み込み
unsigned int Bitstream::read_byte(int size)
{
	if (FAIL(0 <= size && size <= 4))
	{
		ERR << "read byte > 4. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range."));
	}

	if (FAIL(check_offset_byte(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	if (FAIL(bit_pos_ == 0))
	{
		WARNING << "bit_pos_ is not aligned. bit_pos_=" << hex << bit_pos_ << " " << OUTPUT_POS << endl;
	}

	return read_bit(size * 8);
}

// 指数ゴロムとしてビット単位で読み込み
void  Bitstream::read_expgolomb(unsigned int &ret_value, int &ret_size)
{
	unsigned int v = read_bit(1);
	if (v == 1)
	{
		ret_value = 0;
		ret_size = 1;
		return;
	}

	unsigned int count = 1;
	for (;;)
	{
		v = read_bit(1);
		if (v == 1)
		{
			v = read_bit(count);
			ret_value = (v | (1 << count)) - 1;
			ret_size = 2 * count + 1;
			return;
		}

		++count;
	}
}

// 文字列として読み込み
// NULL文字が先に見つかった場合はその分だけ文字列にするがポインタは進む
// NULL文字が見つからなかった場合は最大max_lengthの長さ文字列として終端にNULL文字を入れる
string  Bitstream::read_string(int size)
{
	if (FAIL(check_offset_byte(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	if (FAIL(bit_pos_ == 0))
	{
		WARNING << "bit_pos_ is not aligned. bit_pos_=" << hex << bit_pos_ << " " << OUTPUT_POS << endl;
	}

#if 1
	int offset = 0;
	int c;
	std::stringstream ss;
	for (; offset < size; ++offset)
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

	seekoff_byte(size);
	return ss.str();
#else
	auto pa = std::make_unique<char[]>(size);
	buf_->sgetn(pa.get(), size);
	seekoff_byte(size);
	return pa.get();
#endif
}

// ビット単位で先読み
unsigned int Bitstream::look_bit(int size)
{
	if (FAIL(0 <= size && size <= static_cast<int>(sizeof(unsigned int) * 8)))
	{
		ERR << "bit size range error. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range"));
	}

	if (FAIL(check_offset_bit(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	unsigned int val = read_bit(size);
	seekoff_bit(-size);
	return val;
}

// バイト単位で先読み
unsigned int Bitstream::look_byte(int size)
{
	if (FAIL(0 <= size && size <= 4))
	{
		ERR << "look byte size > 4. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range"));
	}

	if (FAIL(check_offset_byte(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	if (FAIL(bit_pos_ == 0))
	{
		WARNING << "bit_pos_ is not aligned. bit_pos_=" << hex << bit_pos_ << " " << OUTPUT_POS << endl;
	}

	unsigned int val = read_byte(size);
	seekoff_byte(-size);
	return val;
}

// 指数ゴロムで先読み
void  Bitstream::look_expgolomb(unsigned int &ret_val, int &ret_size)
{
	int prev_byte = byte_pos_;
	int prev_bit = bit_pos_;
	read_expgolomb(ret_val, ret_size);
	seekpos(prev_byte, prev_bit);
}

// 指定バッファの分だけ先読み
void  Bitstream::look_byte_string(char* address, int size)
{
	if (FAIL(0 <= size))
	{
		ERR << "look byte size < 0. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range"));
	}

	if (FAIL(bit_pos_ == 0))
	{
		WARNING << "bit_pos_ is not aligned. bit_pos_=" << hex << bit_pos_ << " " << OUTPUT_POS << endl;
	}

	if (FAIL(check_offset_byte(size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	buf_->sgetn(address, size);
	sync();
}

// 特定の１バイトの値を検索
// 見つからなければファイル終端を返す
int  Bitstream::find_byte(char sc, bool advance, int end_offset)
{
	int offset = 0;
	int c;
	auto buf = buf_.get(); // パフォーマンス改善のためキャスト
	for (; byte_pos_ + offset < size_; ++offset)
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
		else if (offset >= end_offset)
		{
			break;
		}
	}

	if (advance)
		seekoff_byte(offset);
	else
		sync();
	return offset;
}

int  Bitstream::rfind_byte(char sc, bool advance, int end_offset)
{
	int offset = 0;
	int c;
	auto buf = buf_.get(); // パフォーマンス改善のためキャスト
	for (; -byte_pos_ <= offset; --offset)
	{
		c = buf->sgetc();
		// buf->sungetc();
		buf->pubseekoff(-1, std::ios::cur);
		if (static_cast<char>(c) == sc)
		{
			break;
		}
		else if (offset <= end_offset)
		{
			break;
		}
	}

	if (offset < (-byte_pos_))
		offset = (-byte_pos_);

	if (advance)
		seekoff_byte(offset);
	else
		sync();
	return offset;
}

// 特定のバイト列を検索
// 見つからなければファイル終端を返す
int  Bitstream::find_byte_string(
	const char* address, int size, bool advance, int end_offset)
{
	//char* contents = new char[size];
	char contents[256];
	if (FAIL(sizeof(contents) >= static_cast<size_t>(size)))
	{
		ERR << "too long search string. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range"));
	}

	if (FAIL(valid_ptr(address)))
	{
		ERR << "invalid address address=" << hex << address << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("invalid argument"));
	}

	int offset = 0;
	int end_offset_remain = end_offset;
	int prev_byte_pos = byte_pos_;
	for (;;)
	{
		// 先頭1バイトを検索
		offset = find_byte(address[0], true, end_offset_remain);

		// 見つからなかった
		if (offset >= end_offset_remain)
		{
			if (!advance)
				seekpos(prev_byte_pos, 0);
			return end_offset;
		}

		// EOSをはみ出す場合
		if (!check_offset_byte(size))
		{
			if (!advance)
				seekpos(prev_byte_pos, 0);
			else
				seekpos(size_, 0);
			return size_ - prev_byte_pos;
		}

		end_offset_remain -= offset;

		// 一致
		// 不一致は1バイト進める
		look_byte_string(contents, size);
		if (std::memcmp(contents, address, static_cast<size_t>(size)) == 0)
		{
			int total_offset = byte_pos_ - prev_byte_pos;
			if (!advance)
				seekpos(prev_byte_pos, 0);
			return total_offset;
		}
		else
		{
			seekoff_byte(1);
			--end_offset_remain;
		}
	}
}

// 特定のバイト列を検索
// 見つからなければファイル終端を返す
int  Bitstream::rfind_byte_string(
	const char* address, int size, bool advance, int end_offset)
{
	//char* contents = new char[size];f
	char contents[256];
	if (FAIL(sizeof(contents) >= static_cast<size_t>(size)))
	{
		ERR << "too long search string. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range"));
	}

	if (FAIL(valid_ptr(address)))
	{
		ERR << "invalid address address=" << hex << address << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("invalid argument"));
	}

	int offset = 0;
	int end_offset_remain = end_offset;
	int prev_byte_pos = byte_pos_;

	// EOSをはみ出す場合は位置バイト進めてから検索検索再開
	if (!check_offset_byte(size))
	{
		if (!check_pos(size_ - size))
		{
			if (advance)
				seekpos(0, 0);
			return 0;
		}
		seekpos(size_ - size, 0);
	}

	for (;;)
	{
		// 先頭位置バイトを検索
		offset = rfind_byte(address[0], true, end_offset_remain);
		if (offset <= 0)
		{
			seekpos(prev_byte_pos, 0);
			return 0;
		}

		end_offset_remain -= offset;

		// 一致
		// 不一致は1バイト進める
		look_byte_string(contents, size);
		if (std::memcmp(contents, address, static_cast<size_t>(size)) == 0)
		{
			int total_offset = byte_pos_ - prev_byte_pos;
			if (!advance)
				seekpos(prev_byte_pos, 0);
			return total_offset;
		}
		else
		{
			seekoff_byte(-1);
			++end_offset_remain;
		}
	}
}

// ストリームにデータを書く
// 辻褄を合わせるためにサイズを計算する
void  Bitstream::write(const char *buf, int size)
{
	if (FAIL(size >= 0))
		throw std::logic_error(FAIL_STR("size error."));

	size_ = std::max(byte_pos_ + size, size_);
	if (FAIL(buf_->sputn(buf, size) == size))
		throw std::runtime_error(FAIL_STR("file write(sputn) error."));
}

// ストリームに１バイト追記する
void  Bitstream::put_char(char c)
{
	size_ = std::max(byte_pos_ + 1, size_);
	if (FAIL(buf_->sputc(c) == c))
		throw std::runtime_error(FAIL_STR("file write(sputc) error."));
}

int RingBuf::overflow(int c)
{
	setp(buf_.get(), buf_.get() + size_);
	return sputc(static_cast<char>(c));
}

int RingBuf::underflow()
{
	setg(buf_.get(), buf_.get(), buf_.get() + size_);
	return buf_[0];
}

std::ios::pos_type RingBuf::seekoff(
	std::ios::off_type off, std::ios::seekdir way, std::ios::openmode)
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

std::ios::pos_type RingBuf::seekpos(
	std::ios::pos_type pos, std::ios::openmode which)
{
	return seekoff(pos, std::ios::beg, which);
}

//-----------------------------------------------
RingBuf::RingBuf()
	: std::streambuf(), size_(0)
{
}

// リングバッファのサイズを指定する
void RingBuf::reserve(int size)
{
	if (FAIL(0 <= size))
	{
		ERR << "buf size error. size=" << hex << size << endl;
		throw std::logic_error(FAIL_STR("out of range"));
	}

	buf_ = std::unique_ptr<char[]>(new char[size]); //, std::default_delete<char[]>() );
	size_ = size;
	setp(buf_.get(), buf_.get() + size);
	setg(buf_.get(), buf_.get(), buf_.get() + size);
}
