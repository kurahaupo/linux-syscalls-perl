#ifndef INCLUDED_sxbuf_h
#define INCLUDED_sxbuf_h

#include <memory.h> /* memcpy */
#include <stdbool.h>
#include <stdio.h> /* fprintf, stderr */
#include <stdlib.h> /* size_t */
//#include <math.h>
//#include <stdarg.h>
//#include <stdint.h>

#include "die.h"
#include "log2ceil.h"

#ifdef no_inline_sxbuf
#undef no_inline_sxbuf
#define SCOPE
#define EXTERN extern
#else
#define SCOPE static
#define EXTERN static
#endif

#define sxDebug 0

#ifndef sxDebug
int sxDebug = 1;
#endif

typedef struct sxbuf {
    char *start;
    char *cur;
    char *end;
    _Bool bufalloc;
    _Bool selfalloc;
} SX[1], *SXP;

EXTERN inline void sxinit(SX b) ;
SCOPE  inline void sxinit(SX b) {
    static SX empty;
    *b = *empty;
    return;

    size_t new_size = 0;
    char * np = malloc(new_size);
    if (!np && new_size)
        die(2, "malloc(%zu) failed", new_size);
    b->cur = b->start = b->end = np;
    if (np) {
        //if (new_size > 0) b->cur[0] = 0;
        b->end = (char*) np + new_size;
    }
    b->bufalloc = true;
    b->selfalloc = false;
}

EXTERN inline SXP sxnew(void) ;
SCOPE  inline SXP sxnew(void) {
    SXP b = malloc(sizeof(SX));
    sxinit(b);
    b->selfalloc = true;
    return b;
}

# if 0
EXTERN inline struct sxbuf sxnew(void) ;
SCOPE  inline struct sxbuf sxnew(void) {
    struct sxbuf *b = malloc(sizeof *b);
    if (!b)
        die(2, "malloc(%zu) failed", sizeof *b);
    sxinit(b);
    b->selfalloc = true;
}
# endif

EXTERN inline void sxreset(SX b) ;
SCOPE  inline void sxreset(SX b) {
    b->cur = b->start;
    if (b->cur != b->end)
        b->cur[0] = 0;
}

EXTERN inline void sxdestroy(SX b) ;
SCOPE  inline void sxdestroy(SX b) {
    if (!b)
        return;
    if (b->bufalloc)
        free(b->start);
    b->start = b->cur = b->end = NULL;
    if (b->selfalloc)   /* from sxnew? */
        free(b);
}

EXTERN inline size_t sxcapacity(SX b) ;
SCOPE  inline size_t sxcapacity(SX b) {
    return b->end || b->start ? b->end - b->start : 0;    /* (NULL-NULL) yields 0 on all known architectures, but let's be 100% standards-compliant */
}

EXTERN inline size_t sxlength(SX b) ;
SCOPE  inline size_t sxlength(SX b) {
    return b->cur || b->start ? b->cur - b->start : 0;    /* (NULL-NULL) yields 0 on all known architectures, but let's be 100% standards-compliant */
}

EXTERN inline char const *sxpeek(SX b) ;
SCOPE  inline char const *sxpeek(SX b) {
    // Look at the internal buffer; this will be invalidated by the next sx
    // operation, so don't keep it too long.
    return b->start;
}

EXTERN inline char *sxfinal(SX b) ;
SCOPE  inline char *sxfinal(SX b) {
    // Return a mallocked "copy" of the string within b, and destroy b;
    // since it's already mallocked, this is very cheap.
    char *ret = b->start;
    b->start = b->end = b->cur = NULL;
    sxdestroy(b);
    return ret;
}

EXTERN inline void sxinfo(char const*step, char const*func, SX b) ;
SCOPE  inline void sxinfo(char const*step, char const*func, SX b) {
    fprintf(stderr, "%-7s %s: b=%p [start=%p, cur=%p, end=%p%s%s]",
            step, func,
            b,
            b->start, b->cur, b->end,
            b->bufalloc?",balloc":"",
            b->selfalloc?",salloc":"");
}

EXTERN inline void sxsetsize(SX b, size_t requested_size, bool force_alloc) ;
SCOPE  inline void sxsetsize(SX b, size_t requested_size, bool force_alloc) {
    if (sxDebug) {
        sxinfo("START:", __FUNCTION__, b);
        fprintf(stderr, ", req_sz=%zu\n", requested_size);
    }
    /* round request up to a power of 2, capped at 16MiB */
    size_t new_capacity = 1 << log2ceil(requested_size + 1, 23);
    if (sxDebug)
        fprintf(stderr, "        %s: round up request from %zu to %zu\n", __FUNCTION__, requested_size, new_capacity);
    size_t old_capacity = sxcapacity(b);
    if (old_capacity == new_capacity && !force_alloc)
        return;
    void * np = b->start;
    if (b->bufalloc) {
        np = realloc(b->start, new_capacity);
        if (!np)
            die(88, "realloc(%zu) failed within %s", new_capacity, __FUNCTION__);
    } else {
        if (new_capacity <= old_capacity && !force_alloc) {
            return;
        }
        /* make a copy */
        np = malloc(new_capacity);
        if (!np)
            die(88, "malloc(%zu) failed within %s", new_capacity, __FUNCTION__);
        size_t min_capacity = old_capacity < new_capacity
                            ? old_capacity : new_capacity;
        if (min_capacity)
            memcpy(np, b->start, min_capacity);
        b->bufalloc = true;
    }
    if (sxDebug)
        if (np != b->start) {
            sxinfo("", __FUNCTION__, b);
            fprintf(stderr, " moved block from %p (%zu bytes) to %p (%zu bytes)\n", b->start, old_capacity, np, new_capacity);
        }
    size_t length = sxlength(b);
    if (length > new_capacity)
        length = new_capacity;
    b->start = np;
    b->cur = (char*) np + length;
    b->end = (char*) np + new_capacity;
}

EXTERN inline void sxresize(SX b, ssize_t make_room_for, bool force_alloc) ;
SCOPE  inline void sxresize(SX b, ssize_t make_room_for, bool force_alloc) {
    /* round request up to a power of 2, capped at 16MiB */
    sxsetsize(b, sxlength(b) + make_room_for, force_alloc);
}

////////////////////////////////////////

EXTERN inline size_t sxprintf(SX b, char const *fmt, ...) ;
SCOPE  inline size_t sxprintf(SX b, char const *fmt, ...) {
    size_t result;
    va_list ap;
    va_start(ap, fmt);
    if (sxDebug) {
        sxinfo("BEGIN:", __FUNCTION__, b);
        fprintf(stderr, ", fmt=\"%s\", args... [", fmt);
        va_list aq;
        va_copy(aq, ap);
        ssize_t n = vfprintf(stderr, fmt, aq);
        va_end(aq);
        fprintf(stderr, "] (output=%zd)\n", n);
    }
    _Bool once = 0;
    for(;;) {
        size_t avail = sxcapacity(b) - sxlength(b);
        va_list aq;
        va_copy(aq, ap);
        ssize_t output_size = vsnprintf(b->cur, avail, fmt, aq);
        va_end(aq);
        if (output_size < 0)
            pdie(88, "FAIL:   sxprintf: vsnprint failed");
        if (output_size < avail) {
            result = output_size;
            b->cur += output_size;
            break;
        }
        if (once++)
            die(88, "FAIL:   sxprintf: resizing more than once!!");
        sxresize(b, output_size, false);
    }
    if (sxDebug) {
        sxinfo("RESULT:", __FUNCTION__, b);
        fputs("\n", stderr);
    }
    va_end(ap);
    return result;
}

#undef EXTERN
#undef SCOPE

#endif
