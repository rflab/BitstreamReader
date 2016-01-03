#ifndef _RF_BITSTREAM_
#define _RF_BITSTREAM_

#include <memory>
#include <iostream>
#include <string>
#include "common/type.h"

namespace rf
{
	namespace data
	{
		using std::unique_ptr;
		using std::string;

		class Bitstream final
		{
		private:
			unique_ptr<std::streambuf> buf_;
			integer size_;
			integer bit_pos_;
			integer byte_pos_;

		protected:
			void sync();

		public:
			Bitstream();
			integer size() const;
			integer bit_pos() const;
			integer byte_pos() const;

			void assign(std::unique_ptr<std::streambuf>&& buf, integer size);
			bool check_pos(integer byte, integer bit) const;
			bool check_off(integer byte, integer bit) const;

			void seekpos(integer byte, integer bit);
			void seekoff(integer byte, integer bit);

			uinteger read_bits(integer size);
			uinteger read_bytes(integer size);
			void     read_expgolomb(uinteger &ret_value, integer &ret_size);
			string   read_string(integer size);
			
			uinteger look_bits(integer size);
			uinteger look_bytes(integer size);
			void     look_expgolomb(uinteger &ret_val, integer &ret_size);
			void     look_byte_string(char* address, integer size);
			
			integer find_byte        (char sc, integer end_offset, bool advance);
			integer rfind_byte       (char sc, integer end_offset, bool advance);
			integer find_byte_string (const char* address, integer size, integer end_offset, bool advance);
			integer rfind_byte_string(const char* address, integer size, integer end_offset, bool advance);
			
			void write(const char *buf, integer size);
			void put_char(char c);
		};

		class RingBuf final : public std::streambuf
		{
		private:
			std::unique_ptr<char[]> buf_;
			integer size_;

		protected:
			int overflow(int c) override;
			int underflow() override;

			std::ios::pos_type seekoff(std::ios::off_type off, std::ios::seekdir way, std::ios::openmode) override;
			std::ios::pos_type seekpos(std::ios::pos_type pos, std::ios::openmode which) override;

		public:
			RingBuf();
			void reserve(integer size);
		};
	}
}

#endif

