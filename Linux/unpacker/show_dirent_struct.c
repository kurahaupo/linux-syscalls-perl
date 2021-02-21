#define _GNU_SOURCE         /* See feature_test_macros(7) */
#define _BSD_SOURCE         /* for the DT_* macros */
#include <fcntl.h>
#include <sys/stat.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <errno.h>
#include <dirent.h>
#include <string.h>

#include <unistd.h>
#include <sys/syscall.h>   /* For SYS_xxx definitions */

#ifndef AT_EMPTY_PATH
#define AT_EMPTY_PATH          0x1000
#endif

static inline int min(int x, int y) { return x<y ? x : y; }

void bad_option(char opt, char *arg) {
    fprintf(stderr, "Invalid option -%c in %s\n", opt, arg);
    exit(64);
}

intmax_t arg_strtoll(char opt, char **arg, char ***argv) {
    char *p = *arg,
         *o = **argv;
    int next_arg = 0;
    if (!*p) {
        // skip to next arg
        p = *++*argv;
        next_arg = 1;
    }
    char *e = NULL;
    intmax_t r = strtoll(p, &e, 0);
    if (*e && e != p && next_arg) {
        /* If '-jNNNx', leave *arg pointing at 'x' */
        *arg = e;
    } else {
        /* If '-j NNNx' abort with error */
        if (*e) {
            fprintf(stderr, "Invalid value %s for option -%c in %s", p, opt, o);
            exit(64);   // EX_USAGE
        }
        /* If '-j ""' abort with error */
        if (p == e) {
            fprintf(stderr, "Invalid empty value for option -%c in %s", opt, o);
            exit(64);   // EX_USAGE
        }
        /* If '-jNNN' or '-j NNN', leave *arg as NULL */
        *arg = NULL;
    }
    return r;
}

void hexdump(void *b_, size_t bsize, off_t addr, size_t lw) {
    char *b = b_;
    int spad = addr%lw;   /* start padding; may be non-zero on first line */
    int dw = lw-spad;     /* preferred data width, after initial padding */
    addr -= spad;
    size_t o = 0;
    for ( ;o<bsize; o += dw, addr += lw, spad = 0, dw = lw ) {

        /* show address and leading padding */
        printf("%10.5jx |%*s", (intmax_t)addr, (int)(spad * 3), "");

        /* byte range to be considered for this line is [ls,ls+ll) */
        char *ls = b+o;
        int ll = min(dw, bsize-o);  /* actual length of data in this line */
        int epad = dw-ll; /* end padding; may be non-zero on last line */

        /* show hex dump of ll bytes */
        int i;
        for(i=0;i<ll;++i)
            printf(" %02hhx", ls[i]);

        /* show mid padding */
        printf("%*s | %*s", (int)(epad*3), "", (int)spad, "");

        /* show ASCII */
        for(i=0;i<ll;i++)
            printf("%c", isprint(ls[i]) ? ls[i] : '.');

        /* show end padding and newline */
        printf("%*s |\n", (int)epad, "");
    }
}

void show_file_content(char *name, int fd) {
    char buf[4096];
    char *const ebuf=(&buf)[1]; // == buf+sizeof buf
    int l;
    intmax_t addr=0;
    for (;(l=read(fd, buf, ebuf-buf)) > 0;addr+=l) {
        hexdump(buf, l, addr, 32);
    }
    if (l<0 && addr==0) {
        fprintf(stderr, "Error from read of %s; %m\n", name);
        exit(19);
    }
}

#if build_mode == 0

  #define                        xSYS_getdents  SYS_getdents
  typedef struct dirent          DirEnt;

  #ifdef _DIRENT_HAVE_D_RECLEN
    #define RDT_RECLEN    _DIRENT_HAVE_D_RECLEN
  #else
    #undef RDT_RECLEN
  #endif
  #ifdef _DIRENT_HAVE_D_NAMLEN
    #define RDT_NAMLEN    _DIRENT_HAVE_D_NAMLEN
  #else
    #undef RDT_NAMLEN
  #endif
  #ifdef _DIRENT_HAVE_D_OFF
    #define RDT_OFF       _DIRENT_HAVE_D_OFF
  #else
    #undef RDT_OFF
  #endif
  #ifdef _DIRENT_HAVE_D_TYPE
    #define RDT_TYPE      _DIRENT_HAVE_D_TYPE
    #undef  RDT_LATETYPE
  #else
    #undef RDT_TYPE
    #define RDT_LATETYPE    /* only since Linux 2.6.4 */
  #endif

#elif build_mode == 1

  #define                        xSYS_getdents  SYS_getdents
  typedef struct linux_dirent32 {
    unsigned long  d_ino;     /* Inode number */
    unsigned long  d_off;     /* Offset to next linux_dirent */
    unsigned short d_reclen;  /* Length of this linux_dirent */
    char           d_name[];  /* Filename (null-terminated) */
                               /* length is actually (d_reclen - 2 - offsetof(struct linux_dirent, d_name)) */
   /*
    char           pad;       // Zero padding byte
    char           d_type;    // File type (only since Linux
                              // 2.6.4); offset is (d_reclen - 1)
   */
  } DirEnt;

  #define RDT_RECLEN
  #undef  RDT_NAMLEN
  #define RDT_OFF
  #undef  RDT_TYPE
  #define RDT_LATETYPE

#elif build_mode == 2

  #define                        xSYS_getdents  SYS_getdents64
  typedef struct linux_dirent64 {
    uint64_t       d_ino;     /* Inode number */
    uint64_t       d_off;     /* Offset to next linux_dirent */
    uint16_t       d_reclen;  /* Length of this linux_dirent */
    char           d_type;    /* File type at this location only on x86_64, not i386 */
    char           d_name[];  /* Filename (null-terminated) */
                              /* length is actually (d_reclen - 2 - offsetof(struct linux_dirent, d_name)) */
  } DirEnt;

  #define RDT_RECLEN
  #undef  RDT_NAMLEN
  #define RDT_OFF
  #define RDT_TYPE
  #undef  RDT_LATETYPE

#else
 #error "Please predefine build_mode"
#endif

static inline int getdents( int fd, void *buf, size_t bsize ) {
    return syscall(xSYS_getdents, fd, buf, bsize);
}

/*
 *  d_ino       is an inode number.
 *  d_off       is the distance from the start of the directory to the start of the next linux_dirent.
 *  d_reclen    is the size of this entire linux_dirent.
 *  d_name      is a null-terminated filename.
 *
 *     d_type is a byte at the end of the structure that indicates the file type.  It contains one of the following values (defined in <dirent.h>):
 *
 *     DT_BLK      This is a block device.
 *     DT_CHR      This is a character device.
 *     DT_DIR      This is a directory.
 *     DT_FIFO     This is a named pipe (FIFO).
 *     DT_LNK      This is a symbolic link.
 *     DT_REG      This is a regular file.
 *     DT_SOCK     This is a UNIX domain socket.
 *     DT_UNKNOWN  The file type is unknown.
 */


static inline char const *dt_desc(uint8_t code) {
    #define DT_MAX 15
    #define DTS(X) " (" #X ")"
    char *dt_desc_[DT_MAX] = {
        [DT_UNKNOWN]  = "Unknown"       DTS(DT_UNKNOWN),    /* 0 */
        [DT_FIFO]     = "Pipe (Fifo)"   DTS(DT_FIFO),       /* 1 */
        [DT_CHR]      = "char Device"   DTS(DT_CHR),        /* 2 */
        [DT_DIR]      = "Directory"     DTS(DT_DIR),        /* 4 */
        [DT_BLK]      = "block Device"  DTS(DT_BLK),        /* 6 */
        [DT_REG]      = "Plain file"    DTS(DT_REG),        /* 8 */
        [DT_LNK]      = "Symlink"       DTS(DT_LNK),        /* 10 */
        [DT_SOCK]     = "Socket"        DTS(DT_SOCK),       /* 12 */
        [DT_WHT]      = "WHT"           DTS(DT_WHT),        /* 14 */
    };
    char *p;
    if (code >= 0 && code < DT_MAX) {
        char *p = dt_desc_[code];
        if (p)
            return p;
    }
    static char b[21];
    sprintf(b, "(unknown code %#.2x)", code);
    return b;
    #undef DT_MAX
}

void show_dir_content(char *name, int fd) {
    char buf[8192];
    printf("Dir fd=%d name=%s buf=%p\n", fd, name, buf);
    char *const ebuf=(&buf)[1]; // == buf+sizeof buf
    off_t addr=0;
    ssize_t res;
    for (;errno = 0, (res=getdents(fd, buf, ebuf-buf)) > 0;addr+=res) {
        size_t blen = res;
        if (0) {
            hexdump(buf, blen, addr, 16);
            puts("-----------");
        }
        size_t ro, rl = 1; /* record offset & length within buffer */
        for ( ro=0 ; rl > 0 && ro < ebuf-buf ; ro += rl ) {
            off_t ra = addr+ro;
            char *rbp = buf+ro;
            DirEnt *rp = (void*)rbp;

            rl = blen-ro;
            #ifdef RDT_RECLEN
            rl = min(rp->d_reclen, rl);   /* either the size given within, or the remainder of the buffer, whichever is smaller */
            #endif

            printf("%10.7jx\n", (intmax_t)ra);
            hexdump(rbp, rl, ra, 16);

          #ifdef RDT_NAMLEN
            int nl = rp->d_namlen;
          #else
            int nl = strlen(rp->d_name)+1;  /* length including terminating null byte */
          #endif

            printf("\tname:   \"%s\" [%d]\n", rp->d_name, nl);
            printf("\tinode:  %jd\n", (intmax_t) rp->d_ino);

          #ifdef RDT_OFF
            printf("\thash:   %jx   (telldir)\n", (intmax_t) rp->d_off);
          #endif
          #ifdef RDT_RECLEN
            printf("\treclen: %jx\n", (intmax_t) rp->d_reclen);
          #endif

          #ifdef RDT_TYPE
            int t = rp->d_type;
          #endif
          #ifdef RDT_LATETYPE
            int t = rp->d_name[nl++];
          #endif
          #if defined RDT_TYPE || defined RDT_LATETYPE
            printf("\ttype:   %s (%#.2hhx)\n", dt_desc(t), t);
          #endif

            /* name-offset and name-end, within record */
            int no = offsetof(DirEnt, d_name);
            int ne = no + nl;

          #ifndef RDT_RECLEN
            /* if no d_reclen, then assume record finishes just after the name
             * (and optional late d_type) */
            rl = min(ne, rl);
          #endif

            if (ne < rl)
                hexdump(rbp+ne, rl-ne, ra+ne, 16);

            puts("");

        }

        if (blen > ro) {
            puts("Residue:");
            hexdump(buf+ro, blen-ro, addr+ro, 16);
        } else if (blen < ro) {
            fprintf(stderr, "Whoops, blen=%zu < ro=%zu\n", blen, ro);
        }
        puts("-----------");
    }
    if (res < 0) {
        fprintf(stderr, "Error from first getdents on %s: %m", name);
        exit(20);
    }
}

int main(int argc, char **argv) {
    char *argv0 = *argv++, *arg;
    int oflags = O_RDONLY;
    int aflags = AT_EMPTY_PATH;
    int read_fifo = 0;
    for (; arg=*argv ; ++argv ) {
        char *oarg = arg;
        int fd;
        if (*arg == '-') {
            if (arg[1]) {
                int opt;
                for (++arg ; arg && (opt = *arg++) ;)
                    switch (opt) {
                        case 'A': aflags  =  0; break;
                        case 'a': aflags  = arg_strtoll(opt, &arg, &argv); break;
                        case 'O': oflags  =  0; break;
                        case 'o': oflags  = arg_strtoll(opt, &arg, &argv); break;

                        case 'D': oflags &= ~O_DIRECTORY; break;
                        case 'd': oflags |=  O_DIRECTORY; break;
                        case 'E': aflags &= ~AT_EMPTY_PATH; break;
                        case 'e': aflags |=  AT_EMPTY_PATH; break;
                        case 'L': oflags &= ~O_LARGEFILE; break;
                        case 'l': oflags |=  O_LARGEFILE; break;
                        case 'P': read_fifo = 0; break;
                        case 'p': read_fifo = 1; break;
                        case 'S': aflags &= ~AT_SYMLINK_NOFOLLOW; break;
                        case 's': aflags |=  AT_SYMLINK_NOFOLLOW; break;
                        default: bad_option(arg[-1], oarg);
                    }
                continue;
            }
            fd = 0; /* STDIN */
        } else {
            fd = openat(AT_FDCWD, arg, oflags, aflags);
            if (fd<0) {
                fprintf(stderr, "Error opening %s; %m\n", arg);
                continue;
            }
        }

        struct stat s;
        int r = fstat(fd, &s);
        if (r<0) { fprintf(stderr, "Can't fstat fd#%d; %m\n", fd); exit(17); }

        if (S_ISDIR(s.st_mode))
            show_dir_content(arg, fd);
        else if (S_ISREG(s.st_mode) || S_ISFIFO(s.st_mode) && read_fifo)
            show_file_content(arg, fd);
        else {
            fprintf(stderr, "skipping %s, neither dir nor plain file\n", arg);
            close(fd);
            continue;
        }
        if (close(fd)<0) {
            fprintf(stderr, "Error closing %s; %m\n", arg);
        }
    }
    return 0;
}
