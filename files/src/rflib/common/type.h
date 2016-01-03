#ifndef __RF_TYPE__
#define __RF_TYPE__

#include <limits.h>

namespace rf
{
	#ifdef _WIN64
		using integer = long long;
		using uinteger = unsigned long long;
		static const integer integer_max = LLONG_MAX;
	#else
		using integer = int;
		using uinteger = unsigned int;
		static const integer integer_max = INT_MAX;
	#endif
}

#endif
