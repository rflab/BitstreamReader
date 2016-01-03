#include "pch.h"
#include "bitstream.h"
#include <sstream>
#include <algorithm>
#include "common/function.h"

using namespace std;
using namespace rf;
using namespace rf::data;

void Bitstream::sync()
{
	// リングバッファの場合のように、必ずしもstreambuf上のいちとbyte_posは同じにならない
	// return byte_pos_ == buf_->pubseekpos(byte_pos_);
	buf_->pubseekpos(byte_pos_);
}

Bitstream::Bitstream()
	: size_(0), bit_pos_(0), byte_pos_(0)
{
	// とりあえずただのバッファ
	buf_ = std::make_unique<std::stringbuf>();

}

// このBitstreamの現在サイズ
integer Bitstream::size() const
{
	return size_;
}

// 読み取りヘッダのビット位置
integer Bitstream::bit_pos() const
{
	return bit_pos_;
}

// 読み取りヘッダのバイト位置
integer Bitstream::byte_pos() const
{
	return byte_pos_;
}

// 読み込み対象のstreambufを設定する
// サイズの扱いをもっとねらないとだめだかなぁ
//template<typename Deleter>
void  Bitstream::assign(std::unique_ptr<std::streambuf>&& buf, integer size)
{
	buf_ = std::move(buf);
	byte_pos_ = 0;
	bit_pos_ = 0;
	size_ = size;
	sync();
}

// ストリーム内か判定
bool  Bitstream::check_pos(integer byte, integer bit) const
{
	integer byte_by_bit = (bit < 0 ? ((bit - 7) / 8) : (bit / 8));

	if ((byte + byte_by_bit < 0) || (size_ < byte + byte_by_bit))
		return false;
	return true;
}

// ビット単位で現在位置＋offsetがストリーム内か判定
bool  Bitstream::check_off(integer byte, integer bit) const
{
	// * -1 ~ 1 は割り算すると0なのでマイナスの場合は1オフセットする
	// * size==byteのときだけbit>0がNG
	// * byte単位->bit単位に変換すると値がintのbit数を超える場合がある。
	// とかあるのでbyte単位でオフセット後に、bit単位でオフセットするときの範囲をチェックする
	// シンプルな式が思いつかん
	integer bit_off = bit_pos_ + bit;
	integer byte_off_by_bit = (bit_off < 0 ? ((bit_off - 7) / 8) : (bit_off / 8));
	integer byte_pos = byte_pos_ + byte + byte_off_by_bit;
	if ((byte_pos < 0) || (size_ < byte_pos))
		return false;
	return true;
}

// 読み込みヘッダを指定位置に移動
// せっかくなのでマイナス指定や8bit以上の許可
void  Bitstream::seekpos(integer byte, integer bit)
{
	if (FAIL(check_pos(byte, bit)))
	{
		ERR << "byte=" << hex << byte << " bit=" << bit << " " << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	integer byte_by_bit = (bit < 0 ? ((bit - 7) / 8) : (bit / 8));

	byte_pos_ = byte + byte_by_bit;
	bit_pos_ = bit&0x7;
	sync();
}

// 読み込みヘッダを現在位置からオフセット
void  Bitstream::seekoff(integer byte, integer bit)
{
	if (FAIL(check_off(byte, bit)))
	{
		ERR << hex << "byte=" << byte << ", bit=" << bit << " " << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	integer bit_off = bit_pos_ + bit;
	integer byte_off_by_bit = (bit_off < 0 ? ((bit_off - 7) / 8) : (bit_off / 8));
	
	byte_pos_ = byte_pos_ + byte + byte_off_by_bit;
	bit_pos_ = bit_off & 0x7;
	sync();
}


// ビット単位で読み込み
uinteger Bitstream::read_bits(integer size)
{
	if (FAIL(0 <= size && size <= static_cast<integer>(sizeof(uinteger) * 8)))
	{
		ERR << "read bit range error. size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR(" range error."));
	}

	if (FAIL(check_off(0, size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR(" range error."));
	}

	uinteger value;
	integer already_read = 0;

	// 先頭の中途半端なビットを読んでから、残りをバイトストリームとして読む
	// read_lengthが現在のバイトに収まるならビット読み出しまでで終了
	if (bit_pos_ + size < 8)
	{
		value = static_cast<uinteger>(buf_->sgetc());
		value >>= 8 - (bit_pos_ + size); // 下位ビットを合わせる
		value &= ((1 << size) - 1); // 上位ビットを捨てる
		seekoff(0, size);
		return value;
	}
	else
	{
		integer remained_bit = 8 - bit_pos_;
		value = buf_->sbumpc() & ((1 << remained_bit) - 1);
		seekoff(0, remained_bit);
		already_read += remained_bit;
	}

	while (size > already_read)
	{
		if (size - already_read < 8)
		{
			value <<= (size - already_read);
			value |= buf_->sgetc() >> (8 - (size - already_read));
			seekoff(0, size - already_read);
			break;
		}
		else
		{
			value <<= 8;
			value |= buf_->sbumpc();
			seekoff(1, 0);
			already_read += 8;
		}
	}

	return value;
}

// バイト単位で読み込み
uinteger Bitstream::read_bytes(integer size)
{
	if (FAIL(0 <= size && size <= static_cast<integer>(sizeof(uinteger))))
	{
		ERR << "read byte > 4. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range."));
	}

	if (FAIL(check_off(size, 0)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	if (FAIL(bit_pos_ == 0))
	{
		WARNING << "bit_pos_ is not aligned. bit_pos_=" << hex << bit_pos_ << " " << OUTPUT_POS << endl;
	}

	return read_bits(size * 8);
}

// 指数ゴロムとしてビット単位で読み込み
void  Bitstream::read_expgolomb(uinteger &ret_value, integer &ret_size)
{
	integer count;
	for (count = 0; count < sizeof(uinteger) * 8; count++)
	{
		if (read_bits(1) == 1LL)
			break;
	}

	if (count >= sizeof(uinteger) * 8)
	{
		ERR << "exp-golomb count=" << hex << count << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("exp-golomb range error."));
	}

	ret_value = (1ULL << count) + read_bits(count) - 1ULL;
	ret_size = 2 * count + 1;
	return;
}

// 文字列として読み込み
// NULL文字が先に見つかった場合はその分だけ文字列にするがポインタは進む
// NULL文字が見つからなかった場合は最大max_lengthの長さ文字列として終端にNULL文字を入れる
string Bitstream::read_string(integer size)
{
	if (FAIL(0 <= size))
	{
		ERR << "minus read string. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range."));
	}

	if (FAIL(check_off(size, 0)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	if (FAIL(bit_pos_ == 0))
	{
		WARNING << "bit_pos_ is not aligned. bit_pos_=" << hex << bit_pos_ << " " << OUTPUT_POS << endl;
	}

#if 1
	integer offset = 0;
	int c;
	std::stringstream ss;
	for (; offset < size; ++offset)
	{
		c = buf_->sbumpc();
		if (static_cast<char>(c) == '\0')
		{
			break;
		}
		else if (c == EOF)
		{
			break;
		}
		// 終端文字はコピーしない
		// \0も文字列長に含まれる（よう）なので
		ss << static_cast<char>(c);
	}

	seekoff(size, 0);
	return ss.str();
#else
	auto pa = std::make_unique<char[]>(size);
	buf_->sgetn(pa.get(), size);
	seekoff_byte(size);
	return pa.get();
#endif
}

// ビット単位で先読み
uinteger Bitstream::look_bits(integer size)
{
	if (FAIL(0 <= size && size <= static_cast<integer>(sizeof(uinteger) * 8)))
	{
		ERR << "bit size range error. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range"));
	}

	if (FAIL(check_off(0, size)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	uinteger val = read_bits(size);
	seekoff(0, -size);
	return val;
}

// バイト単位で先読み
uinteger Bitstream::look_bytes(integer size)
{
	if (FAIL(0 <= size && size <= static_cast<integer>(sizeof(uinteger))))
	{
		ERR << "look byte size > 4. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range"));
	}

	if (FAIL(check_off(size, 0)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	if (FAIL(bit_pos_ == 0))
	{
		WARNING << "bit_pos_ is not aligned. bit_pos_=" << hex << bit_pos_ << " " << OUTPUT_POS << endl;
	}

	uinteger val = read_bytes(size);
	seekoff(-size, 0);
	return val;
}

// 指数ゴロムで先読み
void  Bitstream::look_expgolomb(uinteger &ret_val, integer &ret_size)
{
	integer prev_byte = byte_pos_;
	integer prev_bit = bit_pos_;
	read_expgolomb(ret_val, ret_size);
	seekpos(prev_byte, prev_bit);
}

// 指定バッファの分だけ先読み
void  Bitstream::look_byte_string(char* address, integer size)
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

	if (FAIL(check_off(size, 0)))
	{
		ERR << "size=" << hex << size << OUTPUT_POS << endl;
		throw std::runtime_error(FAIL_STR("range error."));
	}

	buf_->sgetn(address, size);
	sync();
}

// 特定の１バイトの値を検索
// 見つからなければファイル終端を返す
integer Bitstream::find_byte(char sc, integer end_offset, bool advance)
{
	if (FAIL(end_offset >= 0))
		throw std::invalid_argument(FAIL_STR("range error."));


	integer offset = 0;
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
		seekoff(offset, 0);
	else
		sync();
	return offset;
}

integer Bitstream::rfind_byte(char sc, integer end_offset, bool advance)
{
	if (FAIL(end_offset <= 0))
		throw std::invalid_argument(FAIL_STR("range error."));

	integer offset = 0;
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
		seekoff(offset, 0);
	else
		sync();
	return offset;
}

// 特定のバイト列を検索
// 見つからなければファイル終端を返す
// 見つかったかの判定をend_offset==retvalで行いたいので、とりあえずend_offsetはバイト列の先頭位置として、
// バイト列の後半がend_offsetを超えて比較することにした。
integer Bitstream::find_byte_string(
	const char* address, integer size, integer end_offset, bool advance)
{
	if (FAIL(end_offset >= 0))
		throw std::invalid_argument(FAIL_STR("range error."));

	if (FAIL(valid_ptr(address)))
	{
		ERR << "invalid address address=" << hex << address << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("invalid argument"));
	}

	//char* contents = new char[size];
	char contents[256];
	if (FAIL(sizeof(contents) >= static_cast<size_t>(size)))
	{
		ERR << "too long search string. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("too long byte string"));
	}


	integer offset = 0;
	integer end_offset_remain = end_offset;
	integer prev_byte_pos = byte_pos_;
	for (;;)
	{
		// 先頭1バイトを検索
		offset = find_byte(address[0], end_offset_remain, true);

		// 見つからなかった
		if (offset >= end_offset_remain)
		{
			if (!advance)
				seekpos(prev_byte_pos, 0);
			return end_offset;
		}

		// EOSをはみ出す場合
		// バイト列終端含めてend_offsetとするなら、if (!check_off(size, 0))をif (!check_off(size+end_offset, 0))とする
		if (!check_off(size, 0))
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
			integer total_offset = byte_pos_ - prev_byte_pos;
			if (!advance)
				seekpos(prev_byte_pos, 0);
			return total_offset;
		}
		else
		{
			seekoff(1, 0);
			--end_offset_remain;
		}
	}
}

// 特定のバイト列を検索
// 見つからなければファイル終端を返す
integer Bitstream::rfind_byte_string(
	const char* address, integer size, integer end_offset, bool advance)
{
	if (FAIL(end_offset <= 0))
		throw std::invalid_argument(FAIL_STR("range error."));

	if (FAIL(valid_ptr(address)))
	{
		ERR << "invalid address address=" << hex << address << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("invalid argument"));
	}

	//char* contents = new char[size];f
	char contents[256];
	if (FAIL(sizeof(contents) >= static_cast<size_t>(size)))
	{
		ERR << "too long search string. size=" << hex << size << OUTPUT_POS << endl;
		throw std::logic_error(FAIL_STR("out of range"));
	}

	integer offset = 0;
	integer end_offset_remain = end_offset;
	integer prev_byte_pos = byte_pos_;

	// EOSをはみ出す場合は位置バイト進めてから検索検索再開
	if (!check_off(size, 0))
	{
		if (!check_pos(size_ - size, 0))
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
		offset = rfind_byte(address[0], end_offset_remain, true);
		if (offset <= end_offset_remain)
		{
			if (!advance)
				seekpos(prev_byte_pos, 0);
			return end_offset;
		}

		// 先頭をはみ出す場合
		if (!check_off(-1, 0))
		{
			if (!advance)
				seekpos(prev_byte_pos, 0);
			else
				seekpos(0, 0);
			return 0 - prev_byte_pos;
		}

		end_offset_remain -= offset;

		// 一致
		// 不一致は1バイト進める
		look_byte_string(contents, size);
		if (std::memcmp(contents, address, static_cast<size_t>(size)) == 0)
		{
			integer total_offset = byte_pos_ - prev_byte_pos;
			if (!advance)
				seekpos(prev_byte_pos, 0);
			return total_offset;
		}
		else
		{
			seekoff(-1, 0);
			++end_offset_remain;
		}
	}
}

// ストリームにデータを書く
// 辻褄を合わせるためにサイズを計算する
void  Bitstream::write(const char *buf, integer size)
{
	if (FAIL(size >= 0))
		throw std::logic_error(FAIL_STR("size error."));

	size_ = std::max(byte_pos_ + size, size_);
	if (FAIL(buf_->sputn(buf, size) == size))
		throw std::runtime_error(FAIL_STR("file write(sputn) error."));
	
	seekpos(byte_pos_+size, bit_pos_);
}

// ストリームに１バイト追記する
void  Bitstream::put_char(char c)
{
	size_ = std::max(byte_pos_ + 1, size_);
	if (FAIL(buf_->sputc(c) == c))
		throw std::runtime_error(FAIL_STR("file write(sputc) error."));

	seekpos(byte_pos_+1, bit_pos_);
}

RingBuf::RingBuf()
	: std::streambuf(), size_(0)
{
}

// オーバーライド
int RingBuf::overflow(int c)
{
	setp(buf_.get(), buf_.get() + size_);
	return sputc(static_cast<char>(c));
}

// リングバッファのサイズを指定する
void RingBuf::reserve(integer size)
{
	if (FAIL(0 <= size))
	{
		ERR << "buf size error. size=" << hex << size << endl;
		throw std::logic_error(FAIL_STR("out of range"));
	}

	buf_ = std::unique_ptr<char[]>(new char[static_cast<int>(size)]); //, std::default_delete<char[]>() );
	size_ = size;
	setp(buf_.get(), buf_.get() + size);
	setg(buf_.get(), buf_.get(), buf_.get() + size);
}

// オーバーライド
int RingBuf::underflow()
{
	setg(buf_.get(), buf_.get(), buf_.get() + size_);
	return buf_[0];
}

// オーバーライド
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

// オーバーライド
std::ios::pos_type RingBuf::seekpos(
	std::ios::pos_type pos, std::ios::openmode which)
{
	return seekoff(pos, std::ios::beg, which);
}

