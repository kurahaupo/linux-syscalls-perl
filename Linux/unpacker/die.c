#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <errno.h>
#include <signal.h>
#include <string.h>

#include <stdarg.h>

#include "die.h"

////////////////////////////////////////////////////////////////////////////////

void vdie(int excode, char *f, va_list v)
{
    if (excode < 0)
        excode = errno != 0;
    vfprintf(stderr, f, v);
    fputc('\n', stderr);
    if (excode < 0) {
        // kill self with signal instead of exiting
        fflush(NULL);
        raise(-excode);
        abort();
    }
    exit(excode);
}

void die(int excode, char *f, ...)
{
    va_list v;
    va_start(v, f);
    vdie(excode, f, v);
}

void pdie(int excode, char *msg)
{
    die(excode, "%s: %s\n", msg, strerror(errno));
}
