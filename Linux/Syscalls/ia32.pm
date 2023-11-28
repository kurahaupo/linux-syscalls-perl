#! /module/for/perl

use strict;
use warnings;

package Linux::Syscalls::ia32;

#
# This file supports i386, i586 & i686

# On x86 platforms, the choice of architecture is given by this logic (in
# /usr/include/x86_64-linux-gnu/asm/unistd.h):
#   ifdef __i386__
#    include <asm/unistd_32.h>   /* ia32 */
#   elif defined(__ILP32__)
#    include <asm/unistd_x32.h>  /* x86_32 */
#   else
#    include <asm/unistd_64.h>   /* x86_64 */
#   endif
#
# (Note: i386 was the original Linux 0.01, and there are still remnants of that
# legacy in this file. As a result, this file is a maze of dark twisty
# passages; programmers who linger here are likely to be eaten by a grue.)
#
# %syscall_map reports the version of each syscall that most closely aligns
# with the x86_64 version, mostly by adding or removing numeric suffices. In
# most cases this means that they can share an "unpack" format string with
# x86_64.
#
# This generally applies where new syscalls are provided to cope with
#  → File sizes widened from 32 to 64 bits
#  → UID & GID widened from 16 to 32 bits
#  → Timestamp precision improved from seconds to nanoseconds
# However:
#  → PID's are generally half a word on any platform (32-bit on 64-bit
#    platforms, or 16-bit on 32-bit platforms) and there are no size-specific
#    kernel calls like getpid16/getpid32 or kill16/kill32; instead, the
#    relevant syscalls simply take or return an int in a register. Siginfo
#    is an exception to this, but generally
#
#    (Fortunately getpid() returns an int, so we don't need to unpack
#    anything; and we have POSIX::getpid() and $English::PID so we don't need
#    to implement getpid16().)
#
# Examples:
# → __NR_stat64   is given when asked for "stat" (or "stat64"), and
#   __NR_stat     is given when asked for "stat32";
# → __NR_getuid32 is given when asked for "getuid" (or "getuid"), and
#   __NR_getuid   is given when asked for "getuid16".
#
# Full list of renamed syscalls, plus aliases:
#
# ╔══════════════════╤═══════════════════╤═══════════════════╗
# ║ preferred name   │ std name for orig │ std name for new  ║
# ║ for orig call    │ call == preferred │ call              ║
# ║                  │ name for new call │                   ║
# ╠══════════════════╪═══════════════════╪═══════════════════╣
# ║ chown16          │ chown             │ chown32           ║
# ║ fchown16         │ fchown            │ fchown32          ║
# ║ lchown16         │ lchown            │ lchown32          ║
# ╟──────────────────┼───────────────────┼───────────────────╢
# ║ fcntl32          │ fcntl             │ fcntl64           ║
# ╟──────────────────┼───────────────────┼───────────────────╢
# ║ getdents32       │ getdents          │ getdents64        ║
# ╟──────────────────┼───────────────────┼───────────────────╢
# ║ getegid16        │ getegid           │ getegid32         ║
# ║ geteuid16        │ geteuid           │ geteuid32         ║
# ║ setfsgid16       │ setfsgid          │ setfsgid32        ║
# ║ setfsuid16       │ setfsuid          │ setfsuid32        ║
# ║ getgid16         │ getgid            │ getgid32          ║
# ║ setgid16         │ setgid            │ setgid32          ║
# ║ getgroups16      │ getgroups         │ getgroups32       ║
# ║ setgroups16      │ setgroups         │ setgroups32       ║
# ║ setregid16       │ setregid          │ setregid32        ║
# ║ getresgid16      │ getresgid         │ getresgid32       ║
# ║ setresgid16      │ setresgid         │ setresgid32       ║
# ║ getresuid16      │ getresuid         │ getresuid32       ║
# ║ setresuid16      │ setresuid         │ setresuid32       ║
# ║ setreuid16       │ setreuid          │ setreuid32        ║
# ║ getuid16         │ getuid            │ getuid32          ║
# ║ setuid16         │ setuid            │ setuid32          ║
# ╟──────────────────┼───────────────────┼───────────────────╢
# ║ sendfile32       │ sendfile          │ sendfile64        ║
# ╟──────────────────┼───────────────────┼───────────────────╢
# ║ stat32           │ stat              │ stat64            ║
# ║ fstat32          │ fstat             │ fstat64           ║
# ║ lstat32          │ lstat             │ lstat64           ║
# ║                  │ fstatat           │ fstatat64         ║
# ╟──────────────────┼───────────────────┼───────────────────╢
# ║ statfs32         │ statfs            │ statfs64          ║
# ║ fstatfs32        │ fstatfs           │ fstatfs64         ║
# ╟──────────────────┼───────────────────┼───────────────────╢
# ║ truncate32       │ truncate          │ truncate64        ║
# ║ ftruncate32      │ ftruncate         │ ftruncate64       ║
# ╟──────────────────┼───────────────────┼───────────────────╢
# ║                  │ fadvise           │ fadvise64         ║
# ║                  │ getdents          │ getdents64        ║
# ║                  │ prlimit           │ prlimit64         ║
# ╚══════════════════╧═══════════════════╧═══════════════════╝
#
# TODO: Figure out what to do about 64-bit file sizes on 32-bit platforms for:
#           * mmap2 vs mmap
#           * lseek64 vs _llseek vs lseek

# On x86 platforms, the choice of architecture is given by this logic (in
# /usr/include/x86_64-linux-gnu/asm/unistd.h):
#   ifdef __i386__
#    include <asm/unistd_32.h>   /* ia32 */
#   elif defined(__ILP32__)
#    include <asm/unistd_x32.h>  /* x86_32 */
#   else
#    include <asm/unistd_64.h>   /* x86_64 */
#   endif

use Exporter 'import';

our %syscall_map = (

        # FROM /usr/include/i386-linux-gnu/asm/unistd_32.h
        restart_syscall         =>   0,
        exit                    =>   1,
        fork                    =>   2,
        read                    =>   3,
        write                   =>   4,
        open                    =>   5,
        close                   =>   6,
        waitpid                 =>   7,
        creat                   =>   8,
        link                    =>   9,
        unlink                  =>  10,
        execve                  =>  11,
        chdir                   =>  12,
        time                    =>  13,
        mknod                   =>  14,
        chmod                   =>  15,
        lchown16                =>  16,     # was lchown
        break                   =>  17,
        oldstat                 =>  18,     # really-old stat; __old_kernel_stat
        lseek                   =>  19,
        getpid                  =>  20,
        mount                   =>  21,
        umount                  =>  22,
        setuid16                =>  23,     # was setuid
        getuid16                =>  24,     # was getuid
        stime                   =>  25,
        ptrace                  =>  26,
        alarm                   =>  27,
        oldfstat                =>  28,     # really-old fstat; __old_kernel_stat
        pause                   =>  29,
        utime                   =>  30,
        stty                    =>  31,
        gtty                    =>  32,
        access                  =>  33,
        nice                    =>  34,
        ftime                   =>  35,
        sync                    =>  36,
        kill                    =>  37,
        rename                  =>  38,
        mkdir                   =>  39,
        rmdir                   =>  40,
        dup                     =>  41,
        pipe                    =>  42,
        times                   =>  43,
        prof                    =>  44,
        brk                     =>  45,
        setgid16                =>  46,     # was setgid
        getgid16                =>  47,     # was getgid
        signal                  =>  48,
        geteuid16               =>  49,     # was geteuid
        getegid16               =>  50,     # was getegid
        acct                    =>  51,
        umount2                 =>  52,
        lock                    =>  53,
        ioctl                   =>  54,
        fcntl32                 =>  55,     # was fcntl
        mpx                     =>  56,
        setpgid                 =>  57,
        ulimit                  =>  58,
        oldolduname             =>  59,
        umask                   =>  60,
        chroot                  =>  61,
        ustat                   =>  62,
        dup2                    =>  63,
        getppid                 =>  64,
        getpgrp                 =>  65,
        setsid                  =>  66,
        sigaction               =>  67,
        sgetmask                =>  68,
        ssetmask                =>  69,
        setreuid16              =>  70,     # was setreuid
        setregid16              =>  71,     # was setregid
        sigsuspend              =>  72,
        sigpending              =>  73,
        sethostname             =>  74,
        setrlimit               =>  75,
        getrlimit               =>  76,
        getrusage               =>  77,
        gettimeofday            =>  78,
        settimeofday            =>  79,
        getgroups16             =>  80,     # was getgroups
        setgroups16             =>  81,     # was setgroups
        select                  =>  82,
        symlink                 =>  83,
        oldlstat                =>  84,     # really-old lstat; __old_kernel_stat
        readlink                =>  85,
        uselib                  =>  86,
        swapon                  =>  87,
        reboot                  =>  88,
        readdir                 =>  89,
        mmap                    =>  90,
        munmap                  =>  91,
        truncate32              =>  92,     # was truncate
        ftruncate32             =>  93,     # was ftruncate
        fchmod                  =>  94,
        fchown16                =>  95,     # was fchown
        getpriority             =>  96,
        setpriority             =>  97,
        profil                  =>  98,
        statfs32                =>  99,     # was statfs
        fstatfs32               => 100,     # was fstatfs
        ioperm                  => 101,
        socketcall              => 102,
        syslog                  => 103,
        setitimer               => 104,
        getitimer               => 105,
        stat32                  => 106,     # was stat
        lstat32                 => 107,     # was lstat
        fstat32                 => 108,     # was fstat
        olduname                => 109,
        iopl                    => 110,
        vhangup                 => 111,
        idle                    => 112,
        vm86old                 => 113,
        wait4                   => 114,
        swapoff                 => 115,
        sysinfo                 => 116,
        ipc                     => 117,
        fsync                   => 118,
        sigreturn               => 119,
        clone                   => 120,
        setdomainname           => 121,
        uname                   => 122,
        modify_ldt              => 123,
        adjtimex                => 124,
        mprotect                => 125,
        sigprocmask             => 126,
        create_module           => 127,
        init_module             => 128,
        delete_module           => 129,
        get_kernel_syms         => 130,
        quotactl                => 131,
        getpgid                 => 132,
        fchdir                  => 133,
        bdflush                 => 134,
        sysfs                   => 135,
        personality             => 136,
        afs_syscall             => 137,
        setfsuid16              => 138,     # was setfsuid
        setfsgid16              => 139,     # was setfsgid
        _llseek                 => 140,
        getdents32              => 141,     # was getdents
        _newselect              => 142,
        flock                   => 143,
        msync                   => 144,
        readv                   => 145,
        writev                  => 146,
        getsid                  => 147,
        fdatasync               => 148,
        _sysctl                 => 149,
        mlock                   => 150,
        munlock                 => 151,
        mlockall                => 152,
        munlockall              => 153,
        sched_setparam          => 154,
        sched_getparam          => 155,
        sched_setscheduler      => 156,
        sched_getscheduler      => 157,
        sched_yield             => 158,
        sched_get_priority_max  => 159,
        sched_get_priority_min  => 160,
        sched_rr_get_interval   => 161,
        nanosleep               => 162,
        mremap                  => 163,
        setresuid16             => 164,     # was setresuid
        getresuid16             => 165,     # was getresuid
        vm86                    => 166,
        query_module            => 167,
        poll                    => 168,
        nfsservctl              => 169,
        setresgid16             => 170,     # was setresgid
        getresgid16             => 171,     # was getresgid
        prctl                   => 172,
        rt_sigreturn            => 173,
        rt_sigaction            => 174,
        rt_sigprocmask          => 175,
        rt_sigpending           => 176,
        rt_sigtimedwait         => 177,
        rt_sigqueueinfo         => 178,
        rt_sigsuspend           => 179,
        pread64                 => 180,
        pwrite64                => 181,
        chown16                 => 182,     # was chown
        getcwd                  => 183,
        capget                  => 184,
        capset                  => 185,
        sigaltstack             => 186,
        sendfile32              => 187,     # was sendfile
        getpmsg                 => 188,
        putpmsg                 => 189,
        vfork                   => 190,
        ugetrlimit              => 191,
        mmap2                   => 192,
        truncate                => 193,     truncate64              => 193,
        ftruncate               => 194,     ftruncate64             => 194,
        stat                    => 195,     stat64                  => 195,
        lstat                   => 196,     lstat64                 => 196,
        fstat                   => 197,     fstat64                 => 197,
        lchown                  => 198,     lchown32                => 198,
        getuid                  => 199,     getuid32                => 199,
        getgid                  => 200,     getgid32                => 200,
        geteuid                 => 201,     geteuid32               => 201,
        getegid                 => 202,     getegid32               => 202,
        setreuid                => 203,     setreuid32              => 203,
        setregid                => 204,     setregid32              => 204,
        getgroups               => 205,     getgroups32             => 205,
        setgroups               => 206,     setgroups32             => 206,
        fchown                  => 207,     fchown32                => 207,
        setresuid               => 208,     setresuid32             => 208,
        getresuid               => 209,     getresuid32             => 209,
        setresgid               => 210,     setresgid32             => 210,
        getresgid               => 211,     getresgid32             => 211,
        chown                   => 212,     chown32                 => 212,
        setuid                  => 213,     setuid32                => 213,
        setgid                  => 214,     setgid32                => 214,
        setfsuid                => 215,     setfsuid32              => 215,
        setfsgid                => 216,     setfsgid32              => 216,
        pivot_root              => 217,
        mincore                 => 218,
        madvise                 => 219,
        getdents                => 220,     getdents64              => 220,
        fcntl                   => 221,     fcntl64                 => 221,
        # unused => 222
        # unused => 223
        gettid                  => 224,
        readahead               => 225,
        setxattr                => 226,
        lsetxattr               => 227,
        fsetxattr               => 228,
        getxattr                => 229,
        lgetxattr               => 230,
        fgetxattr               => 231,
        listxattr               => 232,
        llistxattr              => 233,
        flistxattr              => 234,
        removexattr             => 235,
        lremovexattr            => 236,
        fremovexattr            => 237,
        tkill                   => 238,
        sendfile                => 239,     sendfile64              => 239,
        futex                   => 240,
        sched_setaffinity       => 241,
        sched_getaffinity       => 242,
        set_thread_area         => 243,
        get_thread_area         => 244,
        io_setup                => 245,
        io_destroy              => 246,
        io_getevents            => 247,
        io_submit               => 248,
        io_cancel               => 249,
        fadvise                 => 250,     fadvise64               => 250,
        # unused => 251
        exit_group              => 252,
        lookup_dcookie          => 253,
        epoll_create            => 254,
        epoll_ctl               => 255,
        epoll_wait              => 256,
        remap_file_pages        => 257,
        set_tid_address         => 258,
        timer_create            => 259,
        timer_settime           => 260,
        timer_gettime           => 261,
        timer_getoverrun        => 262,
        timer_delete            => 263,
        clock_settime           => 264,
        clock_gettime           => 265,
        clock_getres            => 266,
        clock_nanosleep         => 267,
        statfs                  => 268,     statfs64                => 268,
        fstatfs                 => 269,     fstatfs64               => 269,
        tgkill                  => 270,
        utimes                  => 271,
        fadvise64_64            => 272,
        vserver                 => 273,
        mbind                   => 274,
        get_mempolicy           => 275,
        set_mempolicy           => 276,
        mq_open                 => 277,
        mq_unlink               => 278,
        mq_timedsend            => 279,
        mq_timedreceive         => 280,
        mq_notify               => 281,
        mq_getsetattr           => 282,
        kexec_load              => 283,
        waitid                  => 284,
        # unused => 285
        add_key                 => 286,
        request_key             => 287,
        keyctl                  => 288,
        ioprio_set              => 289,
        ioprio_get              => 290,
        inotify_init            => 291,
        inotify_add_watch       => 292,
        inotify_rm_watch        => 293,
        migrate_pages           => 294,
        openat                  => 295,
        mkdirat                 => 296,
        mknodat                 => 297,
        fchownat                => 298,
        futimesat               => 299,
        fstatat                 => 300,     fstatat64               => 300,
        unlinkat                => 301,
        renameat                => 302,
        linkat                  => 303,
        symlinkat               => 304,
        readlinkat              => 305,
        fchmodat                => 306,
        faccessat               => 307,
        pselect6                => 308,
        ppoll                   => 309,
        unshare                 => 310,
        set_robust_list         => 311,
        get_robust_list         => 312,
        splice                  => 313,
        sync_file_range         => 314,
        tee                     => 315,
        vmsplice                => 316,
        move_pages              => 317,
        getcpu                  => 318,
        epoll_pwait             => 319,
        utimensat               => 320,
        signalfd                => 321,
        timerfd_create          => 322,
        eventfd                 => 323,
        fallocate               => 324,
        timerfd_settime         => 325,
        timerfd_gettime         => 326,
        signalfd4               => 327,
        eventfd2                => 328,
        epoll_create1           => 329,
        dup3                    => 330,
        pipe2                   => 331,
        inotify_init1           => 332,
        preadv                  => 333,
        pwritev                 => 334,
        rt_tgsigqueueinfo       => 335,
        perf_event_open         => 336,
        recvmmsg                => 337,
        fanotify_init           => 338,
        fanotify_mark           => 339,
        prlimit                 => 340,     prlimit64               => 340,
        name_to_handle_at       => 341,
        open_by_handle_at       => 342,
        clock_adjtime           => 343,
        syncfs                  => 344,
        sendmmsg                => 345,
        setns                   => 346,
        process_vm_readv        => 347,
        process_vm_writev       => 348,
        kcmp                    => 349,
        finit_module            => 350,
        sched_setattr           => 351,
        sched_getattr           => 352,
        renameat2               => 353,
        seccomp                 => 354,

);

our %pack_map = (

        adjtimex => 'Lx4q4lx4q3q2q3lx4q5lx44',
                    # modes offset freq maxerror esterror status constant precision
                    # tolerance timenow tick ppsfreq jitter shift stabil jitcnt
                    # calcnt errcnt stbcnt tai; everything except modes is signed

        time_t   => 'L',    # seconds
        timespec => 'LL',   # seconds, nanoseconds
        timeval  => 'LL',   # seconds, microseconds

);

our @EXPORT = qw(

    %pack_map
    %syscall_map

    unpack_dent

);

1;
