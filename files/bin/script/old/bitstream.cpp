
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

// �ݒ肵���o�b�t�@����r�b�g�P�ʂŃf�[�^��ǂݏo��
// �r�b�O�G���f�B�A���Œ�
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

		// �擪�̒��r���[�ȃr�b�g��ǂ�ł���A�c����o�C�g�X�g���[���Ƃ��ēǂ�
		// read_length�����݂̃o�C�g�Ɏ��܂�Ȃ�r�b�g�ǂݏo���܂łŏI��
		if (cur_bit_ + read_length < 8)
		{
			*ret_value = buf_[cur_byte_];
			*ret_value >>= 8 - (cur_bit_ + read_length); // ���ʃr�b�g�����킹��
			*ret_value &= ((1 << read_length) - 1); // ��ʃr�b�g���̂Ă�
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
