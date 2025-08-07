#include <sys/types.h>

#include <asm/stat.h>

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

#include "sxbuf.h"
#include "getlink.h"

#include "show_struct.h"

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

#if defined st_atime   // assuming st_atime→st_atim.tv_sec
    # define Fxtime(_X)     F(st_##_X##tim.tv_sec); F(st_##_X##tim.tv_nsec)
    //# define Fxtime(_X)     F(st_##_X##tim)
#elif STAT_HAVE_NSEC
    # define Fxtime(_X)     F(st_##_X##time); F(st_##_X##time_nsec)
#elif USE_NSEC
    # define Fxtime(_X)     F(st_##_X##time); F(st_##_X##timensec)
#else
    # define Fxtime(_X)     Ftime(st_##_X##time)
#endif

#define field_before(x, y) (offsetof(T,x) < offsetof(T,y))

////////////////////////////////////////

void Poldkstat() {
    puts("");
    #define T struct __old_kernel_stat
    Begin();
    F(st_dev);
    F(st_ino);
    F(st_mode);
    F(st_nlink);
    F(st_uid);
    F(st_gid);
    F(st_rdev);
    F(st_size);
    F(st_atime);
    F(st_mtime);
    F(st_ctime);
    End();
    #undef T
}

////////////////////////////////////////////////////////////////////////////////

int main() {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    Poldkstat();

    return 0;
}
