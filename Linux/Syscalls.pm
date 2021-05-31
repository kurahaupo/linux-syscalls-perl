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

use base 'Exporter';

use Config;
use Scalar::Util qw( looks_like_number blessed );

use Errno qw( ENOSYS EBADF );
use Fcntl qw( S_IFMT );
use POSIX qw( uname );

################################################################################
#
# Fetch a constant without deoptimizing it.
#
# Since Perl v5.9.2, "use constant" has been able to create true compile-time
# constants that participate in compile-time constant folding, and dead code
# elimination.
#
# If the symbol table for the package does not contain an entry for the name,
# then instead of creating a GLOB, it puts a reference to the constant value
# instead, which is recognized by the compilation phase, and can participate in
# constant folding and dead code elimination.
#
# However this mechanism is brittle: the GLOB can be forced into existence
# merely encountering "&constname" at compile time (even as "exists
# &constname"), or "&{$symtab::{name}}".  The reference-to-constant reverts to
# a normal GLOB whose CODE element is a reference to "sub { $constant_value }",
# and it ceases to participate in compile-time optimization.
#
# So this sub tries hard to avoid breaking the optimizer.

sub _get_scalar_constant($) {
    my ($name) = @_;
    my $us = do { no strict 'refs'; \%{ caller . '::' }; };
    my $p = $us->{$name} or return; # non-existent
    my $r = ref $p;
    return $$p if $r eq 'SCALAR';   # still optimized

    # Any other kind of reference isn't allowed, but ref(*some_glob) and
    # ref($symtab::{$name}) both return empty string.
    return if $r && ! wantarray;
    return $p, $r if $r;            # error signalling

    # Already deoptimized to a GLOB, so we aren't making it any worse...
    return if ! exists &$p;         # non-existent
    return scalar &$p;
}

sub _listlen(@) { return 0+@_; }

################################################################################

BEGIN {
    # When in checking mode, import everything from POSIX, to find out whether
    # we clash with anything. Do this after all other modules are imported, so
    # POSIX won't complain if we've already defined something that it provides.
    POSIX->import() if $^C;
}

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

# Internal magic numbers
use constant {
    default_getdents_bufsize => 0x4000, # a multiple of the file allocation block size
};

# Magic numbers for Linux; these should be (but aren't) in Fcntl
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
#
# These O_* constants can also be provided by POSIX.pm and/or Fcntl.pm, so
# only define them here if they're /not/ provided by those.
#
# They all be specified to open*(), but some are applicable
# to other calls, notably the *_at() family.
#
# On Linux fcntl(F_SETFL,...) can change only the O_APPEND, O_ASYNC, O_DIRECT,
# O_NOATIME, and O_NONBLOCK flags, and fcnl(F_SETFD,...) can only change the
# FD_CLOEXEC flag).
my %o_const = (

    # Open-time flags - control what open() will do, and not visible later (inaccessible to fcntl)
    # (in the order listed in https://www.gnu.org/software/libc/manual/html_node/Open_002dtime-Flags.html)
    O_CREAT     =>   0x000040,  #
    O_EXCL      =>   0x000080,  #
    O_DIRECTORY =>   0x010000,  # Must be a directory
    O_NOFOLLOW  =>   0x020000,  # Do not follow links
    O_TMPFILE   =>   0x410000,  # Atomically create nameless file
#   O_NONBLOCK & O_NDELAY -- see below
    O_NOCTTY    =>   0x000100,  #
#   O_IGNORE_CTTY               # (not in Linux)
    O_NOLINK    =>   0x220000,  # (not native to Linux, but approximated by O_NOFOLLOW|O_PATH)
#   O_NOTRANS                   # (not in Linux)
    O_TRUNC     =>   0x000200,  #
#   O_SHLOCK                    # (not in Linux)
#   O_EXLOCK                    # (not in Linux)

    # Linux-only open-time flags
    O_LARGEFILE =>   0x008000,  # Allow open on files whose size does not fit into an offset_t, and permit a file to grow beyond 4GiB. On Linux there's no open64 syscall; it's emulated by setting this bit when calling open.

    # Multi-action flag
    # Don't block waiting for the entity to be ready.
    #   - When opening, return success immediately even if a device or pipe isn't connected;
    #   - When reading, return 0 ("empty") if no data is available from a connection (device, pipe, or socket)
    #   - When writing, return EAGAIN if the minimum size could not be written; it's permissible to truncate longer writes.
    O_NONBLOCK  =>   0x000800,
    O_NDELAY    =>   0x000800,  # == O_NONBLOCK (deprecated)

    # Access modes - which operations will be subsequently be allowed; visible but unchangible after open()
    # (in the order listed in https://www.gnu.org/software/libc/manual/html_node/Access-Modes.html)
    O_RDONLY    =>   0x000000,  #
    O_WRONLY    =>   0x000001,  #
    O_RDWR      =>   0x000002,  #
    O_READ      =>   0x000000,  # == O_RDONLY (non-standard)
    O_WRITE     =>   0x000001,  # == O_WRONLY (non-standard)
#   O_EXEC                      # (not in Linux!?)
    O_ACCMODE   =>   0x000003,  #

    # Linux-only access modes
    O_PATH      =>   0x200000,  # Resolve pathname but do not open file

    # Operating modes - affects the subsequent operations; can be seen and changed by fcntl
    # (in the order listed in https://www.gnu.org/software/libc/manual/html_node/Operating-Modes.html)
    O_APPEND    =>   0x000400,  #
#   O_NONBLOCK & O_NDELAY -- see above
    O_ASYNC     =>   0x002000,  #
    O_FSYNC     =>   0x101000,  # == O_SYNC Synchronize writing of file data; each write call will make sure the data is reliably stored on disk before returning. By implication metadata is also uptodate before returning.
    O_SYNC      =>   0x101000,  #
    O_NOATIME   =>   0x040000,  # Do not set atime when reading (useful for backups)

    # Linux-only operating modes
    O_DIRECT    =>   0x004000,  # Direct disk access
    O_DSYNC     =>   0x001000,  # Synchronize data (but not metadata)
    O_RSYNC     =>   0x101000,  # Should be its own bit, but currently == O_SYNC. When reading from cache, ensure that it's synch'ed to disk before returning.

    # Filedescriptor flags, not shared through dup()
    # Arrange for fd to be closed upon execve by using
    #  fcntl(F_SETFD,...|FD_CLOEXEC) rather than
    #  fcntl(F_SETFL,...|O_CLOEXEC).  Note the different numeric values!
    O_CLOEXEC   =>   0x080000,  # Set FD_CLOEXEC

);
    for my $k (keys %o_const) {
        # empty list indicates that the constant is not defined; a singleton
        # indicates defined value; a pair indicates an error...
        my @ov = _get_scalar_constant $k or next;
        @ov == 1 or die "Symbol $k already defined with a $ov[1] value!\n";
        # constant $k already exists (probably from POSIX) so delete it from
        # the list that we're about to add.
        my $nv = delete $o_const{$k};
        # But verify that we would provide the same numeric value.
        $ov[0] == $nv or
            die "Symbol $k already has value $ov[0], which disagrees our value $nv\n";
        warn "Already have $k (probably from POSIX)\n" if $^C;
    }
    constant->import(\%o_const);
}

_export_tag qw{ o_ =>
    O_RDONLY O_WRONLY O_RDWR O_ACCMODE O_CREAT O_EXCL O_NOCTTY O_TRUNC O_APPEND
    O_NONBLOCK O_NDELAY O_DSYNC O_ASYNC O_DIRECT O_LARGEFILE O_DIRECTORY
    O_NOFOLLOW O_NOATIME O_CLOEXEC O_SYNC O_RSYNC O_PATH O_TMPFILE
};

# Not in Linux, so not exported by default
_export_ok qw{ O_FSYNC O_NOLINK O_READ O_WRITE };

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
#   CHMOD_MASK  => S_ISUID | S_ISGID | ( exists &S_ISVTX ? &S_ISVTX
#                                        exists &S_ISTXT ? &S_ISTXT
#                                                        : 01000 )
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
    return $s + $µs / 1E6;
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
    return $s + $ns / 1E9;
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
#     - a blessed reference with a fileno method, use that to get its
#       underlying filedescriptor number
#     - a glob or filehandle, use the fileno function to get its underlying
#       filedescriptor number; or
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

sub _resolve_dir_fd_path(\$;\$\$$) {
    my ($dir_fd) = @_;
    while (1) {
        # Only "loop" once; either fail with "return", or succeed with "last"
        my $D = $$dir_fd;
        if ( ref $D ) {
            # Try calling fileno method on any object that implements it
            eval { $$dir_fd = $D->fileno; 1 } and last;
        } else {
            # undef, '' and '.' refer to current directory
            if ( ! defined $D || $D eq '' || $D eq '.' ) {
                $$dir_fd = AT_FDCWD;
                last;
            }
            # Keep the input value unchanged if it's an integer
            looks_like_number $D and last;
        }
        # Try calling fileno builtin func on an IO::File (ref) or GLOB-ref (ref) or
        # GLOB (non-ref)
        defined eval { $$dir_fd = fileno $D } and last;
        # It's not a valid filedescriptor
        $$dir_fd = undef;
        $! = EBADF;
        return;
    }

    shift;
    @_ or return 1;
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

# TODO
# arrange to avoid requiring syscall.ph by using
#       use Linux::Syscalls ':xdebug_skip_syscall_ph';
# ideally by using something like this:
#       _export_pragma_tag xdebug_skip_syscall_ph => sub { $skip_syscall_ph = 1 };

our $built_for_os;
our $built_for_hw;
our $running_on_os;
our $running_on_hw;

BEGIN {
    # Pull in %syscall_map and %pack_map from
    $built_for_os = ucfirst $^O;
    my ($running_on_os, undef, undef, undef, $running_on_hw, undef) = uname;
    $built_for_os eq 'Linux' or die "Perl not built for Linux\n";
    $running_on_os eq $built_for_os or die "Perl built for '$built_for_os' but running on '$running_on_os'\n";
    # Normalize all of i386, i486, i586, i686, & i786 to "ia32" (which was Intel's official name for it).
    defined && m/^i[3-7]86$/ and $_ = 'ia32' for $running_on_hw, $built_for_hw;
    my @e;
    for my $mm ( do { my %seen; grep { defined && ! $seen{$_}++ }
        $built_for_hw,
        $running_on_hw,
        'generic',
    } ) {
        my $m = "${built_for_os}::Syscalls::$mm";
        warn "Trying to load $m" if $^C;
        eval qq{
            use $m;
          # printf "syscall_map=%s\\n", scalar %syscall_map;
          # printf "pack_map=%s\\n", scalar %pack_map;
            1;
        } and last;
        push @e, $@;
        warn "Failed to load $m; $@" if $^C;
    }
    no diagnostics;
    @e and die "@e\n";
    sub _get_syscall_id($;$);
};

sub _get_syscall_id($;$) {
    my ($name, $quiet) = @_;
    warn "looking up syscall number for '$name'\n" if $^C && ! $quiet;
    if ( !$skip_syscall_ph ) {
        my $func = 'SYS_' . $name;
        require 'syscall.ph';
        no strict 'refs';
        if (exists &$func) {
            #goto &$func;
            my $r = &$func();
            warn sprintf "syscall number for %s is %d\n", $name, $r if $^C && ! $quiet;
            return $r;
        }
        warn "syscall.ph doesn't define $func, having to guess...\n" if $^C && ! $quiet;
    }

    my $s = $syscall_map{$name};
    $s // warn "Syscall $name not known for @{[$running_on_os // ()]} / @{[$running_on_hw // ()]}\n" if ! $quiet;
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
    ADJTIME_MASK_OFFSET     =>  ADJ_OFFSET,
    ADJTIME_MASK_FREQUENCY  =>  ADJ_FREQUENCY,
    ADJTIME_MASK_MAXERROR   =>  ADJ_MAXERROR,
    ADJTIME_MASK_ESTERROR   =>  ADJ_ESTERROR,
    ADJTIME_MASK_STATUS     =>  ADJ_STATUS,
    ADJTIME_MASK_TIMECONST  =>  ADJ_TIMECONST,
    ADJTIME_MASK_TICK       =>  ADJ_TICK,
    ADJTIME_MASK_SINGLESHOT =>  ADJ_SINGLESHOT,
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

_export_tag qw{ adjtime_res adjtime_ =>
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

    my $pf = $pack_map{adjtimex}; #'Lx4q4lx4q3q2q3lx4q5lx44';  # pack format; note everything except modes is signed

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
    _resolve_dir_fd_path $dir_fd, $path, $flags or return;
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
    _resolve_dir_fd_path $dir_fd, $path, $flags or return;
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
    _resolve_dir_fd_path $dir_fd, $path, $flags or return;
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
    _resolve_dir_fd_path $olddir_fd, $oldpath, $flags, 0 or return; # without 0 → AT_SYMLINK_NOFOLLOW;
    _resolve_dir_fd_path $newdir_fd, $newpath, $flags, 0 or return; # in effect, AT_SYMLINK_FOLLOW;
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
{ package Linux::Syscalls::bless::stat; }

sub _unpack_stat {
    my ($buffer) = @_;

    my $time_resolution = TIMERES_SECOND;

    state $m32 = ! $Config{use64bitint};
    state $unpacking;
    $unpacking ||= sub {
        my ($os, undef, undef, undef, $hw, undef) = uname;
        if ($os eq 'Linux') {
            return 1+$m32 if $hw eq 'x86_64' || $hw eq 'i686';
            return 3      if $hw eq 'x86_32' || $hw eq 'i386';
        }
        warn "Cannot unpack stat buffer on this OS ($os) and HW ($hw)\n" if $^C || $^W;
        return 0;
    }->() or return;

    my $unpack_fmt;
    if ($unpacking == 1) {
        # x86_64
        $unpack_fmt = 'Q2'
                     .'x[Q]LX[QL]Qx[L]'
                     .'LLx[L]Qq3Q6'.'q*';
        $time_resolution = TIMERES_NANOSECOND;    # Has nanosecond-resolution timestamps.
    } elsif ($unpacking == 2) {
        # compiled with -mx32 ⇒ 32-bit mode on 64-bit CPU
        # Buffer is filled to 64 bytes (128 nybbles)
        # struct stat from asm/stat.h on x86_32

        $unpack_fmt = 'L2S4L4l6'.'l*';

        $time_resolution = TIMERES_NANOSECOND;
    } elsif ($unpacking == 3) {
        # i386
        die "Unimplemented";
    }

    my ( $dev, $ino,
         $mode, $nlink, # Take care when unpacking, these are swapped in later versions of the syscall
         $uid, $gid,
         $rdev,
         $size, $blksize, $blocks,
         $atime, $atime_ns, $mtime, $mtime_ns, $ctime, $ctime_ns ) = unpack $unpack_fmt, $buffer;

    $atime = _timespec_to_seconds $atime, $atime_ns;
    $mtime = _timespec_to_seconds $mtime, $mtime_ns;
    $ctime = _timespec_to_seconds $ctime, $ctime_ns;

    return  $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
            $atime, $mtime, $ctime,
            $blksize, $blocks,
            # the following extend the normal stat call
            $time_resolution,
        if wantarray;
    #
    return bless [
            $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
            $atime, $mtime, $ctime,
            $blksize, $blocks,
            # the following extend the normal stat call
            $time_resolution,
           ], Linux::Syscalls::bless::stat::
        if defined wantarray;
}

{
    package Linux::Syscalls::bless::stat;
    use parent 'File::stat';
    sub dev             { $_[0]->[0]  }
    sub ino             { $_[0]->[1]  }
    sub mode            { $_[0]->[2]  }
    sub nlink           { $_[0]->[3]  }
    sub uid             { $_[0]->[4]  }
    sub gid             { $_[0]->[5]  }
    sub rdev            { $_[0]->[6]  }
    sub size            { $_[0]->[7]  }
    sub atime           { $_[0]->[8]  }
    sub mtime           { $_[0]->[9]  }
    sub ctime           { $_[0]->[10] }
    sub blksize         { $_[0]->[11] }
    sub blocks          { $_[0]->[12] }

    sub _time_res       { $_[0]->[13] }     # returns one of the TIMERES_* values, or undef if unknown
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
    _resolve_dir_fd_path $dir_fd, $path, $flags or return;
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
    _resolve_dir_fd_path $dir_fd or return;
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
    _resolve_dir_fd_path $dir_fd or return;
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
    _resolve_dir_fd_path $dir_fd, $path, $flags or return;
    $mode //= 0666;
    state $syscall_id = _get_syscall_id 'openat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $flags, $mode;
}

################################################################################


_export_tag qw{ _at => readlinkat };
sub readlinkat($$) {
    my ($dir_fd, $path) = @_;
    _resolve_dir_fd_path $dir_fd or return;
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
    $oldpath .= "";
    $newpath .= "";
    _resolve_dir_fd_path $olddir_fd or return;
    _resolve_dir_fd_path $newdir_fd or return;
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
    _resolve_dir_fd_path $newdir_fd, $newpath or return;
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
    _resolve_dir_fd_path $dir_fd, $path, $flags, 0 or return;
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
    _resolve_dir_fd_path $dir_fd, $path, $flags, AT_SYMLINK_NOFOLLOW or return;
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
    _resolve_dir_fd_path $dir_fd, $path, $flags or return;
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
# Read entries from a directory
#
# Although opendir/readdir/closedir are a standard part of Perl, opendir does
# not understand "<&=$fd", so it's impossible to use fopenat and then readdir
# from that; conversely, dirfd is not available in core Perl before about
# v5.26, so it's impossible to go the other way as well.
#
# This can also be used in conjunction with sysopen, systell, sysseek, etc.
#
# Takes a filedescriptor and an optional buffer size.
# Returns:
#   a list of arrays, each blessed as dirent entry; or
#   an empty list at EOF; or
#   an undef on error (a non-empty list).
#
# NB:
#  1. The kernel call may return as many dirent entries as fit in the buffer,
#     and there is no direct mechanism to limit the number of entries returned.
#
#  2. When a fd is open on a directory, the position reported by systell (and
#     used by sysseek) is an opaque tokens, not a computable integer.
#

use constant {
    DT_UNKNOWN  => 0,
    DT_FIFO     => 1,
    DT_CHR      => 2,
    DT_DIR      => 4,
    DT_BLK      => 6,
    DT_REG      => 8,
    DT_LNK      => 10,
    DT_SOCK     => 12,
    DT_WHT      => 14,
};

{
    package Linux::Syscalls::bless::dirent;
    sub name  { $_[0]->[0]  }
    sub inode { $_[0]->[1]  }
    sub type  { $_[0]->[2]  }
    sub hash  { $_[0]->[3]  }
}

sub getdents($;$) {
    my ($fd, $bufsize) = @_;
    # Keep track of this usage:
    #   $bufsize is the size of the buffer passed to the kernel
    #   $blksize is the size of the received data block
    #   $entsize is the size of each entry
    # however the buffer size and the received size have non-ov
    state $syscall_id = _get_syscall_id 'getdents64';
    state $packfmt = $pack_map{getdents64};    # 'QQSC'
    state $packlen = length pack $packfmt, (0) x 5;
    $bufsize ||= default_getdents_bufsize;
    my $buffer = ' ' x $bufsize;
    my $blksize = syscall $syscall_id, $fd, $buffer, $bufsize;
    return undef if $blksize < 0;
  # substr($buffer, $blksize) = '';  # cut off unfilled tail of buffer

    my @r;
    for (my $offset = 0 ; $offset < $blksize ;) {
        my ($entsize, @e) = unpack_dent $buffer;
        $entsize or last;    # can't get anything more out of this block
        push @r, bless \@e, Linux::Syscalls::bless::dirent::;
        $offset += $entsize;
    }
    return @r;
}

_export_tag qw( DT_ dirent  =>  getdents
                                DT_UNKNOWN
                                DT_FIFO DT_CHR DT_DIR DT_BLK
                                DT_REG DT_LNK DT_SOCK DT_WHT
              );

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
# (which takes an additional parameter that has a struct times to
# record the time usage of any reaped processses). This extension
# does not have any official name, so I simply call it "waitid5",
# since the syscall takes 5 parameters, analoguously to wait3 & wait4.
#
# Note that unlike the C version, values are returned, rather than
# modifying parameters through pointers.
#

BEGIN {
my %w_const = (

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
    for my $k (keys %w_const) {
        # empty list indicates that the constant is not defined; a singleton
        # indicates defined value; a pair indicates an error...
        my @ov = _get_scalar_constant $k or next;
        @ov == 1 or die "Symbol $k already defined with a $ov[1] value!\n";
        # constant $k already exists (probably from POSIX) so delete it from
        # the list that we're about to add.
        my $nv = delete $w_const{$k};
        # But verify that we would provide the same numeric value.
        $ov[0] == $nv or
            die "Symbol $k already has value $ov[0], which disagrees our value $nv\n";
        warn "Already have $k (probably from POSIX)\n" if $^C;
    }
    constant->import(\%w_const);
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

# wait3 and wait4 return:
#   empty-list (and sets $!) when there are no children, or on error
#   0 when WNOHANG prevents immediate reaping
#   a 17-element list otherwise
# (always include rusage, since otherwise one could simply use waitpid)

_export_tag qw{ proc => wait3 } if _get_syscall_id 'wait3', 1;
sub wait3($) {
#   unshift @_, -1;
#   goto &wait4;
    my ($options) = @_;
    my $status = pack 'I*', (0) x 1;
    my $rusage = pack 'Q*', (0) x 18;
    state $syscall_id = _get_syscall_id 'wait3';
    $! = 0;
    my $rpid = syscall $syscall_id,
                       $status,
                       $options,
                       $rusage;
    warn sprintf "Invoked\tsyscall  %u WAIT3\n"
                ."\targs     options=%#x\n"
                ."\treturned rpid=%d, status=%s, rusage=(%s)\n"
                ."\terrno    %s\n",
            $syscall_id, $options, $rpid, unpack("Q",$status), join(' ', unpack 'Q*', $rusage), $!;
    $rpid > 0 or return $rpid && ();    # 0->0, -1->empty
    $status = unpack 'I', $status;
    my ( $ru_utime, $ru_stime,
         $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
         $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
         $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw) = _unpack_rusage $rusage;
    return $rpid,
           $status,
           $ru_utime, $ru_stime,
           $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
           $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
           $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw;
}

_export_tag qw{ proc => wait4 } if _get_syscall_id 'wait4', 1;
sub wait4($$) {
    my ($cpid, $options) = @_;
    my $status = pack 'I*', (0) x 1;
    my $rusage = pack 'Q*', (0) x 18;
    state $syscall_id = _get_syscall_id 'wait4';
    $! = 0;
    my $rpid = syscall $syscall_id,
                       $cpid,
                       $status,
                       $options,
                       $rusage;
    warn sprintf "Invoked\tsyscall  %u WAIT4\n"
                ."\targs     cpid=%d, options=%#x\n"
                ."\treturned rpid=%d, status=(%s), rusage=(%s)\n"
                ."\terrno    %s\n",
                $syscall_id,
                $cpid, $options,
                $rpid, join(' ', unpack 'Q',$status), join(' ', unpack 'Q*', $rusage),
                $!;
    $rpid > 0 or return $rpid && ();    # 0->0, -1->empty
    $status = unpack 'I', $status;
    my ( $ru_utime, $ru_stime,
         $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
         $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
         $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw) = _unpack_rusage $rusage;
    return $rpid,
           $status,
           $ru_utime, $ru_stime,
           $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
           $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
           $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw;
}

# waitpid2 is like the waitpid builtin, except that it returns the pid & status
# instead of setting $?, and returns empty (and sets $!) on error.

_export_ok qw{ proc => waitpid2 } if _get_syscall_id 'waitpid', 1;
sub waitpid2($$) {
    my ($cpid, $options) = @_;
    my $status = pack 'I*', (0) x 1;
    state $syscall_id = _get_syscall_id 'waitpid';
    $! = 0;
    my $rpid = syscall $syscall_id,
                       $cpid,
                       $status,
                       $options;
    warn sprintf "Invoked\tsyscall  %u WAITPID\n"
                ."\targs     cpid=%d, options=%#x\n"
                ."\treturned rpid=%d, status=%s\n"
                ."\terrno    %s\n",
            $syscall_id, $cpid, $options, $rpid, unpack("H*",$status), $!;
    $rpid > 0 or return $rpid && ();    # 0->0, -1->empty
    $status = unpack 'I', $status;
    return $rpid,
           $status;
}

# waitid returns a 5-element array

sub waitid($$;$) {
#   my ($id_type, $id, $options) = @_;
    $_[2] //= WEXITED;
    $_[3] = 0;
    goto &waitid_;
}

# waitid5 returns a 21-element array, starting with the same 5 as waitid

sub waitid5($$;$) {
#   my ($id_type, $id, $options) = @_;
    $_[2] //= WEXITED;
    $_[3] = 1;
    goto &waitid_;
}

# _unpack_siginfo reurns a 5-element array

sub _unpack_siginfo($) {
    #my ($si_pid, $si_uid, $si_signo, $si_status, $si_code) = unpack 'Q5', $_[0];
    #return $si_pid, $si_uid, $si_signo, $si_status, $si_code;
    return unpack 'lx[l]Lx[l]LLL', $_[0];
}

# _unpack_rusage returns a 16-element array, starting with the utime & stime as
# floating-point seconds.

sub _unpack_rusage($) {
    my ($ru_utime, $ru_utime_µs, $ru_stime, $ru_stime_µs, @ru) = unpack 'Q18', $_[0];
    return  _timeval_to_seconds($ru_utime, $ru_utime_µs),
            _timeval_to_seconds($ru_stime, $ru_stime_µs),
            @ru;
}

#use Data::Dumper;


_export_ok 'waitid_';
sub waitid_($$$;$$) {
    my ($id_type, $id, $options, $record_rusage, $record_siginfo) = @_;
    $record_siginfo //= 1;          # normally wanted
    $record_rusage //= 0;           # normally unwanted
    $record_rusage &&= !wantarray;  # functionally unwanted
    #warn "WAITID: ".Dumper(\@_);
    $id_type |= 0;
    $id |= 0;
    $options |= 0;
    my $siginfo = pack 'qQ*', -1, (0) x 15 if $record_siginfo;
    my $rusage = pack 'Q*', (0) x 18 if $record_rusage;
    state $syscall_id = _get_syscall_id 'waitid';
    $! = 0;
    my $r = syscall $syscall_id,
                    $id_type,
                    $id,
                    $record_siginfo ? $siginfo : undef,
                    $options,
                    $record_rusage ? $rusage : undef;
    warn sprintf "Invoked\tsyscall  %u WAITID\n"
                ."\targs     type=%d, id=%d, options=%#x rec_si=%s rec_ru=%s\n"
                ."\treturned result=%d si=(%s) rusage=(%s)\n"
                ."\terrno    %s (%d)\n",
            $syscall_id,
            $id_type,
            $id,
            $options,
            $record_siginfo // '(undef)',
            $record_rusage // '(undef)',
            $r,
            join(' ', unpack 'qQ*', $siginfo // ''),
            join(' ', unpack 'Q*', $rusage // ''),
            $!, $!;
    warn "waitid returned $r $!\n";
    $r == -1 and return;

    my ($si_pid, $si_uid, $si_signo, $si_status, $si_code) = _unpack_siginfo $siginfo
        if $record_siginfo;
    warn sprintf "\tsiginfo: pid=%d uid=%d signo=%d status=%d code=%d\n",
                $si_pid, $si_uid, $si_signo, $si_status, $si_code
        if $record_siginfo;

    return $si_pid if !wantarray;

    my @ru = _unpack_rusage $rusage
        if $record_rusage;

#   my (
#          $ru_utime, $ru_stime,
#          $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
#          $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
#          $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw) = _unpack_rusage $rusage
#       if $record_rusage;
    return $si_pid,
           $si_uid,
           $si_signo,
           $si_status,
           $si_code,
           $record_rusage ? _unpack_rusage $rusage
                          : ();
#          $ru_utime, $ru_stime,
#          $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
#          $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
#          $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw;
#          $record_rusage ? _unpack_rusage $rusage
}

################################################################################

_export_finish;

1;
