#ifndef DEFINED_show_struct_h
#define DEFINED_show_struct_h

#include <stdint.h>     /* the [u]int[n]_t types used as selectors for _Generic */
#include <string.h>     /* strlen */

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
    size_t prev_off;
    SX packfmt;
    SX fieldnames;
    size_t fnw;
    SX extra_perl;
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

EXTERN char const * Pbuildenv(char const * newline);

SCOPE  char const * Pbuildenv(char const * nl) {
    SX C;
    sxinit(C);

    if (!nl) nl = "\n";

#ifndef PENV_SKIP_ARCH
    sxprintf(C, "%sARCH: ", nl);
  #if defined __i386__
    sxprintf(C, "i386");
  #elif defined __x86_64__
    #if defined USE_x64
      sxprintf(C, "x86_64 (-m64)");
    #endif
    #if defined USE_x32
      sxprintf(C, "x86_32 (-mx32)");
    #endif
    #if defined USE_i32
      sxprintf(C, "i386 (-m32 but optimized for x86_64)");
    #endif
  #elif defined __mips__
      sxprintf(C, "mips");
  #else
    sxprintf(C, "(other; need to adjust detection in %s:%d)", __FILE__, __LINE__);
  #endif
#endif

#if defined PENV_WANT_STAT
    sxprintf(C, "%s", nl);
  #if defined _SYS_STAT_H
    sxprintf(C, ", using <sys/stat.h>");
  #else
    sxprintf(C, ", without <sys/stat.h>");
  #endif

  #if defined USE_ASM_STAT
    sxprintf(C, ", using <asm/stat.h>");
  #else
    sxprintf(C, ", without <asm/stat.h>");
  #endif
  #if defined _ASM_X86_STAT_H || defined _ASM_IA64_STAT_H \
    || defined _ALPHA_STAT_H || defined _ASM_M32R_STAT_H \
    || defined _ASM_POWERPC_STAT_H || defined _ASM_SCORE_STAT_H \
    || defined __ASM_SH_STAT_H || defined _ASM_STAT_H || defined __ASM_STAT_H \
    || defined _ASMARM_STAT_H || defined _CRIS_STAT_H || defined _M68K_STAT_H \
    || defined _PARISC_STAT_H || defined _S390_STAT_H \
    || defined __SPARC_STAT_H || defined _UAPI__ASM_AVR32_STAT_H \
    || defined _UAPI_BFIN_STAT_H || defined _XTENSA_STAT_H
    sxprintf(C, ", using <asm/stat.h> (%s)", getlink("/usr/include/asm"));
  #endif

  #if 0
    #if defined _BITS_STAT_H
      sxprintf(C, ", using <bits/stat.h>");
    #endif
  #endif
#endif

#if defined PENV_WANT_GNU
    sxprintf(C, "%s", nl);
  #if defined _GNU_SOURCE
    sxprintf(C, " -D_GNU_SOURCE=%-5jd", (intmax_t)_GNU_SOURCE);
  #else
    sxprintf(C, " -U_GNU_SOURCE");
  #endif
#endif

#if defined PENV_WANT_LARGEFILE
    sxprintf(C, "%s", nl);
  #if defined _LARGEFILE64_SOURCE
    sxprintf(C, " -D_LARGEFILE64_SOURCE=%-5jd", (intmax_t)_LARGEFILE64_SOURCE);
  #else
    sxprintf(C, " -U_LARGEFILE64_SOURCE");
  #endif
  #if 0
    #if defined _LARGEFILE_SOURCE
      sxprintf(C, " -D_LARGEFILE_SOURCE=%-5jd", (intmax_t)_LARGEFILE_SOURCE);
    #else
      sxprintf(C, " -U_LARGEFILE_SOURCE");
    #endif
  #endif

//  puts("Inferred options:");

  #if defined __USE_LARGEFILE64
    sxprintf(C, " -D__USE_LARGEFILE64=%-5jd (implicit)", (intmax_t)__USE_LARGEFILE64);
  #else
    sxprintf(C, " -U__USE_LARGEFILE64 (implicit)");
  #endif
  #if defined __USE_LARGEFILE
    sxprintf(C, " -D__USE_LARGEFILE=%-5jd (implicit)", (intmax_t)__USE_LARGEFILE);
  #else
    sxprintf(C, " -U__USE_LARGEFILE (implicit)");
  #endif
#endif

#if defined PENV_WANT_STAT_VER
    sxprintf(C, "%s", nl);
  #if defined _STAT_VER_LINUX_OLD
    sxprintf(C, " -D_STAT_VER_LINUX_OLD=%-5jd", (intmax_t)_STAT_VER_LINUX_OLD);
  #else
    sxprintf(C, " -U_STAT_VER_LINUX_OLD");
  #endif
  #if defined _STAT_VER_KERNEL
    sxprintf(C, " -D_STAT_VER_KERNEL=%-5jd", (intmax_t)_STAT_VER_KERNEL);
  #else
    sxprintf(C, " -U_STAT_VER_KERNEL");
  #endif
  #if defined _STAT_VER_SVR4
    sxprintf(C, " -D_STAT_VER_SVR4=%-5jd", (intmax_t)_STAT_VER_SVR4);
  #else
    sxprintf(C, " -U_STAT_VER_SVR4");
  #endif
  #if defined _STAT_VER_LINUX
    sxprintf(C, " -D_STAT_VER_LINUX=%-5jd", (intmax_t)_STAT_VER_LINUX);
  #else
    sxprintf(C, " -U_STAT_VER_LINUX");
  #endif
#endif

#ifndef PEV_SKIP_COMPILE_OPTS
  #if defined compilation_options
    sxprintf(C, "%s", nl);
    sxprintf(C, "COMPILED with %s", STR(compilation_options));
  #endif
#endif

    return sxfinal(C);
}

EXTERN inline void StartStruct(TK *tr, void *example_record, size_t struct_size, char const *struct_name, char const *strip_prefix) ;
SCOPE  inline void StartStruct(TK *tr, void *example_record, size_t struct_size, char const *struct_name, char const *strip_prefix) {
    printf("%6zu %s {\n", struct_size, struct_name);
    tr->example_record = example_record;
    tr->struct_size = struct_size;
    tr->struct_name = struct_name;
    tr->strip_prefix = strip_prefix;
    tr->prev_off = 0;
    sxinit(tr->packfmt);
    sxinit(tr->fieldnames);
    tr->fnw = 0;
    sxinit(tr->extra_perl);
}

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

enum { UnlimitedRepeat = (size_t)-1U };

EXTERN inline void Field(TK *tr, size_t off, size_t sz, size_t isz, FMode mode, char const *name, char const * extra) ;
SCOPE  inline void Field(TK *tr, size_t off, size_t sz, size_t isz, FMode mode, char const *name, char const * extra) {
    if (off != tr->prev_off) {
        int d = (int)off-(int)tr->prev_off;
        char const * pfmt = perl_unpack_fmt(d, 1, NULL);
        printf("   %+3d   %s\n", d, pfmt);
        sxprintf(tr->packfmt, "%s", pfmt);
    }

    int repeat = 1;
    if (!isz)
        isz = sz;
    else
        repeat = sz / isz;

    tr->prev_off = off+sz;
    int count;
    char const * pfmt = perl_unpack_fmt(isz, 0, &count);

    if (repeat != 1 && strlen(pfmt) != 1)
        sxprintf(tr->packfmt, "(%s)", pfmt);
    else
        sxprintf(tr->packfmt, "%s", pfmt);

    if (repeat == UnlimitedRepeat)
        sxprintf(tr->packfmt, "*");
    else if (repeat != 1)
        sxprintf(tr->packfmt, "%zu", repeat);

    printf("%3zu %2zu   %-6s  %s%s\n", off, sz, pfmt, name, extra);

    if ( tr->strip_prefix ) {
        char const *p = tr->strip_prefix;
        size_t l = strlen(p);
        if ( !memcmp(name,p,l) )
            name += l;
    }

    if (tr->fnw > 0 && tr->fnw + (strlen(name)+3)*count > 72) {
        sxprintf(tr->fieldnames, "\n    ");
        tr->fnw = 0;
    }

    if (count == 2 && mode == FM_struct_timespec) {
        /* atime, mtime, ctime, & variants */
        tr->fnw += sxprintf(tr->fieldnames, "$%s.sec,$%s.nsec, ", name, name); /**/
        sxprintf(tr->extra_perl, "my $%1$s = new_timespec($%1$s_1, $%1$1_2);\n", name);
    } else if (count == 2 && mode == FM_struct_timeval) {
        /* atime, mtime, ctime, & variants */
        tr->fnw += sxprintf(tr->fieldnames, "$%s.sec,$%s.nsec, ", name, name); /**/
        sxprintf(tr->extra_perl, "my $%1$s = new_timeval($%1$s_1, $%1$s_2);\n", name);
    } else if (count > 1) {
        int i;
        for (i = 1 ; i<= count ; ++i)
            tr->fnw += sxprintf(tr->fieldnames, "$%s_%d, ", name, i);
    }
    else
        tr->fnw += sxprintf(tr->fieldnames, "$%s, ", name);
}

EXTERN inline void EndStruct(TK *tr) ;
SCOPE  inline void EndStruct(TK *tr) {
    if (tr->struct_size != tr->prev_off) {
        int d = (int)tr->struct_size - (int)tr->prev_off;
        char const * pfmt = perl_unpack_fmt(d, 1, NULL);
        printf("   %+3d   %s\n", d, pfmt);
        sxprintf(tr->packfmt, "%s", pfmt);
    }
    printf("%6zu }\n", tr->struct_size);
    printf("BEGIN PERL:\n\nmy (%s) = unpack\n            '%s',\n            $in; \t# %s (%zu bytes)\n%s\n",
            sxpeek(tr->fieldnames),
            sxpeek(tr->packfmt),
            tr->struct_name,
            (size_t) tr->struct_size,
            sxpeek(tr->extra_perl));
    char const * env = Pbuildenv("\n#   ");
    if (env) {
        printf("# Build Env:%s\n", env);
        free((void*)env);       // stupidly, free does not accept const void*
    }
    puts("\nEND PERL");
    sxdestroy(tr->packfmt);
    sxdestroy(tr->fieldnames);
    sxdestroy(tr->extra_perl);
}

#undef EXTERN
#undef SCOPE

////////////////////////////////////////

#define STR(X) STR2(X)
#define STR2(X) #X

# define Begin()        Begin1(NULL)
# define Begin1(pref)   TK tracker; T sample_struct; StartStruct(&tracker, &sample_struct, sizeof sample_struct, STR(T), pref)

# define End()          EndStruct(&tracker)

# define Foffset(X)     offsetof(T,X)
# define Fsize(X)       sizeof sample_struct.X
# define Fcommon(X)     &tracker, Foffset(X), Fsize(X)
# define Fsigned(X)     (((__typeof(sample_struct.X))-1) > 0 ? FM_unsigned : FM_signed)

/* Fint & Ffloat can adapt to different arg sizes */
# define Fint(X,E)      Field(Fcommon(X), 0, Fsigned(X), #X, E)
# define Ffloat(X,E)    Field(Fcommon(X), 0, FM_float, #X, E)

# define FAint(X,E)     Field(Fcommon(X), Fsize(X[0]), Fsigned(X[0]), #X, E)
# define FAfloat(X,E)   Field(Fcommon(X), Fsize(X[0]), FM_float, #X, E)

# define Ftimeval(X,E)  Field(Fcommon(X), 0, FM_struct_timeval, #X, E)
# define Ftimespec(X,E) Field(Fcommon(X), 0, FM_struct_timespec, #X, E)

# define Fptr(X,E)      Field(Fcommon(X), 0, FM_pointer, #X, E)

/* If all else fails */
# define Fblob2(X,E)    Field(Fcommon(X), 1, FM_blob, #X, E)
# define Fblob(X)       Fblob2(X, "")

// Tweak the following to match the available numeric types in your compiler...

# define F2(X,E) _Generic((sample_struct.X),   \
                             char : Fint(X,E),   \
                           int8_t : Fint(X,E),   \
                          uint8_t : Fint(X,E),   \
                          int16_t : Fint(X,E),   \
                         uint16_t : Fint(X,E),   \
                          int32_t : Fint(X,E),   \
                         uint32_t : Fint(X,E),   \
                          int64_t : Fint(X,E),   \
                         uint64_t : Fint(X,E),   \
           long long unsigned int : Fint(X,E),   \
                       __int128_t : Fint(X,E),   \
                      __uint128_t : Fint(X,E),   \
                      long double : Ffloat(X,E), \
                           double : Ffloat(X,E), \
                            float : Ffloat(X,E), \
             _Complex long double : Ffloat(X,E), \
                  _Complex double : Ffloat(X,E), \
                   _Complex float : Ffloat(X,E))

 # define F(X)   F2(X,"")

# define FA2(X,E) _Generic((sample_struct.X),   \
                             char* : FAint(X,E),   \
                           int8_t* : FAint(X,E),   \
                          uint8_t* : FAint(X,E),   \
                          int16_t* : FAint(X,E),   \
                         uint16_t* : FAint(X,E),   \
                          int32_t* : FAint(X,E),   \
                         uint32_t* : FAint(X,E),   \
                          int64_t* : FAint(X,E),   \
                         uint64_t* : FAint(X,E),   \
           long long unsigned int* : FAint(X,E),   \
                       __int128_t* : FAint(X,E),   \
                      __uint128_t* : FAint(X,E),   \
                      long double* : FAfloat(X,E), \
                           double* : FAfloat(X,E), \
                            float* : FAfloat(X,E), \
             _Complex long double* : FAfloat(X,E), \
                  _Complex double* : FAfloat(X,E), \
                   _Complex float* : FAfloat(X,E))

 # define FA(X)   FA2(X,"")

//#define field_before(x, y) (offsetof(T,x) < offsetof(T,y))

#endif
