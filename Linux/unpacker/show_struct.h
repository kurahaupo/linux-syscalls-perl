#ifndef DEFINED_show_struct_h
#define DEFINED_show_struct_h

#include <string.h> /* strlen */

#include "perl_unpack.h"
#include "sxbuf.h"

#ifdef no_inline_show_struct
#undef no_inline_show_struct
#define SCOPE
#define EXTERN extern
#else
#define SCOPE static
#define EXTERN static
#endif

typedef struct tracking {
    void *example_record;
    size_t struct_size;
    char const *struct_name;
    char const *strip_prefix;
    char const *compile_options;
    size_t prev_off;
    SX packfmt;
    SX fieldnames;
} TK;

typedef enum fmode {
    FM_unsigned,
    FM_signed,
    FM_struct_timeval,
    FM_struct_timespec,
    FM_float,
    FM_blob,
    FM_char_array = FM_blob,
    FM_pointer,
} FMode;

EXTERN inline void StartStruct(TK *tr, void *example_record, size_t struct_size, char const *struct_name, char const *strip_prefix, char const *compile_options) ;
SCOPE  inline void StartStruct(TK *tr, void *example_record, size_t struct_size, char const *struct_name, char const *strip_prefix, char const *compile_options) {
    printf("%6zu %s {\n", struct_size, struct_name);
    tr->example_record = example_record;
    tr->struct_size = struct_size;
    tr->struct_name = struct_name;
    tr->strip_prefix = strip_prefix;
    tr->compile_options = compile_options;
    tr->prev_off = 0;
    sxinit(tr->packfmt);
    sxinit(tr->fieldnames);
}

EXTERN inline void Field(TK *tr, size_t off, size_t sz, FMode mode, char const *name, char const * extra) ;
SCOPE  inline void Field(TK *tr, size_t off, size_t sz, FMode mode, char const *name, char const * extra) {
    if (off != tr->prev_off) {
        int d = (int)off-(int)tr->prev_off;
        char const * pfmt = perl_unpack_fmt(d, 1, NULL);
        printf("   %+3d   %s\n", d, pfmt);
        sxprintf(tr->packfmt, "%s", pfmt);
    }
    tr->prev_off = off+sz;
    int count;
    char const * pfmt = perl_unpack_fmt(sz, 0, &count);
    printf("%3zu %2zu   %-6s  %s%s\n", off, sz, pfmt, name, extra);
    sxprintf(tr->packfmt, "%s", pfmt);

    if ( tr->strip_prefix ) {
        char const *p = tr->strip_prefix;
        size_t l = strlen(p);
        if ( !memcmp(name,p,l) )
            name += l;
    }

    if (count == 2 && !strncmp(name+1, "tim", 3))
        /* atime, mtime, ctime, & variants */
        sxprintf(tr->fieldnames, ",$%s.sec,$%s.nsec", name, name); /**/
    else if (count > 1) {
        int i;
        for (i = 1 ; i<= count ; ++i)
            sxprintf(tr->fieldnames, ",$%s_%d", name, i);
    }
    else
        sxprintf(tr->fieldnames, ",$%s", name);
}

EXTERN inline void EndStruct(TK *tr) ;
SCOPE  inline void EndStruct(TK *tr) {
    int diff = (int)tr->struct_size - (int)tr->prev_off;
    if (diff)
        printf("   %+3d\n", diff);
    printf("%6zu }\n", tr->struct_size);
    printf("PERL: my (%s) \t= unpack '%s', $in; \t# %zu bytes\t%s \t # %s\n",
            sxpeek(tr->fieldnames)+1,
            sxpeek(tr->packfmt),
            tr->struct_size,
            tr->struct_name,
            tr->compile_options);
    sxdestroy(tr->packfmt);
    sxdestroy(tr->fieldnames);
}

#undef EXTERN
#undef SCOPE

#endif
