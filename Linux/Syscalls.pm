#! /module/for/perl

# Linux::Syscalls implements perl subs for Linux syscalls that are missing
# from module POSIX. (Some are POSIX, some are Linux innovations.)
#
# Where a whole family of calls are provided, generally they all call the new
# syscall, with various fixed options. Examples include:
#   * lchown & fchown calling chownat, and
#   * utimes, futimes, lutimes, futimesat, & futimens calling utimensat.
#
# In some cases, versions of functions provided because the POSIX module may
# not include the syscall, or may have been built without the syscall call
# enabled. notably:
#   * lchown.
#
# In addition, alias names are provided where the Linux (or POSIX) names are
# inconsistent; for example removing an "f" prefix when an "at" suffix is
# already present:
#   * faccessat
#   * fchmodat
#   * fchownat
#   * fstatat
#   * futimesat
#
# Where timestamps are required as arguments, they may be provided as floating
# point numbers, or as Time::Nanosecond::ts references (or indeed, any blessed
# object that implements the _sec, _µsec and _nsec methods).
#
# Lastly, in some cases, we do a more sane job of handling arguments than the
# POSIX version; in particular, we accept C<undef> in numerous places where a
# numeric value would normally be presented, and provide a sane & relevant
# default in its place:
#   * the UID & GID arguments to the *chown family may be given as C<undef> to
#     mean "don't change", which avoids the user having to know that C<-1> is a
#     magic value for this purpose; alternatively they may be given an an empty
#     string to mean "now".
#   * the dir_fd argument(s) to the *at family may be given as C<undef> to mean
#     AT_FDCWD.
#   * the path argument(s) to the *at family may be given as C<undef> to mean
#     "apply the AT_EMPTY_PATH flag, and pass an empty path";
#

use 5.010;
use utf8;       # allow $µs symbol
use strict;
use warnings;
use feature 'state';

package Linux::Syscalls v0.3.0;

use base 'Exporter';

use Config;
use Scalar::Util qw( looks_like_number blessed );

use Errno qw( ENOSYS EBADF );
use Fcntl qw( S_IFMT );
use POSIX qw( floor uname );

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
    getdents_default_bufsize => 0x4000, # a multiple of the file allocation block size
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
    if (ref $t) {
        return $t->_sec, $t->_µsec;
    } else {
        my $s = floor($t);
        my $µs = floor(($t - $s) * 1E6 + 0.5);
        return $s, $µs;
    }
}

# Newer-style "timespec" contains tv_sec & tv_nsec (ns precision)
sub _SC_timespec_to_seconds($$) {
    my ($s, $ns) = @_;
    return $s + $ns / 1E9;
}

sub _seconds_to_timespec($) {
    my $t = $_[0] // 0.0;
    if (ref $t) {
        return $t->_sec, $t->_nsec;
    } else {
        my $s = floor($t);
        my $ns = floor(($t - $s) * 1E9 + 0.5);
        return $s, $ns;
    }
}

sub _timespec_to_seconds($$) {
    my $f = \&_SC_timespec_to_seconds;
    $f = \&Time::Nanosecond::new_timespec if exists &Time::Nanosecond::new_timespec;
    no warnings 'redefine';
    *_timespec_to_seconds = $f;
    goto &$f;
}

#
# Standardized argument handling:
#
# * when dir_fd is:
#     - undef or empty or ".", use AT_FDCWD; or
#     - a blessed reference with a C<dirfd> or C<fileno> method, use that to
#       get its underlying filedescriptor number
#     - a glob or filehandle, use the C<fileno> function to get its underlying
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
    MAP_FD: {
        my $D = $$dir_fd;
        if ( ref $D ) {
            # Try calling fileno method on any object that implements it
            eval { $$dir_fd = $D->dirfd;  1 } and last MAP_FD if $^V ge v5.25.0;
            eval { $$dir_fd = $D->fileno; 1 } and last MAP_FD;
        } else {
            # undef, '' and '.' refer to current directory
            if ( ! defined $D || $D eq '' || $D eq '.' ) {
                $$dir_fd = AT_FDCWD;
                last MAP_FD;
            }
            # Keep the input value unchanged if it's an integer
            looks_like_number $D and last MAP_FD;
        }
        # Try calling fileno builtin func on an IO::File (ref) or GLOB-ref (ref) or
        # GLOB (non-ref)
        defined eval { $$dir_fd = fileno $D } and last MAP_FD;
        # It's not a valid filedescriptor
        $$dir_fd = undef;
        $! = EBADF;
        return;
    }

    shift;
    goto &_normalize_path if @_;
}

sub _normalize_path(\$;\$\$) {
    my ($path, $flags, $default) = @_;
    if (defined $$path) {
        $$flags //= $default // AT_SYMLINK_NOFOLLOW if $flags;
        $$path = "$$path";
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
        #  L   unsigned long  f_bsize;    /* filesystem block size */
        #  L   unsigned long  f_frsize;   /* fragment size */
        #  Q   fsblkcnt_t     f_blocks;   /* size of fs in f_frsize units */
        #  Q   fsblkcnt_t     f_bfree;    /* # free blocks */
        #  Q   fsblkcnt_t     f_bavail;   /* # free blocks for unprivileged users */
        #  Q   fsfilcnt_t     f_files;    /* # inodes */
        #  Q   fsfilcnt_t     f_ffree;    /* # free inodes */
        #  Q   fsfilcnt_t     f_favail;   /* # free inodes for unprivileged users */
        #  L   unsigned long  f_fsid;     /* filesystem ID */
        #  L   unsigned long  f_flag;     /* mount flags */
        #  L   unsigned long  f_namemax;  /* maximum filename length */
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
        _normalize_path $path;
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
# Pass undef for path to apply to dir_fd (which might be a symlink)
# Pass undef for uid or gid to avoid changing that id.
# Pass AT_SYMLINK_NOFOLLOW for flags to check on a symlink itself.
#

*accessat = \&faccessat;
_export_tag qw{ _at => faccessat accessat };
sub faccessat($$$;$) {
    my ($dir_fd, $path, $mode, $flags) = @_;
    _resolve_dir_fd_path $dir_fd, $path, $flags, 0 or return;
    $mode += 0;
    state $syscall_id = _get_syscall_id 'faccessat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $mode, $flags;
}

################################################################################

#
# fchmodat - like chmod but relative to a DIR
#
# Pass undef for dir_fd to use CWD for relative paths.
# Pass undef for path to apply to dir_fd (which might be a symlink)
# Pass AT_SYMLINK_NOFOLLOW for flags to modify a symlink itself. However the
# man page for fchmodat warns:
#   "AT_SYMLINK_NOFOLLOW
#       If pathname is a symbolic link, do not dereference it: instead operate
#       on the link itself.  This flag is not currently implemented."
#
# Whilst the mode of a symlink has no meaning and so it's pointless to try
# to change it, it is perhaps useful to avoid changing the mode of something
# pointed to by a symlink.
#

*chmodat = \&fchmodat;
_export_tag qw{ _at => fchmodat chmodat };
sub fchmodat($$$;$) {
    my ($dir_fd, $path, $perm, $flags) = @_;
    _resolve_dir_fd_path $dir_fd, $path, $flags, 0 or return;
    if ($flags & AT_SYMLINK_NOFOLLOW) {
        $! = ENOSYS;
        return;
    }
    $perm &= CHMOD_MASK; # force int, and range-limit
    state $syscall_id = _get_syscall_id 'fchmodat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $perm, $flags;
}

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
#    _normalize_path $path;
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
# Pass undef for path to apply to dir_fd (which might be a symlink)
# Pass undef for uid or gid to avoid changing that id.
# Omit flags (or pass undef) to modify a symlinks itself.
#

*chownat = \&fchownat;
_export_tag qw{ _at => fchownat chownat };
sub fchownat($$$$;$) {
    my ($dir_fd, $path, $uid, $gid, $flags) = @_;
    _resolve_dir_fd_path $dir_fd, $path, $flags or return;
    ($uid //= -1) += 0;
    ($gid //= -1) += 0;
    state $syscall_id = _get_syscall_id 'fchownat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $uid, $gid, $flags;
}

################################################################################

#
# linkat - like link but relative to (two) DIRs
#
# Pass undef for either dir_fd to use CWD for relative paths.
# Omit flags (or pass undef) to avoid following symlinks.
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

_export_ok qw{ statns };
sub statns($) {
    my ($path) = @_;
    _normalize_path $path;
    my $buffer = "\xa5" x 160;
    state $syscall_id = _get_syscall_id 'stat';
    0 == syscall $syscall_id, $path, $buffer or return;
    return _unpack_stat($buffer);
}

_export_ok qw{ lstatns };
sub lstatns($) {
    my ($path) = @_;
    _normalize_path $path;
    my $buffer = "\xa5" x 160;
    state $syscall_id = _get_syscall_id 'lstat';
    0 == syscall $syscall_id, $path, $buffer or return;
    return _unpack_stat($buffer);
}

_export_ok qw{ fstatns };
sub fstatns($) {
    my ($fd) = @_;
    $fd = $fd->fileno if ref $fd;
    my $buffer = "\xa5" x 160;
    state $syscall_id = _get_syscall_id 'fstat';
    0 == syscall $syscall_id, $fd, $buffer or return;
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

*statat = \&fstatat;
_export_tag qw{ _at => fstatat statat };
sub fstatat($$;$) {
    my ($dir_fd, $path, $flags) = @_;
    _resolve_dir_fd_path $dir_fd, $path, $flags or return;
    my $buffer = "\xa5" x 160;
    state $syscall_id = _get_syscall_id 'newfstatat';
    #warn "syscall=$syscall_id, dir_fd=$dir_fd, path=$path, buffer=".length($buffer)."-bytes, flags=$flags\n";
    0 == syscall $syscall_id, $dir_fd, $path, $buffer, $flags or return;
    return _unpack_stat($buffer);
}

################################################################################

#
# mkdir but relative to an open dir_fd
#  pass undef for mode to use 0777
#

_export_tag qw{ _at => mkdirat };
sub mkdirat($$$) {
    my ($dir_fd, $path, $mode) = @_;
    _resolve_dir_fd_path $dir_fd, $path or return;
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
    _resolve_dir_fd_path $dir_fd, $path or return;
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
    _resolve_dir_fd_path $dir_fd, $path or return;  # $flags here means something unrelated
    $mode //= 0666;
    state $syscall_id = _get_syscall_id 'openat';
    return syscall $syscall_id, $dir_fd, $path, $flags, $mode;
}

################################################################################


_export_tag qw{ _at => readlinkat };
sub readlinkat($;$) {
    my ($dir_fd, $path) = @_;
    _resolve_dir_fd_path $dir_fd, $path or return;
    my $buffer = "\xa5" x 8192;
    state $syscall_id = _get_syscall_id 'readlinkat';
    my $r = syscall $syscall_id, $dir_fd, $path, $buffer, length($buffer);
    $r > 0 or return;
    return substr $buffer, 0, $r;
}

################################################################################

#
# renameat - like rename but with each path relative to a given DIR
#
# Pass undef for either dir_fd to use CWD for relative paths.
# Omit flags (or pass undef) to avoid following symlinks.
#

_export_tag qw{ _at => renameat };
sub renameat($$$$) {
    my ($olddir_fd, $oldpath, $newdir_fd, $newpath) = @_;
    _resolve_dir_fd_path $olddir_fd, $oldpath or return;
    _resolve_dir_fd_path $newdir_fd, $newpath or return;
    state $syscall_id = _get_syscall_id 'renameat';
    return 0 == syscall $syscall_id, $olddir_fd, $oldpath, $newdir_fd, $newpath;
}

################################################################################

#
# symlinkat - like symlink but relative to (two) DIRs
#
# Pass undef for either dir_fd to use CWD for relative paths.
# Omit flags (or pass undef) to avoid following symlinks.
#

_export_tag qw{ _at => symlinkat };
sub symlinkat($$$) {
    my ($oldpath, $newdir_fd, $newpath) = @_;
    _normalize_path $oldpath;
    _resolve_dir_fd_path $newdir_fd, $newpath or return;
    state $syscall_id = _get_syscall_id 'symlinkat';
    return 0 == syscall $syscall_id, $oldpath, $newdir_fd, $newpath;
}

################################################################################

#
# unlinkat - like unlink but relative to a given DIR
#
# Pass undef for dir_fd to use CWD for relative paths.
#
# Will refuse to remove a directory unless flags includes AT_REMOVEDIR; see
# rmdirat.
#

_export_tag qw{ _at => unlinkat };
sub unlinkat($$;$) {
    my ($dir_fd, $path, $flags) = @_;
    _resolve_dir_fd_path $dir_fd, $path, $flags or return;
    state $syscall_id = _get_syscall_id 'unlinkat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $flags, 0;
}

#
# rmdirat (fake syscall) - like rmdir but relative to a given DIR
#
# Pass undef for dir_fd to use CWD for relative paths.
#

_export_tag qw{ _at => rmdirat };
sub rmdirat($$) {
    my ($dir_fd, $path) = @_;
    return unlinkat $dir_fd, $path, AT_REMOVEDIR|AT_SYMLINK_NOFOLLOW;
}

################################################################################

sub _normalize_utimens($$) {
    my ($t, $time_res) = @_;
    defined $t          || return -1, UTIME_OMIT;
    ref $t || $t ne ''  || return -1, UTIME_NOW;
    my ($s, $ns) =  _seconds_to_timespec $t;
    if ( $time_res == TIMERES_SECOND ) {
        $ns = 0;
    } elsif ( $time_res < TIMERES_NANOSECOND ) {
        $ns -= $ns % 10 ** ( TIMERES_NANOSECOND - $time_res );
    }
    return $s, $ns;
}

#
# utimensat (POSIX syscall) - like utimes, but:
#
#   * relative to an open dir_fd, and:
#   * with nanosecond precision
#
#   * Pass undef for dir_fd to use CWD for relative paths.
#   * Pass undef for path to apply to dir_fd (which might be a symlink)
#   * Pass undef for atime or mtime to avoid changing that timestamp, empty
#     string to set it to the current time, or an epoch second (with decimal
#     fraction) to set it to that value (with nanosecond resolution).
#     Time::Nanosecond::ts values are also supported.
#   * Omit flags (or pass undef) to avoid following symlinks.
#   * Accepts an optional time_res parameter to moderate the precision
#     (normally only used when emulating utime or utimes syscalls, where
#     timestamps have microsecond or whole second resolution).
#
#

_export_tag qw{ _at => utimensat };
sub utimensat($$$$;$$) {
    my ($dir_fd, $path, $atime, $mtime, $flags, $time_res) = @_;
    _resolve_dir_fd_path $dir_fd, $path, $flags or return;
    $time_res //= TIMERES_NANOSECOND;
    my $ts = pack "(Q2)2", map { _normalize_utimens $_, $time_res } $atime, $mtime;
    state $syscall_id = _get_syscall_id 'utimensat';
    return 0 == syscall $syscall_id, $dir_fd, $path, $ts, $flags;
}

#
# futimesat (abandoned POSIX syscall proposal)
#
#   * now a Linux-specific syscall, though a similar syscall exists on Solaris.
#   * like utimes, but use dir_fd in place of CWD; or equivalently, like
#     utimensat except that times are only microsecond precision, and there's
#     no flags so modifying a symlink is not possible (hence pass 0 for flags).
#
#   * Pass undef for dir_fd to use CWD for relative paths.
#   * Pass undef for path to apply to dir_fd (which might be a symlink; this is
#     an extension from the syscall)
#   * Pass undef for atime or mtime to avoid changing that timestamp, empty
#     string to set it to the current time, or an epoch second (with decimal
#     fraction) to set it to that value (with microsecond resolution).
#     Time::Nanosecond::ts values are also supported.
#

_export_ok qw{ futimesat };
sub futimesat($$$$) {
    my ($dir_fd, $path, $atime, $mtime) = @_;
    return utimensat $dir_fd, $path, $atime, $mtime, 0, TIMERES_MICROSECOND;
}

#
# futimens (POSIX syscall) - like utimensat but just an open fd (no filepath)
#

_export_tag qw{ f_ => futimens };
sub futimens($$$) {
    my ($fd, $atime, $mtime) = @_;
    return utimensat $fd, undef, $atime, $mtime;
}

#
# futimes (POSIX syscall) - like utimes but on an open fd instead of filepath
#
#   * microsecond resolution
#
# fd may refer to a symlink obtained with C<open ... O_PATH>, so pass C<undef>
# for flags.
#

_export_tag qw{ f_ => futimes };
sub futimes($$$) {
    my ($fd, $atime, $mtime) = @_;
    return utimensat $fd, undef, $atime, $mtime, undef, TIMERES_MICROSECOND;
}

#
# utimes (POSIX syscall)
#
#   * microsecond resolution
#   * always follow symlinks
#

_export_tag qw{ f_ => utimes };
sub utimes($$$) {
    my ($path, $atime, $mtime) = @_;
    return utimensat undef, $path, $atime, $mtime, 0, TIMERES_MICROSECOND;
}

#
# utimens (fake syscall) - like utimes but to nanosecond resolution
#
#   * microsecond resolution
#   * always follow symlinks
#

_export_ok qw{ utimens };
sub utimens($$$) {
    my ($path, $atime, $mtime) = @_;
    return utimensat undef, $path, $atime, $mtime, 0;
}

#
# lutime (fake syscall) - like utime but on a symlink
#
#   * wholesecond resolution
#   * never follow symlinks
#

_export_tag qw{ l_ => lutime };
sub lutime($$$) {
    my ($path, $atime, $mtime) = @_;
    return utimensat undef, $path, $atime, $mtime, AT_SYMLINK_NOFOLLOW, TIMERES_SECOND;
}

#
# lutimes (fake syscall) - like utimes but on a symlink
#
#   * microsecond resolution
#   * never follow symlinks
#

_export_tag qw{ l_ => lutimes };
sub lutimes($$$) {
    my ($path, $atime, $mtime) = @_;
    return utimensat undef, $path, $atime, $mtime, AT_SYMLINK_NOFOLLOW, TIMERES_MICROSECOND;
}

#
# lutimens (fake syscall) - like utimes but on a symlink and to nanosecond resolution
#
#   * microsecond resolution
#   * never follow symlinks
#

_export_tag qw{ l_ => lutimens };
sub lutimens($$$) {
    my ($path, $atime, $mtime) = @_;
    return utimensat undef, $path, $atime, $mtime, AT_SYMLINK_NOFOLLOW;
}

################################################################################

#
# C<getdents> read entries from a directory.
#
# Parameters:
#   * a filedescriptor; and
#   * an optional buffer size.
# Returns:
#   * a list blessed dirent entries; or
#   * an empty list at EOF; or
#   * an undef on error (including "buffer too small").
#
# The C<getdents> syscall is provided to work around some deficiencies in
# Perl's core C<opendir>/C<readdir>/C<closedir> functions. Converting between a
# filedescriptor and DirHandle is awkward and unreliable.
#   1. You can't easily use C<readdir> given a filedescriptor;
#   2. You can't easily use C<fstat>, C<fchmod>, C<openat>, etc, given a
#      C<DirHandle> (from C<opendir>).
#   3. You don't get access to any additional information contained in a dirent
#      record, such as the file type.
#   4. There are no C<telldir> and C<seekdir> functions.
#   5. The overloading of IO::Handle to hold both an open file and an open dir
#      makes many operations much harder than necessary. (Later versions of
#      Perl fixed that.)
#
# Perl's C<opendir> does not understand C<< <&=$fd >> (and there's no
# C<fdopendir>). Most work-arounds involve C<diropen("/dev/fd/$fd")>, which
# opens a new filedescriptor, and as a result:
#   1. There is a (small) chance that C<opendir("/dev/fd/$fd")> might fail with
#      C<EMFILE> or C<ENFILE>;
#   2. Extra code is needed ensure that C<closedir> and C<sysclose> are done
#      together.
#   3. The new filedescriptor has its own separate cursor, so you still can't
#      use C<sysseek> and C<systell>.
#
# On the other hand, C<dirfd> was not added to core Perl until about v5.26, but
# there's no C<flushdir>, so even if you use sysseek on the underlying
# filedescriptor, there's no way to be sure that you get the corresponding
# dirent immediately.
#
# C<getdents> takes a filedescriptor and an optional buffer size. It returns:
#   * a list of arrays, each blessed as dirent entry; or
#   * an empty list at EOF; or
#   * an undef on error.
#
# NB:
#  1. The kernel call may return as many dirent entries as fit in the buffer,
#     and there is no direct mechanism to limit the number of entries returned.
#     If there is not enough room for at least one entry, then undef is
#     returned with set $! to EINVAL.
#
#  2. When a fd is open on a directory, the position reported by systell (and
#     used by sysseek) is an opaque token, not a linear position.
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
    $bufsize ||= getdents_default_bufsize;
    my $buffer = "\xee" x $bufsize;
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

{
    package Linux::Syscalls::ioctl;
    # Perlified version of /usr/include/asm-generic/ioctl.h

    # Universal
    use constant _IOC_NRBITS   => 8;
    use constant _IOC_TYPEBITS => 8;
    use constant _IOC_DIRBITS  => 2;

    # SIZEBITS is (supposedly) platform-specific, however it will always be
    # BitsPerWord-(sum of other sizes), and since BitsPerWord will normally be
    # 32, SIZEBITS will normally be 14. (However this might change if a new
    # ioctl needs a parameter block larger than 16 KiB.)

    use constant _IOC_SIZEBITS => 14;

    # Universally computed; note that the order of the bitfields is fixed for
    # all implementation.
    use constant _IOC_NRSHIFT   => 0;                              # 0
    use constant _IOC_TYPESHIFT => _IOC_NRSHIFT   + _IOC_NRBITS;   # 8
    use constant _IOC_SIZESHIFT => _IOC_TYPESHIFT + _IOC_TYPEBITS; # 16
    use constant _IOC_DIRSHIFT  => _IOC_SIZESHIFT + _IOC_SIZEBITS; # 30

    sub __b2m($) { my ($w) = @_; $w = 1 << $w; --$w or --$w; return $w; }

    use constant _IOC_DIRMASK  => __b2m _IOC_DIRBITS;
    use constant _IOC_SIZEMASK => __b2m _IOC_SIZEBITS;
    use constant _IOC_TYPEMASK => __b2m _IOC_TYPEBITS;
    use constant _IOC_NRMASK   => __b2m _IOC_NRBITS;

    #
    # Direction bits, which any architecture can choose to override
    # before including this file.
    #

    use constant {
        _IOC_NONE  => 0,
        _IOC_WRITE => 1,
        _IOC_READ  => 2,
        _IOC_RDWR  => 3,    # Perlish, not in C header
    };

    sub _IOC($$$$) {
        my ($dir, $type, $nr, $size) = @_;
        use Carp 'confess';
        grep { ! defined || /\D|^$/ } @_ and confess 'Non-numeric arg';

        return $dir  << _IOC_DIRSHIFT
             | $size << _IOC_SIZESHIFT
             | $type << _IOC_TYPESHIFT
             | $nr   << _IOC_NRSHIFT;
    }

    #sub _IOC_packsize($) { my ($t) = @_; return $t =~ /\D/ ? length pack $t, (0) x 99 : $t; } # (sizeof(t))

    #/* used to create numbers */
    sub _IO($$)         { my ($type, $nr)        = @_; return _IOC( _IOC_NONE,  $type, $nr, 0 ); }
    sub _IOR($$$)       { my ($type, $nr, $size) = @_; return _IOC( _IOC_READ,  $type, $nr, $size ); }
    sub _IOW($$$)       { my ($type, $nr, $size) = @_; return _IOC( _IOC_WRITE, $type, $nr, $size ); }
    sub _IOWR($$$)      { my ($type, $nr, $size) = @_; return _IOC( _IOC_RDWR,  $type, $nr, $size ); }

    # used to decode ioctl numbers
    sub _IOC_DIR($)  { my ($nr) = @_; return $nr >> _IOC_DIRSHIFT  & _IOC_DIRMASK;  }
    sub _IOC_SIZE($) { my ($nr) = @_; return $nr >> _IOC_SIZESHIFT & _IOC_SIZEMASK; }
    sub _IOC_TYPE($) { my ($nr) = @_; return $nr >> _IOC_TYPESHIFT & _IOC_TYPEMASK; }
    sub _IOC_NR($)   { my ($nr) = @_; return $nr >> _IOC_NRSHIFT   & _IOC_NRMASK;   }
}

################################################################################

# fiemap - a wrapper for ioctl(fd, FS_IOC_FIEMAP, &buffer);
# see https://github.com/torvalds/linux/blob/b9f5dba225aede4518ab0a7374c2dc38c7c049ce/Documentation/filesystems/fiemap.txt
#
# Constants from /usr/include/linux/fiemap.h

use constant {

    FIEMAP_FLAG_SYNC             => 0x00000001, # sync file data before map
    FIEMAP_FLAG_XATTR            => 0x00000002, # map extended attribute tree
    FIEMAP_FLAGS_COMPAT          => 0x00000003, # = FIEMAP_FLAG_SYNC | FIEMAP_FLAG_XATTR
    FIEMAP_FLAG_CACHE            => 0x00000004, # request caching of the extents

    FIEMAP_EXTENT_LAST           => 0x00000001, # Last extent in file.
    FIEMAP_EXTENT_UNKNOWN        => 0x00000002, # Data location unknown.
    FIEMAP_EXTENT_DELALLOC       => 0x00000004, # Location still pending. Sets EXTENT_UNKNOWN.
    FIEMAP_EXTENT_ENCODED        => 0x00000008, # Data can not be read while fs is unmounted
    FIEMAP_EXTENT_DATA_ENCRYPTED => 0x00000080, # Data is encrypted by fs. Sets EXTENT_NO_BYPASS.
    FIEMAP_EXTENT_NOT_ALIGNED    => 0x00000100, # Extent offsets may not be block aligned.
    FIEMAP_EXTENT_DATA_INLINE    => 0x00000200, # Data mixed with metadata. Sets EXTENT_NOT_ALIGNED.
    FIEMAP_EXTENT_DATA_TAIL      => 0x00000400, # Multiple files in block. Sets EXTENT_NOT_ALIGNED.
    FIEMAP_EXTENT_UNWRITTEN      => 0x00000800, # Space allocated, but no data (i.e. zero).
    FIEMAP_EXTENT_MERGED         => 0x00001000, # File does not natively support extents. Result merged for efficiency.
    FIEMAP_EXTENT_SHARED         => 0x00002000, # Space shared with other files.

    FIEMAP_MAX_OFFSET            => ~0,         # UINT64_MAX = 0xffffffffffffffff

    FIEMAP_FLAG_PARTIAL          => (~0 ^ (~0>>1)),

};

#     # struct fiemap {
#  Q  #     __u64 fm_start;             /* logical offset (inclusive) at which to start mapping (in) */
#  Q  #     __u64 fm_length;            /* logical length of mapping which userspace wants (in) */
#  L  #     __u32 fm_flags;             /* FIEMAP_FLAG_* flags for request (in/out) */
#  L  #     __u32 fm_mapped_extents;    /* number of extents that were mapped (out) */
#  L  #     __u32 fm_extent_count;      /* size of fm_extents array (in) */
#x[L] #     __u32 fm_reserved;
#     #     struct fiemap_extent {
#  Q  #         __u64 fe_logical;       /* logical offset in bytes for the start of the extent from the beginning of the file */
#  Q  #         __u64 fe_physical;      /* physical offset in bytes for the start of the extent from the beginning of the disk */
#  Q  #         __u64 fe_length;        /* length in bytes for this extent */
#x[Q2]#         __u64 fe_reserved64[2];
#  L  #         __u32 fe_flags;         /* FIEMAP_EXTENT_* flags for this extent */
#x[L3]#         __u32 fe_reserved[3];
#     #     } fm_extents[];             /* array of mapped extents (out) */
#     # };

use constant fiemap_header_packfmt  => 'QQLLLx[L]';
use constant fiemap_header_size     => length pack fiemap_header_packfmt, (0) x length fiemap_header_packfmt;   # = 32 = 2×8+4×4
use constant fiemap_header_elements => scalar @{[ unpack fiemap_header_packfmt, 'x' x fiemap_header_size ]};    # = 5

use constant fiemap_extent_packfmt  => 'QQQx[Q2]Lx[L3]';
use constant fiemap_extent_size     => length pack fiemap_extent_packfmt, (0) x length fiemap_extent_packfmt;   # = 56 = 5×8+4×4
use constant fiemap_extent_elements => scalar @{[ unpack fiemap_extent_packfmt, 'x' x fiemap_extent_size ]};    # = 4

use constant fiemap_default_bufcount => 1;

use constant FS_IOC_FIEMAP => Linux::Syscalls::ioctl::_IOWR(ord 'f', 11, fiemap_header_size);

{
    package Linux::Syscalls::bless::fiemap_extent;
    sub logical  { $_[0]->[0]  }
    sub physical { $_[0]->[1]  }
    sub length   { $_[0]->[2]  }
    sub flags    { $_[0]->[3]  }
}

sub fiemap($;$$) {
    my ($fd, $bufcount, $in_flags) = @_;
    state $syscall_id = _get_syscall_id 'ioctl';
    state $packfmt = 'QQLLLL';
    state $extent_fmt = 'QQQQLL';
    $bufcount ||= fiemap_default_bufcount;
    my $fm_start = 0;
    my $fm_length = FIEMAP_MAX_OFFSET;
    $in_flags //= 0;
    my $fm_ext_count = 0;
    my $buffer = pack( $packfmt, $fm_start, $fm_length, $in_flags, 0xeeeeeeee, $bufcount ) . (  "\xee" x ( $bufcount * fiemap_extent_size ) );
    my $res = ioctl $fd, FS_IOC_FIEMAP, $buffer;
    #my $res = syscall $syscall_id, $fd, $buffer;
    printf STDERR "ioctl(%d, FS_IOC_FIEMAP, [%s]) -> %s\n", $fd, unpack("H*",$buffer), $res // '(undef)';
    $res >= 0 or return;
    my (undef, undef, $out_flags, $fm_mapped_extents ) = unpack fiemap_header_packfmt, $buffer;
    my @r = map {
            bless [ unpack fiemap_extent_packfmt,
                           substr $buffer,
                                  fiemap_header_size + $_ * fiemap_extent_size, fiemap_extent_size
                  ], Linux::Syscalls::bless::fiemap_extent::
        } 0 .. $fm_mapped_extents - 1;
    @r && $r[-1]->flags & FIEMAP_EXTENT_LAST or $out_flags |= FIEMAP_FLAG_PARTIAL;
    return $out_flags, \@r;
}

_export_tag qw( fiemap =>

    fiemap

    FIEMAP_FLAG_SYNC FIEMAP_FLAG_XATTR FIEMAP_FLAGS_COMPAT FIEMAP_FLAG_CACHE

    FIEMAP_EXTENT_LAST FIEMAP_EXTENT_UNKNOWN FIEMAP_EXTENT_DELALLOC
    FIEMAP_EXTENT_ENCODED FIEMAP_EXTENT_DATA_ENCRYPTED
    FIEMAP_EXTENT_NOT_ALIGNED FIEMAP_EXTENT_DATA_INLINE FIEMAP_EXTENT_DATA_TAIL
    FIEMAP_EXTENT_UNWRITTEN FIEMAP_EXTENT_MERGED FIEMAP_EXTENT_SHARED

    FIEMAP_MAX_OFFSET

    FIEMAP_FLAG_PARTIAL

);

if ($^C) {
    fiemap_header_size     == 32 or die;
    fiemap_header_elements ==  5 or die;
    fiemap_extent_size     == 56 or die;
    fiemap_extent_elements ==  4 or die;
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

{
# Internal subs for unpacking complex proc-related structs

# _unpack_siginfo returns a 6-element array: si_status, si_errno, si_code,
# si_pid, si_uid, si_signo.
#
# By prefilling the struct with a known bit-pattern, we can observe that the
# x86_64 kernel call currently writes to bytes 0~11 and 16~27, so a 28-byte or
# 7-qword buffer is required, but <asm-generic/siginfo.h> sets SI_MAX_SIZE to
# 128, presumably for future expansion, making the whole 140 bytes.
#
# si_errno only gets filled in when the waitid syscall succeeds, so it's always
# 0, but may be observable on other syscalls.
#
# The bytes 12~15 are left untouched; they appear to be alignment padding.

# From man (2) waitid:
#
#   Upon successful return, waitid() fills in the following fields of the
#   siginfo_t structure pointed to by infop:
#
#   si_pid      The process ID of the child.
#
#   si_uid      The real user ID of the child.
#               (This field is not set on most other implementations.)
#
#   si_signo    Always set to SIGCHLD.
#
#   si_status   Either the exit status of the child, as given to _exit(2) (or
#               exit(3)), or the signal that caused the child to terminate,
#               stop, or continue. The si_code field can be used to determine
#               how to interpret this field.
#
#   si_code     Set  to  one  of:
#               CLD_EXITED  (child  called _exit(2));
#               CLD_KILLED (child killed by signal);
#               CLD_DUMPED (child killed by signal, and dumped core);
#               CLD_STOPPED (child stopped by signal);
#               CLD_TRAPPED (traced child has trapped); or
#               CLD_CONTINUED (child continued by SIGCONT).
#
# however the order above is misleading, as in
# /usr/include/asm-generic/siginfo.h the order is:
#
#       #define SI_MAX_SIZE 128
#       ...
#       typedef struct siginfo {
#           int si_signo;
#           int si_errno;
#           int si_code;
#
#           union {
#               int _pad[SI_PAD_SIZE];
#       ...
#               /* SIGCHLD */
#               struct {
#                   __kernel_pid_t _pid;    /* which child */
#                   __ARCH_SI_UID_T _uid;   /* sender's uid */
#                   int _status;        /* exit code */
#                   __ARCH_SI_CLOCK_T _utime;
#                   __ARCH_SI_CLOCK_T _stime;
#               } _sigchld;
#       ...
#           } _sifields;
#       } __ARCH_SI_ATTRIBUTES siginfo_t;
#
# si_errno doesn't get mentioned because not applicable to this case: it's
# 0 when the syscall succeeds, and untouched when the syscall fails.

use constant UNPACK_SIGINFO => 'llLx[L]LLL';
use constant EMPTY_SIGINFO  => pack UNPACK_SIGINFO, (-1) x 6;

sub _unpack_siginfo($) {
    return unpack UNPACK_SIGINFO, $_[0];
}

# _unpack_rusage returns a 16-element array, starting with the utime & stime as
# floating-point seconds.

use constant UNPACK_RUSAGE => 'Q18';
use constant EMPTY_RUSAGE  => pack UNPACK_RUSAGE, (-1) x 18;

sub _unpack_rusage($) {
    my ($ru_utime, $ru_utime_µs, $ru_stime, $ru_stime_µs, @ru) = unpack UNPACK_RUSAGE, $_[0];
    return  _timeval_to_seconds($ru_utime, $ru_utime_µs),
            _timeval_to_seconds($ru_stime, $ru_stime_µs),
            @ru;
}
}

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

_export_tag qw{ proc => waitpid2 } if _get_syscall_id 'waitpid', 1;
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

# Assume that since you're calling waitid, you have an interest in the siginfo,
# but since the rusage is a Linux syscall extension, only include it if you
# explicitly ask for it.
_export_ok 'waitid_';
sub waitid_($$$;$$) {
    my ($id_type, $id, $options, $record_wrusage, $record_siginfo) = @_;
    $id_type |= 0;  # force numeric
    $id |= 0;       # force numeric
    $options |= 0;  # force numeric
    my $siginfo = EMPTY_SIGINFO if $record_siginfo // 1 and wantarray;
    my $wrusage = EMPTY_RUSAGE  if $record_wrusage // 0 and wantarray;
    state $syscall_id = _get_syscall_id 'waitid';
    $! = 0;
    my $r = syscall $syscall_id,
                    $id_type,
                    $id,
                    $siginfo // undef,
                    $options,
                    $wrusage // undef;
    state $debug_waitid = $ENV{PERL5_DEBUG_WAITID};
    warn sprintf "waitid_ invoked\n"
                ."\tsyscall  %u\n"
                ."\targs     type=%d, id=%d, options=%#x rec_si=%s rec_ru=%s\n"
                ."\treturned result=%d si=%s rusage=%s\n"
                ."\t\t errno %s (%d)\n",
            $syscall_id,
            $id_type,
            $id,
            $options,
            $record_siginfo ? wantarray ? defined $record_siginfo ? 'record' : 'record-default' : 'omit-notwantarray' : 'omit',
            $record_wrusage ? wantarray ? 'record' : 'omit-notwantarray' : defined $record_wrusage  ? 'omit' : 'omit-default',
            $r,
            defined $siginfo ? '<'.unpack('H*', $siginfo).'> ('.join(',', _unpack_siginfo $siginfo).')' : '(omitted)',
            defined $wrusage ? '<'.unpack('H*', $wrusage).'> ('.join(',', _unpack_rusage  $wrusage).')' : '(omitted)',
            $!, $!
        if $^C || $debug_waitid;
    $r == -1 and return;

    # ignore si_errno, because it must be 0 if we get here.
    my ($si_status, undef, $si_code, $si_pid, $si_uid, $si_signo, ) =
    my @si = _unpack_siginfo $siginfo
        if $record_siginfo && $r != -1;

    return $si_pid if !wantarray;

    my @wru = _unpack_rusage $wrusage
        if defined $wrusage;

    # Note pid & stat first, to be more consistent with other wait* calls
    return $si_status, $si_code, $si_pid, $si_uid, $si_signo,
           @wru;
}

################################################################################

_export_finish;

1;
