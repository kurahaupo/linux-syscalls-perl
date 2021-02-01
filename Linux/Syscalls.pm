#! /module/for/perl

# Linux::Syscalls implements perl subs for Linux syscalls that are missing
# from module POSIX.
#
# Aliases are provided where the Linux (or POSIX) names are inconsistent, for
# example adding or removing an "f" prefix.
#
# Shorthand versions such as lchown & lutimes are provided where Perl doesn't
# have them built-in.
#

use 5.010;
use utf8;       # allow $µs symbol
use strict;
use warnings;
use feature 'state';

package Linux::Syscalls;

use Config;

BEGIN {
                # When in checking mode, import everything from POSIX, to find
                # out whether we clash with anything.
use POSIX ();   POSIX->import() if $^C && $^W;
use Errno ();   Errno->import('ENOSYS') if ! exists &ENOSYS;
                Errno->import('EBADF')  if ! exists &EBADF;
use Fcntl ();   Fcntl->import('S_IFMT') if ! exists &S_IFMT;
                Fcntl->import('S_IFBLK') if ! exists &S_IFBLK;
                Fcntl->import('S_IFCHR') if ! exists &S_IFCHR;
                POSIX->import('uname' ) if ! exists &uname;
}

#use Scalar::Util 'blessed';

use base 'Exporter';

sub _unique_sorted(\@@) {
    my $r = shift;
    my %r;
    @r{@_} = @_;
    @r{@$r} = @$r;
    @$r = sort keys %r;
}

sub _export_ok(@)  { our @EXPORT_OK; push @EXPORT_OK, @_; }
sub _export_tag(@) {
    my ($j) = grep { $_[$_] eq '=>' } 1 .. $#_;
    my @t = splice @_, 0, $j // 1;
    shift if defined $j;
    &_export_ok;
    our %EXPORT_TAGS;
    push @{$EXPORT_TAGS{$_}}, @_ for @t;
}
sub _export_finish {
    our @EXPORT;
    our @EXPORT_OK;
    our %EXPORT_TAGS;
    for my $e (\@EXPORT, \@EXPORT_OK, values %EXPORT_TAGS) {
        _unique_sorted @$e;
    }
    $EXPORT_TAGS{everything} = \@EXPORT_OK;
}

################################################################################

# Magic numbers for Linux
use constant {
    AT_FDCWD            => -100,        # internal use only; use undef in client code
};

use constant {
    AT_SYMLINK_NOFOLLOW =>  0x100,
    AT_EACCESS          =>  0x200,      # only for faccessat
    AT_REMOVEDIR        =>  0x200,      # only for unlink (behave like rmdir)
    AT_SYMLINK_FOLLOW   =>  0x400,
    AT_NOAUTOMOUNT      =>  0x800,
    AT_EMPTY_PATH       => 0x1000,      # prefer to use undef path in client code
};

_export_tag qw{ _at AT_ =>
    AT_SYMLINK_NOFOLLOW AT_EACCESS   AT_NOAUTOMOUNT
    AT_SYMLINK_FOLLOW   AT_REMOVEDIR AT_EMPTY_PATH
};

# For calls like "stat" that return a list that includes timestamps, add an
# extra element to the return list that indicates the available precision of
# those timestamps. The values used are -log₁₀(ε), so that a simple test of
# "not zero" will say whether subsecond timestamps are available, and the value
# can also be used for %.*f formatting.
#
# We provide both "µs" and "μs" symbols (which are homographs in most fonts),
# because Unicode release 6 deprecated 'µ' (\u00b5) in favour of 'μ' (\u03bc),
# despite the former being the only codepoint provided by X11's and Windows's
# "international" keyboard layouts, and therefore being the only codepoint used
# in existing codebases.  We provide both to simplify editing of "old" and
# "new" codebases, using "old" and "new" keyboard layouts.

use constant {
    TIMERES_SECOND      =>  0,  res_s   =>  0,
    TIMERES_DECISECOND  =>  1,  res_ds  =>  1,  # for human-scale delays
    TIMERES_CENTISECOND =>  2,  res_cs  =>  2,  # for TTY timers
    TIMERES_MILLISECOND =>  3,  res_ms  =>  3,  # unused, filler only
    TIMERES_MICROSECOND =>  6,  res_µs  =>  6,  res_μs  =>  6,
    TIMERES_NANOSECOND  =>  9,  res_ns  =>  9,
    TIMERES_PICOSECOND  => 12,  res_ps  => 12,
};

_export_tag qw{ timeres_ =>
    TIMERES_SECOND TIMERES_DECISECOND TIMERES_CENTISECOND TIMERES_MILLISECOND
    TIMERES_MICROSECOND TIMERES_NANOSECOND TIMERES_PICOSECOND
};

_export_tag qw{ res_ =>
    res_s res_ds res_cs res_ms res_µs res_μs res_ns res_ps
};

################################################################################

# FROM /usr/include/*-linux-gnu/bits/fcntl-linux.h
BEGIN {
my %o_const = (

    O_RDONLY    =>   0x000000,  #
    O_WRONLY    =>   0x000001,  #
    O_RDWR      =>   0x000002,  #
    O_ACCMODE   =>   0x000003,  #
    O_CREAT     =>   0x000040,  # (not fcntl)
    O_EXCL      =>   0x000080,  # (not fcntl)
    O_NOCTTY    =>   0x000100,  # (not fcntl)
    O_TRUNC     =>   0x000200,  # (not fcntl)
    O_APPEND    =>   0x000400,  #
    O_NONBLOCK  =>   0x000800,  #
    O_NDELAY    =>   0x000800,  # ==O_NONBLOCK
    O_DSYNC     =>   0x001000,  # Synchronize data
    O_ASYNC     =>   0x002000,  #
    O_DIRECT    =>   0x004000,  # Direct disk access
    O_LARGEFILE =>   0x008000,  #
    O_DIRECTORY =>   0x010000,  # Must be a directory
    O_NOFOLLOW  =>   0x020000,  # Do not follow links
    O_NOATIME   =>   0x040000,  # Do not set atime
    O_CLOEXEC   =>   0x080000,  # Set close_on_exec
    O_SYNC      =>   0x101000,  #
    O_RSYNC     =>   0x101000,  # == O_SYNC  Synchronize read operations
    O_PATH      =>   0x200000,  # Resolve pathname but do not open file
    O_TMPFILE   =>   0x410000,  # Atomically create nameless file

#   O_FSYNC     =>   0x101000,  # == O_SYNC  Synchronize data & metadata

);
    exists &$_ and delete $o_const{$_} and warn "Already have $_ (probably from POSIX)\n" for keys %o_const;
    *O_NONBLOCK = *O_NDELAY{CODE}, delete $o_const{O_NONBLOCK} if ! exists &O_NONBLOCK && exists &O_NDELAY;
    constant->import(\%o_const);
}

_export_tag qw{ o_ =>
    O_RDONLY O_WRONLY O_RDWR O_ACCMODE O_CREAT O_EXCL O_NOCTTY O_TRUNC O_APPEND
    O_NONBLOCK O_NDELAY O_DSYNC O_ASYNC O_DIRECT O_LARGEFILE O_DIRECTORY
    O_NOFOLLOW O_NOATIME O_CLOEXEC O_SYNC O_RSYNC O_PATH O_TMPFILE
};

################################################################################

use constant {
    UTIME_NOW   => 0x3fffffff,  # INTERNAL ONLY; use empty string in client code
    UTIME_OMIT  => 0x3ffffffe,  # INTERNAL ONLY; use undef in client code
};

use constant {
    CHMOD_MASK  => 0xffff & ~( S_IFMT | - S_IFMT ),
#   CHMOD_MASK  => 07777,
#
## S_ISVTX & S_ISTXT may not be defined
#   CHMOD_MASK  => S_ISUID | S_ISGID | ( defined &S_ISVTX ? &S_ISVTX
#                                        defined &S_ISTXT ? &S_ISTXT
#                                                         : 01000 )
#                | S_IRWXU | S_IRWXG | S_IRWXO;
};

BEGIN { CHMOD_MASK == 07777 or die "Internal Error; for details read source code" };

################################################################################
#
# Linux syscalls vary on whether they take (or return) a timespec or a timeval.
# In general only older POSIX-compatible calls deal in timeval (with microsecond
# resolution); all other calls deal in timespec (with nanosecond resolution).
#
# It seems unlikely that picosecond resolution will ever be needed, as Moore's
# law finally ran out for CPU clock speeds at around 5 GHz, and although they
# will continue to get faster, it will be at a much slower rate.
#
# Although sub-nanosecond timing of individual CPU instructions is useful for
# intra-thread timing, in practice it is pointless for anything outside a
# single thread.
#
# Even a simple rendezvous between threads on separate cores takes several
# nanoseconds;
#
# Making a syscall (involving a round trip from usermode to kernel and back
# again) takes tens of nanoseconds.
#
# Switching context to a different process takes hundreds of nanoseconds.
#

# Older-style "timeval" contains tv_sec & tv_usec (µs precision)
sub _timeval_to_seconds($$) {
    my ($s, $µs) = @_;
    return $s + $µs * 1E-6;
}

sub _seconds_to_timeval($) {
    my $t = $_[0] // 0.0;
    my $s = floor($t);
    my $µs = floor(($t - $s) * 1E6 + 0.5);
    return $s, $µs;
}

# Newer-style "timespec" contains tv_sec & tv_nsec (ns precision)
sub _timespec_to_seconds($$) {
    my ($s, $ns) = @_;
    return $s + $ns * 1E-9;
}

sub _seconds_to_timespec($) {
    my $t = $_[0] // 0.0;
    my $s = floor($t);
    my $ns = floor(($t - $s) * 1E9 + 0.5);
    return $s, $ns;
}

#
# Standardized argument handling:
#
# * when dir_fd is:
#     - undef or empty or ".", use AT_FDCWD; or
#     - a glob or filehandle, use the fileno function to get its underlying
#       filedescriptor number; or
#     - a blessed reference, use the fileno method to get its underlying
#       filedescriptor number
# * make sure the result is a number
#
# * when flags is undef, use the given default, or AT_SYMLINK_NOFOLLOW if no
#   default is given.
#
# * when path is undef, add AT_EMPTY_PATH to the flags; this has the same
#   effect as substituting "." when dir_fd refers to a directory, but also
#   works for non-directories.
# * make sure the result is a string
#

sub _resolve_dir_fd(\$) {
    my ($dir_fd) = @_;
    my $D = $$dir_fd;
    if ( ref $D ) {
        # Try calling fileno builtin func on an IO::File or GLOB-ref
        if ( defined ( my $DD = eval { fileno $D } ) ) {
            # filehandle or glob ref
            $$dir_fd = $DD;
            return 1;
        }
        # Try calling fileno method on any object that implements it
        if ( defined ( my $DD = eval { $D->fileno } ) ) {
            $$dir_fd = $DD;
            return 1;
        }
    } else {
        # undef, '' and '.' refer to current directory
        if ( ! defined $D || $D eq '' || $D eq '.' ) {
            $$dir_fd = AT_FDCWD;
            return 1;
        }
        # Keep the input value unchanged if it's an integer
        if ( $D =~ /^\d\+$/ ) {
            $$dir_fd = $D;
            return 1;
        }
    }
    # It's not a valid filedescriptor
    $$dir_fd = undef;
    $! = EBADF;
    return;
}

sub _resolve_fd_path(\$\$;\$$) {
    &_resolve_dir_fd or return; # invoke using (initial) args of current sub
    shift;
    my ($path, $flags, $default) = @_;
    if (defined $$path) {
        $$flags //= $default // AT_SYMLINK_NOFOLLOW if $flags;
        $$path .= '';
    } else {
        $$flags //= AT_EMPTY_PATH if $flags;
        $$path = '';
    }
    return 1; # OK
}

################################################################################

sub _enum(@) {
    map { ($_[$_] => $_) } 0..$#_;
}

our $skip_syscall_ph;
_export_tag qw{ skip_syscall_ph => $skip_syscall_ph };

# TODO - arrange to avoid requiring syscall.ph by using
#   «use Linux::Syscalls ':xdebug_skip_syscall_ph';»
# or similar, ideally by using something like this:
#   _export_pragma_tag xdebug_skip_syscall_ph => sub { $skip_syscall_ph = 1 };

BEGIN { sub _get_syscall_id($); }
sub _get_syscall_id($) {
    my ($name) = @_;
    warn "looking up syscall number for '$name'\n" if $^C;

    if ( !$skip_syscall_ph ) {
        my $func = 'SYS_' . $name;
        require 'syscall.ph';
        no strict 'refs';
        #require 'syscall.ph' if ! exists &$func;
        if (exists &$func) {
            #goto &$func;
            my $r = &$func();
            warn sprintf "syscall number for %s is %d\n", $name, $r if $^C;
            return $r;
        }
        warn "syscall.ph doesn't define $func, having to guess...\n";
    }

    my ($os, undef, undef, undef, $hw, undef) = uname;
    #$os eq $^O or warn "Funky uname OS ($os) doesn't match Perl OS ($^O)\n";
    state %K;

    if (!%K) {
        if ( $os eq 'Linux' ) {
            if ( $hw eq 'i386' ) {

                # FROM /usr/include/x86_64-linux-gnu/asm/unistd_32.h
                %K = (
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
                    lchown                  =>  16,
                    break                   =>  17,
                    oldstat                 =>  18,
                    lseek                   =>  19,
                    getpid                  =>  20,
                    mount                   =>  21,
                    umount                  =>  22,
                    setuid                  =>  23,
                    getuid                  =>  24,
                    stime                   =>  25,
                    ptrace                  =>  26,
                    alarm                   =>  27,
                    oldfstat                =>  28,
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
                    setgid                  =>  46,
                    getgid                  =>  47,
                    signal                  =>  48,
                    geteuid                 =>  49,
                    getegid                 =>  50,
                    acct                    =>  51,
                    umount2                 =>  52,
                    lock                    =>  53,
                    ioctl                   =>  54,
                    fcntl                   =>  55,
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
                    setreuid                =>  70,
                    setregid                =>  71,
                    sigsuspend              =>  72,
                    sigpending              =>  73,
                    sethostname             =>  74,
                    setrlimit               =>  75,
                    getrlimit               =>  76,
                    getrusage               =>  77,
                    gettimeofday            =>  78,
                    settimeofday            =>  79,
                    getgroups               =>  80,
                    setgroups               =>  81,
                    select                  =>  82,
                    symlink                 =>  83,
                    oldlstat                =>  84,
                    readlink                =>  85,
                    uselib                  =>  86,
                    swapon                  =>  87,
                    reboot                  =>  88,
                    readdir                 =>  89,
                    mmap                    =>  90,
                    munmap                  =>  91,
                    truncate                =>  92,
                    ftruncate               =>  93,
                    fchmod                  =>  94,
                    fchown                  =>  95,
                    getpriority             =>  96,
                    setpriority             =>  97,
                    profil                  =>  98,
                    statfs                  =>  99,
                    fstatfs                 => 100,
                    ioperm                  => 101,
                    socketcall              => 102,
                    syslog                  => 103,
                    setitimer               => 104,
                    getitimer               => 105,
                    stat                    => 106,
                    lstat                   => 107,
                    fstat                   => 108,
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
                    setfsuid                => 138,
                    setfsgid                => 139,
                    _llseek                 => 140,
                    getdents                => 141,
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
                    setresuid               => 164,
                    getresuid               => 165,
                    vm86                    => 166,
                    query_module            => 167,
                    poll                    => 168,
                    nfsservctl              => 169,
                    setresgid               => 170,
                    getresgid               => 171,
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
                    chown                   => 182,
                    getcwd                  => 183,
                    capget                  => 184,
                    capset                  => 185,
                    sigaltstack             => 186,
                    sendfile                => 187,
                    getpmsg                 => 188,
                    putpmsg                 => 189,
                    vfork                   => 190,
                    ugetrlimit              => 191,
                    mmap2                   => 192,
                    truncate64              => 193,
                    ftruncate64             => 194,
                    stat64                  => 195,
                    lstat64                 => 196,
                    fstat64                 => 197,
                    lchown32                => 198,
                    getuid32                => 199,
                    getgid32                => 200,
                    geteuid32               => 201,
                    getegid32               => 202,
                    setreuid32              => 203,
                    setregid32              => 204,
                    getgroups32             => 205,
                    setgroups32             => 206,
                    fchown32                => 207,
                    setresuid32             => 208,
                    getresuid32             => 209,
                    setresgid32             => 210,
                    getresgid32             => 211,
                    chown32                 => 212,
                    setuid32                => 213,
                    setgid32                => 214,
                    setfsuid32              => 215,
                    setfsgid32              => 216,
                    pivot_root              => 217,
                    mincore                 => 218,
                    madvise                 => 219,
                    getdents64              => 220,
                    fcntl64                 => 221,
                    #
                    #
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
                    sendfile64              => 239,
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
                    fadvise64               => 250,
                    #
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
                    statfs64                => 268,
                    fstatfs64               => 269,
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
                    #
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
                    fstatat64               => 300,
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
                    prlimit64               => 340,
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

            } elsif ( $hw eq 'x86_64' || $hw eq 'x86_32' ) {

                %K = (
                    # FROM /usr/include/i386-linux-gnu/asm/unistd_64.h
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
                    rt_sigaction            =>  13,  ## replaces x86_32 call #512
                    rt_sigprocmask          =>  14,
                    rt_sigreturn            =>  15,  ## replaces x86_32 call #513
                    ioctl                   =>  16,  ## replaces x86_32 call #514
                    pread64                 =>  17,
                    pwrite64                =>  18,
                    readv                   =>  19,  ## replaces x86_32 call #515
                    writev                  =>  20,  ## replaces x86_32 call #516
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
                    recvfrom                =>  45,  ## replaces x86_32 call #517
                    sendmsg                 =>  46,  ## replaces x86_32 call #518
                    recvmsg                 =>  47,  ## replaces x86_32 call #519
                    shutdown                =>  48,
                    bind                    =>  49,
                    listen                  =>  50,
                    getsockname             =>  51,
                    getpeername             =>  52,
                    socketpair              =>  53,
                    setsockopt              =>  54,  ## replaces x86_32 call #541
                    getsockopt              =>  55,  ## replaces x86_32 call #542
                    clone                   =>  56,
                    fork                    =>  57,
                    vfork                   =>  58,
                    execve                  =>  59,  ## replaces x86_32 call #520
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
                    ptrace                  => 101,  ## replaces x86_32 call #521
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
                    rt_sigpending           => 127,  ## replaces x86_32 call #522
                    rt_sigtimedwait         => 128,  ## replaces x86_32 call #523
                    rt_sigqueueinfo         => 129,  ## replaces x86_32 call #524
                    rt_sigsuspend           => 130,
                    sigaltstack             => 131,  ## replaces x86_32 call #525
                    utime                   => 132,
                    mknod                   => 133,
                    #
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
                    #
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
                    #
                    init_module             => 175,
                    delete_module           => 176,
                    #
                    #
                    quotactl                => 179,
                    #
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
                    #
                    io_setup                => 206,  ## replaces x86_32 call #543
                    io_destroy              => 207,
                    io_getevents            => 208,
                    io_submit               => 209,  ## replaces x86_32 call #544
                    io_cancel               => 210,
                    #
                    lookup_dcookie          => 212,
                    epoll_create            => 213,
                    #
                    #
                    remap_file_pages        => 216,
                    getdents64              => 217,
                    set_tid_address         => 218,
                    restart_syscall         => 219,
                    semtimedop              => 220,
                    fadvise64               => 221,
                    timer_create            => 222,  ## replaces x86_32 call #526
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
                    #
                    mbind                   => 237,
                    set_mempolicy           => 238,
                    get_mempolicy           => 239,
                    mq_open                 => 240,
                    mq_unlink               => 241,
                    mq_timedsend            => 242,
                    mq_timedreceive         => 243,
                    mq_notify               => 244,  ## replaces x86_32 call #527
                    mq_getsetattr           => 245,
                    kexec_load              => 246,  ## replaces x86_32 call #528
                    waitid                  => 247,  ## replaces x86_32 call #529
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
                    newfstatat              => 262,
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
                    set_robust_list         => 273,  ## replaces x86_32 call #530
                    get_robust_list         => 274,  ## replaces x86_32 call #531
                    splice                  => 275,
                    tee                     => 276,
                    sync_file_range         => 277,
                    vmsplice                => 278,  ## replaces x86_32 call #532
                    move_pages              => 279,  ## replaces x86_32 call #533
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
                    preadv                  => 295,  ## replaces x86_32 call #534
                    pwritev                 => 296,  ## replaces x86_32 call #535
                    rt_tgsigqueueinfo       => 297,  ## replaces x86_32 call #536
                    perf_event_open         => 298,
                    recvmmsg                => 299,  ## replaces x86_32 call #537
                    fanotify_init           => 300,
                    fanotify_mark           => 301,
                    prlimit64               => 302,
                    name_to_handle_at       => 303,
                    open_by_handle_at       => 304,
                    clock_adjtime           => 305,
                    syncfs                  => 306,
                    sendmmsg                => 307,  ## replaces x86_32 call #538
                    setns                   => 308,
                    getcpu                  => 309,
                    process_vm_readv        => 310,  ## replaces x86_32 call #539
                    process_vm_writev       => 311,  ## replaces x86_32 call #540
                    kcmp                    => 312,
                    finit_module            => 313,
                    sched_setattr           => 314,
                    sched_getattr           => 315,
                    renameat2               => 316,
                    seccomp                 => 317,
                );

                if ( $hw eq 'x86_32' ) {
                    # Perl compiled as 32-bit for 64-bit kernel

                    use constant { B_x32 => 0x40000000 };
                    $_ |= B_x32 for values %K;

                    # FROM /usr/include/x86_64-linux-gnu/asm/unistd_x32.h
                    use constant {               B_x32r => 0x40000200 };
                    $K{rt_sigaction}      =  0 | B_x32r, # replaces x86_64 call #13
                    $K{rt_sigreturn}      =  1 | B_x32r, # replaces x86_64 call #15
                    $K{ioctl}             =  2 | B_x32r, # replaces x86_64 call #16
                    $K{readv}             =  3 | B_x32r, # replaces x86_64 call #19
                    $K{writev}            =  4 | B_x32r, # replaces x86_64 call #20
                    $K{recvfrom}          =  5 | B_x32r, # replaces x86_64 call #45
                    $K{sendmsg}           =  6 | B_x32r, # replaces x86_64 call #46
                    $K{recvmsg}           =  7 | B_x32r, # replaces x86_64 call #47
                    $K{execve}            =  8 | B_x32r, # replaces x86_64 call #59
                    $K{ptrace}            =  9 | B_x32r, # replaces x86_64 call #101
                    $K{rt_sigpending}     = 10 | B_x32r, # replaces x86_64 call #127
                    $K{rt_sigtimedwait}   = 11 | B_x32r, # replaces x86_64 call #128
                    $K{rt_sigqueueinfo}   = 12 | B_x32r, # replaces x86_64 call #129
                    $K{sigaltstack}       = 13 | B_x32r, # replaces x86_64 call #131
                    $K{timer_create}      = 14 | B_x32r, # replaces x86_64 call #222
                    $K{mq_notify}         = 15 | B_x32r, # replaces x86_64 call #244
                    $K{kexec_load}        = 16 | B_x32r, # replaces x86_64 call #246
                    $K{waitid}            = 17 | B_x32r, # replaces x86_64 call #247
                    $K{set_robust_list}   = 18 | B_x32r, # replaces x86_64 call #273
                    $K{get_robust_list}   = 19 | B_x32r, # replaces x86_64 call #274
                    $K{vmsplice}          = 20 | B_x32r, # replaces x86_64 call #278
                    $K{move_pages}        = 21 | B_x32r, # replaces x86_64 call #279
                    $K{preadv}            = 22 | B_x32r, # replaces x86_64 call #295
                    $K{pwritev}           = 23 | B_x32r, # replaces x86_64 call #296
                    $K{rt_tgsigqueueinfo} = 24 | B_x32r, # replaces x86_64 call #297
                    $K{recvmmsg}          = 25 | B_x32r, # replaces x86_64 call #299
                    $K{sendmmsg}          = 26 | B_x32r, # replaces x86_64 call #307
                    $K{process_vm_readv}  = 27 | B_x32r, # replaces x86_64 call #310
                    $K{process_vm_writev} = 28 | B_x32r, # replaces x86_64 call #311
                    $K{setsockopt}        = 29 | B_x32r, # replaces x86_64 call #54
                    $K{getsockopt}        = 30 | B_x32r, # replaces x86_64 call #55
                    $K{io_setup}          = 31 | B_x32r, # replaces x86_64 call #206
                    $K{io_submit}         = 32 | B_x32r, # replaces x86_64 call #209
                } else {
                    # Only x86_64 - no _32 equivalent
                    $K{uselib}          = 134;
                    $K{_sysctl}         = 156;
                    $K{create_module}   = 174;
                    $K{get_kernel_syms} = 177;
                    $K{query_module}    = 178;
                    $K{nfsservctl}      = 180;
                    $K{set_thread_area} = 205;
                    $K{get_thread_area} = 211;
                    $K{epoll_ctl_old}   = 214;
                    $K{epoll_wait_old}  = 215;
                    $K{vserver}         = 236;
                }

            } else {

                my $m32 = ! $Config{use64bitint};
                my $use_arch_want_sync_file_range2 = 0;
                my $have_MMU = 1;
                my $use_arch_want_syscall_no_at = 0;
                my $use_arch_want_syscall_no_flags = 0;
                my $use_32bit_off_t = 0;
                my $use_arch_want_syscall_deprecated = 0;

                %K = (
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
                              : 'lseek')        => 62,
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
                        timer_gettime           => 108,
                        timer_getoverrun        => 109,
                        timer_settime           => 110,
                        timer_delete            => 111,
                        clock_settime           => 112,
                        clock_gettime           => 113,
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

            }
        }
    }
    my $s = $K{$name} // warn "Syscall $name not known for $os / $hw\n" if $^C || $^W;
    return $s;
}

# Classic POSIX names for constants
use constant {
    # Bitmask
    ADJ_OFFSET      =>  0x0001,  # time offset
    ADJ_FREQUENCY   =>  0x0002,  # frequency offset
    ADJ_MAXERROR    =>  0x0004,  # maximum time error
    ADJ_ESTERROR    =>  0x0008,  # estimated time error
    ADJ_STATUS      =>  0x0010,  # clock status
    ADJ_TIMECONST   =>  0x0020,  # PLL time constant
    ADJ_TICK        =>  0x4000,  # tick value
    ADJ_SINGLESHOT  =>  0x8000,  # in combination with OFFSET, mimic old-fashioned adjtime()
    # Enum
    TIME_OK         =>  0,       # clock synchronized
    TIME_INS        =>  1,       # insert leap second
    TIME_DEL        =>  2,       # delete leap second
    TIME_OOP        =>  3,       # leap second in progress
    TIME_WAIT       =>  4,       # leap second has occurred
    TIME_BAD        =>  5,       # clock not synchronized
};

# Namespaced names for constants
use constant {
    # Bitmask
    ADJTIME_MASK_OFFSET      =>  ADJ_OFFSET,
    ADJTIME_MASK_FREQUENCY   =>  ADJ_FREQUENCY,
    ADJTIME_MASK_MAXERROR    =>  ADJ_MAXERROR,
    ADJTIME_MASK_ESTERROR    =>  ADJ_ESTERROR,
    ADJTIME_MASK_STATUS      =>  ADJ_STATUS,
    ADJTIME_MASK_TIMECONST   =>  ADJ_TIMECONST,
    ADJTIME_MASK_TICK        =>  ADJ_TICK,
    ADJTIME_MASK_SINGLESHOT  =>  ADJ_SINGLESHOT,
    # Enum
    ADJTIME_RES_OK          =>  TIME_OK,
    ADJTIME_RES_INS         =>  TIME_INS,
    ADJTIME_RES_DEL         =>  TIME_DEL,
    ADJTIME_RES_OOP         =>  TIME_OOP,
    ADJTIME_RES_WAIT        =>  TIME_WAIT,
    ADJTIME_RES_BAD         =>  TIME_BAD,
};

_export_tag qw{ adjtime_mask adjtime_ =>
    ADJTIME_MASK_OFFSET ADJTIME_MASK_FREQUENCY
    ADJTIME_MASK_MAXERROR ADJTIME_MASK_ESTERROR
    ADJTIME_MASK_STATUS ADJTIME_MASK_TIMECONST
    ADJTIME_MASK_TICK ADJTIME_MASK_SINGLESHOT
};

_export_tag qw{ adjtime_res adjtime =>
    ADJTIME_RES_OK ADJTIME_RES_INS ADJTIME_RES_DEL
    ADJTIME_RES_OOP ADJTIME_RES_WAIT ADJTIME_RES_BAD
};

_export_tag qw{ adjtime adjtimex =>
    adjtimex

    ADJ_OFFSET ADJ_FREQUENCY ADJ_MAXERROR ADJ_ESTERROR
    ADJ_STATUS ADJ_TIMECONST ADJ_TICK ADJ_SINGLESHOT

    TIME_OK TIME_INS TIME_DEL
    TIME_OOP TIME_WAIT TIME_BAD
};

sub adjtimex($;$$$$$$$$$$$$$$$$$$$) {
    my ($modes, $offset, $freq, $maxerror, $esterror, $status, $constant,
        $precision, $tolerance, $timenow, $tick, $ppsfreq, $jitter, $shift,
        $stabil, $jitcnt, $calcnt, $errcnt, $stbcnt, $tai) = @_;

    my $pf = 'Lx4q4lx4q3q2q3lx4q5lx44';  # pack format; note everything except modes is signed

    my $buf = pack $pf,
        $modes // 0, $offset // 0, $freq // 0, $maxerror // 0, $esterror // 0,
        $status // 0, $constant // 0, $precision // 0, $tolerance // 0,
        _seconds_to_timeval($timenow // 0.0), $tick // 0, $ppsfreq // 0, $jitter // 0,
        $shift // 0, $stabil // 0, $jitcnt // 0, $calcnt // 0, $errcnt // 0,
        $stbcnt // 0, $tai // 0;

    state $syscall_id = _get_syscall_id 'adjtimex';
    my $ret = syscall $syscall_id, $buf;

    ($modes, $offset, $freq, $maxerror, $esterror,
     $status, $constant, $precision, $tolerance,
     my $time_s, my $time_ns, $tick, $ppsfreq, $jitter,
     $shift, $stabil, $jitcnt, $calcnt, $errcnt,
     $stbcnt, $tai) = unpack $pf, $buf;

    return  $ret,
            $modes, $offset, $freq, $maxerror, $esterror, $status, $constant,
            $precision, $tolerance, _timeval_to_seconds($time_s, $time_ns), $tick,
            $ppsfreq, $jitter, $shift, $stabil, $jitcnt, $calcnt, $errcnt,
            $stbcnt, $tai;
}

#
# Report details of the filesystem at a particular path
#

_export_ok 'statvfs';

sub statvfs($) {
    my ($path) = @_;
    my $buf = '\x00' x 80;
    state $syscall_id = _get_syscall_id 'statvfs';
    0 == syscall $syscall_id, $path, $buf or return ();
    return unpack "L2Q6Lx![Q]L2", $buf;
        #      unsigned long  f_bsize;    /* filesystem block size */
        #      unsigned long  f_frsize;   /* fragment size */
        #      fsblkcnt_t     f_blocks;   /* size of fs in f_frsize units */
        #      fsblkcnt_t     f_bfree;    /* # free blocks */
        #      fsblkcnt_t     f_bavail;   /* # free blocks for unprivileged users */
        #      fsfilcnt_t     f_files;    /* # inodes */
        #      fsfilcnt_t     f_ffree;    /* # free inodes */
        #      fsfilcnt_t     f_favail;   /* # free inodes for unprivileged users */
        #      unsigned long  f_fsid;     /* filesystem ID */
        #      unsigned long  f_flag;     /* mount flags */
        #      unsigned long  f_namemax;  /* maximum filename length */
}

#
# lchown - chown but on a symlink.
#
# Pass undef for uid or gid to avoid changing that id
#
# Later versions of « use POSIX » provide this, so make it conditional.
#

BEGIN {
use POSIX ();
eval q{
    sub lchown($$$) {
        my ($path, $uid, $gid) = @_;
        $path .= "";
        ($uid //= -1) += 0;
        ($gid //= -1) += 0;
        state $syscall_id = _get_syscall_id "lchown";
        return 0 == syscall $syscall_id, $path, $uid, $gid;
    }
} if ! eval { POSIX->import('lchown'); 1; };
}
_export_tag qw{ l_ => lchown };

################################################################################

#
# faccessat - like access but relative to a DIR
# accessat - synonym
#
# Pass undef for dir_fd to use CWD for relative paths.
# Pass undef for uid or gid to avoid changing that id.
# Omit or pass undef for flags to check on a symlink itself.
#

_export_tag qw{ _at => faccessat };
sub faccessat($$$;$) {
    my ($dir_fd, $path, $mode, $flags) = @_;
    _resolve_fd_path $dir_fd, $path, $flags or return;
    $mode += 0;
    state $syscall_id = _get_syscall_id 'faccessat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $mode, $flags;
}

_export_ok 'accessat';
BEGIN { *accessat = \&faccessat; }

################################################################################

#
# fchmodat - like chmod but relative to a DIR
#
# Pass undef for dir_fd to use CWD for relative paths.
# Omit or pass undef for flags to try to avoid following symlinks, however the man page
# for fchmodat warns:
#   "AT_SYMLINK_NOFOLLOW
#       If pathname is a symbolic link, do not dereference it: instead operate
#       on the link itself.  This flag is not currently implemented."
#
# Whilst the mode of a symlink has no meaning and so it's pointless to try
# to change it, it is perhaps useful to avoid changing the mode of something
# pointed to by a symlink.
#

_export_tag qw{ _at => fchmodat };
sub fchmodat($$$;$) {
    my ($dir_fd, $path, $perm, $flags) = @_;
    _resolve_fd_path $dir_fd, $path, $flags or return;
    if ($flags & AT_SYMLINK_NOFOLLOW) {
        $! = ENOSYS;
        return;
    }
    $perm &= CHMOD_MASK; # force int, and range-limit
    state $syscall_id = _get_syscall_id 'fchmodat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $perm, $flags;
}

_export_tag qw{ _at => chmodat };
BEGIN { *chmodat = \&fchmodat; }

#
# lchmod (fake syscall) - like chmod but on a symlink
#  NB: THIS CURRENTLY DOES NOT WORK.
#   The man page for fchmodat says:
#   "AT_SYMLINK_NOFOLLOW
#       If pathname is a symbolic link, do not dereference it: instead operate
#       on the link itself.  This flag is not currently implemented."
#

_export_tag qw{ l_ => lchmod };
sub lchmod($$) {
    my ($path, $perm) = @_;
    return fchmodat undef, $path, $perm, AT_SYMLINK_NOFOLLOW;
}

#sub lchmod($$) {
#    my ($path, $perm) = @_;
#    my $dir_fd = 0|AT_FDCWD;
#    $path .= "";    # force string
#    $perm &= CHMOD_MASK; # force int, and range-limit
#    my $flags = AT_SYMLINK_NOFOLLOW;
#    state $syscall_id = _get_syscall_id 'fchmodat';
#    return 0 == syscall $syscall_id, $dir_fd, $path, $perm, $flags;
#}

################################################################################

#
# chown but relative to an open dir_fd
#
# Pass undef for dir_fd to use CWD for relative paths.
# Pass undef for uid or gid to avoid changing that id.
# Omit or pass undef for flags to not follow symlinks.
#

_export_tag qw{ _at => fchownat };
sub fchownat($$$$;$) {
    my ($dir_fd, $path, $uid, $gid, $flags) = @_;
    _resolve_fd_path $dir_fd, $path, $flags or return;
    ($uid //= -1) += 0;
    ($gid //= -1) += 0;
    state $syscall_id = _get_syscall_id 'fchownat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $uid, $gid, $flags;
}

_export_tag qw{ _at => chownat };
BEGIN { *chownat = \&fchownat; }

################################################################################

#
# link but relative to (two) DIRs
# Pass undef for either dir_fd to use CWD for relative paths.
# Omit or pass undef for flags to not follow symlinks.
#

_export_tag qw{ _at => linkat };
sub linkat($$$$;$) {
    my ($olddir_fd, $oldpath, $newdir_fd, $newpath, $flags) = @_;
    _resolve_fd_path $olddir_fd, $oldpath, $flags, 0 or return; # without 0 → AT_SYMLINK_NOFOLLOW;
    _resolve_fd_path $newdir_fd, $newpath, $flags, 0 or return; # in effect, AT_SYMLINK_FOLLOW;
    state $syscall_id = _get_syscall_id 'linkat';
    return 0 == syscall $syscall_id, $olddir_fd, $oldpath, $newdir_fd, $newpath, $flags;
}

################################################################################

#
# lstat but with nanosecond resolution on atime, mtime & ctime.
# And no, Time::HiRes doesn't provide this, at least as of version 1.9725, as
# shipped with Perl version 5.18.2.
#
# Returns the same 13-element array as CORE::stat, with these appended:
#   * A numeric 1, to indicate that timestamps with nanosecond resolution are
#      supported;
#   * Unknown/padding & unused sections, as an array unpacked using "Q*"
#   * The raw buffer, as a string of bytes
#   * The full unpacked list as a plain array
# (These will be removed in a later version.)
#
# From "man perlfunc":
#            0 dev      device number of filesystem
#            1 ino      inode number
#            2 mode     file mode  (type and permissions)
#            3 nlink    number of (hard) links to the file
#            4 uid      numeric user ID of file's owner
#            5 gid      numeric group ID of file's owner
#            6 rdev     the device identifier (special files only)
#            7 size     total size of file, in bytes
#            8 atime    last access time in seconds since the epoch
#            9 mtime    last modify time in seconds since the epoch
#           10 ctime    inode change time in seconds since the epoch (*)
#           11 blksize  preferred I/O size in bytes for interacting with the
#                       file (may vary from file to file)
#           12 blocks   actual number of system-specific blocks allocated
#                       on disk (often, but not always, 512 bytes each)
#

# There are many variations of the stat syscall; Linux x86 has at least 6.
# There are two #include files that can be used: <sys/stat.h> (from POSIX)
# and <asm/stat.h> (LFS).
#
#     STRUCT              SIZE    sys/stat.h          asm/stat.h  ARCH          UNPACK
#     __old_kernel_stat   32      -                   asm         any           my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime)                                                            = unpack 'S7x2L4', $in;
#     stat                64      -                   asm         i386_32       my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$blksize,$blocks,$atime,$atime_nsec,$mtime,$mtime_nsec,$ctime,$ctime_nsec)       = unpack 'L2S4L4l6', $in;
#     stat                80      -                   asm         x86_64_x32    my ($dev,$ino,$nlink,$mode,$uid,$gid,$rdev,$size,$blksize,$blocks,$atime,$atime_nsec,$mtime,$mtime_nsec,$ctime,$ctime_nsec)       = unpack 'L6x4L10', $in;
#     stat                88      yes                 -           i386_32       my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$blksize,$blocks,$atime,$atime_nsec,$mtime,$mtime_nsec,$ctime,$ctime_nsec)       = unpack 'Qx4L5Qx4L9', $in;
#     stat64              96      _LARGFILE64_SOURCE  yes         i386_32       my ($dev,$jno,$mode,$nlink,$uid,$gid,$rdev,$size,$blksize,$blocks,$atime,$atime_nsec,$mtime,$mtime_nsec,$ctime,$ctime_nsec,$ino)  = unpack 'Qx4L5Qx4QLQL6Q', $in;
#     stat                144     yes                 yes         x86_64_64   }
#     stat                144     yes                 -           x86_64_x32  } my ($dev,$ino,$nlink,$mode,$uid,$gid,$rdev,$size,$blksize,$blocks,$atime,$atime_nsec,$mtime,$mtime_nsec,$ctime,$ctime_nsec)       = unpack 'Q3L3x4Q10', $in;
#     stat64              144     _LARGFILE64_SOURCE  -           x86_64_x32  }
#
# my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime)                                                           = unpack 'S7x2L4', $in;        #  32 __old_kernel_stat i386_32     <asm/stat.h> (x86_64-linux-gnu/asm) +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -m32  -DUSE_i32 -D_LARGEFILE64_SOURCE -DUSE_ASM_STAT
#                                                                                                                                                                 #                       i386_32     <asm/stat.h> (x86_64-linux-gnu/asm) -_LARGEFILE64_SOURCE    *-__USE_LARGEFILE64    *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -m32  -DUSE_i32                       -DUSE_ASM_STAT
#                                                                                                                                                                 #                       x86_64_64   <asm/stat.h> (x86_64-linux-gnu/asm) +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -m64  -DUSE_x64 -D_LARGEFILE64_SOURCE -DUSE_ASM_STAT
#                                                                                                                                                                 #                       x86_64_64   <asm/stat.h> (x86_64-linux-gnu/asm) -_LARGEFILE64_SOURCE    *-__USE_LARGEFILE64    *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -m64  -DUSE_x64                       -DUSE_ASM_STAT
#                                                                                                                                                                 #                       x86_64_x32  <asm/stat.h> (x86_64-linux-gnu/asm) +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -mx32 -DUSE_x32 -D_LARGEFILE64_SOURCE -DUSE_ASM_STAT
#                                                                                                                                                                 #                       x86_64_x32  <asm/stat.h> (x86_64-linux-gnu/asm) -_LARGEFILE64_SOURCE    *-__USE_LARGEFILE64    *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -mx32 -DUSE_x32                       -DUSE_ASM_STAT
# my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$blksize,$blocks,$atime,$atime_nsec,$mtime,$mtime_nsec,$ctime,$ctime_nsec)      = unpack 'L2S4L10', $in;       #  64 stat              i386_32     <asm/stat.h>                        +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -m32  -DUSE_i32 -D_LARGEFILE64_SOURCE -DUSE_ASM_STAT
#                                                                                                                                                                 #                       i386_32     <asm/stat.h>                        -_LARGEFILE64_SOURCE    *-__USE_LARGEFILE64    *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -m32  -DUSE_i32                       -DUSE_ASM_STAT
# my ($dev,$ino,$nlink,$mode,$uid,$gid,$rdev,$size,$blksize,$blocks,$atime,$atime_nsec,$mtime,$mtime_nsec,$ctime,$ctime_nsec)      = unpack 'L6x4L10', $in;       #  80 stat              x86_64_x32  <asm/stat.h>                        +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -mx32 -DUSE_x32 -D_LARGEFILE64_SOURCE -DUSE_ASM_STAT
#                                                                                                                                                                 #                       x86_64_x32  <asm/stat.h>                        -_LARGEFILE64_SOURCE    *-__USE_LARGEFILE64    *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -mx32 -DUSE_x32                       -DUSE_ASM_STAT
# my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$blksize,$blocks,$atime,$atime_nsec,$mtime,$mtime_nsec,$ctime,$ctime_nsec)      = unpack 'Qx4L5Qx4L9', $in;    #  88 stat              i386_32     <sys/stat.h>                        +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  +_STAT_VER_LINUX_OLD=1  +_STAT_VER_KERNEL=1, +_STAT_VER_SVR4=2, +_STAT_VER_LINUX=3; COMPILED gcc -m32  -DUSE_i32 -D_LARGEFILE64_SOURCE
#                                                                                                                                                                 #                       i386_32     <sys/stat.h>                        -_LARGEFILE64_SOURCE    *-__USE_LARGEFILE64    *-__USE_LARGEFILE  +_STAT_VER_LINUX_OLD=1  +_STAT_VER_KERNEL=1, +_STAT_VER_SVR4=2, +_STAT_VER_LINUX=3; COMPILED gcc -m32  -DUSE_i32
# my ($dev,$JNO,$mode,$nlink,$uid,$gid,$rdev,$size,$blksize,$blocks,$atime,$atime_nsec,$mtime,$mtime_nsec,$ctime,$ctime_nsec,$ino) = unpack 'Qx4L5Qx4QLQL6Q', $in; # 96 stat64            i386_32     <asm/stat.h>                        +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -m32  -DUSE_i32 -D_LARGEFILE64_SOURCE -DUSE_ASM_STAT
#                                                                                                                                                                 #                       i386_32     <asm/stat.h>                        -_LARGEFILE64_SOURCE    *-__USE_LARGEFILE64    *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -m32  -DUSE_i32                       -DUSE_ASM_STAT
#                                                                                                                                                                 #                       i386_32     <sys/stat.h>                        +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  +_STAT_VER_LINUX_OLD=1  +_STAT_VER_KERNEL=1, +_STAT_VER_SVR4=2, +_STAT_VER_LINUX=3; COMPILED gcc -m32  -DUSE_i32 -D_LARGEFILE64_SOURCE
# my ($dev,$ino,$nlink,$mode,$uid,$gid,$rdev,$size,$blksize,$blocks,$atime,$atime_nsec,$mtime,$mtime_nsec,$ctime,$ctime_nsec)      = unpack 'Q3L3x4Q10', $in;     # 144 stat              x86_64_64   <asm/stat.h>                        +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -m64  -DUSE_x64 -D_LARGEFILE64_SOURCE -DUSE_ASM_STAT
#                                                                                                                                                                 #                       x86_64_64   <asm/stat.h>                        -_LARGEFILE64_SOURCE    *-__USE_LARGEFILE64    *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    -_STAT_VER_KERNEL,   -_STAT_VER_SVR4,   -_STAT_VER_LINUX;   COMPILED gcc -m64  -DUSE_x64                       -DUSE_ASM_STAT
#                                                                                                                                                                 #                       x86_64_64   <sys/stat.h>                        +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    +_STAT_VER_KERNEL=0, -_STAT_VER_SVR4,   +_STAT_VER_LINUX=1; COMPILED gcc -m64  -DUSE_x64 -D_LARGEFILE64_SOURCe
#                                                                                                                                                                 #                       x86_64_64   <sys/stat.h>                        -_LARGEFILE64_SOURCE    *-__USE_LARGEFILE64    *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    +_STAT_VER_KERNEL=0, -_STAT_VER_SVR4,   +_STAT_VER_LINUX=1; COMPILED gcc -m64  -DUSE_x64
#                                                                                                                                                                 #                       x86_64_x32  <sys/stat.h>                        +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    +_STAT_VER_KERNEL=0, -_STAT_VER_SVR4,   +_STAT_VER_LINUX=1; COMPILED gcc -mx32 -DUSE_x32 -D_LARGEFILE64_SOURCE
#                                                                                                                                                                 #                       x86_64_x32  <sys/stat.h>                        -_LARGEFILE64_SOURCE    *-__USE_LARGEFILE64    *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    +_STAT_VER_KERNEL=0, -_STAT_VER_SVR4,   +_STAT_VER_LINUX=1; COMPILED gcc -mx32 -DUSE_x32
#                                                                                                                                                                 # 144 stat64            x86_64_64   <sys/stat.h>                        +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    +_STAT_VER_KERNEL=0, -_STAT_VER_SVR4,   +_STAT_VER_LINUX=1; COMPILED gcc -m64  -DUSE_x64 -D_LARGEFILE64_SOURCE
#                                                                                                                                                                 #                       x86_64_x32  <sys/stat.h>                        +_LARGEFILE64_SOURCE=1  *+__USE_LARGEFILE64=1  *-__USE_LARGEFILE  -_STAT_VER_LINUX_OLD    +_STAT_VER_KERNEL=0, -_STAT_VER_SVR4,   +_STAT_VER_LINUX=1; COMPILED gcc -mx32 -DUSE_x32 -D_LARGEFILE64_SOURCE

sub _unpack_stat {
    my ($buffer) = @_;

    my ($dev, $ino, $nlink,
        $mode, $uid, $gid, $U1,
        $rdev, $size, $blksize, $blocks,
        $atime, $atime_ns, $mtime, $mtime_ns, $ctime, $ctime_ns,
        @unused);

    my $has_subsecond_resolution = 0;

    state $m32 = ! $Config{use64bitint};
    state $unpacking;
    $unpacking ||= sub {
        my ($os, undef, undef, undef, $hw, undef) = uname;
        if ($os eq 'Linux') {
            return 1+$m32 if $hw eq 'x86_64' || $hw eq 'i686';
            return 3      if $hw eq 'x86_32' || $hw eq 'i386';
        }
        warn "CANNOT UNPACK on this OS ($os) and HW ($hw)\n" if $^C || $^W;
        return 0;
    }->() or return;

    my @unpacked;
    if ($unpacking == 1) {
        # x86_64
        @unpacked = unpack "Q3L4Qq3Q6q*", $buffer;
        ($dev, $ino, $nlink,
         $mode, $uid, $gid, $U1,
         $rdev, $size, $blksize, $blocks,
         $atime, $atime_ns, $mtime, $mtime_ns, $ctime, $ctime_ns,
         @unused) = @unpacked;
         $has_subsecond_resolution = TIMERES_NANOSECOND;    # Has nanosecond-resolution timestamps.
    } elsif ($unpacking == 2) {
        # compiled with -mx32 ⇒ 32-bit mode on 64-bit CPU
        # Buffer is filled to 64 bytes (128 nybbles)
        # struct stat from asm/stat.h on x86_32

        state $seen_subsecond_resolution;

        @unpacked = unpack "L2S4L4l6"."l*", $buffer;

        ( $dev, $ino,
          $mode, $nlink, $uid, $gid,
          $rdev, $size, $blksize, $blocks,
          $atime, $atime_ns, $mtime, $mtime_ns, $ctime, $ctime_ns,
          @unused ) = @unpacked;

        # Syscall has room to report on subsecond resolution, but often the
        # filesystem on old hosts doesn't have it turned on.
        $seen_subsecond_resolution ||= $atime_ns || $mtime_ns || $ctime_ns;
         $has_subsecond_resolution = $seen_subsecond_resolution ? TIMERES_NANOSECOND : TIMERES_SECOND;    # Has no sub-second-resolution timestamps.
    } elsif ($unpacking == 3) {
        # i386
        die "Unimplemented";
    }

    unshift @unused, $U1;

    $atime += $atime_ns*1E-9;
    $mtime += $mtime_ns*1E-9;
    $ctime += $ctime_ns*1E-9;

    return $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
           $atime, $mtime, $ctime,
           $blksize, $blocks,
           $has_subsecond_resolution,
#          \@unused, $buffer, \@unpacked;   # extra debug info
}

_export_ok qw{ lstatns };
sub lstatns($) {
    my ($path) = @_;
    $path .= "";
    my $buffer = "\xa5" x 160;
    state $syscall_id = _get_syscall_id 'lstat';
    0 == syscall $syscall_id, $path, $buffer or return;
    return _unpack_stat($buffer);
}

BEGIN {
    eval {
        require Time::HiRes;
        Time::HiRes->import('lstat');
        1
    } or do {
        *lstat = \&lstatns;
        _export_tag qw{ l_ => lstat };
    };
    _export_ok qw{ lstat };
}

_export_tag qw{ _at => fstatat };
sub fstatat($$;$) {
    my ($dir_fd, $path, $flags) = @_;
    _resolve_fd_path $dir_fd, $path, $flags or return;
    my $buffer = "\xa5" x 160;
    state $syscall_id = _get_syscall_id 'newfstatat';
    #warn "syscall=$syscall_id, dir_fd=$dir_fd, path=$path, buffer=".length($buffer)."-bytes, flags=$flags\n";
    0 == syscall $syscall_id, $dir_fd, $path, $buffer, $flags or return;
    return _unpack_stat($buffer);
}

_export_ok qw{ statat };
BEGIN { *statat = \&fstatat; }

################################################################################

#
# mkdir but relative to an open dir_fd
#  pass undef for mode to use 0777
#

_export_tag qw{ _at => mkdirat };
sub mkdirat($$$) {
    my ($dir_fd, $path, $mode) = @_;
    _resolve_dir_fd $dir_fd or return;
    $path .= '';
    $mode //= 0777;
    state $syscall_id = _get_syscall_id 'mkdirat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $mode;
}

################################################################################

#
# mknod but relative to an open dir_fd
#  pass undef for mode to use 0777
#

_export_tag qw{ _at => mknodat };
sub mknodat($$$$) {
    my ($dir_fd, $path, $mode, $dev) = @_;
    _resolve_dir_fd $dir_fd or return;
    $path .= '';
    $mode //= 0666;
    state $syscall_id = _get_syscall_id 'mknodat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $mode, $dev;
}

################################################################################

#
# open but relative to an open dir_fd
#  pass undef for mode to use 0777
#

_export_tag qw{ _at => openat };
sub openat($$;$$) {
    my ($dir_fd, $path, $flags, $mode) = @_;
    _resolve_fd_path $dir_fd, $path, $flags or return;
    $mode //= 0666;
    state $syscall_id = _get_syscall_id 'openat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $flags, $mode;
}

################################################################################


_export_tag qw{ _at => readlinkat };
sub readlinkat($$) {
    my ($dir_fd, $path) = @_;
    _resolve_dir_fd $dir_fd or return;
    $path .= "";
    my $buffer = "\xa5" x 8192;
    state $syscall_id = _get_syscall_id 'readlinkat';
    my $r = syscall $syscall_id, $dir_fd, $path, $buffer, length($buffer);
    $r > 0 or return;
    return substr $buffer, 0, $r;
}

################################################################################

#
# renameat - like rename but with each path relative to an DIR
#
# Pass undef for either dir_fd to use CWD for relative paths.
# Omit or pass undef for flags to not follow symlinks.
#

_export_tag qw{ _at => renameat };
sub renameat($$$$) {
    my ($olddir_fd, $oldpath, $newdir_fd, $newpath) = @_;
    _resolve_dir_fd($olddir_fd) // return;
    $oldpath .= "";
    _resolve_dir_fd($newdir_fd) // return;
    $newpath .= "";
    state $syscall_id = _get_syscall_id 'renameat';
    return 0 == syscall $syscall_id, $olddir_fd, $oldpath, $newdir_fd, $newpath;
}

################################################################################

#
# symlinkat - like symlink but relative to (two) DIRs
#
# Pass undef for either dir_fd to use CWD for relative paths.
# Omit or pass undef for flags to not follow symlinks.
#

_export_tag qw{ _at => symlinkat };
sub symlinkat($$$) {
    my ($oldpath, $newdir_fd, $newpath) = @_;
    $oldpath .= "";
    _resolve_fd_path $newdir_fd, $newpath or return;
    state $syscall_id = _get_syscall_id 'symlinkat';
    return 0 == syscall $syscall_id, $oldpath, $newdir_fd, $newpath;
}

################################################################################

#
# unlinkat - like unlink but relative to an DIR
#
# Pass undef for dir_fd to use CWD for relative paths.
# Omit or pass undef for flags to not follow symlinks.
#

_export_tag qw{ _at => unlinkat };
sub unlinkat($$$) {
    my ($dir_fd, $path, $flags) = @_;
    _resolve_fd_path $dir_fd, $path, $flags, 0 or return;
    # consider AT_REMOVEDIR|AT_SYMLINK_NOFOLLOW;
    state $syscall_id = _get_syscall_id 'unlinkat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $flags;
}

#
# rmdirat (fake syscall) - like rmdir but relative to an DIR
#
# Pass undef for either dir_fd to use CWD for relative paths.
# Omit or pass undef for flags to not follow symlinks.
#

_export_tag qw{ _at => rmdirat };
sub rmdirat($$$) {
    my ($dir_fd, $path, $flags) = @_;
    _resolve_fd_path $dir_fd, $path, $flags, AT_SYMLINK_NOFOLLOW or return;
    $flags |= AT_REMOVEDIR;
    state $syscall_id = _get_syscall_id 'unlinkat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $flags;
}

################################################################################

sub _pack_utimes($$) {
    return pack "(Q2)2", map {
            ! defined $_ ? ( -1, UTIME_OMIT )
              : $_ eq '' ? ( -1, UTIME_NOW )
                         : _seconds_to_timespec $_ ;
        } @_;
}

#
# futimesat - like utimes but relative to an open dir_fd
#
# Pass undef for atime or mtime to avoid changing that timestamp, empty string
# to set it to the current time, or an epoch second (with decimal fraction) to
# set it to that value (with nanosecond resolution).
# Omit or pass undef for flags to not follow symlinks.
#

_export_tag qw{ _at => futimesat };
sub futimesat($$$$$) {
    my ($dir_fd, $path, $atime, $mtime, $flags) = @_;
    _resolve_fd_path $dir_fd, $path, $flags or return;
    my $ts = _pack_utimes $atime, $mtime;
    state $syscall_id = _get_syscall_id 'utimensat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $ts, $flags;
}

#
# lutimes (fake syscall) - like utimes but on a symlink
#
# Pass undef for atime or mtime to avoid changing that timestamp, empty string
# to set it to the current time, or an epoch second (with decimal fraction) to
# set it to that value (with nanosecond resolution).
#

_export_tag qw{ l_ => lutimes };
sub lutimes($$$) {
  # my ($path, $atime, $mtime) = @_;
  # return futimesat undef, $path, $atime, $mtime, AT_SYMLINK_NOFOLLOW;
    return &futimesat(undef, @_, AT_SYMLINK_NOFOLLOW);  # bypass parameter checking
}

################################################################################

#
# Exit
#
# Invoke the exit syscall directly, with no cleanup.
# This may allow a process to return an exit status wider than 8 bits.
#

_export_tag qw{ proc => Exit };
sub Exit($) {
    my ($status) = @_;
    state $syscall_id = _get_syscall_id 'exit_group';
    return 0 == syscall $syscall_id, $status;
}

#
# waitid
#
# Implement the POSIX waitid call and the Linux-specific extension
# (which takes an additional parameter that has a stuct times to
# record the time usage of any reaped processses). This extension
# does not have any official name, so I simply call it "waitid5",
# since the syscall takes 5 parameters, analoguously to wait3 & wait4.
#
# Note that unlike the C version, values are returned, rather than
# modifying parameters through pointers.
#

BEGIN {
my %o_const = (

    # Values taken from /usr/include/asm-generic/siginfo.h
    CLD_EXITED      =>  1, #   Child has exited.
    CLD_KILLED      =>  2, #   Child was killed.
    CLD_DUMPED      =>  3, #   Child was killed and dumped core.
    CLD_TRAPPED     =>  4, #   Traced child has trapped (for debugging).
    CLD_STOPPED     =>  5, #   Child has stopped (and can be resumed).
    CLD_CONTINUED   =>  6, #   Stopped child has continued.

    # Values taken from /usr/include/linux/wait.h
    WNOHANG         =>  0x00000001,
    WUNTRACED       =>  0x00000002, # alias for WSTOPPED
    WSTOPPED        =>  0x00000002, #WUNTRACED
    WEXITED         =>  0x00000004,
    WCONTINUED      =>  0x00000008,
    WNOWAIT         =>  0x01000000, # Don't reap, just poll status.
    WNOTHREAD       =>  0x20000000, # (__WNOTHREAD) Don't wait on children of other threads in this group
    WALLCHILDREN    =>  0x40000000, # (__WALL) Wait on all children, regardless of type
    WCLONE          =>  0x80000000, # (__WCLONE) Wait only on non-SIGCHLD children

    # Values taken from /usr/include/bits/waitflags.h
    P_ALL           =>  0,         # Any child (ignoring ID)
    P_PID           =>  1,         # A specific child by PID
    P_PGID          =>  2,         # Any child within a process group, by PGID

);
    exists &$_ and delete $o_const{$_} and warn "Already have $_ (probably from POSIX)\n" for keys %o_const;
    *O_NONBLOCK = *O_NDELAY{CODE}, delete $o_const{O_NONBLOCK} if ! exists &O_NONBLOCK && exists &O_NDELAY;
    constant->import(\%o_const);
};

_export_tag qw{ proc si_codes =>
                    CLD_EXITED
                    CLD_KILLED
                    CLD_DUMPED
                    CLD_TRAPPED
                    CLD_STOPPED
                    CLD_CONTINUED };

_export_tag qw{ proc wait_id_types =>
                    P_ALL
                    P_PID
                    P_PGID };

_export_tag qw{ proc wait_options =>
                    WNOHANG
                    WUNTRACED
                    WSTOPPED
                    WEXITED
                    WCONTINUED
                    WNOWAIT
                    WNOTHREAD
                    WALLCHILDREN
                    WCLONE };
_export_tag qw{ proc => waitid waitid5 Exit };

# waitid returns a 5-element array

sub waitid($$$) {
    push @_, 0, 0;
    goto &waitid_;
}

# waitid5 returns a 21-elment array, starting with the same 5 as waitid

sub waitid5($$$) {
    my ($id_type, $id, $options) = @_;
    push @_, 1, 1;
    goto &waitid_;
}

# _unpack_siginfo reurns a 5-element array

sub _unpack_siginfo($) {
    #my ($si_pid, $si_uid, $si_signo, $si_status, $si_code) = unpack 'Q5', $_[0];
    #return $si_pid, $si_uid, $si_signo, $si_status, $si_code;
    return unpack 'Q5', $_[0];
}

# _unpack_rusage returns a 16-element array, starting with the utime & stime as
# floating-point seconds.

sub _unpack_rusage($) {
    my ($ru_utime, $ru_utime_µs, $ru_stime, $ru_stime_µs, $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
        $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
        $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw) = unpack 'Q18', shift;
    return  _timeval_to_seconds($ru_utime, $ru_utime_µs),
            _timeval_to_seconds($ru_stime, $ru_stime_µs),
            $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
            $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
            $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw;
}

#use Data::Dumper;


_export_ok 'waitid_';
sub waitid_($$$$$) {
    my ($id_type, $id, $options, $record_rusage, $record_siginfo) = @_;
    #warn "WAITID: ".Dumper(\@_);
    $id_type |= 0;
    $id |= 0;
    $options |= 0;
    my $siginfo = pack 'Q32', (0) x 5;
    my $rusage = pack 'Q32', (0) x 18;
    state $syscall_id = _get_syscall_id 'waitid';
    warn sprintf "Invoking waitid [syscall %d]\n\t type=%d id=%d\n\t rec_si=%s (%s)\n\t options=%#x\n\t rec_ru=%s (%s)\n",
            $syscall_id,
            $id_type,
            $id,
            $record_siginfo // '(undef)', join(' ', unpack 'Q*', $siginfo),
            $options,
            $record_rusage // '(undef)', join(' ', unpack 'Q*', $rusage),
            ;
    my $rpid = syscall $syscall_id,
                        $id_type,
                        $id,
                        $record_siginfo ? $siginfo : undef,
                        $options,
                        $record_rusage ? $rusage : undef;
    warn "waitid returned $rpid $!\n";
    $rpid == -1 and return;
    my ($si_pid, $si_uid, $si_signo, $si_status, $si_code) = _unpack_siginfo $siginfo;
    #return $si_pid if !wantarray;
    return $si_pid,
           $si_uid,
           $si_signo,
           $si_status,
           $si_code,
           $record_rusage ? _unpack_rusage $rusage
                          : ();
}

################################################################################

#
# Emulate a hangup on this process's controlling terminal, which should result
# in all processes in this session being sent SIGHUP when they attempt to
# interact with the terminal.
#

_export_ok 'vhangup';

sub vhangup() {
    state $syscall_id = _get_syscall_id 'vhangup';
    return 0 == syscall $syscall_id;
}

_export_finish;

1;
