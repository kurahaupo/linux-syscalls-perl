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

{ package Time::Nanosecond::base;
  BEGIN { $INC{'Time/Nanosecond/base.pm'} = __FILE__ }
}

{
# Represent a time as a struct timespec, which contains two integers: a number
# of seconds, and 0..999999999 nanoseconds. Also use this when a struct timeval
# is desired, as there's no performance improvement in providing two classes.
package Time::Nanosecond::ts;
BEGIN { $INC{'Time/Nanosecond/ts.pm'} = __FILE__ }
use parent Time::Nanosecond::base::;

use constant _prec => 9;

sub _normalize {
    my ($t) = @_;

    #
    # On many CPUs, integer remainder is calculated such that the sign of the
    # remainder matches the sign of the numerator, rather than the sign of the
    # denominator, and integer division is defined as "truncate towards zero"
    # so that a%b = a-(a∕b×b) or equivalently a∕b = (a-a%b)∕b
    #
    # This does not match the meaning of the mathematical modulus, because
    # relationship
    #      (a-b)∕b = a∕b-1
    # fails when 0<a<b.
    #
    # The expression ((-7)/8 > -1) tells us whether we need to adjust for this,
    # given the current arithmetic mode; with any luck this will be treated as
    # a compile-time constant thus eliminating the $ns < 0 test when it's not
    # needed.
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

# constructor
sub from_seconds($) {
    my $class = shift;
    my $s = int $_[0];
    no integer;     # needed to map [0.0,1.0) to [0,999999999]
    my $ns = ($_[0] - $s) * 1E9;
    return _normalize bless [ $s, $ns ], $class;
}

# constructor
sub from_nanoseconds($) {
    my $class = shift;
    my $s = $_[0] / 1E9;
    my $ns = $_[0] % 1E9;
    return _normalize bless [ $s, $ns ], $class;
}

# constructor
sub from_timespec($$) {
    my $class = shift;
    return _normalize bless [ @_ ], $class;
}

sub add {
    my ($t, $u) = @_;
    my @t = @$t;
    if (ref $u) {
        $t[0] += $u->[0];
        $t[1] += $u->[1];
    } else {
        $t[0] += $u
    }
    return _normalize bless \@t;
}

sub subtract {
    my ($t, $u, $swap) = @_;
    my @t = @$t;
    if (ref $u) {
        $t[0] += $u->[0];
        $t[1] += $u->[1];
    } else {
        $t[0] += $u
    }
    if ($swap) {
        $t[0] = -$t[0];
        $t[1] = -$t[1];
    }
    return _normalize bless \@t;
}

use overload
    '+'     => \&add,
    '-'     => \&subtract,
    ;

sub compare {
    my ($t, $u) = @_;
    return $t->[0] <=> $u->[0]
        || $t->[1] <=> $u->[1];
}

sub copy {
    my ($t) = @_;
    return bless [ @$t ];
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
    bool    => \&boolify,
    ;

}

{
# Same but with default precision of 6 digits (microseconds)
package Time::Nanosecond::ts6;
use parent Time::Nanosecond::ts::;
use constant _prec => 6;
}

{
# Same but with default precision of 3 digits (milliseconds)
package Time::Nanosecond::ts3;
use parent Time::Nanosecond::ts::;
use constant _prec => 3;
}

{
# Same but with default precision of 2 digits (centiseconds)
package Time::Nanosecond::ts2;
use parent Time::Nanosecond::ts::;
use constant _prec => 2;
}

{
# Same but with default precision of 1 digit (deciseconds)
package Time::Nanosecond::ts1;
use parent Time::Nanosecond::ts::;
use constant _prec => 1;
}

{
# Same but with default precision of 0 digit (whole seconds)
package Time::Nanosecond::ts0;
use parent Time::Nanosecond::ts::;
use constant _prec => 0;
}

{
# Represent a time as an integer number of nanoseconds
package Time::Nanosecond::ns;
use parent Time::Nanosecond::base::;

# constructor
sub from_seconds($) {
    my $class = shift;
    no integer;     # needed to map [0.0,1.0) to [0,999999999]
    my $ns = int( $_[0] * 1E9 );
    return bless \$ns, $class;
}

# constructor
sub from_nanoseconds($) {
    my $class = shift;
    my $ns = $_[0];
    return bless \$ns, $class;
}

# constructor
sub from_timespec($$) {
    my $class = shift;
    my $ns = $_[0] * 1E9 + $_[1];
    return bless \$ns, $class;
}

sub _nsec($) {
    my ($t) = @_;
    my $r = $$t % 1E9;
    $r += 1E9 if $r<0;
    return
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
    my $r = $$t + $$u;
    return bless \$r;
}

sub subtract {
    my ($t, $u, $swap) = @_;
    my $r = $$t - $$u;
    $r = -$r if $swap;
    return bless \$r;
}

use overload
    '+'     => \&add,
    '-'     => \&subtract,
    ;

sub compare {
    my ($t, $u) = @_;
    return $$t <=> $$u;
}

sub copy {
    my ($t) = @_;
    my $r = $$t;
    return bless \$r;
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
    bool    => \&boolify,
    ;

}

{
package Time::Nanosecond::base;

use Carp qw(cluck);

# constructor
sub from_timeval($$) {
    my ($class, $sec, $µsec) = @_;
    return $class->from_timespec($sec, $µsec * 1000);
}

# constructor
sub from_microseconds($) {
    my ($class, $µsec) = @_;
    return $class->from_nanoseconds($µsec * 1000);
}

# Fallback output conversions; you MUST override at least one.

sub _fsec($) { no integer; return $_[0]->_nsec / 1E9 }
sub _µsec($) {             return $_[0]->_nsec / 1E3 }
sub _nsec($) { no integer; return int( $_[0]->_fsec * 1E9 ) }

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
    return $t->_sec * 1E9 + $t->_nsec if 0x80000000 << 1;
    no integer;
    return $t->_sec * 1E9 + $t->_nsec;
}

sub timespec($) {
    my ($t) = @_;
    return $t->_sec, $t->_nsec if wantarray;
    cluck 'timespec called in non-array context';
    return;
    if (ref $t && $t->isa(Time::Nanosecond::ts::)) { return $t }
    return Time::Nanosecond::ts->from_timespec($t->_sec, $t->_nsec);
}

sub timeval($) {
    my ($t) = @_;
    return $t->_sec, $t->_µsec if wantarray;
    cluck 'timeval called in non-array context';
    return;
    if (ref $t && $t->isa(Time::Nanosecond::ts::) && $t->_nsec % 1000 == 0) { return $t }
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

use overload
    '""'    => \&stringify,
    bool    => \&boolify,
    '0+'    => \&seconds,
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

# Mutating operators; These are optional

#sub increment { $_[0]->[0]++ }
#sub decrement { $_[0]->[0]-- }
#use overload
#   '++'    => \&increment,
#   '--'    => \&decrement;

}

{
package Time::Nanosecond;

our $VERSION = '0.01';

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
    return $_[0]->localtime if UNIVERSAL::can($_[0], 'localtime');
    goto &CORE::localtime;
    goto &CORE::localtime::localtime;
}
push @EXPORT, 'localtime';

sub gmtime {
    return $_[0]->gmtime if UNIVERSAL::can($_[0], 'gmtime');
    goto &CORE::gmtime;
    goto &Time::gmtime::gmtime;
}
push @EXPORT, 'gmtime';

sub new_timeval  { return Time::Nanosecond::ts6->from_timeval(@_); } push @EXPORT, qw( new_timeval  );
sub new_timespec { return Time::Nanosecond::ts->from_timespec(@_); } push @EXPORT, qw( new_timespec );

################################################################################
#
# We extend Perl's version of strftime as follows:
#
#   1.  A new '.' modifier introduces a precision, similar to printf, applicable
#       to the 'r', 's', 'S' and 'T' conversions. If no digits occur after the
#       '.' then the maximum precision (9) is used.
#
#   2.  A new 'N' conversion provides the fractional part of the second; if a
#       width is specified, this acts the same as the precision (mimicking
#       behaviour of GNU "date") but without a leading decimal point. When the
#       '.' modifier is used with the 'N' conversion, it turns on the leading
#       decimal point, making it consistent with precision used elsewhere. If
#       the '.' modifier is used, a width should _not_ be used.
#
#       %.N   - nanoseconds padded to 9 digits, with leading '.'
#       %N    - nanoseconds padded to 9 digits, without leading '.'
#       %.ρN  - fractional seconds and scaled and padded to ρ digits, with leading '.'
#       %ρN   - fractional seconds and scaled and padded to ρ digits, without leading '.'
#
#       %s    - integer epoch-seconds (for compatibility with existing code)
#       %.s   - epoch-seconds with all available precision
#       %.ρs  - epoch-seconds with ρ digits of subsecond precision
#
#       %S    - integer second-within-minute (for compatibility with existing code)
#       %.S   - second-within-minute with all available precision
#       %.ρS  - second-within-minute with ρ digits of subsecond precision
#
#       %.T   - equivalent to %H:%M:%.S
#       %.ρT  - equivalent to %H:%M:%.ρS
#
#       _   (underscore) Also replaces trailing 0's on fractions with spaces
#       -   (dash) Also suppresses trailing 0's on fractions, and suppresses
#           the decimal point if there are no fractional digits left.
#
#       .   forces the inclusion of a decimal point on N conversions.
#       .   introduces precision for S & T
#
#   In general the existing format conversions do not visibly change unless
#   there the '.' modifier is included. 'N' is new, and therefore an exception
#
#   Normally the '.' is excluded if trailing 0 suppression results in no digits
#   after the decimal point, or if the precision is 0.
#
#   Only ρ values 1..9 are guaranteed to be supported, and in particular:
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

    my $keep_nsec;   # stash after first use

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
                        ($r[0] - int $r[0]) * 1E9 + 0.5
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
        } else {
          # $ns *= 2;
            $ns /= 10 ** (9-$prec);
          # $ns++;
          # $ns /= 2;
        }

        my $np = substr "000000000$ns", -$prec;
        $np = ".$np" if $dot;
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
push @EXPORT, 'strftime';
}

1;

=head 1

Time::Nanosecond - fixed-point arithmetic for timespec's

# There can be several implementations:
# 1. use an extended float (on platforms that support it)
# 2. just use a 64-bit int to represent nanoseconds
# 3. use a packed 8-byte string that holds 2× 32-bit ints that represent
#    seconds and nanoseconds (like the syscalls)
# 4. use a pair of 32-bit ints that represent seconds and nanoseconds (same)
#
# The initial version of this is using (4) but I really want to change it.
#
# Version 1 should be used automatically when Perl is built to include support
# (which can be tested with 'pack "D"').
# Otherwise version 2 is the easiest to do arithmetic, and version 3 is the
# least likely for clients to mess with.
#
# Unfortunately none of them interworks well with localtime or gmtime.

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
floating point to store a C<time_t> with a

The problem with this approach is the loss of precision. Perl uses a regular C
"double", which (on most platforms) is 64 bits comprising a sign bit, a 11-bit
exponent, and a 52-bit normalized mantissa.

When epoch time is between about 1E9 and 2E9 (when this module was written),
the least significant bit of the mantissa represents a step of 2**-22 seconds
or 0.238 µs, which although acceptable as a replacement for C<struct timeval>
is obviously totally inadequate for representing C<struct timespec>.

=head NOTE

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

"≥2d" at least 2 digits
"≥3d" at least 3 digits
"≥4d" at least 4 digits


    %%      a literal '%'  (C, POSIX, GNU-date, GNU-strftime)
    %A      localized full weekday name ("Sunday")  (GNU-date, GNU-strftime)
    %B      localized full month name ("January")  (GNU-date, GNU-strftime)
    %C      century (year/100) ("19" or "20")  (SU, GNU-date, GNU-strftime)
    %D      equivalent to %m/%d/%y  (SU, GNU-date, GNU-strftime)
    %F      equivalent to %Y-%m-%d (the ISO 8601 date format)  (C99, GNU-date, GNU-strftime)
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
    %k      equivalent to %_H  (TZ, GNU-strftime, GNU-date)
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
