#ifndef INCLUDED_die_h
#define INCLUDED_die_h

#include <stdarg.h>

extern void die(int excode, char *f, ...) __attribute__((__noreturn__));
extern void vdie(int excode, char *f, va_list v) __attribute__((__noreturn__));
extern void pdie(int excode, char *msg) __attribute__((__noreturn__));

#endif
