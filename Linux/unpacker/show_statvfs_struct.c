
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define __USE_LARGEFILE64
#define __USE_GNU
#include <stddef.h>
#include <sys/statfs.h>
#include <sys/statvfs.h>

#define PS(S)   printf( #S " -> size=%lu\n", (unsigned long) sizeof (S) )
#define PF(S,F) printf( "\t" #S "." #F " -> offset=%tu, size=%zu\n", offsetof(S,F), sizeof ((S*)0)->F )
#define PE(E)   printf( "\t" #E "=%#jx\n", (intmax_t) E )
#define PM(S,F) printf( "\t" #S "." #F " -> not defined\n" )

int main() {

    puts("");
    PS(struct statfs);
    PF(struct statfs,f_type);
    PF(struct statfs,f_bsize);
    #ifndef __USE_FILE_OFFSET64
    PF(struct statfs,f_blocks);
    PF(struct statfs,f_bfree);
    PF(struct statfs,f_bavail);
    PF(struct statfs,f_files);
    PF(struct statfs,f_ffree);
    #else
    PF(struct statfs,f_blocks);
    PF(struct statfs,f_bfree);
    PF(struct statfs,f_bavail);
    PF(struct statfs,f_files);
    PF(struct statfs,f_ffree);
    #endif
    PF(struct statfs,f_fsid);
    #ifdef _STATFS_F_NAMELEN
    PF(struct statfs,f_namelen);
    #else
    PM(struct statfs,f_namelen);
    #endif
    #ifdef _STATFS_F_FRSIZE
    PF(struct statfs,f_frsize);
    #else
    PM(struct statfs,f_frsize);
    #endif
    #ifdef _STATFS_F_FLAGS
    PF(struct statfs,f_flags);
    #else
    PM(struct statfs,f_flags);
    #endif
    PF(struct statfs,f_spare);

    #ifdef __USE_LARGEFILE64
    puts("");
    PS(struct statfs64);
    PF(struct statfs64,f_type);
    PF(struct statfs64,f_bsize);
    PF(struct statfs64,f_blocks);
    PF(struct statfs64,f_bfree);
    PF(struct statfs64,f_bavail);
    PF(struct statfs64,f_files);
    PF(struct statfs64,f_ffree);
    PF(struct statfs64,f_fsid);
    #ifdef _STATFS_F_NAMELEN
    PF(struct statfs64,f_namelen);
    #else
    PM(struct statfs64,f_namelen);
    #endif
    #ifdef _STATFS_F_FRSIZE
    PF(struct statfs64,f_frsize);
    #else
    PM(struct statfs64,f_frsize);
    #endif
    #ifdef _STATFS_F_FLAGS
    PF(struct statfs64,f_flags);
    #else
    PM(struct statfs64,f_flags);
    #endif
    PF(struct statfs64,f_spare);
    #endif

    puts("");
    PS(struct statvfs);
    PF(struct statvfs,f_bsize);
    PF(struct statvfs,f_frsize);
    #ifndef __USE_FILE_OFFSET64
    PF(struct statvfs,f_blocks);
    PF(struct statvfs,f_bfree);
    PF(struct statvfs,f_bavail);
    PF(struct statvfs,f_files);
    PF(struct statvfs,f_ffree);
    PF(struct statvfs,f_favail);
    #else
    PF(struct statvfs,f_blocks);
    PF(struct statvfs,f_bfree);
    PF(struct statvfs,f_bavail);
    PF(struct statvfs,f_files);
    PF(struct statvfs,f_ffree);
    PF(struct statvfs,f_favail);
    #endif
    PF(struct statvfs,f_fsid);
    #ifdef _STATVFSBUF_F_UNUSED
    PF(struct statvfs,__f_unused);
    #else
    //PM(struct statvfs,__f_unused);
    #endif
    PF(struct statvfs,f_flag);
    PF(struct statvfs,f_namemax);
    PF(struct statvfs,__f_spare);

    #ifdef __USE_LARGEFILE64
    puts("");
    PS(struct statvfs64);
    PF(struct statvfs64,f_bsize);
    PF(struct statvfs64,f_frsize);
    PF(struct statvfs64,f_blocks);
    PF(struct statvfs64,f_bfree);
    PF(struct statvfs64,f_bavail);
    PF(struct statvfs64,f_files);
    PF(struct statvfs64,f_ffree);
    PF(struct statvfs64,f_favail);
    PF(struct statvfs64,f_fsid);
    #ifdef _STATVFSBUF_F_UNUSED
    PF(struct statvfs64,__f_unused);
    #else
    //PM(struct statvfs64,__f_unused);
    #endif
    PF(struct statvfs64,f_flag);
    PF(struct statvfs64,f_namemax);
    PF(struct statvfs64,__f_spare);
    #endif

    puts("\nFlags:");
    PE(ST_RDONLY);
    PE(ST_NOSUID);
    #ifdef __USE_GNU
    PE(ST_NODEV);
    PE(ST_NOEXEC);
    PE(ST_SYNCHRONOUS);
    PE(ST_MANDLOCK);
    PE(ST_WRITE);
    PE(ST_APPEND);
    PE(ST_IMMUTABLE);
    PE(ST_NOATIME);
    PE(ST_NODIRATIME);
    PE(ST_RELATIME);
    #endif

    return 0;
}
