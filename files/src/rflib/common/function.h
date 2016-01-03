#ifndef __RF_FUNCTION__
#define __RF_FUNCTION__

#include <iostream>
#include <stdio.h>
#include <string>
#include <stdint.h>
#include "type.h"

#define FAIL(...) ::rf::fail((__VA_ARGS__), __LINE__, __FUNCTION__, #__VA_ARGS__)
#define ERR std::cerr << "# c++ error. L" << std::dec << __LINE__ << " " << __FUNCTION__ << ": "
#define WARNING std::cerr << "# c++ warning. L" << std::dec << __LINE__ << " " << __FUNCTION__ << ": "
#define FAIL_STR(msg) fail_msg(__LINE__, __FUNCTION__, msg)
#define OUTPUT_POS "at 0x" << std::hex << byte_pos() <<  "(+" << bit_pos() << ')'

namespace rf
{
	bool        fail(bool b, int line, const std::string &fn, const std::string &exp);
	std::string fail_msg(int line, const std::string &fn, const std::string& msg);
	
	bool valid_ptr(const void *p);
	
	uint16_t reverse_endian_16(uint16_t value);
	uint32_t reverse_endian_32(uint32_t value);
	
	void dump_bytes(const char* buf, integer offset, integer size);
	void dump_string(const char* buf, integer offset, integer size);
	void dump(const char* buf, integer offset, integer size, integer original_address);
}

#endif
