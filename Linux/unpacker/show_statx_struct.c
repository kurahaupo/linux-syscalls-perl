#define _GNU_SOURCE

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

void Pstatx() {
  //#ifdef STATX_TYPE
    puts("");
    puts("use constant {");
    C(STATX_TYPE);
    C(STATX_MODE);
    C(STATX_NLINK);
    C(STATX_UID);
    C(STATX_GID);
    C(STATX_ATIME);
    C(STATX_MTIME);
    C(STATX_CTIME);
    C(STATX_INO);
    C(STATX_SIZE);
    C(STATX_BLOCKS);
    C(STATX_BASIC_STATS);
    C(STATX_ALL);
    C(STATX_BTIME);
  #ifdef STATX_MNT_ID
    C(STATX_MNT_ID);
  #endif
  #ifdef STATX_DIOALIGN
    C(STATX_DIOALIGN);
  #endif
    puts("};");

    puts("use constant {");
    C(STATX_ATTR_COMPRESSED);
    C(STATX_ATTR_IMMUTABLE);
    C(STATX_ATTR_APPEND);
    C(STATX_ATTR_NODUMP);
    C(STATX_ATTR_ENCRYPTED);
    C(STATX_ATTR_AUTOMOUNT);
    C(STATX_ATTR_MOUNT_ROOT);
    C(STATX_ATTR_VERITY);
    C(STATX_ATTR_DAX);
    puts("};");

    puts("");
    #define T struct statx
    Begin();
    F(stx_mask);
    F(stx_blksize);
    F(stx_attributes);
    F(stx_nlink);
    F(stx_uid);
    F(stx_gid);
    F(stx_mode);
//  F(__statx_pad1[1]);
    F(stx_ino);
    F(stx_size);
    F(stx_blocks);
    F(stx_attributes_mask);
    # define Fxt(_X)     F(_X.tv_sec); F(_X.tv_nsec)
    Fxt(stx_atime);
    Fxt(stx_btime);
    Fxt(stx_ctime);
    Fxt(stx_mtime);
    # undef Fxt
    F(stx_rdev_major);
    F(stx_rdev_minor);
    F(stx_dev_major);
    F(stx_dev_minor);
  #ifdef STATX_MNT_ID
    F(stx_mnt_id);
  #endif
  #ifdef STATX_DIOALIGN
    F(stx_dio_mem_align);
    F(stx_dio_offset_align);
  #endif
//  F(__statx_pad2[14];
    End();
    #undef T
  //#endif
}

////////////////////////////////////////////////////////////////////////////////

int main() {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    Pstatx();

    return 0;
}
