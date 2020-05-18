#ifndef INCLUDED_perl_unpack_h
#define INCLUDED_perl_unpack_h

#include <stdio.h> /* sprintf */

#include "log2ceil.h"
#include "die.h"

#ifdef no_inline_perl_unpack
#undef no_inline_perl_unpack
#define SCOPE
#define EXTERN extern
#else
#define SCOPE static
#define EXTERN static
#endif

// perl_unpack_fmt - show Perl's "unpack" formatter

EXTERN inline char const * perl_unpack_fmt(int sz, int pad, int *countp) __attribute__((always_inline)) ;
SCOPE  inline char const * perl_unpack_fmt(int sz, int pad, int *countp) {
    static char b[10];
    char *p = b;

    if (countp) *countp = sz;
    if (sz == 0)
        return "";

    char const cv[4] = "CSLQ";
    char cc;
    if (pad || sz < 0)
        if (sz < 0)
            cc = 'X', sz = -sz;
        else
            cc = 'x';
    else {
        int scale = log2ceil(sz, sizeof cv-1);
        sz >>= scale;
        if (countp) *countp = sz;
        cc = cv[scale];
    }
    *p++ = cc;
    if (sz > 1)
        p += sprintf(p, "%d", sz);
    *p++ = 0;
    if (p < &b[0] || p >= &b[sizeof b / sizeof b[0]])
        die(99, "sprintf buffer overflow");
    return b;
}

#undef EXTERN
#undef SCOPE

#endif
