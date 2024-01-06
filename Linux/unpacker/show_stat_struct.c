#include <sys/types.h>

#if defined USE_ASM_STAT
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

//#include "die.h"
//#include "log2ceil.h"
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

void Pstat() {
  #if 1

    puts("");
   #define T struct stat
    Begin();
    F(st_dev);
    int shown_ino = 0;
    if (field_before(st_ino, st_mode) && !shown_ino++)
        F(st_ino);
   #ifdef HAS_STAT_old_st_ino
    else
        F2(__st_ino, "   (broken)");
   #endif
    int shown_nlink = 0;
    if (field_before(st_nlink,st_mode) && !shown_nlink++)
        F(st_nlink);
    F(st_mode);
    if (!shown_nlink)
        F(st_nlink);
    F(st_uid);
    F(st_gid);
    F(st_rdev);
    F(st_size);
    F(st_blksize);
    F(st_blocks);
    Fxtime(a);  // usually st_atime
    Fxtime(m);  // usually st_mtime
    Fxtime(c);  // usually st_ctime
    if (!shown_ino++)
        F2(st_ino, "   (replacement)");
    End();
   #undef T
  #endif
}

void Pstat64() {

  #if defined HAS_STAT64
    puts("");
   #define T struct stat64
    Begin();
    F(st_dev);

    int shown_ino = 0;
  #if STAT64_HAS_BROKEN_ST_INO
    F2(__st_ino,"   (STAT64_HAS_BROKEN_ST_INO=1)");
  #else
    if (field_before(st_ino,st_mode) && !shown_ino++)
        F(st_ino);
   #ifdef HAS_STAT64_old_st_ino
    else
        F(__st_ino);
   #endif
  #endif
    int shown_mode = 0;
    if (field_before(st_mode,st_nlink) && !shown_mode++)
        F(st_mode);
    F(st_nlink);
    if (!shown_mode++)
        F(st_mode);
    F(st_uid);
    F(st_gid);
    F(st_rdev);
    F(st_size);
    F(st_blksize);
    F(st_blocks);
    Fxtime(a);  // usually st_atime
    Fxtime(m);  // usually st_mtime
    Fxtime(c);  // usually st_ctime
    if (!shown_ino++)
        F2(st_ino, "   (replacement)");
    End();
   #undef T
  #endif
}

void Poldkstat() {
  #if defined USE_ASM_STAT
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
  #endif
}

////////////////////////////////////////////////////////////////////////////////

int main() {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    Pstat();
    Pstat64();
    Poldkstat();

    return 0;
}
