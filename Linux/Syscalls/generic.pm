#! /module/for/perl

use strict;
use warnings;

package Linux::Syscalls::generic;

# Generic variables, constants, and methods, which are architecture-
# independent, or common to the majority of architectures.

use Exporter 'import';

use Config;

our $have_MMU = 1;
our $m32 = ! $Config{use64bitint};
our $use_32bit_off_t = 0;
our $use_arch_want_sync_file_range2 = 0;
our $use_arch_want_syscall_deprecated = 0;
our $use_arch_want_syscall_no_at = 0;
our $use_arch_want_syscall_no_flags = 0;
our $use_arch_want_time32_syscalls = 0;
our $use_syscall_compat = 0;

sub __SYSCALL {
    my ($nr, $name) = @_;
    $name =~ s/^__NR_//;
    $name =~ s/^compat_//;
    $name =~ s/^sys_//;
    return $name => $nr;
}

sub __SC_3264 {
    my ($_nr, $_32, $_64) = @_;
    if ($m32) {
        return __SYSCALL($_nr, $_32);
    } else {
        return __SYSCALL($_nr, $_64);
    }
}

#if __BITS_PER_LONG == 32 || defined(__SYSCALL_COMPAT)
#define __SC_3264(_nr, _32, _64) __SYSCALL(_nr, _32)
#else
#define __SC_3264(_nr, _32, _64) __SYSCALL(_nr, _64)
#endif

#ifdef __SYSCALL_COMPAT
#define __SC_COMP(_nr, _sys, _comp) __SYSCALL(_nr, _comp)
#define __SC_COMP_3264(_nr, _32, _64, _comp) __SYSCALL(_nr, _comp)
#else
#define __SC_COMP(_nr, _sys, _comp) __SYSCALL(_nr, _sys)
#define __SC_COMP_3264(_nr, _32, _64, _comp) __SC_3264(_nr, _32, _64)
#endif

our %syscall_map = (

        # FROM /usr/include/asm-generic/unistd.h
        #
        # This file contains the system call numbers, based on the
        # layout of the x86-64 architecture, which embeds the
        # pointer to the syscall in the table.
        #
        # As a basic principle, no duplication of functionality
        # should be added, e.g. we don't use lseek when llseek
        # is present. New architectures should use this file
        # and implement the less feature-full calls in user space.
        #
        # CC denotes "COMPAT" mode
        #
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
        ($m32 ? 'fcntl64'
              : 'fcntl')        => 25,
        CCfcntl64               => 25,
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
        umount                  => 39,
        mount                   => 40,
        pivot_root              => 41,
        ## fs/nfsctl.c
        ni_syscall              => 42,
        ## fs/open.c
        ($m32 ? 'statfs64'
              : 'statfs')       => 43,
        CCstatfs64              => 43,
        ($m32 ? 'fstatfs64'
              : 'fstatfs')      => 44,
        CCfstatfs64             => 44,
        ($m32 ? 'truncate64'
              : 'truncate')     => 45,
        CCtruncate64            => 45,
        ($m32 ? 'ftruncate64'
              : 'ftruncate')    => 46,
        CCftruncate64           => 46,
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
        getdents64              => 61,
        ## fs/read_write.c
        ($m32 ? 'llseek'
              : 'lseek')        => 62,  # lseek64
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
        pselect6                => 72,
        ppoll                   => 73,
        ## fs/signalfd.c
        signalfd4               => 74,
        ## fs/splice.c
        vmsplice                => 75,
        splice                  => 76,
        tee                     => 77,
        ## fs/stat.c
        readlinkat              => 78,
        ($m32 ? 'fstatat64'
              : 'newfstatat')     => 79,
        ($m32 ? 'fstat64'
              : 'newfstat')     => 80,
        ## fs/sync.c
        sync                    => 81,
        fsync                   => 82,
        fdatasync               => 83,
    $use_arch_want_sync_file_range2 ? (
        sync_file_range2        => 84,
    ) : (
        sync_file_range         => 84,
    ),
        ## fs/timerfd.c
        timerfd_create          => 85,
        timerfd_settime         => 86,
        timerfd_gettime         => 87,
        ## fs/utimes.c
        utimensat               => 88,
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
        futex                   => 98,
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
        timer_gettime32         => 108,
        timer_getoverrun        => 109,
        timer_settime32         => 110,
        timer_delete            => 111,
        clock_settime32         => 112,
        clock_gettime32         => 113,
        clock_getres            => 114,
        clock_nanosleep         => 115,
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
        sched_rr_get_interval   => 127,
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
        rt_sigtimedwait         => 137,
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
        newuname                => 160,
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
        mq_timedsend            => 182,
        mq_timedreceive         => 183,
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
        semtimedop              => 192,
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
        ($m32 ? 'mmap2'
              : 'mmap')         => 222,
        ## mm/fadvise.c
        fadvise64_64            => 223,
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
        recvmmsg                => 243,

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
        clock_adjtime           => 266,
        syncfs                  => 267,
        setns                   => 268,
        sendmmsg                => 269,
        process_vm_readv        => 270,
        process_vm_writev       => 271,
        kcmp                    => 272,
        finit_module            => 273,
        ni_syscall              => 274,
        ni_syscall              => 275,
        ni_syscall              => 276,
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
        $use_arch_want_time32_syscalls || ! $m32 ? (
#if defined(__ARCH_WANT_TIME32_SYSCALLS) || __BITS_PER_LONG != 32
        ($m32 ? 'io_pgetevents' : 'io_pgetevents_time32')
                                => 292,
        #__SC_COMP_3264(__NR_io_pgetevents, sys_io_pgetevents_time32, sys_io_pgetevents, compat_sys_io_pgetevents)
#endif
        ) : (),

        rseq                    => 293,
        kexec_file_load         => 294,

        ## 295 through 402 are unassigned to sync up with generic numbers, don't use

#if __BITS_PER_LONG == 32
    $m32 ? (
        clock_gettime           => 403,     clock_gettime64         => 403,
        clock_settime           => 404,     clock_settime64         => 404,
        clock_adjtime           => 405,     clock_adjtime64         => 405,
        clock_getres            => 406,     clock_getres_t64        => 406,
        clock_nanosleep         => 407,     clock_nanosleep_t64     => 407,
        timer_gettime           => 408,     timer_gettime64         => 408,
        timer_settime           => 409,     timer_settime64         => 409,
        timerfd_gettime         => 410,     timerfd_gettime64       => 410,
        timerfd_settime         => 411,     timerfd_settime64       => 411,
        utimensat               => 412,     utimensat_t64           => 412,
        pselect6                => 413,     pselect6_t64            => 413,
        ppoll                   => 414,     ppoll_t64               => 414,
        io_pgetevents           => 416,     io_pgetevents_t64       => 416,
        recvmmsg                => 417,     recvmmsg_t64            => 417,
        mq_timedsend            => 418,     mq_timedsend_t64        => 418,
        mq_timedreceive         => 419,     mq_timedreceive_t64     => 419,
        semtimedop              => 420,     semtimedop_t64          => 420,
        rt_sigtimedwait         => 421,     rt_sigtimedwait_t64     => 421,
        futex                   => 422,     futex_t64               => 422,
        sched_rr_get_interval   => 423,     sched_rr_get_interval_t64 => 423,
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
        # All syscalls below here should go away really,
        # these are provided for both review and as a porting
        # help for the C library version.
        #
        # Last chance: are any of these important enough to
        # enable by default?
        #
    $use_arch_want_syscall_no_at ? (
        open                    => 1024,
        link                    => 1025,
        unlink                  => 1026,
        mknod                   => 1027,
        chmod                   => 1028,
        chown                   => 1029,
        mkdir                   => 1030,
        rmdir                   => 1031,
        lchown                  => 1032,
        access                  => 1033,
        rename                  => 1034,
        readlink                => 1035,
        symlink                 => 1036,
        utimes                  => 1037,
        ($m32 ? 'stat64'
              : 'newstat')      => 1038,
        ($m32 ? 'lstat64'
              : 'newlstat')     => 1039,
    ) : (),
    $use_arch_want_syscall_no_flags ? (
        pipe                    => 1040,
        dup2                    => 1041,
        epoll_create            => 1042,
        inotify_init            => 1043,
        eventfd                 => 1044,
        signalfd                => 1045,
    ) : (),
    $m32 && $use_32bit_off_t ? ( ## 32 bit off_t syscalls
        sendfile                => 1046,
        ftruncate               => 1047,
        truncate                => 1048,
        newstat                 => 1049,
        newlstat                => 1050,
        newfstat                => 1051,
        fcntl                   => 1052,
        fadvise64               => 1053,
        newfstatat              => 1054,
        fstatfs                 => 1055,
        statfs                  => 1056,
        lseek                   => 1057,
        mmap                    => 1058,
    ) : (),
    $use_arch_want_syscall_deprecated ? (
        alarm                   => 1059,
        getpgrp                 => 1060,
        pause                   => 1061,
        time                    => 1062,
        utime                   => 1063,
        creat                   => 1064,
        getdents                => 1065,
        futimesat               => 1066,
        select                  => 1067,
        poll                    => 1068,
        epoll_wait              => 1069,
        ustat                   => 1070,
        vfork                   => 1071,
        wait4                   => 1072,
        recv                    => 1073,
        send                    => 1074,
        bdflush                 => 1075,
        oldumount               => 1076,
        uselib                  => 1077,
        sysctl                  => 1078,
      $have_MMU ? (
        fork                    => 1079,
      ) : (
    #   ni_syscall              => 1079,  # not-implemented
      ),
    ) : (), ## $use_arch_want_syscall_deprecated
);

our %pack_map = (
    time_t   => 'q',
    timespec => 'qLx![q]',
    timeval  => 'qLx![q]',
);

our @EXPORT = qw(

    $have_MMU
    $m32
    $use_32bit_off_t
    $use_arch_want_sync_file_range2
    $use_arch_want_syscall_deprecated
    $use_arch_want_syscall_no_at
    $use_arch_want_syscall_no_flags

    %syscall_map
    %pack_map

);

1;
