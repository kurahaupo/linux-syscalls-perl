#! /module/for/perl

use strict;
use warnings;

package Linux::Syscalls::generic;

# Generic variables, constants, and methods, which are architecture-
# independent, or common to the majority of architectures.

use Exporter 'import';

use Config;

our $have_MMU = 1;
our $m32 = ! $Config{use64bitint};              # in 32-bit mode
our $use_32bit_off_t = $m32;
our $use_32bit_time_t = 0;                      # only on very old Linux (effectively never)
our $use_arch_want_sync_file_range_padding_arg = 0; # only ARM & PowerPC, and only 32-bit
our $use_arch_want_syscall_deprecated = 0;
our $use_arch_want_syscall_without_at = 0;      # fstat etc (in addition to fstatat)
our $use_arch_want_syscall_without_flags = 0;

# In older architectures there are groups of syscalls (each with their own name
# and number) that all perform substantially the same task, but the newer
# syscalls have additional options or wider arguments. Generally the newest of
# such a group is "maximal", having the most features and/or widest arguments.
#
# Linux porting policy suggest that only the maximal syscall of each such group
# be included in the generic syscalls list, with the other names provided by
# libc wrappers. Generally that maximal syscall is the only one we actually
# use, and the name chosen here reflects that.
#
# Most of these names are merely placeholders until the relevant functions are
# written and ported to each platform, at which point these choices will be
# re-assessed, guided by compatibility with syscall.pl.
#
# Where versions with narrower arguments are enabled, they generally have a
# width suffix added.

our %syscall_map = (

        # FROM /usr/include/asm-generic/unistd.h

        io_setup                => 0,
        io_destroy              => 1,
        io_submit               => 2,
        io_cancel               => 3,
        io_getevents            => 4,
        ## fs/xattr.c
        setxattr                => 5,
        lsetxattr               => 6,
        fsetxattr               => 7,
        getxattr                => 8,
        lgetxattr               => 9,
        fgetxattr               => 10,
        listxattr               => 11,
        llistxattr              => 12,
        flistxattr              => 13,
        removexattr             => 14,
        lremovexattr            => 15,
        fremovexattr            => 16,
        ## fs/dcache.c
        getcwd                  => 17,
        ## fs\/cookies.c
        lookup_dcookie          => 18,
        ## fs/eventfd.c
        eventfd2                => 19,
        ## fs/eventpoll.c
        epoll_create1           => 20,
        epoll_ctl               => 21,
        epoll_pwait             => 22,
        ## fs/fcntl.c
        dup                     => 23,
        dup3                    => 24,
        fcntl                   => 25,      fcntl64                 => 25,
        ## fs/inotify_user.c
        inotify_init1           => 26,
        inotify_add_watch       => 27,
        inotify_rm_watch        => 28,
        ## fs/ioctl.c
        ioctl                   => 29,
        ## fs/ioprio.c
        ioprio_set              => 30,
        ioprio_get              => 31,
        ## fs/locks.c
        flock                   => 32,
        ## fs/namei.c
        mknodat                 => 33,
        mkdirat                 => 34,
        unlinkat                => 35,
        symlinkat               => 36,
        linkat                  => 37,
        renameat                => 38,
        ## fs/namespace.c
        umount2                 => 39,      # umount(P) ⇒ umount2(P,0)
        mount                   => 40,
        pivot_root              => 41,
        ## fs/nfsctl.c
    #   not_implemented_42      => 42,
        ## fs/open.c
        statfs                  => 43,      statfs64                => 43,
        fstatfs                 => 44,      fstatfs64               => 44,
        truncate                => 45,      truncate64              => 45,
        ftruncate               => 46,      ftruncate64             => 46,
        fallocate               => 47,
        faccessat               => 48,
        chdir                   => 49,
        fchdir                  => 50,
        chroot                  => 51,
        fchmod                  => 52,
        fchmodat                => 53,
        fchownat                => 54,
        fchown                  => 55,
        openat                  => 56,
        close                   => 57,
        vhangup                 => 58,
        ## fs/pipe.c
        pipe2                   => 59,
        ## fs/quota.c
        quotactl                => 60,
        ## fs/readdir.c
        getdents                => 61,      getdents64              => 61,
        ## fs/read_write.c
        lseek                   => 62,      lseek64                 => 62,      llseek                  => 62,
        read                    => 63,
        write                   => 64,
        readv                   => 65,
        writev                  => 66,
        pread64                 => 67,
        pwrite64                => 68,
        preadv                  => 69,
        pwritev                 => 70,
        ## fs/sendfile.c
        sendfile64              => 71,
        ## fs/select.c
        pselect6                => 72,      pselect64               => 72,      # unless in 32-bit mode; actual syscall is pselect6, which modifies the timeout even on EINTR
        ppoll                   => 73,      ppoll64                 => 73,      # unless in 32-bit mode
        ## fs/signalfd.c
        signalfd4               => 74,
        ## fs/splice.c
        vmsplice                => 75,
        splice                  => 76,
        tee                     => 77,
        ## fs/stat.c
        readlinkat              => 78,
        fstatat                 => 79,      fstatat64               => 79,
        fstat                   => 80,      fstat64                 => 80,
        ## fs/sync.c
        sync                    => 81,
        fsync                   => 82,
        fdatasync               => 83,
        sync_file_range         => 84,      # for 32-bit on ARM & PowerPC this might be sync_file_range2 (to allow for padding arg)
        ## fs/timerfd.c
        timerfd_create          => 85,
        timerfd_settime         => 86,      timerfd_settime64       => 86,      # unless in 32-bit mode
        timerfd_gettime         => 87,      timerfd_gettime64       => 87,      # unless in 32-bit mode
        ## fs/utimes.c
        utimensat               => 88,      utimensat64             => 88,      # unless in 32-bit mode
        ## kernel/acct.c
        acct                    => 89,
        ## kernel/capability.c
        capget                  => 90,
        capset                  => 91,
        ## kernel/exec_domain.c
        personality             => 92,
        ## kernel/exit.c
        exit                    => 93,
        exit_group              => 94,
        waitid                  => 95,
        ## kernel/fork.c
        set_tid_address         => 96,
        unshare                 => 97,
        ## kernel/futex.c
        futex                   => 98,      futex64                 => 98,      # unless in 32-bit-mode
        set_robust_list         => 99,
        get_robust_list         => 100,
        ## kernel/hrtimer.c
        nanosleep               => 101,
        ## kernel/itimer.c
        getitimer               => 102,
        setitimer               => 103,
        ## kernel/kexec.c
        kexec_load              => 104,
        ## kernel/module.c
        init_module             => 105,
        delete_module           => 106,
        ## kernel/posix-timers.c
        timer_create            => 107,
        timer_gettime           => 108,     timer_gettime64         => 108,     # unless in 32-bit mode
        timer_getoverrun        => 109,
        timer_settime           => 110,     timer_settime64         => 110,     # unless in 32-bit mode
        timer_delete            => 111,
        clock_settime           => 112,     clock_settime64         => 112,     # unless in 32-bit mode
        clock_gettime           => 113,     clock_gettime64         => 113,     # unless in 32-bit mode
        clock_getres            => 114,     clock_getres64          => 114,     # unless in 32-bit mode
        clock_nanosleep         => 115,     clock_nanosleep64       => 115,     # unless in 32-bit mode
        ## kernel/printk.c
        syslog                  => 116,
        ## kernel/ptrace.c
        ptrace                  => 117,
        ## kernel/sched/core.c
        sched_setparam          => 118,
        sched_setscheduler      => 119,
        sched_getscheduler      => 120,
        sched_getparam          => 121,
        sched_setaffinity       => 122,
        sched_getaffinity       => 123,
        sched_yield             => 124,
        sched_get_priority_max  => 125,
        sched_get_priority_min  => 126,
        sched_rr_get_interval   => 127,     sched_rr_get_interval64 => 127,     # unless in 32-bit-mode
        ## kernel/signal.c
        restart_syscall         => 128,
        kill                    => 129,
        tkill                   => 130,
        tgkill                  => 131,
        sigaltstack             => 132,
        rt_sigsuspend           => 133,
        rt_sigaction            => 134,
        rt_sigprocmask          => 135,
        rt_sigpending           => 136,
        rt_sigtimedwait         => 137,     rt_sigtimedwait64       => 137,     # unless in 32-bit-mode
        rt_sigqueueinfo         => 138,
        rt_sigreturn            => 139,
        ## kernel/sys.c
        setpriority             => 140,
        getpriority             => 141,
        reboot                  => 142,
        setregid                => 143,
        setgid                  => 144,
        setreuid                => 145,
        setuid                  => 146,
        setresuid               => 147,
        getresuid               => 148,
        setresgid               => 149,
        getresgid               => 150,
        setfsuid                => 151,
        setfsgid                => 152,
        times                   => 153,
        setpgid                 => 154,
        getpgid                 => 155,
        getsid                  => 156,
        setsid                  => 157,
        getgroups               => 158,
        setgroups               => 159,
        uname                   => 160,
        sethostname             => 161,
        setdomainname           => 162,
        getrlimit               => 163,
        setrlimit               => 164,
        getrusage               => 165,
        umask                   => 166,
        prctl                   => 167,
        getcpu                  => 168,
        ## kernel/time.c
        gettimeofday            => 169,
        settimeofday            => 170,
        adjtimex                => 171,
        ## kernel/timer.c
        getpid                  => 172,
        getppid                 => 173,
        getuid                  => 174,
        geteuid                 => 175,
        getgid                  => 176,
        getegid                 => 177,
        gettid                  => 178,
        sysinfo                 => 179,
        ## ipc/mqueue.c
        mq_open                 => 180,
        mq_unlink               => 181,
        mq_timedsend            => 182,     mq_timedsend64          => 182,     # unless in 32-bit-mode
        mq_timedreceive         => 183,     mq_timedreceive64       => 183,     # unless in 32-bit-mode
        mq_notify               => 184,
        mq_getsetattr           => 185,
        ## ipc/msg.c
        msgget                  => 186,
        msgctl                  => 187,
        msgrcv                  => 188,
        msgsnd                  => 189,
        ## ipc/sem.c
        semget                  => 190,
        semctl                  => 191,
        semtimedop              => 192,     semtimedop64            => 192,     # unless in 32-bit-mode
        semop                   => 193,
        ## ipc/shm.c
        shmget                  => 194,
        shmctl                  => 195,
        shmat                   => 196,
        shmdt                   => 197,
        ## net/socket.c
        socket                  => 198,
        socketpair              => 199,
        bind                    => 200,
        listen                  => 201,
        accept                  => 202,
        connect                 => 203,
        getsockname             => 204,
        getpeername             => 205,
        sendto                  => 206,
        recvfrom                => 207,
        setsockopt              => 208,
        getsockopt              => 209,
        shutdown                => 210,
        sendmsg                 => 211,
        recvmsg                 => 212,
        ## mm/filemap.c
        readahead               => 213,
        ## mm/nommu.c, also with MMU
        brk                     => 214,
        munmap                  => 215,
        mremap                  => 216,
        ## security/keys/keyctl.c
        add_key                 => 217,
        request_key             => 218,
        keyctl                  => 219,
        ## arch/example/kernel/sys_example.c
        clone                   => 220,
        execve                  => 221,
        # Syscall 222 implements two different syscalls, depending on the
        # architecture:
        #   → on 32-bit platforms (with 32-bit off_t and 64-bit loff_t), the file offset is in
        #     PAGES, as documented in "man mmap2";
        #   → on 64-bit platforms (with 64-bit off_t), the file offset is (as
        #     usual) in bytes, as documented in "man mmap".
    $use_32bit_off_t ? (
        mmap2                   => 222,
    ) : (
        mmap                    => 222,
    ),
        ## mm/fadvise.c
        fadvise                 => 223,     fadvise64               => 223,     # (note strange naming of the fadvise syscall, either fadvise64 or fadvise64_64)
    $have_MMU ? (
        swapon                  => 224,
        swapoff                 => 225,
        mprotect                => 226,
        msync                   => 227,
        mlock                   => 228,
        munlock                 => 229,
        mlockall                => 230,
        munlockall              => 231,
        mincore                 => 232,
        madvise                 => 233,
        remap_file_pages        => 234,
        mbind                   => 235,
        get_mempolicy           => 236,
        set_mempolicy           => 237,
        migrate_pages           => 238,
        move_pages              => 239,
    ) : (),
        rt_tgsigqueueinfo       => 240,
        perf_event_open         => 241,
        accept4                 => 242,
        recvmmsg                => 243,     recvmmsg64              => 243,     # unless in 32-bit-mode

        #define __NR_arch_specific_syscall 244
        #
        # Architectures may provide up to 16 syscalls of their own
        # starting with this value.
        #

        wait4                   => 260,
        prlimit64               => 261,
        fanotify_init           => 262,
        fanotify_mark           => 263,
        name_to_handle_at       => 264,
        open_by_handle_at       => 265,
        clock_adjtime           => 266,     clock_adjtime64         => 266,     # unless in 32-bit mode
        syncfs                  => 267,
        setns                   => 268,
        sendmmsg                => 269,
        process_vm_readv        => 270,
        process_vm_writev       => 271,
        kcmp                    => 272,
        finit_module            => 273,
    #   not_implemented_274     => 274,
    #   not_implemented_275     => 275,
    #   not_implemented_276     => 276,
        seccomp                 => 277,

        getrandom               => 278,
        memfd_create            => 279,
        bpf                     => 280,
        execveat                => 281,
        userfaultfd             => 282,
        membarrier              => 283,
        mlock2                  => 284,
        copy_file_range         => 285,
        preadv2                 => 286,
        pwritev2                => 287,
        pkey_mprotect           => 288,
        pkey_alloc              => 289,
        pkey_free               => 290,
        statx                   => 291,
        io_pgetevents           => 292,     io_pgetevents64         => 292,     # unless in 32-bit mode
        rseq                    => 293,
        kexec_file_load         => 294,

        ## 295 through 402 are unassigned to sync up with generic numbers, don't use

#if __BITS_PER_LONG == 32
    $m32 ? (
        # Only present in later versions of /usr/include/asm-generic/unistd.h
        clock_gettime           => 403,     clock_gettime64         => 403,     clock_gettime32         => 113,
        clock_settime           => 404,     clock_settime64         => 404,     clock_settime32         => 112,
        clock_adjtime           => 405,     clock_adjtime64         => 405,     clock_adjtime32         => 266,
        clock_getres            => 406,     clock_getres64          => 406,     clock_getres32          => 114, # __NR_clock_getres_time64=406
        clock_nanosleep         => 407,     clock_nanosleep64       => 407,     clock_nanosleep32       => 115,
        timer_gettime           => 408,     timer_gettime64         => 408,     timer_gettime32         => 108,
        timer_settime           => 409,     timer_settime64         => 409,     timer_settime32         => 110,
        timerfd_gettime         => 410,     timerfd_gettime64       => 410,     timerfd_gettime32       => 87,
        timerfd_settime         => 411,     timerfd_settime64       => 411,     timerfd_settime32       => 86,
        utimensat               => 412,     utimensat64             => 412,     utimensat32             => 88,
        pselect6                => 413,     pselect64               => 413,     pselect32               => 72,
        ppoll                   => 414,     ppoll64                 => 414,     ppoll                   => 73,
        io_pgetevents           => 416,     io_pgetevents64         => 416,     io_pgetevents32         => 292,
        recvmmsg                => 417,     recvmmsg64              => 417,     recvmmsg32              => 243,
        mq_timedsend            => 418,     mq_timedsend64          => 418,     mq_timedsend32          => 182,
        mq_timedreceive         => 419,     mq_timedreceive64       => 419,     mq_timedreceive32       => 183,
        semtimedop              => 420,     semtimedop64            => 420,     semtimedop32            => 192,
        rt_sigtimedwait         => 421,     rt_sigtimedwait64       => 421,     rt_sigtimedwait32       => 137,
        futex                   => 422,     futex64                 => 422,     futex32                 => 98,
        sched_rr_get_interval   => 423,     sched_rr_get_interval64 => 423,     sched_rr_get_interval32 => 127, # __NR_sched_rr_get_interval_time64=423
    ) : (),
#endif

        pidfd_send_signal       => 424,
        io_uring_setup          => 425,
        io_uring_enter          => 426,
        io_uring_register       => 427,
        open_tree               => 428,
        move_mount              => 429,
        fsopen                  => 430,
        fsconfig                => 431,
        fsmount                 => 432,
        fspick                  => 433,
        pidfd_open              => 434,
#ifdef __ARCH_WANT_SYS_CLONE3
        clone3                  => 435,
#endif
        close_range             => 436,

        openat2                 => 437,
        pidfd_getfd             => 438,
        faccessat2              => 439,
        process_madvise         => 440,
        epoll_pwait2            => 441,
        mount_setattr           => 442,
        quotactl_fd             => 443,

        landlock_create_ruleset => 444,
        landlock_add_rule       => 445,
        landlock_restrict_self  => 446,

#ifdef __ARCH_WANT_MEMFD_SECRET
        memfd_secret            => 447,
#endif
        process_mrelease        => 448,

        # Last+1
        __NR_syscalls           => 449,

        #
        # Linux porting guidelines suggest that all the following syscalls
        # should be omitted when porting to a new architecture.
        #
    $use_arch_want_syscall_without_at ? (
        open                    => 1024,    # use openat2 instead
        link                    => 1025,    # use linkat instead
        unlink                  => 1026,    # use unlinkat instead
        mknod                   => 1027,    # use mknodat instead
        chmod                   => 1028,    # use fchmodat instead
        chown                   => 1029,    # use fchownat instead
        mkdir                   => 1030,    # use mkdirat instead
        rmdir                   => 1031,    # use unlinkat with AT_REMOVEDIR instead
        lchown                  => 1032,    # use fchownat with AT_SYMLINK_NOFOLLOW instead
        access                  => 1033,    # use faccessat instead
        rename                  => 1034,    # use renameat instead
        readlink                => 1035,    # use readlinkat instead
        symlink                 => 1036,    # use symlinkat instead
        utimes                  => 1037,    # use futimesat instead (or utimensat, converting from nanoseconds)
        stat64                  => 1038,    # use fstatat instead
        lstat64                 => 1039,    # use fstatat with AT_SYMLINK_NOFOLLOW instead
    ) : (),
    $use_arch_want_syscall_without_flags ? (
        pipe                    => 1040,    # use pipe2 instead
        dup2                    => 1041,    # use dup3 instead
        epoll_create            => 1042,    # use epoll_create1 instead
        inotify_init            => 1043,    # use inotify_init1 instead
        eventfd                 => 1044,    # use eventfd2 instead
        signalfd                => 1045,    # use signalfd4 instead
    ) : (),
    $use_32bit_off_t ? ( ## 32 bit off_t syscalls
        sendfile32              => 1046,    # ⎫
        ftruncate32             => 1047,    # ⎮
        truncate32              => 1048,    # ⎮
        stat32                  => 1049,    # ⎮     (aka newstat)
        lstat32                 => 1050,    # ⎮     (aka newlstat)
        fstat32                 => 1051,    # ⎮     (aka newfstat)
        fcntl32                 => 1052,    # ⎬ use 64-bit versions instead
        fadvise32               => 1053,    # ⎮     (note strange naming of the fadvise syscall, either fadvise64 or fadvise64_64)
        fstatat32               => 1054,    # ⎮     (aka newfstatat)
        fstatfs32               => 1055,    # ⎮
        statfs32                => 1056,    # ⎮
        lseek32                 => 1057,    # ⎭
        mmap32                  => 1058,    # use mmap2 instead (which take a 32-bit page offset rather than a byte offset, up to 16 TiB)
    ) : (),
    $use_arch_want_syscall_deprecated ? (
        alarm                   => 1059,    # use a timer instead
        getpgrp                 => 1060,    # use getpgid instead
        pause                   => 1061,    # use sigsuspend instead
        time                    => 1062,    # use clock_gettime with CLOCK_REALTIME instead
        utime                   => 1063,    # use utimensat instead
        creat                   => 1064,    # use openat with O_CREAT instead
        getdents32              => 1065,    # use getdents64 instead
        futimesat               => 1066,    # use utimensat instead
        select                  => 1067,    # use epoll_* or pselect6 or ppoll instead
        poll                    => 1068,    # use epoll_* or pselect6 or ppoll instead
        epoll_wait              => 1069,    # use epoll_pwait instead
        ustat                   => 1070,    # use statfs instead
        vfork                   => 1071,    # use clone or clone3 instead
        wait4                   => 1072,    # use waitid instead
        recv                    => 1073,    # use recvfrom or recvmsg instead
        send                    => 1074,    # use sendto or sendmsg instead
        bdflush                 => 1075,    # no-op (delete rather than replace)
    #   oldumount               => 1076,    # use umount2
        uselib                  => 1077,
        sysctl                  => 1078,
    ) : (), ## $use_arch_want_syscall_deprecated
    $have_MMU && $use_arch_want_syscall_deprecated ? (
        fork                    => 1079,    # use clone or clone3 instead
    ) : (),
);

our %pack_map = (
    time_t   => 'q',
    timespec => 'qLx![q]',
    timeval  => 'qLx![q]',
);

our @EXPORT_OK = qw(
    $have_MMU
    $m32
    $use_32bit_off_t
    $use_32bit_time_t
    $use_arch_want_sync_file_range_padding_arg
    $use_arch_want_syscall_deprecated
    $use_arch_want_syscall_without_at
    $use_arch_want_syscall_without_flags
);

our @EXPORT = qw(
    %syscall_map
    %pack_map
);

1;
