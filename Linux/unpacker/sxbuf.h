#ifndef INCLUDED_sxbuf_h
#define INCLUDED_sxbuf_h

#include <stdio.h> /* fprintf, stderr */
#include <stdlib.h> /* size_t */
//#include <stdint.h>
//#include <math.h>
//#include <stdarg.h>

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

typedef struct sxbuf {
    char *cur;
    char *start;
    char *end;
    _Bool bufalloc;
    _Bool selfalloc;
} SX[1];

EXTERN inline void sxinit(SX b) ;
SCOPE  inline void sxinit(SX b) {
    size_t new_size = 0;
    char * np = malloc(new_size);
    if (!np && new_size)
        die(2, "malloc(%zu) failed", new_size);
    b->cur = b->start = b->end = np;
    if (np) {
        //if (new_size > 0) b->cur[0] = 0;
        b->end = (char*) np + new_size;
    }
    b->bufalloc = 1;
    b->selfalloc = 0;
}

# if 0
EXTERN inline struct sxbuf sxnew(void) ;
SCOPE  inline struct sxbuf sxnew(void) {
    struct sxbuf *b = malloc(sizeof *b);
    if (!b)
        die(2, "malloc(%zu) failed", sizeof *b);
    sxinit(b);
    b->selfalloc = 1;
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
    if (b->bufalloc)
        free(b->start);
    b->start = b->cur = b->end = NULL;
    if (b->selfalloc)
        free(b);
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
    //free(b->start);
    b->start = b->end = b->cur = NULL;
    sxdestroy(b);
    return ret;
}

EXTERN inline void sxresize(SX b, size_t make_room_for) ;
SCOPE  inline void sxresize(SX b, size_t make_room_for) {
    if (!b->bufalloc)
        die(88, "sxresize: external buffer overflowed");
    /* round request up to a power of 2, capped at 16MiB */
    size_t off      = b->start ? b->cur - b->start : 0;
    size_t old_size = b->start ? b->end - b->start : 0;
    size_t requested_size = off + make_room_for;
    size_t new_size = 1 << log2ceil(requested_size + 1, 23);
    if (0)
        fprintf(stderr, "sxresize: round up request from %zu to %zu\n", requested_size, new_size);
    void * np = realloc(b->start, new_size);
    if (!np)
        die(88, "sxresize: realloc(%zu) failed within sxresize", new_size);
    if (0 && np != b->start)
        fprintf(stderr, "realloc moved block from %p (%zu bytes) to %p (%zu bytes)\n", b->start, old_size, np, new_size);
    b->cur = (char*) np + off;
    b->start = np;
    b->end = (char*) np + new_size;
}

////////////////////////////////////////

EXTERN inline void sxprintf(SX b, char const *fmt, ...) ;
SCOPE  inline void sxprintf(SX b, char const *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    if (0) {
        fprintf(stderr,
                "SX: BEGIN   b=%p [ cur=%p start=%p end=%p bufalloc=%d selfalloc=%d ], fmt=%p, args... [",
                (void*) b, b->cur, b->start, b->end, b->bufalloc, b->selfalloc, fmt);
        va_list aq;
        va_copy(aq, ap);
        ssize_t n = vfprintf(stderr, fmt, aq);
        va_end(aq);
        fprintf(stderr, "] (output=%zd)\n", n);
    }
    _Bool once = 0;
    for(;;) {
        size_t avail = b->cur == NULL ? 0 : b->end-b->cur;
        va_list aq;
        va_copy(aq, ap);
        ssize_t output_size = vsnprintf(b->cur, avail, fmt, aq);
        va_end(aq);
        if (output_size < 0)
            pdie(88, "sxprintf: vsnprint failed");
        if (output_size < avail) {
            b->cur += output_size;
            break;
        }
        if (once++)
            die(88, "resizing more than once!!");
        sxresize(b, output_size);
    }
    {
    if (0)
        fprintf(stderr, "SX: RESULT b=%p [ cur=%p start=%p end=%p bufalloc=%d selfalloc=%d ]\n",
                (void*) b, b->cur, b->start, b->end, b->bufalloc, b->selfalloc);
    }
    va_end(ap);
}

#undef EXTERN
#undef SCOPE

#endif
