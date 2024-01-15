#!/module/for/perl

use v5.18.2;
use strict;
use warnings;
use utf8;

package Units::Scales v0.1.0 {

use Exporter 'import';
use Scalar::Util 'looks_like_number';

use POSIX 'ldexp';

our @EXPORT_OK;
our @EXPORT;

################################################

#
# There are two forms of prefixes, standard & binary.
#
#   - standard gives you the binary values with the 'i' suffix, and the decimal values otherwise.
#   - binary give you the same values with or without the 'i' suffix, and c/d/da/h will be rejected.
#
# In general, the multipliers are upper-case while the divisors are lower
# case, except for da, h & k. However unless strict_k is in effect, we accept
# 'K' even when asking for "standard" prefixes.

#
# You can choose can choose a restricted subset prefixes, in any combination of
# multipliers, divisors, decimal, or binary.
#
# In general, if you choose only multipliers or only divisors then case
# sensitivity is optional, but can be enforced if desired.
#
# If you opt for case insensitivity, the supplied prefix will be converted to
# lower case and checked against a down-cased version of the applicable "loose"
# map (meaning you can't be case-insensitive but strict for aliases).
#
# Likewise if you choose only binary prefixes then then the 'i' is optional
# (though only for "loose" maps), but that also can be enforced if desired.
#

# In addition to the standard prefixes, we also accept these synonyms, broadly
# independently of case insensitivity:
#   standard     synonyms
#       µ           u           historical practice in printed media ("uF" for
#                               microfarad) and Unix source code ('tv_usec' in
#                               struct timeval; 'utime' syscall).
#       k           K         ⎫
#       h           H         ⎬ makes all multipliers available as upper-case
#       da          D         ⎭
#       Ki          ki          consistent with lower-case 'k' among standard
#                               multipliers.

# Regardless of any settings, micro may encoded as either:
#   * µ (\u00b5, matching historical practice from ISO-8859-X), or
#   * μ (\u03bc, specified by Unicode revision 6).

########################################

my @si_up   = qw( '' K M G T P E Z Y R Q );
my @si_down = qw( '' m µ n p f a z y r q );

#
# Forbid "K" as alias for "k" in strict standard multipliers, and
# forbid "ki" as an alias for "Ki" in the strict binary multipliers.
#
use constant strict_k => 1;

#
# Allow 'u' as an alias for micro even in strict mode, because many people
# can't type µ on their keyboard.
#
use constant strict_u => 0;

########################################

my %si_up_strict = (
    da  =>  10,
    h   =>  100,
    k   =>  1000,
    map { ( $si_up[$_] => 1E3 ** $_ ) } 0 .. $#si_up
);

my %si_up = (
    %si_up_strict,
    D   =>  10,
    H   =>  100,
#   K   =>  1000,   # already included
);

delete $si_up_strict{K}  if strict_k;

my %si_up_ci = (
    %si_up,
    map { ( lc $_ => $si_up{$_} ) } keys %si_up
);


########################################

my %bi_up_strict = (
    ''  =>  1,
    ki  =>  1024,
    map { ( $si_up[$_].'i' => ldexp(1, 10*$_) ) } 1 .. $#si_up
);

my %bi_up = %bi_up_strict;

delete $bi_up_strict{ki}  if strict_k;

my %bi_up_ci = (
    %bi_up_strict,
    map { ( lc $_ => $bi_up_strict{$_} ) } keys %bi_up_strict
);

# optionally lower-case, optionally without 'i'
my %bi_up_lax = (
    %bi_up_ci,
    map { ( s/i$//r => $bi_up_ci{$_} ) } keys %bi_up_ci
);


########################################

my %si_down_strict = (
    ''  =>  1,
    d   =>  0.1,
    c   =>  0.01,
    map { ( $si_down[$_] => 1E3 ** -$_ ) } 1 .. $#si_down
);
# Micro may be abbreviated as u (\u0075) or µ (\u00b5) or μ (\u03bc)
$si_down_strict{μ}  = $si_down_strict{u}  = $si_down_strict{µ};

my %si_down = %si_down_strict;
delete $si_down_strict{u} if strict_u;


########################################

# Bits can't be fractional, except when discussing entropy, though
# something-per-bit might be, so include power-of-1024 versions for submultiple
# suffices.

my %bi_down_strict = (
    ''  =>  1,
    map { ( $si_down[$_].'i' => ldexp(1, -10*$_) ) } 1 .. $#si_down
);
# Micro may be abbreviated as u (\u0075) or µ (\u00b5) or μ (\u03bc)
$bi_down_strict{μi} = $bi_down_strict{ui} = $bi_down_strict{µi};

my %bi_down = %bi_down_strict;
delete $bi_down_strict{u} if strict_u;

# Optionally without 'i'
my %bi_down_lax = (
    %bi_down,
    map { ( s/i$//r => $bi_down{$_} ) } keys %bi_down
);


################################################

# decimal & binary, multipliers and divisors,
#   ... strict
my %si_ud_bi_ud_strict = (
    %bi_up_strict,
    %bi_down_strict,
    %si_up_strict,
    %si_down_strict,
);

#   ... normal
my %si_ud_bi_ud = (
    %bi_up,
    %bi_down,
    %si_up,
    %si_down,    # last, override any lower case in si_up
);

################

# decimal up & down, binary up-only
#   ... strict
my %si_ud_bi_up_strict = (
    %bi_up_strict,
    %si_up_strict,
    %si_down_strict,
);

#   ... normal
my %si_ud_bi_up = (
    %bi_up,
    %si_up,
    %si_down,    # last, override any lower case in si_up
);

################

# decimal only, up & down
#   ... strict
my %si_ud_strict = (
    %si_up_strict,
    %si_down_strict,
);

#   ... normal
my %si_ud = (
    %si_up,
    %si_down,    # down-scales second, so that it will override any lower case in up-scales
);

################

# binary only, up & down
#   ... strict
my %bi_ud_strict = (
    %bi_up_strict,
    %bi_down_strict,
);

#   ... normal
my %bi_ud = (
    %bi_up,
    %bi_down,
);

#   ... lax ('i' optional)
my %bi_ud_lax = (
    %bi_up_lax,
    %bi_down_lax,
);

################

# decimal & binary, up-only
#   ... strict
my %si_bi_up_strict = (
    %si_up_strict,
    %bi_up_strict,
);

#   ... normal
my %si_bi_up = (
    %si_up,
    %bi_up,
);

#   ... case-insensitive
my %si_bi_up_ci = (
    %si_up_ci,
    %bi_up_ci,
);

################

# decimal & binary, down-only
#   ... strict
my %si_bi_down_strict = (
    %si_down_strict,
    %bi_down_strict,
);

#   ... normal
my %si_bi_down = (
    %si_down,
    %bi_down,
);

################

#
# _scale is the core conversion function, called from elsewhere.
#
# Take a value and return it as a number after processing any suffix.
#
# All take
#   the string to be converted,
#   a prefix map
#   a default scale (as a number)
#   a regex for a base unit that can optionally be trimmed off; and
#
# The default scale is useful where an unlabelled value should be taken as
# (say) microseconds, but you want to be able to accept labelled milliseconds
# or nanoseconds.
#
# Having the base unit last means it can be curried, sort of.

use Carp 'confess';
use Data::Dumper;

sub _scale($\%;$$) {
    my ($v, $map, $scale, $trim) = @_;
    $v // return;
    $scale //= 1;   # TODO: decide whether accepting 0 is a bug or a feature

    if ($v =~ s/\D+$//) {
        $scale = $&;
    }
    if ($scale =~ /\D/) {
        $scale =~ s/$trim$// if $trim;  # trim off 'bytes', 'octets', etc
        $scale = $map->{$scale} // confess "Invalid scale '$scale'\n" . Dumper(\@_);
    }
    return $v * $scale;
}

################################################

#
# Second, parameters to Getopts::Long; return a lambda that takes a value, and
# assigns it to the original parameter.
#

use constant {
    _map_si_up  => 1,
    _map_si_dn  => 2,
    _map_bi_up  => 4,
    _map_bi_dn  => 8,
};
use constant {
    _map_si     => _map_si_up | _map_si_dn,
    _map_bi     => _map_bi_up | _map_bi_dn,
    _map_up     => _map_si_up | _map_bi_up,
    _map_dn     => _map_si_dn | _map_bi_dn,
    _map_all    => _map_si_up | _map_si_dn | _map_bi_up | _map_bi_dn,
    _map_def    => _map_si_up | _map_si_dn | _map_bi_up,
};

my @_mapx = map {
        my $q = $_;
        my @m = {};
        for my $r ( @$_ ) {
            push @m, map { { %$_, %$r } } @m;
        }
        undef $m[0];
        \@m
    } (
        # _map_si_up        _map_si_dn          _map_bi_up      _map_bi_dn
        [ \%si_up_strict,   \%si_down_strict,   \%bi_up_strict, \%bi_down_strict, ],    # strict
        [ \%si_up,          \%si_down,          \%bi_up,        \%bi_down,        ],    # normal
        [ \%si_up_ci,       \%si_down,          \%bi_up_ci,     \%bi_down,        ],    # ci
        [ \%si_up_ci,       \%si_down,          \%bi_up_lax,    \%bi_down_lax,    ],    # lax
    );

sub SI($;$$$) {
    my $r = \$_[0];
    my (undef, $opt, $def_scale, $trim) = @_;

    my $relax_i = 1;
    my $wantmap = 0;
    $relax_i = 0            if $opt =~ s/b\Ki+//gi; # using 'bi' rather than just 'b' means the 'i' in 'Ki' etc is NOT optional
    $wantmap |= _map_si_up  if $opt =~ s/SI*//;     # SI multipliers
    $wantmap |= _map_si_dn  if $opt =~ s/si*//;     # SI divisors
    $wantmap |= _map_bi_up  if $opt =~ s/B//;       # BI multipliers
    $wantmap |= _map_bi_dn  if $opt =~ s/b//;       # BI divisors

    $wantmap |= _map_up     if $opt =~ s/m//i;      # SI & BI multipliers
    $wantmap |= _map_dn     if $opt =~ s/d//;       # divisors (SI & BI)

    $wantmap |= _map_def    if $opt =~ s/z//;       # SI & BI multipliers and SI divisors

    $wantmap ||= _map_def;                          # default, if nothing specified

                        #   ⎧ 0: strict, exact SI only
    my $laxity = 1;     # ◁─⎨ 1: normal, aliases allowed
                        #   ⎩ 2: case-insensitive (with aliases)

    $laxity-- while $opt =~ s/\!//;    # stricter
    $laxity++ while $opt =~ s/\~//;    # laxer

    $opt eq '' or die "Invalid control option $opt in $_[1]\n";

    $laxity = 0 if $laxity < 0;
    $laxity = $#_mapx if $laxity > $#_mapx;
    $laxity-- if $laxity == $#_mapx && ! $relax_i;

    # Turn off case insensitivity if strict, or if using mixed up & down scales
    my $case_sensitive = $laxity < 2 || $wantmap & _map_up && $wantmap & _map_dn;
    # Can't relax the requirement for 'i' if mixing decimal & binary
    $relax_i = 0 if $wantmap & _map_si;

    my $map = $_mapx[$laxity][$wantmap];

    $def_scale ||= 1;
    $trim ||= undef;
  # $def_scale = $si_up{lc $def_scale} || $def_scale;
    sub {
        my $v = pop;
        $$r = _scale($v, %$map, $def_scale, $trim)
            // die "Invalid scaled value \"$v\"";
    }
}
push @EXPORT, 'SI';
push @EXPORT_OK, 'SI';

my $byte_suffix = qr/oct\w*|oc|o|byt\w*|by|b/;

sub bytes($) { push @_, 'B~', $byte_suffix;       goto &SI; }
sub B($)     { push @_, 'B~', $byte_suffix;       goto &SI; }
sub KB($)    { push @_, 'BS', $byte_suffix, 'k';  goto &SI; }
sub KiB($)   { push @_, 'B~', $byte_suffix, 'Ki'; goto &SI; }
sub MB($)    { push @_, 'BS', $byte_suffix, 'M';  goto &SI; }
sub MiB($)   { push @_, 'B~', $byte_suffix, 'Mi'; goto &SI; }
sub GB($)    { push @_, 'BS', $byte_suffix, 'G';  goto &SI; }
sub GiB($)   { push @_, 'B~', $byte_suffix, 'Gi'; goto &SI; }
sub TB($)    { push @_, 'BS', $byte_suffix, 'T';  goto &SI; }
sub TiB($)   { push @_, 'B~', $byte_suffix, 'Ti'; goto &SI; }

push @EXPORT_OK, qw(
    bytes B KB KiB MB MiB GB GiB TB TiB
);

my $second_suffix = qr/sec\w*|se|s/;

sub seconds($)  { push @_, 's~', 1,   $second_suffix; goto &SI; }
sub millisec($) { push @_, 's~', 'm', $second_suffix; goto &SI; }
sub microsec($) { push @_, 's~', 'µ', $second_suffix; goto &SI; }
sub nanosec($)  { push @_, 's~', 'n', $second_suffix; goto &SI; }
sub picosec($)  { push @_, 's~', 'p', $second_suffix; goto &SI; }

push @EXPORT_OK, qw(
    seconds millisec microsec nanosec picosec
);

################################################

# SI_scale_up only allows multiplicative prefixes
# SI_scale_down only allows divisor prefixes
# SI_scale_any allows both

sub SI_scale_any($;$$) {
    my ($v, $scale, $trim) = @_;
    return _scale $v, %si_ud_bi_up, $scale, $trim;
}

sub SI_scale_up($;$$) {
    my ($v, $scale, $trim) = @_;
    return _scale $v, %si_bi_up, $scale, $trim;
}

sub SI_scale_down($;$$) {
    my ($v, $scale, $trim) = @_;
    return _scale $v, %si_down, $scale, $trim;
}

}

1;
