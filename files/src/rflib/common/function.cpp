#include "pch.h"
#include "function.h"

bool rf::fail(bool b, int line, const std::string &fn, const std::string &exp)
{
	if (!b)
		std::cerr << "# c++ L." << std::dec
		<< line << " " << fn << ": failed [ " << exp << " ]" << std::endl;
	return !b;
}

std::string rf::fail_msg(int line, const std::string &fn, const std::string& msg)
{
	std::stringstream ss;
	ss << "# c++ L." << std::dec
		<< line << " " << fn << " failed. [" << msg << "]" << std::endl;
	return ss.str();
}

bool rf::valid_ptr(const void *p)
{
	return p != nullptr;
}

uint16_t rf::reverse_endian_16(uint16_t value)
{
	return ((value >> 8) & 0xff) | ((value << 8) & 0xff00);
}

uint32_t rf::reverse_endian_32(uint32_t value)
{
	return ((value >> 24) & 0xff) | ((value >> 8) & 0xff00)
		| ((value << 8) & 0xff0000) | ((value << 24) & 0xff000000);
}
	
// 指定アドレスをバイト列でダンプ
void rf::dump_bytes(const char* buf, integer offset, integer size)
{
	uint8_t c;
	for (integer i = 0; i < size; ++i)
	{
		c = buf[offset + i];
		printf("%02x ", (c));
	}
}

// 指定アドレスを文字列でダンプ
void rf::dump_string(const char* buf, integer offset, integer size)
{
	uint8_t c;
	for (integer i = 0; i < size; ++i)
	{
		c = buf[offset + i];
		if (isgraph(c))
			putchar(c);
		else
			putchar('.');
	}
}

// 指定アドレスをダンプ
void rf::dump(const char* buf, integer offset, integer size, integer original_address)
{
	// ヘッダ表示
	printf(
		"       offset    "
		"| +0 +1 +2 +3 +4 +5 +6 +7 +8 +9 +A +B +C +D +E +F "
		"| 0123456789ABCDE\n");

	// データ表示
	integer padding = original_address & 0xfLLU;
	integer write_lines = (size + padding + 15) / 16;
	integer byte_print_pos = 0;
	integer str_print_pos = 0;
	integer byte_pos = 0;
	integer str_pos = 0;
	uint8_t c;
	for (integer cur_line = 0; cur_line < write_lines; ++cur_line)
	{
		// アドレス
		printf("     0x%010llx| ", 
			static_cast<unsigned long long>((original_address + byte_pos) & (~0xfLLU)));

		// バイナリ
		for (int i = 0; i < 16; ++i)
		{
			if ((byte_print_pos < padding)
			|| (byte_print_pos >= size + offset + padding))
			{
				printf("   ");
			}
			else
			{
				c = buf[offset + byte_pos];
				printf("%02x ", c);
				++byte_pos;
			}

			++byte_print_pos;
		}

		printf("| ");

		// キャラクタ
		for (int i = 0; i < 16; ++i)
		{
			if ((str_print_pos < padding)
			||  (str_print_pos >= size + offset + padding))
			{
				printf(" ");
			}
			else
			{
				c = buf[offset + str_pos];
				if (isgraph(c))
					putchar(c);
				else
					putchar('.');
				++str_pos;
			}

			++str_print_pos;
		}

		putchar('\n');
	}
}

	