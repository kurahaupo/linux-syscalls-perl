#ifndef INCLUDED_log2ceil_h
#define INCLUDED_log2ceil_h

#include <math.h>   /* frexp */
#include <stdint.h> /* uintmax_t */

#ifdef no_inline_log2ceil_h
#undef no_inline_log2ceil_h
#define SCOPE
#define EXTERN extern
#else
#define SCOPE static
#define EXTERN static
#endif

EXTERN inline int log2ceil(uintmax_t x, int cap) ;
SCOPE  inline int log2ceil(uintmax_t x, int cap) {
    if (x<2) return 0;
    int i = __builtin_clzll((uintmax_t)1) - __builtin_clzll(x-1) + 1;
    return i > cap ? cap : i;

    frexp(x-1.0, &i);
    return i > cap ? cap : i;

    uintmax_t b=1;
    static int j = 0;
    for (i=0; !(b & x) && i!=cap && b ;++i, b<<=1 )
        ++j;
    return i;
}

#undef EXTERN
#undef SCOPE

#endif
