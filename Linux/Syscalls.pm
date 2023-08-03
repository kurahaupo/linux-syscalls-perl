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
#   * lchown
#
# In addition, alias names are provided where the Linux (or POSIX) names are
# inconsistent; for example removing an "f" prefix when an "at" suffix is
# already present:
#   * faccessat → accessat
#   * fchmodat  → chmodat
#   * fchownat  → chownat
#   * fstatat   → statat
#   * futimesat → utimesat
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
# In some cases one or more blessed objects may be returned:
#   * fiemap (fiemap_extent)
#   * getdents (dirent)
#   * stat, lstat
#   * statfs
# These returned objects have methods to choose the fields, but named without
# any invariant prefix so that (for example) stat returns an object with an
# "ino" method rather than a "st_ino" method.
#
# To make stat and lstat usable as a drop-in replacement for the built-in stat
# and lstat, they return the same list as provided by those functions when
# wantarray is true, and only return a blessed object when wantarray is false.

use 5.010;
use utf8;       # allow $µs symbol
use strict;
use warnings;
use feature 'state';

package Linux::Syscalls v0.5.0;

use base 'Exporter';

use Config;
use Scalar::Util qw( looks_like_number blessed );

use Fcntl qw( S_IFMT );
use POSIX qw( EBADF EFAULT EINVAL ENOSYS floor uname );
# Avoid «use Errno qw( E... );» as it results in dup import warnings with perl -Wc

BEGIN {
    # When in syntax-checking mode, check for clashes with the POSIX module,
    # which (unhelpfully) exports everything by default, including optional
    # symbols like lchown.
    #
    # Import POSIX after all other modules are imported, but before we define
    # anything. (POSIX normally won't complain if we've already defined
    # something that it provides.)
    POSIX->import() if $^C;
}

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
        # Remove duplicates from each list
        my %r;
        @r{@$e} = @$e;
        @$e = keys %r;
    }
    $EXPORT_TAGS{everything} = \@EXPORT_OK;
}

################################################################################

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
# These O_* constants can also be provided by POSIX.pm and/or Fcntl.pm, so only
# define them here if they're /not/ provided by those.
#
# They can all be specified to open*(), but some are applicable to other calls,
# notably the *_at() family.
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
        warn "Already have $k (probably from POSIX)\n" if $^C && $^W;
    }
    constant->import(\%o_const);
}

_export_tag qw{ O_ =>
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
#     - an integer, use it directly
#     - undef or empty or ".", use AT_FDCWD; or
#     - a blessed reference with a C<dirfd> or C<fileno> method, use that to
#       get its underlying filedescriptor number
#     - a glob or filehandle, use the C<fileno> function to get its underlying
#       filedescriptor number
#   otherwise fail
#
# * when flags is undef, use the given default, or AT_SYMLINK_NOFOLLOW if no
#   default is given.
#
# * when path is undef, add AT_EMPTY_PATH to the flags; this has the same
#   effect as substituting "." when dir_fd refers to a directory, but also
#   works for non-directories.
# * make sure the result is a string
#

sub _map_fd(\$;$) {
    my ($dir_fd, $allow_at_cwd) = @_;
    my $D = $$dir_fd;
    if ( ref $D ) {
        # Try calling fileno method on any object that implements it
        eval { $$dir_fd = $D->dirfd;  1 } and return 1 if $^V ge v5.25.0;
        eval { $$dir_fd = $D->fileno; 1 } and return 1;
        # Fall through and use fileno builtin
    } else {
        # Keep the input value unchanged if it's an integer, including
        # "0 but true"
        looks_like_number $D and return 1;
        if ( $allow_at_cwd and ! defined $D || $D eq '' || $D eq '.' ) {
            # undef, '' and '.' refer to current directory
            $$dir_fd = AT_FDCWD;
            return 1;
        }
    }
    # Try calling fileno builtin func on an IO::File (ref) or GLOB-ref (ref) or
    # GLOB (non-ref)
    defined eval { $$dir_fd = fileno $D } and return 1;
    # It's not a valid filedescriptor
    $$dir_fd = undef;
    $! = EBADF;
    return;
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

sub _resolve_dir_fd_path(\$;\$\$$) {
    my ($dir_fd) = @_;
    &_map_fd(shift, 1) or return;
    goto &_normalize_path if @_;
    return 1;
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
        warn "Trying to load $m" if $^C && $^W;
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

#
#   The statvfs POSIX call returns a field called f_flag that is a bit-mask
#   indicating the mount options for the file system.
#
#   Newer statfs syscalls return f_flags with this information, but it was not
#   originally present. We treat these as synonyms for the same field, and set
#   it to undef if it's not provided.
#
#   f_flags replaced one of the zero-filled padding fields, with its presence
#   is indicated by the ST_VALID bit, which we suppress in the returned field.
#
#   (Most of these constants are defined in <bits/statvfs.h>; some are from
#   kernel sources.)
#
#   It contains zero or more of the following bits:
#

use constant {
    ST_RDONLY       => 0x000001,    #* Mounted read-only.
    ST_NOSUID       => 0x000002,    #* Set-uid & set-gid bits are ignored by execve.
    ST_NODEV        => 0x000004,    #* Disallow access to device special files.
    ST_NOEXEC       => 0x000008,    #* Disallow program execution.
    ST_SYNCHRONOUS  => 0x000010,    #* Writes are synchronized immediately, as if O_SYNC always included when calling open(); see open(2) and fcntl(2)
    ST_VALID        => 0x000020,    # Kernel statfs has provided all the statvfs flags; hidden by libc
    ST_MANDLOCK     => 0x000040,    #* Enable mandatory locking (see fcntl(2)).
    ST_WRITE        => 0x000080,    # Explicit 'mount -w' (opposite of 'mount -r'; not implemented in Linux)
    ST_APPEND       => 0x000100,    # Honour append-only file attribute
    ST_IMMUTABLE    => 0x000200,    # Honour immutable file attribute
    ST_NOATIME      => 0x000400,    #* Do not update access times; see mount(2).
    ST_NODIRATIME   => 0x000800,    #* Do not update directory access times; see mount(2).
    ST_RELATIME     => 0x001000,    #* Update atime relative to mtime/ctime; see mount(2).
    #                  0x002000
    #                  0x004000
    #                  0x008000
    #                  0x010000
    ST_UNBINDABLE   => 0x020000,    # Currently unbindable
    ST_PRIVATE      => 0x040000,    # Currently private
    #                  0x080000
    ST_SHARED       => 0x100000,    # Currently shared
};

package Linux::Syscalls::bless::statfs {
    use constant {
        ST_VALID => Linux::Syscalls::ST_VALID
    };

    our %magic = (

        QNX4         =>     0x002f, # (_super)
        DevFS        =>     0x1373, # (_super)
        Ext          =>     0x137d, # (_super)
        MINIX1       =>     0x137f, # (_super) orig. minix, 14 char names
        MINIX12      =>     0x138f, # (_super2) minix, 30 char names
        DEVPTS       =>     0x1cd1, # (_super)
        MINIX2       =>     0x2468, # (_super) minix V2, 14 char names
        MINIX22      =>     0x2478, # (_super2) minix V2, 30 char names
        NILFS        =>     0x3434, # (_super)
        HFS          =>     0x4244, # (_super)
        MSDOS        =>     0x4d44, # (_super)
        MINIX3       =>     0x4d5a, # (_super) minix V3, 60 char names
        SMB          =>     0x517b, # (_super)
        NCP          =>     0x564c, # (_super)
        NFS          =>     0x6969, # (_super)
        ROMFS        =>     0x7275,
        JFFS2        =>     0x72b6, # (_super)
        ISOFS        =>     0x9660, # (_super)
        PROC         =>     0x9fa0, # (_super)
        OPENPROM     =>     0x9fa1, # (_super)
        USBDEVICE    =>     0x9fa2, # (_super)
        ADFS         =>     0xadf5, # (_super)
        AFFS         =>     0xadff, # (_super)
        EXT2_OLD     =>     0xef51, # (_super)
        EXT2         =>     0xef53, # (_super)
        EXT3         =>     0xef53, # (_super)
        EXT4         =>     0xef53, # (_super)
        UFS          => 0x00011954,
        CGROUP       => 0x0027e0eb, # (_super)
        EFS          => 0x00414a53, # (_super)
        HOSTFS       => 0x00c0ffee, # (_super) "coffee"
        TMPFS        => 0x01021994,
        V9FS         => 0x01021997,
        XIAFS        => 0x012fd16d, # (_super)
        XENIX        => 0x012ff7b4, # (_super)
        SYSV4        => 0x012ff7b5, # (_super)
        SYSV2        => 0x012ff7b6, # (_super)
        COH          => 0x012ff7b7, # (_super)
        FUTEXFS      => 0x0bad1dea, # (_super)  "0 bad idea"
        UDF          => 0x15013346, # (_super)
        MQUEUE       => 0x19800202,
        BFS          => 0x1badface, #           "1 bad face"
        CRAMFS       => 0x28cd3d45,
        JFS          => 0x3153464a, # (_super)
        BEFS         => 0x42465331, # (_super)
        BINFMTFS     => 0x42494e4d,
        SMACK        => 0x43415d53,
        PIPEFS       => 0x50495045,
        REISERFS     => 0x52654973, # (_super)
        NTFS_SB      => 0x5346544e,
        SOCKFS       => 0x534f434b,
        XFS          => 0x58465342, # (_super)
        PSTOREFS     => 0x6165676c,
        BDEVFS       => 0x62646576,
        SYSFS        => 0x62656572,
        DEBUGFS      => 0x64626720,
        FUSE         => 0x65735546, # (_super)
        QNX6         => 0x68191122, # (_super)
        SQUASHFS     => 0x73717368,
        CODA         => 0x73757245, # (_super)
        OCFS2        => 0x7461636f, # (_super)
        RAMFS        => 0x858458f6,
        BTRFS        => 0x9123683e, # (_super)
        HUGETLBFS    => 0x958458f6,
        VXFS         => 0xa501fcf5, # (_super)
        XENFS        => 0xabba1974, # (_super)
        EFIVARFS     => 0xde5e81e4,
        SELINUX      => 0xf97cff8c,
        HPFS         => 0xf995e849, # (_super)
        CIFS_NUMBER  => 0xff534d42,

    );

    our %names;
        @names{ values %magic } = keys %magic;
        $names{$magic{EXT4}} = 'EXT2~4';    # 3 mapped together; depends on feature set instead

    sub type($)    { return $_[0]->[0] }
    sub type_name($) { my $t = $_[0]->[0]; return $names{$t} // "Type#".$t }
    sub bsize($)   { return $_[0]->[1] }
    sub blocks($)  { return $_[0]->[2] }
    sub bfree($)   { return $_[0]->[3] }
    sub bavail($)  { return $_[0]->[4] }
    sub files($)   { return $_[0]->[5] }
    sub ffree($)   { return $_[0]->[6] }
    sub fsid($)    { return $_[0]->[7] }
    sub namelen($) { return $_[0]->[8] }    # statvfs calls this 'f_namemax'
    sub frsize($)  { return $_[0]->[9] }
    sub flags($)   { my $f = $_[0]->[10] ^ ST_VALID; return $f & ST_VALID ? undef : $f }   # statvfs calls this 'f_flag'
    sub spares($)  { my $r = $_[0]; return @$r[11..$#$r] }

    BEGIN {
        # Aliases for statvfs
        *favail     = \&ffree;      # Linux doesn't have "reserved inodes"
        *flag       = \&flags;
        *namemax    = \&namelen;
    }

    # Dissect flags
    sub flag_RDONLY($)      { return $_[0]->[10] & Linux::Syscalls::ST_RDONLY      }
    sub flag_NOSUID($)      { return $_[0]->[10] & Linux::Syscalls::ST_NOSUID      }
    sub flag_NODEV($)       { return $_[0]->[10] & Linux::Syscalls::ST_NODEV       }
    sub flag_NOEXEC($)      { return $_[0]->[10] & Linux::Syscalls::ST_NOEXEC      }
    sub flag_SYNCHRONOUS($) { return $_[0]->[10] & Linux::Syscalls::ST_SYNCHRONOUS }
    sub flag_MANDLOCK($)    { return $_[0]->[10] & Linux::Syscalls::ST_MANDLOCK    }
#   sub flag_VALID($)       { return $_[0]->[10] & Linux::Syscalls::ST_VALID       }
    sub flag_WRITE($)       { return $_[0]->[10] & Linux::Syscalls::ST_WRITE       }
    sub flag_APPEND($)      { return $_[0]->[10] & Linux::Syscalls::ST_APPEND      }
    sub flag_IMMUTABLE($)   { return $_[0]->[10] & Linux::Syscalls::ST_IMMUTABLE   }
    sub flag_NOATIME($)     { return $_[0]->[10] & Linux::Syscalls::ST_NOATIME     }
    sub flag_NODIRATIME($)  { return $_[0]->[10] & Linux::Syscalls::ST_NODIRATIME  }
    sub flag_RELATIME($)    { return $_[0]->[10] & Linux::Syscalls::ST_RELATIME    }
    sub flag_UNBINDABLE($)  { return $_[0]->[10] & Linux::Syscalls::ST_UNBINDABLE  }
    sub flag_PRIVATE($)     { return $_[0]->[10] & Linux::Syscalls::ST_PRIVATE     }
    sub flag_SHARED($)      { return $_[0]->[10] & Linux::Syscalls::ST_SHARED      }
}

sub statfs($;$) {
    my ($path, $opts) = @_;
    my $obs = 120;
    my $buf = "\xaa" x $obs;
    state $syscall_id = _get_syscall_id('statfs');
    0 == syscall $syscall_id, $path, $buf or return;
    my @R = unpack "qqQQQQQqqqqq*", $buf or return;
#   return @R if $opts & ST_RETURN_ARRAY && wantarray;
    my $nbs = length $buf;
    warn "buffer size changed from $obs to $nbs" if $obs != $nbs;
    return bless \@R, Linux::Syscalls::bless::statfs::;
        #  q   __fsword_t f_type;    /* Type of filesystem (see below) */
        #  q   __fsword_t f_bsize;   /* Optimal transfer block size */
        #  Q   fsblkcnt_t f_blocks;  /* Total data blocks in filesystem */
        #  Q   fsblkcnt_t f_bfree;   /* Free blocks in filesystem */
        #  Q   fsblkcnt_t f_bavail;  /* Free blocks available to unprivileged user */
        #  Q   fsfilcnt_t f_files;   /* Total file nodes in filesystem */
        #  Q   fsfilcnt_t f_ffree;   /* Free file nodes in filesystem */
        #  q   fsid_t     f_fsid;    /* Filesystem ID (officially a struct with two 32-bit ints; treat as one 64-bit int) */
        #  q   __fsword_t f_namelen; /* Maximum length of filenames */
        #  q   __fsword_t f_frsize;  /* Fragment size (since Linux 2.6) */
        #  q   __fsword_t f_flags;   /* Mount flags of filesystem (since Linux 2.6.36) */
        #  q4  __fsword_t f_spare[4]; /* Padding bytes reserved for future use */
}

*statvfs = \&statfs;    # Linux implements statvfs as a library call on top of an extended statfs

_export_ok qw{ statfs statvfs };
_export_tag qw{
    ST_  => ST_RDONLY ST_NOSUID ST_NODEV ST_NOEXEC ST_SYNCHRONOUS ST_MANDLOCK
            ST_WRITE ST_APPEND ST_IMMUTABLE ST_NOATIME ST_NODIRATIME
            ST_RELATIME ST_UNBINDABLE ST_PRIVATE ST_SHARED
};

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
        my ($uid, $gid, $path) = @_;
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
\&accessat or die; # suppress "only used once" warning
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
\&chmodat or die; # suppress "only used once" warning
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
    return 0 == fchmodat undef, $path, $perm, AT_SYMLINK_NOFOLLOW;
}

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
\&chownat or die; # suppress "only used once" warning
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

    sub _dtype          { $_[0]->[2] >> 12   }  # same as stmode_to_dt
    sub _perms          { $_[0]->[2] & 07777 }
    sub _time_res       { $_[0]->[13] }     # returns one of the TIMERES_* values, or undef if unknown

    use constant {
      # DT_UNKNOWN  => 0,
        DT_FIFO     => 1,   # S_IFIFO  >> 12
        DT_CHR      => 2,   # S_IFCHR  >> 12
        DT_DIR      => 4,   # S_IFDIR  >> 12
      # DT_NAM      => 5,   # S_IFNAM  >> 12
        DT_BLK      => 6,   # S_IFBLK  >> 12
        DT_REG      => 8,   # S_IFREG  >> 12
        DT_LNK      => 10,  # S_IFLNK  >> 12
        DT_SOCK     => 12,  # S_IFSOCK >> 12
      # DT_WHT      => 14,  # whiteout; you should never see these entries
    };

    sub _is_er { 0444 & $_[0]->_is_eugo_perms } # File is readable by effective uid/gid.
    sub _is_ew { 0222 & $_[0]->_is_eugo_perms } # File is writable by effective uid/gid.
    sub _is_ex { 0111 & $_[0]->_is_eugo_perms } # File is executable by effective uid/gid.
    sub _is_eu { $> == $_[0]->uid }             # File is owned by effective uid.
    sub _is_eg { $) == $_[0]->gid }             # File's primary group is effective gid.
    sub _is_eugo_perms { ( $_[0]->_is_eu ? 04700 :
                           $_[0]->_is_eg ? 02070 :
                                           01007 ) & $_[0]->_perms; }

    sub _is_rr { 0444 & $_[0]->_is_rugo_perms } # File is readable by real uid/gid.
    sub _is_rw { 0222 & $_[0]->_is_rugo_perms } # File is writable by real uid/gid.
    sub _is_rx { 0111 & $_[0]->_is_rugo_perms } # File is executable by real uid/gid.
    sub _is_ru { $< == $_[0]->uid }             # File is owned by real uid.
    sub _is_rg { $( == $_[0]->gid }             # File's primary group is real gid.
    sub _is_rugo_perms { ( $_[0]->_is_ru ? 04700 :
                           $_[0]->_is_rg ? 02070 :
                                           01007 ) & $_[0]->_perms; }

    sub _is_u { $_[0]->_perms & 04000 }         # File has setuid bit set.
    sub _is_g { $_[0]->_perms & 02000 }         # File has setgid bit set.
    sub _is_k { $_[0]->_perms & 01000 }         # File has sticky bit set.

    sub _is_z { $_[0]->_is_f && ! $_[0]->size } # File has zero size (is empty).
    sub _is_s { $_[0]->_is_f &&   $_[0]->size } # File has nonzero size (returns size in bytes).
    sub _is_f { $_[0]->_dtype == DT_REG }       # File is a plain file.
    sub _is_d { $_[0]->_dtype == DT_DIR }       # File is a directory.
    sub _is_l { $_[0]->_dtype == DT_LNK }       # File is a symbolic link (false if symlinks aren't supported by the file system).
    sub _is_p { $_[0]->_dtype == DT_FIFO }      # File is a named pipe (FIFO), or Filehandle is a pipe.
    sub _is_S { $_[0]->_dtype == DT_SOCK }      # File is a socket.
    sub _is_b { $_[0]->_dtype == DT_BLK }       # File is a block special file.
    sub _is_c { $_[0]->_dtype == DT_CHR }       # File is a character special file.

    sub _is_M { ($^T - $_[0]->mtime) / 86400 }  # Script start time minus file modification time, in days.
    sub _is_A { ($^T - $_[0]->atime) / 86400 }  # Script start time minus file access time.
    sub _is_C { ($^T - $_[0]->ctime) / 86400 }  # Script start time minus file inode change time (Unix, may differ for other platforms)
  # sub _is_e { 1 },                            # File exists. Necessarily true if we get here
  # sub _is_t { confess "Not implemented" },    # Filehandle is opened to a tty. (Not implemented; need to call tcgetattr() on original FD)
  # sub _is_T { confess "Not implemented" },    # File is an ASCII or UTF-8 text file (heuristic guess). (Not implemented; need to read original FD)
  # sub _is_B { confess "Not implemented" },    # File is a "binary" file (opposite of -T). (Not implemented; need to read original FD)

    use Carp 'confess';

    use overload -X => sub {
        my ($self, $op, undef) = @_;
        state $v = {
          # Effective           Real
            r =>  \&_is_er,     R =>  \&_is_rr, # File is readable by effective/real uid/gid.
            w =>  \&_is_ew,     W =>  \&_is_rw, # File is writable by effective/real uid/gid.
            x =>  \&_is_ex,     X =>  \&_is_rx, # File is executable by effective/real uid/gid.
            o =>  \&_is_eu,     O =>  \&_is_ru, # File is owned by effective/real uid.
            u =>  \&_is_u,  # File has setuid bit set.
            g =>  \&_is_g,  # File has setgid bit set.
            k =>  \&_is_k,  # File has sticky bit set.

            z =>  \&_is_z,  # File has zero size (is empty).
            s =>  \&_is_s,  # File has nonzero size (returns size in bytes).
            f =>  \&_is_f,  # File is a plain file.
            d =>  \&_is_d,  # File is a directory.
            l =>  \&_is_l,  # File is a symbolic link (false if symlinks aren't supported by the file system).
            p =>  \&_is_p,  # File is a named pipe (FIFO), or Filehandle is a pipe.
            S =>  \&_is_S,  # File is a socket.
            b =>  \&_is_b,  # File is a block special file.
            c =>  \&_is_c,  # File is a character special file.

            M =>  \&_is_M,  # Script start time minus file modification time, in days.
            A =>  \&_is_A,  # Script start time minus file access time.
            C =>  \&_is_C,  # Script start time minus file inode change time (Unix, may differ for other platforms)
          # e =>  \&_is_e,  # File exists. Necessarily true if we get here
          # t =>  \&_is_t,  # Filehandle is opened to a tty. (Not implemented; need to call tcgetattr() on original FD)
          # T =>  \&_is_T,  # File is an ASCII or UTF-8 text file (heuristic guess). (Not implemented; need to read original FD)
          # B =>  \&_is_B,  # File is a "binary" file (opposite of -T). (Not implemented; need to read original FD)
        };
        $v->{$op}->($self);
    };

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
    _map_fd($fd);
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
\&statat or die; # suppress "only used once" warning
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
# openat is like open, but non-absolute paths are taken as relative to a
# specified dir_fd;
#
# * flags defaults to O_PATH if omitted or undef
# * mode defaults to 0666 if omitted or undef
#
# openat returns truish on success (the new fd number, or "0 but true" if that
# would be 0), or falsish (an empty list) on failure.
#
# Use the O_PATH flag to allow opening symlinks and unreadable directories,
# with the intention of supplying the returned filedescriptor as the dir_fd to
# a subsequent call to fstatat or openat.
#

_export_tag qw{ _at => openat };
sub openat($$;$$) {
    my ($dir_fd, $path, $flags, $mode) = @_;
    # _resolve_dir_fd_path takes an AT_* flags parameter, but $flags holds O_*
    # flags, so don't use it here.
    _resolve_dir_fd_path $dir_fd, $path or return;
    $mode //= 0666;
    $flags //= O_PATH;
    state $syscall_id = _get_syscall_id 'openat';
    my $r = syscall $syscall_id, $dir_fd, $path, $flags, $mode;
    return if $r < 0;
    return $r || '0 but true';
}

# Undecided whether I should expose this publicly.
#sub openatn($$;$$) {
#    return &openat // -1;    # pass through unmodified args
#}

################################################################################

#
# close a filedescriptor previously returned by openat.
#
# (I wish this could simply be called "close", but obviously that would
# conflict with CORE::close)
#

_export_ok qw{ closefd };
sub closefd($) {
    my ($fd) = @_;
    state $syscall_id = _get_syscall_id 'close';
    my $r = syscall $syscall_id, $fd;
    return if $r < 0;
    return 1;
}

################################################################################

#
# Returns a Perl string holding the result of reading a symbolic link.
#

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
# This being Perl, we don't actually need separate function names when
# additional parameters are added. We just always call renameat2, with
# 0 when the flags are not supplied.
#

# from /usr/include/linux/fs.h
use constant {
    RENAME_NOREPLACE => 1 << 0,        # Don't overwrite target
    RENAME_EXCHANGE  => 1 << 1,        # Exchange source and dest
    RENAME_WHITEOUT  => 1 << 2,        # Whiteout source
};

_export_tag qw{
    RENAME_ rename rename2 =>
    RENAME_NOREPLACE RENAME_EXCHANGE RENAME_WHITEOUT renameat
};

_export_tag qw{ _at => renameat };
sub renameat($$$$;$) {
    my ($olddir_fd, $oldpath, $newdir_fd, $newpath, $flags) = @_;
    _resolve_dir_fd_path $olddir_fd, $oldpath or return;
    _resolve_dir_fd_path $newdir_fd, $newpath or return;
    state $syscall_id2 = _get_syscall_id 'renameat2';
    $flags //= 0;
    my $r = 0 == syscall $syscall_id2, $olddir_fd, $oldpath, $newdir_fd, $newpath, $flags;
  #
  # Uncomment this code if you ever run on a kernel that supports
  # renameat but not renameat2...
  #
  # if ( !$r && $! == ENOSYS && !$flags ) {
  #     state $syscall_id = _get_syscall_id 'renameat';
  #     return 0 == syscall $syscall_id, $olddir_fd, $oldpath, $newdir_fd, $newpath;
  # }
    return $r;
}
*renameat2 = \&renameat;
_export_ok qw{ renameat2 };

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
#   * relative to an open dir_fd
#   * with nanosecond precision
#
#   * Pass undef for dir_fd to use CWD for relative paths.
#   * Pass undef for path to apply to dir_fd (which might be a symlink)
#   * Pass undef for atime or mtime to avoid changing that timestamp, empty
#     string to set it to the current time, or an epoch second (with decimal
#     fraction) to set it to that value (with nanosecond resolution).
#     Time::Nanosecond::ts values are also supported.
#   * Omit flags (or pass undef) to avoid following symlinks.
#
#   * Accepts an optional time_res parameter to moderate the precision
#     (normally only used when emulating utime or utimes syscalls, where
#     timestamps have microsecond or whole second resolution).
#
# IMPORTANT NOTE:
#   1.  Because of the dir_fd+path pairing, and because of the optional flags,
#       only one file is processed per call, and the order of the parameters
#       differs from Perl's built-in utime.
#   2.  The timestamp handling differs from utime and utimes, where undef sets
#       to current time and there is no option to leave either timestamp
#       unchanged.
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
#   * like utimensat except that times are only microsecond precision, and
#     there's no flags argument; or equivalently,
#   * like utimes, but use dir_fd in place of CWD.
#
#   * Pass undef for dir_fd to use CWD for relative paths.
#   * Pass undef for path to apply to dir_fd (which might be a symlink; this is
#     an extension from the syscall)
#   * Pass undef for atime or mtime to avoid changing that timestamp, empty
#     string to set it to the current time, or an epoch second (with decimal
#     fraction) to set it to that value (with microsecond resolution).
#   * Time::Nanosecond::ts timestamps are also supported, though they will be
#     truncated to microsecond precision.
#

*utimesat = \&futimesat;
\&utimesat or die; # suppress "only used once" warning
_export_tag qw{ _at => futimesat utimesat };
sub futimesat($$$$) {
    my ($dir_fd, $path, $atime, $mtime) = @_;
    return 0 == utimensat $dir_fd, $path, $atime, $mtime, 0, TIMERES_MICROSECOND;
}

#
# futimens (POSIX syscall) - like utimensat but just an open fd (no filepath)
#

_export_ok qw{ futimens };
sub futimens($$$) {
    my ($fd, $atime, $mtime) = @_;
    _map_fd($fd);
    return 0 == utimensat $fd, undef, $atime, $mtime;
}

#
# futimes (POSIX syscall) - like utimes but on an open fd instead of filepath
#
#   * microsecond resolution
#
# fd may refer to a symlink obtained with C<open ... O_PATH>, so pass C<undef>
# for flags.
#

_export_ok qw{ futimes };
sub futimes($$$) {
    my ($fd, $atime, $mtime) = @_;
    _map_fd($fd);
    return 0 == utimensat $fd, undef, $atime, $mtime, undef, TIMERES_MICROSECOND;
}

#
# utimes (POSIX syscall)
#
#   * microsecond resolution
#   * always follow symlinks
#

_export_ok qw{ utimes };
sub utimes($$$) {
    my ($path, $atime, $mtime) = @_;
    return 0 == utimensat undef, $path, $atime, $mtime, 0, TIMERES_MICROSECOND;
}

#
# utimens (fake syscall) - like utimes but to nanosecond resolution
#
#   * nanosecond resolution
#   * always follow symlinks
#

_export_ok qw{ utimens };
sub utimens($$$) {
    my ($path, $atime, $mtime) = @_;
    return 0 == utimensat undef, $path, $atime, $mtime, 0;
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
    return 0 == utimensat undef, $path, $atime, $mtime, AT_SYMLINK_NOFOLLOW, TIMERES_SECOND;
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
    return 0 == utimensat undef, $path, $atime, $mtime, AT_SYMLINK_NOFOLLOW, TIMERES_MICROSECOND;
}

#
# lutimens (fake syscall) - like utimes but on a symlink and to nanosecond resolution
#
#   * nanosecond resolution
#   * never follow symlinks
#

_export_tag qw{ l_ => lutimens };
sub lutimens($$$) {
    my ($path, $atime, $mtime) = @_;
    return 0 == utimensat undef, $path, $atime, $mtime, AT_SYMLINK_NOFOLLOW;
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

# These DT_* constants are the same as the corresponding S_IF* constants
# shifted right 12 bits.

use constant {
    DT_UNKNOWN  => 0,
    DT_FIFO     => 1,   # S_IFIFO  >> 12
    DT_CHR      => 2,   # S_IFCHR  >> 12
    DT_DIR      => 4,   # S_IFDIR  >> 12
    DT_NAM      => 5,   # S_IFNAM  >> 12
    DT_BLK      => 6,   # S_IFBLK  >> 12
    DT_REG      => 8,   # S_IFREG  >> 12
    DT_LNK      => 10,  # S_IFLNK  >> 12
    DT_SOCK     => 12,  # S_IFSOCK >> 12
    DT_WHT      => 14,  # whiteout; you should never see these entries
};

# Options for extensions
use constant {
    GDE_RETRY           => 1,   # try again if buffer too small
    GDE_SKIP_DOTDOTDOT  => 2,   # filter out '.' and '..'
    GDE_SKIP_WHITEOUT   => 4,   # filter out DT_WHT entries
    GDE_NONE            => 0,   # none of the above
    GDE_DEFAULT         => 7,   # all of the above
};

{
my @dt_names = (
    'unknown',
    'fifo',
    'chr',
    undef,
    'dir',
    'nam',
    'blk',
    undef,
    'reg',
    undef,
    'lnk',
    undef,
    'sock',
    undef,
    'wht',
    undef,
);
sub dt_name($) {
    return $dt_names[$_[0]&15];
}
}

# Internal magic numbers
use constant {
    # Enough room for a dirent header (19 bytes) plus a maximal-length name
    # (MAXNAMELEN=1024 bytes) plus terminator (1 byte)
    getdents_maxnamelen_plus =>    0x400 + 19 + 1,

    # Same, rounded up to next power of 2
    getdents_minimum_bufsize =>    0x800, # == 1 << scalar frexp( getdents_maxnamelen_plus - 1 ),

    # The default size should be a multiple of the file allocation block size,
    # and must be at least sizeof(struct dirent)+MAXNAMELEN
    getdents_default_bufsize =>   0x4000,

    # Cap buffer size at 1MiB, which is enough for at least 1000 names
    getdents_maximum_bufsize => 0x100000,
};

{
    package Linux::Syscalls::bless::dirent;
    sub name  { $_[0]->[0]  }
    sub inode { $_[0]->[1]  }
    sub type  { $_[0]->[2]  }
    sub next  { $_[0]->[3]  }   # seek to this position to read the NEXT entry
}

sub getdents($;$$) {
    my ($fd, $bufsize, $options) = @_;
    _map_fd($fd);
    $bufsize ||= getdents_default_bufsize;
    $options //= GDE_DEFAULT;

    state $syscall_id = _get_syscall_id 'getdents';
    FETCH: for (;;) {
        $bufsize <= getdents_maximum_bufsize or $bufsize = getdents_maximum_bufsize;
        my $buffer = "\xee" x $bufsize;
        my $res_size = syscall $syscall_id, $fd, $buffer, $bufsize;

        # end-of-file
        return () if ! $res_size;

        # some sort of error
        if ( $res_size < 0 ) {
            if ( $! == EINVAL && $bufsize < getdents_minimum_bufsize && $options & GDE_RETRY ) {
                # Buffer wasn't big enough; try again with a bigger buffer
                $bufsize = getdents_maximum_bufsize;
                redo FETCH
            }
            return undef;   # keep $!
        }

        # returned result bigger than given size should not happen
        last FETCH if $res_size > $bufsize;

        my @r;
        UNPACK: for (my $offset = 0 ; $offset < $res_size ;) {
            #
            # The new getdents64 always returns d_inode, d_next, d_reclen, d_type,
            # and d_name (null-terminated) in that order on all architectures.
            #
            my ($inode, $next, $entsize, $type, $name) = unpack '@'.$offset.'QQSCU0Z*', $buffer;
            $entsize or last UNPACK;    # can't get anything more out of this block
            $entsize < 0 || $entsize > $res_size - $offset and $! = EFAULT, return undef;  # error while unpacking
            push @r, bless [$name, $inode, $type, $next], Linux::Syscalls::bless::dirent::
                unless $options & GDE_SKIP_WHITEOUT && $type == DT_WHT
                    || $options & GDE_SKIP_DOTDOTDOT && ( $name eq '.' || $name eq '..' );
            $offset += $entsize;
        }
        return @r if @r;
        # Buffer empty after eliding unwanted entries, try again
        $bufsize <<= 1;
    }
    $! = EINVAL;    # E2BIG would have been nicer, but POSIX says EINVAL
    return undef;
}

sub dt_to_stmode($) { $_[0] << 12 }
sub stmode_to_dt($) { $_[0] >> 12 }

_export_tag qw( DT_ dirent  =>  getdents
                                dt_to_stmode stmode_to_dt

                                DT_UNKNOWN
                                DT_FIFO DT_CHR DT_DIR DT_NAM DT_BLK
                                DT_REG DT_LNK DT_SOCK DT_WHT

                                GDE_RETRY
                                GDE_SKIP_DOTDOTDOT GDE_SKIP_WHITEOUT
              );

BEGIN { $^C and eval q{
# Include this in regression testing with perl -c but otherwise hide it

sub old_getdents_do_not_use_this($;$) {
    my ($fd, $bufsize) = @_;
    _map_fd($fd);
    state $syscall_id = _get_syscall_id 'getdents32';   # does not exist in x86_64
    $syscall_id or $! = ENOSYS, return undef;
    $bufsize ||= getdents_default_bufsize;
    my $buffer = '\xee' x $bufsize;
    my $res = syscall $syscall_id, $fd, $buffer, $bufsize;
    return undef if $res < 0;
    my @r;
    for (my $offset = 0, $bufsize = $res ; 0 <= $offset && $offset < $bufsize ;) {
        #
        # The old getdents returns fields in a different order from getdents64.
        # In particular, d_type field *follows* d_name, at d_reclen-1, or may
        # be missing entirely.
        # Fortunately in that case, the byte at d_reclen-1 will be the null
        # terminator of d_name, so d_type will still be DT_UNKNOWN.
        #
        # Furthermore, the 16-bit d_inode field is too small to be reliable;
        # you then need to lstat the name to get all its bits.
        #
        my ($inode, $next, $entsize, $name) = unpack '@'.$offset.'SSSU0Z*', $buffer;
        $entsize or last;    # can't get anything more out of this block
        $entsize < 0 || $entsize > $bufsize - $offset and $! = EFAULT, return undef;  # error while unpacking
        my ($type) = unpack '@'.($offset+$entsize-1).'C', $buffer;
        push @r, bless [$name, $inode, $type, $next], Linux::Syscalls::bless::dirent::;
        $offset += $entsize;
    }
    return @r;
}
} }

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
    _map_fd($fd);
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
        warn "Already have $k (probably from POSIX)\n" if $^C && $^W;
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

_export_tag qw{ proc => waitid } if _get_syscall_id 'waitid', 1;
sub waitid($$;$) {
#   my ($id_type, $id, $options) = @_;
    $_[2] //= WEXITED;
    $_[3] = 0;
    goto &waitid_;
}

# waitid5 returns a 21-element array, starting with the same 5 as waitid

_export_tag qw{ proc => waitid5 } if _get_syscall_id 'waitid', 1;
sub waitid5($$;$) {
#   my ($id_type, $id, $options) = @_;
    $_[2] //= WEXITED;
    $_[3] = 1;
    goto &waitid_;
}

# Assume that since you're calling waitid, you have an interest in the siginfo,
# but since the rusage is a Linux syscall extension, only include it if you
# explicitly ask for it.
_export_ok 'waitid_' if _get_syscall_id 'waitid', 1;
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

# vim: set ai et sts=4 sw=4 ts=9999 nowrap :
1;
