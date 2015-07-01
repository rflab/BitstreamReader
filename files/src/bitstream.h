#ifndef _RF_BITSTREAM__
#define _RF_BITSTREAM__

#include <string>
#include <memory>

#if defined(_MSC_VER) && (_MSC_VER >= 1800)
#elif defined(__GNUC__) && __cplusplus >= 201300L // __GNUC_PREREQ(4, 9)
#else
#endif

namespace rf
{
	using std::string;
	using std::unique_ptr;
	using std::streambuf;
	using std::ios;
	
	class Bitstream
	{
	public:
		
		Bitstream();

		bool assign(unique_ptr<streambuf>&& buf, int size);
		int size() const;
		int bit_pos() const;
		int byte_pos() const;
		
		bool write_byte_string(const char *buf, int size);
		bool put_char(char c);
		
		bool check_bit(int bit) const;
		bool check_byte(int byte) const;
		bool check_offset_bit(int offset) const;
		bool check_offset_byte(int offset) const;
		
		bool seekpos(int byte, int bit);
		bool seekpos_bit(int offset);
		bool seekpos_byte(int offset);
		bool seekoff(int byte, int bit);
		bool seekoff_bit(int offset);
		bool seekoff_byte(int offset);
		
		bool read_bit(int size, uint32_t &ret_value);
		bool read_byte(int size, uint32_t &ret_value);
		bool read_expgolomb(uint32_t &ret_value, int &ret_size);
		bool read_string(int max_length, string &ret_str);
		
		bool look_bit(int size, uint32_t &ret_val);
		bool look_byte(int size, uint32_t &ret_val);
		bool look_expgolomb(uint32_t &ret_val);
		bool look_byte_string(char* address, int size);
		
		bool find_byte(char sc, int &ret_offset, bool advance, int end_offset = INT_MAX);
		bool find_byte_string(const char* address, int size, int &ret_offset, bool advance, int end_offset = INT_MAX);

	public:
		
		class RingBuf final : public streambuf
		{
		public:
			RingBuf(explicit int size);
		private:
			unique_ptr<char[]> buf_;
			int size_;
			RingBuf();
			bool reserve(int size);
		protected:
			int overflow(int c) override;
			int underflow() override;
			ios::pos_type seekoff(ios::off_type off, ios::seekdir way, ios::openmode) override;
			ios::pos_type seekpos(ios::pos_type pos, ios::openmode which) override;
		};
			
	protected:

		bool sync();
		
	private:

		unique_ptr<streambuf> buf_;
		int size_;
		int bit_pos_;
		int byte_pos_;

	};
}

#endif
