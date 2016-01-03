#ifndef __RF_PCH__
#define __RF_PCH__

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
#include <climits>

#if defined(_MSC_VER) && (_MSC_VER >= 1800)
#elif defined(__GNUC__) && __cplusplus >= 201300L // __GNUC_PREREQ(4, 9)
#define throw(x)
#else
// unsupported
#define nullptr NULL
#define final
#define throw(x)
#endif

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
}

#endif
