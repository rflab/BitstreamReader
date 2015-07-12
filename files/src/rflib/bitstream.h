#ifndef _RF_BITSTREAM_
#define _RF_BITSTREAM_

#include "bighead.h"

namespace rf{

	class Bitstream final
	{
	private:
		unique_ptr<std::streambuf> buf_;
		int size_;
		int bit_pos_;
		int byte_pos_;
	protected:
		void sync();
	public:
		Bitstream();
		int size() const;
		int bit_pos() const;
		int byte_pos() const;
		void assign(std::unique_ptr<std::streambuf>&& buf, int size);
		bool check_pos(int byte_pos) const;
		bool check_offset_bit(int offset) const;
		bool check_offset_byte(int offset) const;
		void seekpos(int byte, int bit);
		void seekoff_bit(int offset);
		void seekoff_byte(int offset);
		unsigned int read_bit(int size);
		unsigned int read_byte(int size);
		void read_expgolomb(unsigned int &ret_value, int &ret_size);
		string read_string(int size);
		unsigned int look_bit(int size);
		unsigned int look_byte(int size);
		void look_expgolomb(unsigned int &ret_val, int &ret_size);
		void look_byte_string(char* address, int size);
		int find_byte(char sc, bool advance, int end_offset = INT_MAX);
		int rfind_byte(char sc, bool advance, int end_offset = INT_MIN);
		int find_byte_string(const char* address, int size, bool advance, int end_offset = INT_MAX);
		int rfind_byte_string(const char* address, int size, bool advance, int end_offset = INT_MIN);
		void write(const char *buf, int size);
		void put_char(char c);
	};

	class RingBuf final : public std::streambuf
	{
	private:
		std::unique_ptr<char[]> buf_;
		int size_;
	protected:
		int overflow(int c) override;
		int underflow() override;
		std::ios::pos_type seekoff(std::ios::off_type off, std::ios::seekdir way, std::ios::openmode) override;
		std::ios::pos_type seekpos(std::ios::pos_type pos, std::ios::openmode which) override;
	public:
		RingBuf();
		void reserve(int size);
	};
}

#endif

