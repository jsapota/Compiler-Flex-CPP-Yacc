#ifndef COMMON_HPP
#define COMMON_HPP

#include <iostream>
#include <stdio.h>
#include <cstdlib>
#include <stdint.h> /* intX_t */
#include <cstring> /* SSE */
#include <string> /* string */


#define SWAP(a, b) \
    do{ \
        typeof(a) __temp = b; \
        a = b; \
        b = __temp; \
    }while(0)


#endif
