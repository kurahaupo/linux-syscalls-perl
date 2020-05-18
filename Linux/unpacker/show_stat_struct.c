#include <sys/types.h>

#ifdef USE_ASM_STAT
 #include <asm/stat.h>
#else
 #include <sys/stat.h>
#endif

#include <errno.h>  // errno, perror, strerror
#include <math.h>
#include <signal.h> // raise
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "die.h"
#include "log2ceil.h"
#include "sxbuf.h"
#include "show_struct.h"
#include "perl_unpack.h"
#include "getlink.h"

////////////////////////////////////////////////////////////////////////////////

#if defined _BITS_STAT_H
    /* copy #if/#endif logic from /usr/include/.../sys/stat.h */
    #if defined __x86_64__ || !defined __USE_FILE_OFFSET64
    #else
        #define HAS_STAT_old_st_ino // __ino_t __st_ino;   /* 32bit file serial number. */
    #endif
    #ifdef __USE_LARGEFILE64
        #define HAS_STAT64 // struct stat64
        # ifdef __x86_64__
        # else
            #define HAS_STAT64_old_st_ino // __ino_t __st_ino;   /* 32bit file serial number. */
            #define HAS_STAT64_old_st_ino
        # endif
    #endif

#elif defined _ASM_X86_STAT_H
    /* copy #if/#endif logic from /usr/include/.../asm/stat.h */
    #ifdef __i386__
        #define HAS_STAT64 // struct stat64 {
        #define HAS_STAT64_old_st_ino // unsigned long __st_ino;
    #endif
#endif

////////////////////////////////////////

#define STR(X) STR2(X)
#define STR2(X) #X

# define Begin(E)   TK tracker; T sample_struct; StartStruct(&tracker, &sample_struct, sizeof sample_struct, STR(T), "st_", E)
# define End()      EndStruct(&tracker)

# define P(X)       Q(X,"")
# define Q(X,Y)     Field(&tracker, offsetof(T,X), sizeof sample_struct.X, FM_unsigned, #X, Y)

#if defined st_atime   // assuming st_atime→st_atim.tv_sec
    # define Ptime(_X)     P(st_##_X##tim.tv_sec); P(st_##_X##tim.tv_nsec)
    //# define Ptime(_X)     P(st_##_X##tim)
#elif STAT_HAVE_NSEC
    # define Ptime(_X)     P(st_##_X##time); P(st_##_X##time_nsec)
#elif USE_NSEC
    # define Ptime(_X)     P(st_##_X##time); P(st_##_X##timensec)
#else
    # define Ptime(_X)     P(st_##_X##time)
#endif

#define field_before(x, y) (offsetof(T,x) < offsetof(T,y))

////////////////////////////////////////

void Pstat(char const *compile_options) {
  #if 1

    puts("");
   #define T struct stat
    Begin(compile_options);
    P(st_dev);
    int shown_ino = 0;
    if (field_before(st_ino, st_mode) && !shown_ino++)
        P(st_ino);
   #ifdef HAS_STAT_old_st_ino
    else
        Q(__st_ino, "   (broken)");
   #endif
    int shown_nlink = 0;
    if (field_before(st_nlink,st_mode) && !shown_nlink++)
        P(st_nlink);
    P(st_mode);
    if (!shown_nlink)
        P(st_nlink);
    P(st_uid);
    P(st_gid);
    P(st_rdev);
    P(st_size);
    P(st_blksize);
    P(st_blocks);
    Ptime(a);  // usually st_atime
    Ptime(m);  // usually st_mtime
    Ptime(c);  // usually st_ctime
    if (!shown_ino++)
        Q(st_ino, "   (replacement)");
    End();
   #undef T
  #endif
}

void Pstat64(char const *compile_options) {

  #if defined HAS_STAT64
    puts("");
   #define T struct stat64
    Begin(compile_options);
    P(st_dev);

    int shown_ino = 0;
  #if STAT64_HAS_BROKEN_ST_INO
    Q(__st_ino,"   (STAT64_HAS_BROKEN_ST_INO=1)");
  #else
    if (field_before(st_ino,st_mode) && !shown_ino++)
        P(st_ino);
   #ifdef HAS_STAT64_old_st_ino
    else
        P(__st_ino);
   #endif
  #endif
    int shown_mode = 0;
    if (field_before(st_mode,st_nlink) && !shown_mode++)
        P(st_mode);
    P(st_nlink);
    if (!shown_mode++)
        P(st_mode);
    P(st_uid);
    P(st_gid);
    P(st_rdev);
    P(st_size);
    P(st_blksize);
    P(st_blocks);
    Ptime(a);  // usually st_atime
    Ptime(m);  // usually st_mtime
    Ptime(c);  // usually st_ctime
    if (!shown_ino++)
        Q(st_ino, "   (replacement)");
    End();
   #undef T
  #endif
}

void Poldkstat(char const *compile_options) {
  #if defined USE_ASM_STAT
    puts("");
    #define T struct __old_kernel_stat
    Begin(compile_options);
    P(st_dev);
    P(st_ino);
    P(st_mode);
    P(st_nlink);
    P(st_uid);
    P(st_gid);
    P(st_rdev);
    P(st_size);
    P(st_atime);
    P(st_mtime);
    P(st_ctime);
    End();
    #undef T
  #endif
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

  #ifdef USE_ASM_STAT
    puts("request <asm/stat.h>");
    sxprintf(C,", request <asm/stat.h>");
  #else
    puts("request <sys/stat.h>");
    sxprintf(C,", request <sys/stat.h>");
  #endif

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

    Pstat(compile_options);
    Pstat64(compile_options);
    Poldkstat(compile_options);

    return 0;
}
