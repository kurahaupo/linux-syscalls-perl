#! /module/for/perl

use strict;
use utf8;

use integer;    # Don't remove this or you will break stuff

use Time::tm(); # Load classes but don't import anything
use POSIX();

# Work around the limitations of Time::HiRes, which (because it uses floating
# point) loses precision when considering timestamps after 1970-04-08,02:10:08Z
# (when epoch-seconds reached 2^23).

# To be effective, we need:
#
# * a class to provide representation and arithmetic, whenever the units of
#   measure make sense:
#       T+T→T, T-T→T, T+N→T, T-N→T, N+T→T, N-T→T, T*N→T, N*T→T, T/N→T, T/T→N
#
# * to modify [l/f]stat[at] & [l]utimes[at] to use these values
#
# * a conversion to fixed-precision decimal string
#   (ideally we would like sprintf %f to work, but not yet)
#
# * replacements for localtime & gmtime
#
# * a replacement for POSIX::strftime that understands additional conversions:

#
# Values are notionally fixed-point epoch seconds, but with multiple
# implementations.
#
# Each implementation should define "_sec" and at least one of "_nsec", "_µsec" or
# "_fsec"; it may implement more:
#
#   _sec  - whole (floored) part, as integer seconds
#   _nsec - positive fractional part, as integer nanoseconds
#   _µsec - positive fractional part, as integer microseconds
#   _msec - positive fractional part, as integer milliseconds
#   _fsec - positive fractional part, as floating point
#
# The base class defines these methods which yield the complete value:
#
#   seconds      - full value, as seconds (usually floating point)
#   microseconds - full value, as microseconds (usually floating point)
#   nanoseconds  - full value, as nanoseconds (usually floating point)
#   timespec     - full value, as a Time::Nanosecond::ts object
#   timeval      - full value, as a Time::Nanosecond::timeval object
#
# Implementation classes may implement optimized versions of any of these.
#
# The base class also provides implementations for localtime & gmtime.

package Time::Nanosecond::base {
    BEGIN { $INC{'Time/Nanosecond/base.pm'} = __FILE__ }
}

package Time::Nanosecond::ts {
    # Represent a time as a struct timespec, which contains two integers: a number
    # of seconds, and 0..999999999 nanoseconds. Also use this when a struct timeval
    # is desired, as there's no performance improvement in providing two classes.

    use POSIX qw(floor);
    use Scalar::Util qw( blessed );

    BEGIN { $INC{'Time/Nanosecond/ts.pm'} = __FILE__ }
    use parent -norequire => Time::Nanosecond::base::;

    use constant _prec => undef;

    sub _normalize {
        my ($t) = @_;

        #
        # On many CPUs, integer division is defined as "truncate towards zero",
        # and this behaviour is mandated by recent versions of ISO-9899 (the C
        # language specification).
        #
        # In order to maintain the remainder identity
        #       a%b = a-(a∕b×b),
        # the integer remainder is defined so that the sign of the remainder
        # matches the sign of the numerator, rather than the denominator.
        #
        # This definition does not match the mathematical meaning of modulus,
        # because it causes the identity
        #       (a-b)%b = a%b
        # to fail when 0<a<b.
        #
        # The following tells us whether we need to adjust for this, given the
        # current arithmetic mode; the expression ((-7)/8 > -1) should be
        # a compile-time constant, possibly eliminating the $ns < 0 part.
        #

        if ( my $r = ((-7)/8 > -1) &&
                     $t->[1] < 0 ? -((1E9-1 - $t->[1]) / 1E9)
                                 :            $t->[1]  / 1E9 ) {
            $t->[0] += $r;
            $t->[1] -= $r * 1E9;
        }
        return $t;
    }

    sub _sec($)  { my ($t) = @_; return $t->[0]; }
    sub _nsec($) { my ($t) = @_; return $t->[1]; }
    sub _µsec($) { my ($t) = @_; return $t->[1] / 1E3; }
    sub _msec($) { my ($t) = @_; return $t->[1] / 1E6; }

    # delegated constructor
    sub from_seconds($) {
        my $class = shift;
        return _normalize bless [ $_[0], 0 ], $class;
    }

    # delegated constructor
    sub from_fseconds($) {
        my $class = shift;
        no integer;     # needed to map [0.0,1.0) to [0,999999999]
        my $s = floor $_[0];
        my $ns = ($_[0] - $s) * 1E9;
        return _normalize bless [ $s, $ns ], $class;
    }

    # delegated constructor
    sub from_nanoseconds($) {
        my $class = shift;
        my $s = $_[0] / 1E9;
        my $ns = $_[0] % 1E9;
        return _normalize bless [ $s, $ns ], $class;
    }

    # delegated constructor
    sub from_timespec($$) {
        my $class = shift;
        return _normalize bless [ @_ ], $class;
    }

    sub add {
        my ($t, $u) = @_;
        my @t = @$t;
        $u = ref($t)->from_fseconds($u) if ! ref $u;
        $t[0] += $u->_sec;
        $t[1] += $u->_nsec;
        return _normalize bless \@t, ref $t;
    }

    sub subtract {
        my ($t, $u, $swap) = @_;
        my @t = @$t;
        $u = ref($t)->from_fseconds($u) if ! ref $u;
        $t[0] -= $u->_sec;
        $t[1] -= $u->_nsec;
        if ($swap) {
            $t[0] = -$t[0];
            $t[1] = -$t[1];
        }
        return _normalize bless \@t, ref $t;
    }

    sub negate {
        my ($t) = @_;
        return _normalize bless [ map { -$_ } @$t ], ref $t;
    }

    use overload
        '+'     => \&add,
        '-'     => \&subtract,
        'neg'   => \&negate,
        ;

    sub compare {
        my ($t, $u, $swap) = @_;
        $u = ref($t)->from_fseconds($u) if ! ref $u;
        my $r;
        if (blessed $u && $u->can('_nsec')) {
            $r = $t->[0] <=> $u->_sec
              || $t->[1] <=> $u->_nsec;
        } else {
            no integer;
            my $u0 = floor($u);
            $r = $t->[0] <=> $u0
              || $t->[1] <=> ($u - $u0) * 1E9;
        }
        $r = -$r if $swap;
        return $r;
    }

    sub copy {
        my ($t) = @_;
        return bless [ @$t ], ref $t;
    }

    use overload
        '<=>'   => \&compare,
        '='     => \&copy,
        ;

    # Conversions

    sub boolify {
        my $t = shift;
        return $t->[0] || $t->[1];
    }

    use overload
        'bool'  => \&boolify,
        '0+'    => \&seconds,   # use base method
        'int'   => \&_sec,
        ;

}

package Time::Nanosecond::ts9 {
    # Same but with default precision of 9 digits (nanoseconds)
    use parent Time::Nanosecond::ts::;
    use constant _prec => 9;
}

package Time::Nanosecond::ts6 {
    # Same but with default precision of 6 digits (microseconds)
    use parent Time::Nanosecond::ts::;
    use constant _prec => 6;
}

package Time::Nanosecond::ts3 {
    # Same but with default precision of 3 digits (milliseconds)
    use parent Time::Nanosecond::ts::;
    use constant _prec => 3;
}

package Time::Nanosecond::ts2 {
    # Same but with default precision of 2 digits (centiseconds)
    use parent Time::Nanosecond::ts::;
    use constant _prec => 2;
}

package Time::Nanosecond::ts1 {
    # Same but with default precision of 1 digit (deciseconds)
    use parent Time::Nanosecond::ts::;
    use constant _prec => 1;
}

package Time::Nanosecond::ts0 {
    # Same but with default precision of 0 digit (whole seconds)
    use parent Time::Nanosecond::ts::;
    use constant _prec => 0;
}

BEGIN { if (0x80000000 << 31 || $^C) { eval q{
# This entire class will be elided if integers are narrower than 62 bits.

package Time::Nanosecond::ns {
    # Represent a time as an integer number of nanoseconds

    use parent -norequire => Time::Nanosecond::base::;

    use POSIX qw(floor);

    # delegated constructor
    sub from_seconds($) {
        my ($class, $ns) = @_;
        $ns *= 1E9;
        return bless \$ns, $class;
    }

    # delegated constructor
    sub from_fseconds($) {
        my ($class, $ns) = @_;
        no integer;     # needed to map [0.0,1.0) to [0,999999999]
        $ns *= 1E9;
        $ns = int $ns;
        return bless \$ns, $class;
    }

    # delegated constructor
    sub from_nanoseconds($) {
        my $class = shift;
        my $ns = $_[0];
        return bless \$ns, $class;
    }

    # delegated constructor
    sub from_timespec($$) {
        my $class = shift;
        my $ns = $_[0] * 1E9 + $_[1];
        return bless \$ns, $class;
    }

    sub _nsec($) {
        my ($t) = @_;
        my $r = $$t % 1E9;
        $r += 1E9 if $r<0;
        return $r;
    }

    sub _sec($) {
        my ($t) = @_;
        return $$t / 1E9 - ( $$t % 1E9 < 0 );
    }

    sub seconds($) {
        my ($t) = @_;
        no integer;
        return $$t / 1E9;
    }

    sub nanoseconds($) {
        my ($t) = @_;
        return $$t;
    }

    sub microseconds($) {
        my ($t) = @_;
        return $$t / 1E3;
    }

    sub add {
        my ($t, $u) = @_;
        my $r = $$t + ( ref $u ? $u->nanoseconds : do { no integer; $u * 1E9 } );
        return bless \$r, ref $t;
    }

    sub subtract {
        my ($t, $u, $swap) = @_;
        my $r = $$t - ( ref $u ? $u->nanoseconds : do { no integer; $u * 1E9 } );
        $r = -$r if $swap;
        return bless \$r, ref $t;
    }

    sub negate {
        my ($t) = @_;
        my $r = -$$t;
        return bless \$r, ref $t;
    }

    use overload
        '+'     => \&add,
        '-'     => \&subtract,
        'neg'   => \&negate,
        ;

    sub compare {
        my ($t, $u, $swap) = @_;
        my $r = $$t <=> ( ref $u ? $u->nanoseconds : do { no integer; $u * 1E9 } );
        $r = -$r if $swap;
        return $r;
    }

    sub copy {
        my ($t) = @_;
        my $r = $$t;
        return bless \$r, ref $t;
    }

    use overload
        '<=>'   => \&compare,
        '='     => \&copy,
        ;

    # Conversions; we can do this MUCH more effectively

    sub boolify {
        my $t = shift;
        return $$t;
    }

    use overload
        'bool'  => \&boolify,
        '0+'    => \&seconds,
        'int'   => \&_sec,
        ;

}
}}}

package Time::Nanosecond::base {

    use Carp qw(cluck);
    use POSIX qw(floor);

    # fallback delegated constructor
    sub from_timeval($$) {
        my ($class, $sec, $µs) = @_;
        return $class->from_timespec($sec, $µs * 1000);
    }

    # These fallback delegated constructors require from_nanoseconds to be
    # implemented by the subclass.

    # fallback delegated constructor
    sub from_seconds($) {
        my ($class, $sec) = @_;
        return $class->from_nanoseconds($sec * 1E9);
    }

    # fallback delegated constructor
    sub from_deciseconds($) {
        my ($class, $ds) = @_;
        return $class->from_nanoseconds($ds * 1E8);
    }

    # fallback delegated constructor
    sub from_centiseconds($) {
        my ($class, $cs) = @_;
        return $class->from_nanoseconds($cs * 1E7);
    }

    # fallback delegated constructor
    sub from_milliseconds($) {
        my ($class, $ms) = @_;
        return $class->from_nanoseconds($ms * 1E6);
    }

    # fallback delegated constructor
    sub from_microseconds($) {
        my ($class, $µs) = @_;
        return $class->from_nanoseconds($µs * 1E3);
    }

    # Fallback output conversions.
    #   * all of these SHOULD be overridden (for performance);
    #   * at least one of _nsec or _fsec MUST be overridden.

    sub _fsec($) { no integer; return        $_[0]->_nsec / 1E9         }
    sub _nsec($) { no integer; return floor( $_[0]->_fsec * 1E9 + 0.5 ) }
    sub _µsec($) {             return        $_[0]->_nsec / 1E3         }  # microseconds

    # Unicode version 6 deprecated U+00b5 (classic SI micro symbol µ), unifying
    # it with U+03bc (Greek letter mu μ). But since _µsec is an internal
    # callback and should not be use outside this module, we decline to offer
    # aliases such as _μsec or _usec.
    #BEGIN { *_μsec = *_usec = \&_µsec; }
    # (Furthermore, we contend that this deprecation was a mistake, because it
    # assumes that normalisation is always available, and that is simply not
    # true. For several decades X11 has set aside AltGr+m for U+00b5 on Latin
    # keyboard layouts, so that U+00b5 has become embedded in places that are
    # case-sensitive and have no code-point folding, such as passwords and
    # APIs, such as this one.)

    # Default conversions; good for most uses.

    sub seconds($) {
        my ($t) = @_;
        no integer;
        return $t->_sec + $t->_nsec / 1E9;
    }

    sub deciseconds($) {
        my ($t) = @_;
        no integer;
        return $t->_sec * 1E1 + $t->_nsec / 1E8;
    }

    sub centiseconds($) {
        my ($t) = @_;
        no integer;
        return $t->_sec * 1E2 + $t->_nsec / 1E7;
    }

    sub milliseconds($) {
        my ($t) = @_;
        no integer;
        return $t->_sec * 1E3 + $t->_nsec / 1E6;
    }

    # TODO: should this be double or int64_t?
    # Standard "double" cannot represent microsecond precision outside the range
    # 1684-07-28 00:12:26 to 2255-06-05 23:47:34 +0000
    sub microseconds($) {
        my ($t) = @_;
        no integer;
        return $t->_sec * 1E6 + $t->_nsec / 1E3;
    }

    # The return value from nanoseconds() is a 64-bit integer where available;
    # otherwise it's floating point, which loses precision but avoids wrap-around
    # on a 32-bit integer.
    sub nanoseconds($) {
        my ($t) = @_;
        return $t->_sec * 1E9 + $t->_nsec if 0x80000000 << 31;
        no integer;
        return $t->_sec * 1E9 + $t->_nsec;
    }

    sub timespec($) {
        my ($t) = @_;
        return $t->_sec, $t->_nsec if wantarray;
        cluck 'timespec called in non-array context';
        return;
        if (blessed $t && $t->isa(Time::Nanosecond::ts::)) { return $t }
        return Time::Nanosecond::ts->from_timespec($t->_sec, $t->_nsec);
    }

    sub timeval($) {
        my ($t) = @_;
        return $t->_sec, $t->_µsec if wantarray;
        cluck 'timeval called in non-array context';
        return;
        if (blessed $t && $t->isa(Time::Nanosecond::ts::) && $t->_nsec % 1000 == 0) { return $t }
        return Time::Nanosecond::ts->from_timeval($t->_sec, $t->_µsec);
    }

    sub to_timespec($) {
        my ($t) = @_;
        return $t->timespec if ! wantarray;
        return $t->_sec, $t->_nsec;
    }

    sub to_timeval($) {
        my ($t) = @_;
        return $t->timeval if ! wantarray;
        return $t->_sec, $t->_µsec;
    }

    sub withprecision($$) {
        my ($r, $p) = @_;
        return $r->copy->_setprecision($p);
    }

    sub stringify {
        my $t = shift;
        my $s = $t->_sec;
        my $ns = $t->_nsec;
        my $q = '';
        if ($s < 0) {
            $q = '-';
            $s = -$s;
            if ($ns) {
                $ns = 1E9-$ns;
                $s--;
            }
        }
        return sprintf '%s%d.%09u', $q, $s, $ns;
    }

    sub boolify {
        my $t = shift;
        return $t->_sec || $t->_nsec;
    }

    sub negate {
        my $t = shift;
        return $t->subtract(0, 1);  # swap and subtract
    }

    use overload
        '""'    => \&stringify,
        'bool'  => \&boolify,
        '0+'    => \&seconds,
        'neg'   => \&negate,
        ;

    sub localtime {
        my $t = shift;
        my $s = $t->_sec;
        my @r = CORE::localtime $s;
        { no integer; $r[0] += $t->_fsec; }
        $r[9] = $t->_prec;
        return @r if wantarray;
        # This bit of magic copied from Time::localtime::populate
        my $r = Time::tm->new();
        @$r = @r;
        return $r;
    }

    sub gmtime {
        my $t = shift;
        my @r = CORE::gmtime $t->_sec;
        { no integer; $r[0] += $t->_fsec; }
        $r[9] = $t->_prec;
        return @r if wantarray;
        # This bit of magic copied from Time::gmtime::populate
        my $r = Time::tm->new();
        @$r = @r;
        return $r;
    }

    # A Time::Nanosecond::ts has value semantics, not container semantics, so
    # mutating operators are very strongly discouraged.
    #
    # We can rely on Perl to convert $t++ to $t += 1 to $t = $t+1, which
    # we then interpret to produce a new instance.

    #sub increment { $_[0]->[0]++ }
    #sub decrement { $_[0]->[0]-- }
    #use overload
    #   '++'    => \&increment,
    #   '--'    => \&decrement;

}

package Time::Nanosecond v0.1.1 {

    use Scalar::Util qw( blessed );

    use Exporter 'import';
    our @EXPORT;
    our @EXPORT_OK;

    ################################################################################
    #
    # localtime and gmtime (above) work as methods, but the following are intended
    # as replacements for CORE::localtime and CORE::gmtime that recognize values
    # from this package and adjust their behaviour appropriately.
    #
    # In array context, element 0 of the returned list is a floating-point value,
    # but are otherwise indistinguishable from the regular versions.
    #
    # However in a scalar context they will emulate Time::localtime::localtime and
    # Time::gmtime::gmtime (except that they populate the tm_sec field with a float
    # rather than an int), rather than returning a "ctime" string.

    sub localtime {
        return $_[0]->localtime if blessed($_[0]) && $_[0]->can('localtime');
        goto &Time::localtime::localtime if exists &Time::localtime::localtime;
        goto &CORE::localtime;
    }
    push @EXPORT_OK, 'localtime';

    sub gmtime {
        return $_[0]->gmtime if blessed($_[0]) && $_[0]->can('gmtime');
        goto &Time::gmtime::gmtime if exists &Time::gmtime::gmtime;
        goto &CORE::gmtime;
    }
    push @EXPORT_OK, 'gmtime';

    sub new_timeval($$)  {
        return Time::Nanosecond::ts6->from_timeval(@_) if @_ >= 2;
    }
    push @EXPORT_OK, qw( new_timeval  );

    sub new_timespec($$) {
        return Time::Nanosecond::ts->from_timespec(@_) if @_ >= 2;
    }
    push @EXPORT_OK, qw( new_timespec );

    sub new_seconds($) {
        return Time::Nanosecond::ts0->from_seconds($_[0]) if @_;
    }
    push @EXPORT_OK, qw( new_seconds );

    sub new_fseconds($) {
        return Time::Nanosecond::ts6->from_fseconds($_[0]) if @_;
    }
    push @EXPORT_OK, qw( new_seconds );

    sub new_deciseconds($) {
        return Time::Nanosecond::ts1->from_deciseconds($_[0]) if @_;
    }
    push @EXPORT_OK, qw( new_deciseconds );

    sub new_centiseconds($) {
        return Time::Nanosecond::ts2->from_centiseconds($_[0]) if @_;
    }
    push @EXPORT_OK, qw( new_centiseconds );

    sub new_milliseconds($) {
        return Time::Nanosecond::ts3->from_milliseconds($_[0]) if @_;
    }
    push @EXPORT_OK, qw( new_milliseconds );

    sub new_microseconds($) {
        return Time::Nanosecond::ts6->from_microseconds($_[0]) if @_;
    }
    push @EXPORT_OK, qw( new_microseconds );

    sub new_nanoseconds($) {
        return Time::Nanosecond::ts9->from_nanoseconds($_[0]) if @_;
    }
    push @EXPORT_OK, qw( new_nanoseconds );

    ################################################################################
    #
    # We extend Perl's version of strftime as follows:
    #
    #   1.  A new '.' modifier introduces a precision, similar to printf, applicable
    #       to the 'r', 's', 'S' and 'T' conversions.
    #
    #   2.  A new 'N' conversion provides the fractional part of the second; if a
    #       width is specified, this acts the same as the precision (mimicking
    #       behaviour of GNU "date") but without a leading decimal point. When the
    #       precision is used with the 'N' conversion, it turns on the leading
    #       decimal point, making it consistent with precision used elsewhere.
    #
    #       Do not use both width and precision; the behaviour is subject to change
    #       without notice. (In the current implementation, even an empty precision
    #       will cause width to be ignored.)
    #
    #       %.N   - fractional seconds with all available precision, with leading '.'
    #       %N    - fractional seconds with all available precision, without leading '.'
    #       %.0N  - empty string
    #       %0N   - empty string
    #       %.ρN  - fractional seconds to ρ digit precision, with leading '.'
    #       %ρN   - fractional seconds to ρ digit precision, without leading '.'
    #
    #       %s    - integer epoch-seconds (for compatibility with existing code)
    #       %.0s  - same as %s
    #       %.s   - epoch-seconds with all available precision
    #       %.ρs  - epoch-seconds with ρ digits of subsecond precision
    #
    #       %S    - integer second-within-minute (for compatibility with existing code)
    #       %.0S  - same as %S
    #       %.S   - second-within-minute with all available precision
    #       %.ρS  - second-within-minute with ρ digits of subsecond precision
    #
    #       %.T   - equivalent to %H:%M:%.S
    #       %.0T  - same as %T
    #       %.ρT  - equivalent to %H:%M:%.ρS
    #
    #       _   (underscore) Replaces trailing 0's on fractions with spaces;
    #           also replaces the decimal point if there are no fractional
    #           digits left.
    #
    #       -   (dash) Suppresses trailing 0's on fractions, and suppresses the
    #           decimal point if there are no fractional digits left.
    #
    #       .   introduces precision for S & T, and
    #           forces the inclusion of a decimal point on N conversions.
    #
    #   The "available precision" is generally 9 digits, but if the original
    #   time value was a Time::Nanoseconds object, then the precision used when
    #   creating that object is passed through by gmtime and localtime, so that
    #   (for example) if the original was constructed from a floating point
    #   value, only 6 digits will be available.
    #
    #   In general the existing format conversions do not visibly change unless
    #   there the '.' modifier is included; 'N' is new, and therefore an exception
    #
    #   The '.' is excluded if the precision is 0, or if trailing 0 suppression
    #   results in no digits after the decimal point.
    #
    #   Only ρ values 0..9 are guaranteed to be supported, and in particular:
    #       %.0χ (seconds)
    #       %.1χ (deciseconds)
    #       %.2χ (centiseconds)
    #       %.3χ (milliseconds)
    #       %.6χ (microseconds)
    #       %.9χ (nanoseconds)
    #

    sub strftime {
        my ($fmt, @r) = @_;
        my @p = split qr{( %%
                         | %[-^#_0]*\d*\.?\d*[EO]?\w
                         )}x, $fmt;

        my $keep_nsec;   # stash upon first use

        for my $pp (@p) {
            if ( not $pp =~ m<^%([-_#^0]*)(\d*)(?:(\.)(\d*))?([OE]?)([NrsST])$>x ) {
                next;
            }
            $3 || $6 eq 'N' or next;
            my ($flags, $width, $dot, $prec, $mod, $conv) = ($1, $2, $3, $4, $5, $6);

            # Convert empty or unmatched to undef; otherwise coerce to integer
            $_ = ($_ // '') eq '' ? undef
                                  : 0 + $_
                for $width, $prec;
            # Convert to 1 or 0 to indicate '.' present or absent
            $dot = 0+!!$dot;

            # Take a working copy, since we might want to mangle it
            my $ns = $keep_nsec //= int do {
                            no integer;
                            blessed $r[0] && $r[0]->can('_nsec')
                                ? $r[0]->_nsec
                                : ($r[0] - int $r[0]) * 1E9 + 0.5
                        };
            my $replace_pp = undef;

            if ($conv eq 'N') {
                $dot and undef $width;  # width not legal with precision, so ignore it
                $prec //= $width;
                # There won't be anything left after the fractional seconds are
                # done, so set $replace_pp to empty (so it won't get reconstructed)
                $replace_pp = '';
            } else {
                if ($conv eq 's') {
                    # Do the whole of the conversion here, because when negative, the
                    # integer component has to be be increased by one second, and the
                    # fractional component has to be decreased by one second (and then
                    # negated to become positive).
                    my @q = @r[0..8];
                    $q[0] = int $q[0];
                    # POSIX::strftime can take care of tm_sec==60
                    my $es = POSIX::strftime '%s', @q;
                    # Having computed %s, let's not waste it; finish the job and
                    # replace the conversion with the result:
                    my $sign = '';
                    if ($es < 0) {
                        $sign = '-';
                        $width-- if $width;    # 1 == length $sign
                        $es++;
                        $ns -= 1E9;
                        $es = abs $es;
                        $ns = abs $ns;
                    }
                    $replace_pp = sprintf "%s%0*d", $sign, $width // 0, $es;
                }
                if (!$dot) {
                    # If the conversion doesn't have a '.' then just fall back to
                    # the default.
                    next
                }
            }

            if (!defined $prec || $prec < 0 || $prec > 9) {
                $prec = $r[9] // 9;
            }
            if ($prec != 9) {
              # $ns *= 2;
                $ns /= 10 ** (9-$prec);
              # $ns++;
              # $ns /= 2;
            }

            my $np = substr '000000000'.$ns.'0', -$prec-1, -1;
            $np = ".$np" if $dot && $prec;
            if ($flags =~ /-/) {
                $np =~ s/0*$// and
                $np =~ s/\.$//;
            } elsif ($flags =~ /_/ && $np =~ s/\.?0*$//) {
                $np = substr "$np         ", 0, $prec+$dot;
            }

            $width ||= 0;
            $width -= length($np);
            $width > 0 or $width = '';
            $width ||= '';  # ignore undef and zero-width

            # Use $replace_pp if it's defined, even if it's empty; otherwise
            # reassemble conversion but omitting '.ρ'.
            $pp = ($replace_pp // '%'.$flags.$width.$mod.$conv) . $np;

        }
        $fmt = join '', @p;
        $fmt =~ /%/ or return $fmt;
        return POSIX::strftime( $fmt, @r[0..8] );
    }
    push @EXPORT_OK, 'strftime';
}

1;

=encoding utf8

=head1

Time::Nanosecond - fixed-point arithmetic for timespec's

=pod

The Linux kernel provides nanosecond resolution timestamps in many contexts,
however it is difficult to deal with them reliably.

It might be tempting to express time as a floating-point number of seconds,
effectively treating time_t as the basic function type. From a functional
perspective that works quite well, but you discover that the round trip from
struct timespec to float and back is not lossless:

Between 2004 and 2038, time_t values will in the range 1<<30..1<<31 which means
that to accurately represent nanoseconds, a numeric type with at least 60 bits
of precision is needed, whereas the IEEE 64-bit "float" used by C (and thus by
Perl) has only 52 bits of precision.

On the other hand, if you only want microsecond precision, 52 bits of precision
will be quite sufficient until March 2242.

There are several plausible implementations:

=over 4

=item 1
Use floating point.

This is fine if you only need microseconds precision.

You don't need library support, you just go ahead and use it.

=item 2
Use "extended" floating point.

Note that this is the 80-bit 80x87-specific floating point format, and is not
compiled into Perl by default even on i686 and x86 platforms.

But where it is, you just go ahead and use it.

A future version of Perl may provide a standard method for selecting 128-bit
floating point on platforms that support it. When that happens, there will
probably be a version of this module that uses them.

=item 3
Use an integer to represent nanoseconds.

This offers the best performance for arithmetic, but is only available on
64-bit platforms.

This is implemented by the Time::Nanosecond::ns class.

=item 4
Use struct timespec

(Use a pair of ints to represent seconds and nanoseconds.)

This is the most portable format, and gives reasonable performance across most
operations.

This is implemented by the Time::Nanosecond::ts class.

=item 5
Use packed 32-bit struct timespec

Use a packed 8-byte string that holds 2× 32-bit ints that represent seconds and
nanoseconds.

This is optimal when interacting with a 32-bit system calls and otherwise not
manipulalating the values other than checking for equality. On big-endian CPUs
you can also do ordering comparisons.

This is not currently implemented, but a future version will provide a
Time::Nanosecond::ll class (named for the pack format specifier).

=item 6
Use packed 64-bit struct timespec

Use a packed 16-byte string that holds 2× 64-bit ints that represent seconds
and nanoseconds.

This is optimal when interacting with a 64-bit system calls and otherwise not
manipulalating the values other than checking for equality. On big-endian CPUs
you can also do ordering comparisons.

This is not currently implemented, but a future version will provide a
Time::Nanosecond::qq class (named for the pack format specifier).

=back

Option 4 is currently the only implementation provided if you just import
methods from the package. A future version will allow different implementations
to be selected, either directly, or based on desired performance
characteristics. All classes will provide the same interface methods.

The core localtime or gmtime know nothing of this additional precision, so this
module provides enhanced versions of those too.

=pod

The purpose of this module is to allow arithmetic and conversion of
C<struct timespec> values with full precision.

The Unix and Linux kernels have syscalls that report times in one of three
formats:

=over 4

=item *
C<time_t> - an integer number of seconds since 1 Jan 1970 00:00 UTC; this is
the "original" format that almost everything understands.

=item *
C<struct timeval> - a time_t accompanied by an integer number of microseconds

=item *
C<struct timespec> - a time_t accompanied by an integer number of nanoseconds

=back

When dealing with subsecond resolution, the naïve approach would be to use a
floating point to store a fractional C<time_t>.

The problem with this approach is the loss of precision. Perl uses a regular C
"double", which (on most platforms) is 64 bits comprising a sign bit, a 11-bit
exponent, and a 52-bit normalized mantissa.

When epoch time is between about 1E9 and 2E9 (when this module was written),
the least significant bit of the mantissa represents a step of 2**-22 seconds
or 0.238 µs, which although acceptable as a replacement for C<struct timeval>
is obviously totally inadequate for representing C<struct timespec>.

=head1
NOTE

=pod

Note that the nanoseconds component is always positive, even if the
whole-seconds component is negative; so values between -1 and 0 are represented
with seconds==-1.

=cut

__END__

NOTES

For strftime, we take our cues from GNU libc and GNU date (which together
incorporate almost everything from other standards). In particular, GNU date
gives us the %N modifier.

Bash's man page simply states that printf can take a %(...)T conversion,
where ...
    %(datefmt)T
        causes printf to output the date-time string resulting from using
        datefmt as a format string for strftime(3). The corresponding argument
        is an integer representing the number of seconds since the epoch.
... which clearly implies that "localtime" is involved, and does not seem to
add anything beyond what GNU libc offers.

The format specifiers for strftime are similar to those for printf; they
comprise a '%' followed by flags, precision, options, and finally a selector.

The following are all the formatting options recognized by C, POSIX, SU (Single
UNIX Specification), TZ (Olson's timezone package), GNU-date, and GNU-strftime:

    %%      a literal '%'  (C, POSIX, GNU-date, GNU-strftime)
    %A      localized full weekday name ("Sunday")  (GNU-date, GNU-strftime)
    %B      localized full month name ("January")  (GNU-date, GNU-strftime)
    %C      century (year/100) ("19" or "20")  (SU, GNU-date, GNU-strftime)
    %D      equivalent to %m/%d/%y  (SU, GNU-date, GNU-strftime)
    %F      equivalent to %Y-%m-%d (the ISO 8601 date format)  (C99, POSIX2001, GNU-date, GNU-strftime)
    %G      year matching ISO 8601 week number (see %V)  This has the same format and value as %Y, except that if the ISO 8601 week number belongs to the previous or next year, that year is used instead  (TZ, GNU-date, GNU-strftime)
    %H      hour using a 24-hour clock (00..23)  (GNU-date, GNU-strftime)
    %I      hour using a 12-hour clock (01..12)  (GNU-date, GNU-strftime)
    %M      minute (00..59)  (GNU-date, GNU-strftime)
    %N      nanoseconds (000000000..999999999)  (GNU-date)
    %P      like %p but lower case (localized "am" or "pm")  (GNU-date, GNU-strftime)
    %R      equivalent to %H:%M  (SU, GNU-date, GNU-strftime)
    %S      second (00..60) (allows for leap seconds)  (GNU-date, GNU-strftime)
    %T      equivalent to %H:%M:%S  (SU, GNU-date, GNU-strftime)
    %U      week-of-year number (00..53) where first Sunday is the first day of week 01  (GNU-date, GNU-strftime)
    %V      ISO 8601 week-of-year number, with Monday as first day of week (01..53) where week 1 is the first week that has at least 4 days in the new year  (SU, GNU-date, GNU-strftime)
    %W      week-of-year number (00..53) where the first Monday is the first day of week 01  (GNU-date, GNU-strftime)
    %X      localized time representation without date ("23:13:48")  (GNU-date, GNU-strftime)
    %Y      year  (GNU-date, GNU-strftime)
    %Z      timezone abbreviation ("EDT")  (GNU-date, GNU-strftime)
    %a      localized abbreviated weekday name ("Sun")  (GNU-date, GNU-strftime)
    %b      localized abbreviated month name ("Jan")  (GNU-date, GNU-strftime)
    %c      localized date and time ("Thu Mar  3 23:05:25 2005")  (GNU-date, GNU-strftime)
    %d      day of month (01..31) ("01")  (GNU-date, GNU-strftime)
    %e      equivalent to %_d  (SU, GNU-date, GNU-strftime)
    %g      year within century of %G (year of ISO 8601 week number) (00..99)  (TZ, GNU-date, GNU-strftime)
    %h      equivalent to %b  (SU, GNU-date, GNU-strftime)
    %j      day of year (001..366)  (GNU-date, GNU-strftime)
    %k      equivalent to %_H  (TZ, GNU-date, GNU-strftime)
    %l      equivalent to %_I  (TZ, GNU-date, GNU-strftime)
    %m      month (01..12)  (GNU-date, GNU-strftime)
    %n      a newline  (SU, GNU-date, GNU-strftime)
    %p      half-day indicator (localized "AM" or "PM" or blank if the locale uses a 24-hour clock). Noon is treated as "PM" and midnight as "AM"  (GNU-date, GNU-strftime)
    %r      localized 12-hour time (in the POSIX locale this is equivalent to %I:%M:%S %p, so "11:11:04 PM")  (SU, GNU-date, GNU-strftime)
    %s      seconds since the Epoch, 1970-01-01 00:00:00 UTC  (TZ, GNU-date, GNU-strftime)
    %t      a tab  (SU, GNU-date, GNU-strftime)
    %u      day of week (1..7) 7==Sunday 1==Monday  (SU, GNU-date, GNU-strftime)
    %w      day of week (0..6) 0==Sunday 1==Monday  (GNU-date, GNU-strftime)
    %x      localized date without time ("12/31/99")  (GNU-date, GNU-strftime)
    %y      year within century (00..99)  (GNU-date, GNU-strftime)
    %z      ±hhmm numeric timezone ("-0400", "+1300") (hour and minute offset from UTC)  (SU, GNU-date, GNU-strftime)

    %:z     ±hh:mm numeric timezone ("-04:00")  (GNU-date)
    %::z    ±hh:mm:ss numeric timezone ("-04:00:00")  (GNU-date)
    %:::z   numeric timezone with : to necessary precision ("-04", "+05:30")  (GNU-date)

    %+      date and time in date(1) format. (TZ) (Not supported in glibc2.)  (GNU-strftime)

    %Eχ     Modifier: use alternative format for %χ  (GNU-strftime)
    %Oχ     Modifier: use alternative format for %χ  (SU, GNU-strftime)

By default, numeric fields are padded with zeroes, and textual fields are
padded with spaces (or not at all).

The following optional flags may follow '%':
    0   (zero) pad with zeros  (GNU-date, GNU-strftime)
    _   (underscore) pad with spaces instead of 0  (GNU-date, GNU-strftime)
    -   (dash) do not pad  (GNU-date, GNU-strftime)
    #   use opposite case  (GNU-date, GNU-strftime) (This flag works only with certain conversion specifier characters, and of these, it is only really useful with %Z.)
    ^   use upper case  (GNU-date, GNU-strftime)
After any flags comes
    an optional field width, as a decimal number  (GNU-date, GNU-strftime);
then an optional modifier, which is either
    E   use the locale's alternate representations if available  (GNU-date, GNU-strftime)
    O   use the locale's alternate numeric symbols if available  (GNU-date, GNU-strftime)

Note that the %s conversion is problematic, as its implementation as part of
strftime involves a round trip from time_t to struct tm and back to time_t,
which could introduce errors due to timezone ambiguity. However it's too late
to change now.
