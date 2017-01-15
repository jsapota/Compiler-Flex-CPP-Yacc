#ifndef COMMON_HPP
#define COMMON_HPP

#include <iostream>
#include <stdio.h>
#include <cstdlib>
#include <stdint.h> /* intX_t */
#include <cstring> /* SSE */
#include <string> /* string */
#include <cln/integer.h>

#define GET_BIT(n , k)      (((n) & (1ull << k)) >> k )
#define GET_BIGBIT(n, k)    ((cln :: oddp(n >> k)))
#define MAX(a,b) ((a) > (b) ? (a) : (b))



#endif
