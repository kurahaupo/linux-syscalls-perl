#! /module/for/perl

use strict;
use warnings;

package Linux::Syscalls::x86_64;

use Config;
use Exporter 'import';

#
# This file supports x86_64 in both 64-bit and 32-bit modes.
#
# The 32-bit mode is untested because I've yet to obtain a version of Perl
# compiled with '-mx32'. If you have one, please let me know.
#
# Alternative names are available for some syscalls:
#   fadvise                 ← fadvise64
#   fstatat                 ← newfstatat
#   getdents                ← getdents64
#   prlimit                 ← prlimit64
#

# On x86 platforms, the choice of architecture is given by this logic (in
# /usr/include/x86_64-linux-gnu/asm/unistd.h):
#   ifdef __i386__
#    include <asm/unistd_32.h>   /* ia32 */
#   elif defined(__ILP32__)
#    include <asm/unistd_x32.h>  /* x86_32 */
#   else
#    include <asm/unistd_64.h>   /* x86_64 */
#   endif

my $x32 = $Config{ptrsize} == 4;   # normally 8

use constant { X32_SYSCALL_BIT => 0x40000000 };    # 1 << 30

our %syscall_map = (

        # FROM /usr/include/x86_64-linux-gnu/asm/unistd_64.h

        read                    =>   0,
        write                   =>   1,
        open                    =>   2,
        close                   =>   3,
        stat                    =>   4,
        fstat                   =>   5,
        lstat                   =>   6,
        poll                    =>   7,
        lseek                   =>   8,
        mmap                    =>   9,
        mprotect                =>  10,
        munmap                  =>  11,
        brk                     =>  12,
        rt_sigaction            =>  13,  ## for x86_32 replaced by call #512
        rt_sigprocmask          =>  14,
        rt_sigreturn            =>  15,  ## for x86_32 replaced by call #513
        ioctl                   =>  16,  ## for x86_32 replaced by call #514
        pread64                 =>  17,
        pwrite64                =>  18,
        readv                   =>  19,  ## for x86_32 replaced by call #515
        writev                  =>  20,  ## for x86_32 replaced by call #516
        access                  =>  21,
        pipe                    =>  22,
        select                  =>  23,
        sched_yield             =>  24,
        mremap                  =>  25,
        msync                   =>  26,
        mincore                 =>  27,
        madvise                 =>  28,
        shmget                  =>  29,
        shmat                   =>  30,
        shmctl                  =>  31,
        dup                     =>  32,
        dup2                    =>  33,
        pause                   =>  34,
        nanosleep               =>  35,
        getitimer               =>  36,
        alarm                   =>  37,
        setitimer               =>  38,
        getpid                  =>  39,
        sendfile                =>  40,
        socket                  =>  41,
        connect                 =>  42,
        accept                  =>  43,
        sendto                  =>  44,
        recvfrom                =>  45,  ## for x86_32 replaced by call #517
        sendmsg                 =>  46,  ## for x86_32 replaced by call #518
        recvmsg                 =>  47,  ## for x86_32 replaced by call #519
        shutdown                =>  48,
        bind                    =>  49,
        listen                  =>  50,
        getsockname             =>  51,
        getpeername             =>  52,
        socketpair              =>  53,
        setsockopt              =>  54,  ## for x86_32 replaced by call #541
        getsockopt              =>  55,  ## for x86_32 replaced by call #542
        clone                   =>  56,
        fork                    =>  57,
        vfork                   =>  58,
        execve                  =>  59,  ## for x86_32 replaced by call #520
        exit                    =>  60,
        wait4                   =>  61,
        kill                    =>  62,
        uname                   =>  63,
        semget                  =>  64,
        semop                   =>  65,
        semctl                  =>  66,
        shmdt                   =>  67,
        msgget                  =>  68,
        msgsnd                  =>  69,
        msgrcv                  =>  70,
        msgctl                  =>  71,
        fcntl                   =>  72,
        flock                   =>  73,
        fsync                   =>  74,
        fdatasync               =>  75,
        truncate                =>  76,
        ftruncate               =>  77,
        getdents                =>  78,
        getcwd                  =>  79,
        chdir                   =>  80,
        fchdir                  =>  81,
        rename                  =>  82,
        mkdir                   =>  83,
        rmdir                   =>  84,
        creat                   =>  85,
        link                    =>  86,
        unlink                  =>  87,
        symlink                 =>  88,
        readlink                =>  89,
        chmod                   =>  90,
        fchmod                  =>  91,
        chown                   =>  92,
        fchown                  =>  93,
        lchown                  =>  94,
        umask                   =>  95,
        gettimeofday            =>  96,
        getrlimit               =>  97,
        getrusage               =>  98,
        sysinfo                 =>  99,
        times                   => 100,
        ptrace                  => 101,  ## for x86_32 replaced by call #521
        getuid                  => 102,
        syslog                  => 103,
        getgid                  => 104,
        setuid                  => 105,
        setgid                  => 106,
        geteuid                 => 107,
        getegid                 => 108,
        setpgid                 => 109,
        getppid                 => 110,
        getpgrp                 => 111,
        setsid                  => 112,
        setreuid                => 113,
        setregid                => 114,
        getgroups               => 115,
        setgroups               => 116,
        setresuid               => 117,
        getresuid               => 118,
        setresgid               => 119,
        getresgid               => 120,
        getpgid                 => 121,
        setfsuid                => 122,
        setfsgid                => 123,
        getsid                  => 124,
        capget                  => 125,
        capset                  => 126,
        rt_sigpending           => 127,  ## for x86_32 replaced by call #522
        rt_sigtimedwait         => 128,  ## for x86_32 replaced by call #523
        rt_sigqueueinfo         => 129,  ## for x86_32 replaced by call #524
        rt_sigsuspend           => 130,
        sigaltstack             => 131,  ## for x86_32 replaced by call #525
        utime                   => 132,
        mknod                   => 133,
        uselib                  => 134, # Only x86_64 - no x86_32 equivalent
        personality             => 135,
        ustat                   => 136,
        statfs                  => 137,
        fstatfs                 => 138,
        sysfs                   => 139,
        getpriority             => 140,
        setpriority             => 141,
        sched_setparam          => 142,
        sched_getparam          => 143,
        sched_setscheduler      => 144,
        sched_getscheduler      => 145,
        sched_get_priority_max  => 146,
        sched_get_priority_min  => 147,
        sched_rr_get_interval   => 148,
        mlock                   => 149,
        munlock                 => 150,
        mlockall                => 151,
        munlockall              => 152,
        vhangup                 => 153,
        modify_ldt              => 154,
        pivot_root              => 155,
        _sysctl                 => 156, # Only x86_64 - no x86_32 equivalent
        prctl                   => 157,
        arch_prctl              => 158,
        adjtimex                => 159,
        setrlimit               => 160,
        chroot                  => 161,
        sync                    => 162,
        acct                    => 163,
        settimeofday            => 164,
        mount                   => 165,
        umount2                 => 166,
        swapon                  => 167,
        swapoff                 => 168,
        reboot                  => 169,
        sethostname             => 170,
        setdomainname           => 171,
        iopl                    => 172,
        ioperm                  => 173,
        create_module           => 174, # Only x86_64 - no x86_32 equivalent
        init_module             => 175,
        delete_module           => 176,
        get_kernel_syms         => 177, # Only x86_64 - no x86_32 equivalent
        query_module            => 178, # Only x86_64 - no x86_32 equivalent
        quotactl                => 179,
        nfsservctl              => 180, # Only x86_64 - no x86_32 equivalent
        getpmsg                 => 181,
        putpmsg                 => 182,
        afs_syscall             => 183,
        tuxcall                 => 184,
        security                => 185,
        gettid                  => 186,
        readahead               => 187,
        setxattr                => 188,
        lsetxattr               => 189,
        fsetxattr               => 190,
        getxattr                => 191,
        lgetxattr               => 192,
        fgetxattr               => 193,
        listxattr               => 194,
        llistxattr              => 195,
        flistxattr              => 196,
        removexattr             => 197,
        lremovexattr            => 198,
        fremovexattr            => 199,
        tkill                   => 200,
        time                    => 201,
        futex                   => 202,
        sched_setaffinity       => 203,
        sched_getaffinity       => 204,
        set_thread_area         => 205, # Only x86_64 - no x86_32 equivalent
        io_setup                => 206,  ## for x86_32 replaced by call #543
        io_destroy              => 207,
        io_getevents            => 208,
        io_submit               => 209,  ## for x86_32 replaced by call #544
        io_cancel               => 210,
        get_thread_area         => 211, # Only x86_64 - no x86_32 equivalent
        lookup_dcookie          => 212,
        epoll_create            => 213,
        epoll_ctl_old           => 214, # Only x86_64 - no x86_32 equivalent
        epoll_wait_old          => 215, # Only x86_64 - no x86_32 equivalent
        remap_file_pages        => 216,
        getdents                => 217,     getdents64              => 217,
        set_tid_address         => 218,
        restart_syscall         => 219,
        semtimedop              => 220,
        fadvise                 => 221,     fadvise64               => 221,
        timer_create            => 222,  ## for x86_32 replaced by call #526
        timer_settime           => 223,
        timer_gettime           => 224,
        timer_getoverrun        => 225,
        timer_delete            => 226,
        clock_settime           => 227,
        clock_gettime           => 228,
        clock_getres            => 229,
        clock_nanosleep         => 230,
        exit_group              => 231,
        epoll_wait              => 232,
        epoll_ctl               => 233,
        tgkill                  => 234,
        utimes                  => 235,
        vserver                 => 236, # Only x86_64 - no x86_32 equivalent
        mbind                   => 237,
        set_mempolicy           => 238,
        get_mempolicy           => 239,
        mq_open                 => 240,
        mq_unlink               => 241,
        mq_timedsend            => 242,
        mq_timedreceive         => 243,
        mq_notify               => 244,  ## for x86_32 replaced by call #527
        mq_getsetattr           => 245,
        kexec_load              => 246,  ## for x86_32 replaced by call #528
        waitid                  => 247,  ## for x86_32 replaced by call #529
        add_key                 => 248,
        request_key             => 249,
        keyctl                  => 250,
        ioprio_set              => 251,
        ioprio_get              => 252,
        inotify_init            => 253,
        inotify_add_watch       => 254,
        inotify_rm_watch        => 255,
        migrate_pages           => 256,
        openat                  => 257,
        mkdirat                 => 258,
        mknodat                 => 259,
        fchownat                => 260,
        futimesat               => 261,
        fstatat                 => 262,     fstatat64               => 262,     newfstatat              => 262,
        unlinkat                => 263,
        renameat                => 264,
        linkat                  => 265,
        symlinkat               => 266,
        readlinkat              => 267,
        fchmodat                => 268,
        faccessat               => 269,
        pselect6                => 270,
        ppoll                   => 271,
        unshare                 => 272,
        set_robust_list         => 273,  ## for x86_32 replaced by call #530
        get_robust_list         => 274,  ## for x86_32 replaced by call #531
        splice                  => 275,
        tee                     => 276,
        sync_file_range         => 277,
        vmsplice                => 278,  ## for x86_32 replaced by call #532
        move_pages              => 279,  ## for x86_32 replaced by call #533
        utimensat               => 280,
        epoll_pwait             => 281,
        signalfd                => 282,
        timerfd_create          => 283,
        eventfd                 => 284,
        fallocate               => 285,
        timerfd_settime         => 286,
        timerfd_gettime         => 287,
        accept4                 => 288,
        signalfd4               => 289,
        eventfd2                => 290,
        epoll_create1           => 291,
        dup3                    => 292,
        pipe2                   => 293,
        inotify_init1           => 294,
        preadv                  => 295,  ## for x86_32 replaced by call #534
        pwritev                 => 296,  ## for x86_32 replaced by call #535
        rt_tgsigqueueinfo       => 297,  ## for x86_32 replaced by call #536
        perf_event_open         => 298,
        recvmmsg                => 299,  ## for x86_32 replaced by call #537
        fanotify_init           => 300,
        fanotify_mark           => 301,
        prlimit                 => 302,     prlimit64               => 302,
        name_to_handle_at       => 303,
        open_by_handle_at       => 304,
        clock_adjtime           => 305,
        syncfs                  => 306,
        sendmmsg                => 307,  ## for x86_32 replaced by call #538
        setns                   => 308,
        getcpu                  => 309,
        process_vm_readv        => 310,  ## for x86_32 replaced by call #539
        process_vm_writev       => 311,  ## for x86_32 replaced by call #540
        kcmp                    => 312,
        finit_module            => 313,
        sched_setattr           => 314,
        sched_getattr           => 315,
        renameat2               => 316,
        seccomp                 => 317,
        getrandom               => 318,
        memfd_create            => 319,
        kexec_file_load         => 320,
        bpf                     => 321,
        execveat                => 322,
        userfaultfd             => 323,
        membarrier              => 324,
        mlock2                  => 325,
        copy_file_range         => 326,
        preadv2                 => 327,
        pwritev2                => 328,
        pkey_mprotect           => 329,
        pkey_alloc              => 330,
        pkey_free               => 331,
        statx                   => 332,
        io_pgetevents           => 333,
        rseq                    => 334,

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
        clone3                  => 435,
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
        memfd_secret            => 447,
        process_mrelease        => 448,

);

our %pack_map = (
    struct_timex => 'Lx![q]'    # modes (padded)
                   .'q4'        # offset freq maxerror esterror
                   .'lx![q]'    # status (padded)
                   .'q3'        # constant precision tolerance
                   .'q2'        # timenow (sec & µsec)
                   .'q3'        # tick ppsfreq jitter
                   .'lx![q]'    # shift (padded)
                   .'q5'        # stabil jitcnt calcnt errcnt stbcnt
                   .'l'         # tai
                   .'x[L11]',   # pad 11 more 32-bit integers
                    # (everything except modes is signed, which is why lx![q] instead of q)

    time_t       => 'q',          # seconds
    timespec     => 'qLx![q]',    # seconds, nanoseconds
    timeval      => 'qLx![q]',    # seconds, microseconds
);

if ( $x32 ) {
    # Perl compiled as 32-bit (but for x86_64 architecture)

    # FROM /usr/include/x86_64-linux-gnu/asm/unistd_x32.h
    use constant { _B9 => 0x200 };              # 1<<9
    $syscall_map{rt_sigaction}      =  0 | _B9; # replaces x86_64 call #13
    $syscall_map{rt_sigreturn}      =  1 | _B9; # replaces x86_64 call #15
    $syscall_map{ioctl}             =  2 | _B9; # replaces x86_64 call #16
    $syscall_map{readv}             =  3 | _B9; # replaces x86_64 call #19
    $syscall_map{writev}            =  4 | _B9; # replaces x86_64 call #20
    $syscall_map{recvfrom}          =  5 | _B9; # replaces x86_64 call #45
    $syscall_map{sendmsg}           =  6 | _B9; # replaces x86_64 call #46
    $syscall_map{recvmsg}           =  7 | _B9; # replaces x86_64 call #47
    $syscall_map{execve}            =  8 | _B9; # replaces x86_64 call #59
    $syscall_map{ptrace}            =  9 | _B9; # replaces x86_64 call #101
    $syscall_map{rt_sigpending}     = 10 | _B9; # replaces x86_64 call #127
    $syscall_map{rt_sigtimedwait}   = 11 | _B9; # replaces x86_64 call #128
    $syscall_map{rt_sigqueueinfo}   = 12 | _B9; # replaces x86_64 call #129
    $syscall_map{sigaltstack}       = 13 | _B9; # replaces x86_64 call #131
    $syscall_map{timer_create}      = 14 | _B9; # replaces x86_64 call #222
    $syscall_map{mq_notify}         = 15 | _B9; # replaces x86_64 call #244
    $syscall_map{kexec_load}        = 16 | _B9; # replaces x86_64 call #246
    $syscall_map{waitid}            = 17 | _B9; # replaces x86_64 call #247
    $syscall_map{set_robust_list}   = 18 | _B9; # replaces x86_64 call #273
    $syscall_map{get_robust_list}   = 19 | _B9; # replaces x86_64 call #274
    $syscall_map{vmsplice}          = 20 | _B9; # replaces x86_64 call #278
    $syscall_map{move_pages}        = 21 | _B9; # replaces x86_64 call #279
    $syscall_map{preadv}            = 22 | _B9; # replaces x86_64 call #295
    $syscall_map{pwritev}           = 23 | _B9; # replaces x86_64 call #296
    $syscall_map{rt_tgsigqueueinfo} = 24 | _B9; # replaces x86_64 call #297
    $syscall_map{recvmmsg}          = 25 | _B9; # replaces x86_64 call #299
    $syscall_map{sendmmsg}          = 26 | _B9; # replaces x86_64 call #307
    $syscall_map{process_vm_readv}  = 27 | _B9; # replaces x86_64 call #310
    $syscall_map{process_vm_writev} = 28 | _B9; # replaces x86_64 call #311
    $syscall_map{setsockopt}        = 29 | _B9; # replaces x86_64 call #54
    $syscall_map{getsockopt}        = 30 | _B9; # replaces x86_64 call #55
    $syscall_map{io_setup}          = 31 | _B9; # replaces x86_64 call #206
    $syscall_map{io_submit}         = 32 | _B9; # replaces x86_64 call #209
    $syscall_map{execveat}          = 33 | _B9; # replaces x86_64 call #322
    $syscall_map{preadv2}           = 34 | _B9; # replaces x86_64 call #327
    $syscall_map{pwritev2}          = 35 | _B9; # replaces x86_64 call #328

    # Only x86_64 - no _32 equivalent
    delete $syscall_map{uselib};
    delete $syscall_map{_sysctl};
    delete $syscall_map{create_module};
    delete $syscall_map{get_kernel_syms};
    delete $syscall_map{query_module};
    delete $syscall_map{nfsservctl};
    delete $syscall_map{set_thread_area};
    delete $syscall_map{get_thread_area};
    delete $syscall_map{epoll_ctl_old};
    delete $syscall_map{epoll_wait_old};
    delete $syscall_map{vserver};

    $_ |= X32_SYSCALL_BIT for values %syscall_map;

    $pack_map{time_t}   = 'l' ;     # seconds
    $pack_map{timespec} = 'lL';     # seconds, nanoseconds
    $pack_map{timeval}  = 'lL';     # seconds, microseconds
}

our @EXPORT = qw(
    %pack_map
    %syscall_map
    $x32
);

our %EXPORT_TAGS;
$EXPORT_TAGS{everything} = \@EXPORT;

1;
