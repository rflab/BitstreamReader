#ifndef __RF_BIGHEAD__
#define __RF_BIGHEAD__

#include <stdint.h>
#include <iostream>
#include <iomanip>
#include <vector>
#include <array>
#include <map>
#include <memory>
#include <utility>
#include <sstream>
#include <fstream>
#include <algorithm>
#include <regex>
#include <cctype>
#include <cstring>

#if defined(_MSC_VER) && (_MSC_VER >= 1800)
#elif defined(__GNUC__) && __cplusplus >= 201300L // __GNUC_PREREQ(4, 9)
#define throw(x)
#else
// unsupported
#define nullptr NULL
#define final
#define throw(x)
#endif

#define FAIL(...) ::rf::fail((__VA_ARGS__), __LINE__, __FUNCTION__, #__VA_ARGS__)
#define ERR cerr << "# c++ error. L" << std::dec << __LINE__ << " " << __FUNCTION__ << ": "
#define WARNING cerr << "# c++ warning. L" << std::dec << __LINE__ << " " << __FUNCTION__ << ": "
#define FAIL_STR(msg) fail_msg(__LINE__, __FUNCTION__, msg)
#define OUTPUT_POS "at 0x" << hex << byte_pos() <<  "(+" << bit_pos() << ')'

namespace rf
{
	using std::vector;
	using std::array;
	using std::map;
	using std::string;
	using std::unique_ptr;
	using std::stringstream;
	using std::ofstream;
	using std::exception;
	using std::logic_error;
	using std::runtime_error;
	using std::to_string;
	using std::make_unique;
	using std::cout;
	using std::cin;
	using std::cerr;
	using std::endl;
	using std::hex;
	using std::dec;

	bool fail(bool b, int line, const std::string &fn, const std::string &exp);
	std::string fail_msg(int line, const std::string &fn, const std::string& msg);
	bool valid_ptr(const void *p);
	uint16_t reverse_endian_16(uint16_t value);
	uint32_t reverse_endian_32(uint32_t value);
	void dump_bytes(const char* buf, int offset, int size);
	void dump_string(const char* buf, int offset, int size);
	void dump(const char* buf, int offset, int size, int original_address);
}

#endif
