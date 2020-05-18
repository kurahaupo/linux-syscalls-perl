#include <sys/types.h>
#include <sys/timex.h>

#include <stddef.h>     /* offsetof */
#include <stdint.h>     /* intmax_t */
#include <stdio.h>      /* printf, stdout, stderr */
#include <string.h>

//#include <errno.h>    // errno, perror, strerror
//#include <math.h>
//#include <signal.h>   // raise
//#include <stdarg.h>
//#include <stdlib.h>
//#include <unistd.h>

#include "die.h"
#include "log2ceil.h"
#include "sxbuf.h"
#include "show_struct.h"
#include "perl_unpack.h"
#include "getlink.h"

////////////////////////////////////////

#define STR(X) STR2(X)
#define STR2(X) #X

# define Begin(E)   TK tracker; T sample_struct; StartStruct(&tracker, &sample_struct, sizeof sample_struct, STR(T), NULL, E)
# define End()      EndStruct(&tracker)

# define P(X)       Field(&tracker, offsetof(T,X), sizeof sample_struct.X, FM_signed, #X, "")

#if USE_ASM_STAT /* Fake, just to choose the variation */
  # define Ptime(X) P(X.tv_sec); P(X.tv_nsec)
#else
  # define Ptime(X) Field(&tracker, offsetof(T,X), sizeof sample_struct.X, FM_struct_timeval, #X, "")
#endif

#define field_before(x, y) (offsetof(T,x) < offsetof(T,y))

////////////////////////////////////////

void Ptimex(char const *compile_options) {
    puts("");
   #define T struct timex
    Begin(compile_options);
    P(modes);           /* mode selector */
    P(offset);          /* time offset (usec) */
    P(freq);            /* frequency offset (scaled ppm) */
    P(maxerror);        /* maximum error (usec) */
    P(esterror);        /* estimated error (usec) */
    P(status);          /* clock command/status */
    P(constant);        /* pll time constant */
    P(precision);       /* clock precision (usec) (ro) */
    P(tolerance);       /* clock frequency tolerance (ppm) (ro) */
    Ptime(time);        /* (read only, except for ADJ_SETOFFSET) */
    P(tick);            /* (modified) usecs between clock ticks */
    P(ppsfreq);         /* pps frequency (scaled ppm) (ro) */
    P(jitter);          /* pps jitter (us) (ro) */
    P(shift);           /* interval duration (s) (shift) (ro) */
    P(stabil);          /* pps stability (scaled ppm) (ro) */
    P(jitcnt);          /* jitter limit exceeded (ro) */
    P(calcnt);          /* calibration intervals (ro) */
    P(errcnt);          /* calibration errors (ro) */
    P(stbcnt);          /* stability limit exceeded (ro) */
    P(tai);             /* TAI offset (ro) */
    End();
   #undef T
}

////////////////////////////////////////////////////////////////////////////////

char const * Penvironment(void) {
    SX C;
    sxinit(C);

    puts("Compilation controls:");
  #ifdef __i386__
    puts("arch=i386");
    sxprintf(C, "arch=i80386");
  #endif
  #ifdef __x86_64__
    puts("arch=x86");
    sxprintf(C,"arch=x86_64");
  #endif
  #ifdef USE_i32
    puts("_32");
    sxprintf(C, "_32 ");
  #endif
  #ifdef USE_x32
    puts("_x32");
    sxprintf(C, "_x32");
  #endif
  #ifdef USE_x64
    puts("_64");
    sxprintf(C, "_64 ");
  #endif

  #ifdef compilation_options
    printf("COMPILED: %s\n", STR(compilation_options));
  #endif

    puts("request <sys/stat.h>");
    sxprintf(C,", request <sys/stat.h>");

  #ifdef _SYS_STAT_H
    puts("  using <sys/stat.h>");
    sxprintf(C,", using <sys/stat.h>");
  #endif
  #ifdef _ASM_X86_STAT_H
    printf("  using <asm/stat.h> (%s)\n", getlink("/usr/include/asm"));
    sxprintf(C,", using <asm/stat.h> (%s)", getlink("/usr/include/asm"));
  #endif

  #if 0
    #ifdef _BITS_STAT_H
      puts("  using <bits/stat.h>");
      sxprintf(C,", using <bits/stat.h>");
    #endif
  #endif

  #if 0
    #ifdef _GNU_SOURCE
      printf("request _GNU_SOURCE=%jd\n", (intmax_t)_GNU_SOURCE);
      sxprintf(C,", +_GNU_SOURCE=%-5jd", (intmax_t)_GNU_SOURCE);
    #else
      puts("        _GNU_SOURCE (unset)");
      sxprintf(C,", -_GNU_SOURCE=unset");
    #endif
  #endif
  #ifdef _LARGEFILE64_SOURCE
    printf("request _LARGEFILE64_SOURCE=%jd\n", (intmax_t)_LARGEFILE64_SOURCE);
    sxprintf(C," +_LARGEFILE64_SOURCE=%-5jd", (intmax_t)_LARGEFILE64_SOURCE);
  #else
    puts("        _LARGEFILE64_SOURCE (unset)");
    sxprintf(C," -_LARGEFILE64_SOURCE=unset");
  #endif
  #if 0
    #ifdef _LARGEFILE_SOURCE
      printf("request _LARGEFILE_SOURCE=%jd\n", (intmax_t)_LARGEFILE_SOURCE);
      sxprintf(C," +_LARGEFILE_SOURCE=%-5jd", (intmax_t)_LARGEFILE_SOURCE);
    #else
      puts("        _LARGEFILE_SOURCE (unset)");
      sxprintf(C," -_LARGEFILE_SOURCE=unset");
    #endif
  #endif

    puts("Inferred options:");

  #ifdef __USE_LARGEFILE64
    printf("implied __USE_LARGEFILE64=%jd\n", (intmax_t)__USE_LARGEFILE64);
    sxprintf(C," *+__USE_LARGEFILE64=%-5jd", (intmax_t)__USE_LARGEFILE64);
  #else
    puts("lacking __USE_LARGEFILE64");
    sxprintf(C," *-__USE_LARGEFILE64=unset");
  #endif
  #ifdef __USE_LARGEFILE
    printf("implied __USE_LARGEFILE=%jd\n", (intmax_t)__USE_LARGEFILE);
    sxprintf(C," *+__USE_LARGEFILE=%-5jd", (intmax_t)__USE_LARGEFILE);
  #else
    puts("lacking __USE_LARGEFILE");
    sxprintf(C," *-__USE_LARGEFILE=unset");
  #endif

  #ifdef _STAT_VER_LINUX_OLD
    printf(" _STAT_VER_LINUX_OLD = %jd\n", (intmax_t)_STAT_VER_LINUX_OLD);
    sxprintf(C," _STAT_VER_LINUX_OLD=%-5jd", (intmax_t)_STAT_VER_LINUX_OLD);
  #else
    sxprintf(C," -_STAT_VER_LINUX_OLD=unset");
  #endif
  #ifdef _STAT_VER_KERNEL
    printf(" _STAT_VER_KERNEL = %jd\n", (intmax_t)_STAT_VER_KERNEL);
    sxprintf(C," _STAT_VER_KERNEL=%-5jd", (intmax_t)_STAT_VER_KERNEL);
  #else
    sxprintf(C," -_STAT_VER_KERNEL=unset");
  #endif
  #ifdef _STAT_VER_SVR4
    printf(" _STAT_VER_SVR4 = %jd\n", (intmax_t)_STAT_VER_SVR4);
    sxprintf(C," _STAT_VER_SVR4=%-5jd", (intmax_t)_STAT_VER_SVR4);
  #else
    sxprintf(C," -_STAT_VER_SVR4=unset");
  #endif
  #ifdef _STAT_VER_LINUX
    printf(" _STAT_VER_LINUX = %jd\n", (intmax_t)_STAT_VER_LINUX);
    sxprintf(C," _STAT_VER_LINUX=%-5jd", (intmax_t)_STAT_VER_LINUX);
  #else
    sxprintf(C," -_STAT_VER_LINUX=unset");
  #endif

  #ifdef compilation_options
    sxprintf(C,"; COMPILED %s", STR(compilation_options));
  #endif

    return sxfinal(C);
}

////////////////////////////////////////////////////////////////////////////////

int main() {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    char const *compile_options = Penvironment();

    Ptimex(compile_options);

    return 0;
}
