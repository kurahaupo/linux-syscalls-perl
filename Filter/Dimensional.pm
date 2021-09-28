#!/module/for/perl

=pod

There are three purposes to this package:
  1. To enable units to be written as suffixes in the normal way.
  2. To track the dimensions of values, so that dimensional mis-match can be
     trapped; and
  2. To ensure that numbers are always scaled to a standard unit.

Write
    use Filter::Dimensional;

    my $x = 5mm;

which gets translated to

    use constant encoded_symbol => ParseUnit('mm');

    my $x = 5 ** encoded_symbol;

where ParseUnit returns a blessed object in Filter::Dimensional::Units.

The seven base physical units are provided:
  Time - second (s)
  Length - meter (m)
  Mass - kilogram (kg)
  Amount of substance - mole (mole) (count of molcules)
  Temperature - kelvin (K)
  Electric current - ampere (A)
  Luminous intensity - candela (cd)

In addition
  Data & entropy - bit (b) or bytes (B)
  Angle - degree (°´¨) or radian (r)


TODO:
In addition, special handling [will be] available for values that are time
durations or angles (degree+minute+second), using the forms:

    my $duration = 5w3d4h19m10.33s;
    my $angle    = 5°14´59¨ or 5°14'59" or 5°14’59”

    where all components are optional except:
      * m alone is metres not minutes
      * using ' for minute and/or " for seconds cannot be implemented as code
        literals due to limitations of the Filter::Simple module, but even if
        they were, needs ° would still to be present, to disambiguate from
        their use as quote marks.

Whilst tracking the base physical dimensions is the obvious use-case, this is
actually useful for tracking any denominated quantity; you could add a unit for
anything you wish to measure, including economic units such as US$, GB£,
barley, or petroleum, which then ensures that conversion rates result in the
correct dimensions.

TODO: Currently a single class is used for both values and bare units.
They need to be separated of "bare" units (U) vs "values" (V);

TODO: improve separation of "absolute" (Ua, Va) vs "relative" (Ur, Vr) (allow
absolute with 0 offset)

Only units may be named.

Absolute units are derived from relative ones, by specifying an "origin"
(which may be zero). This is envisaged as being useful for:
  * Temperatures, where different units have different numerical values for absolute zero;
  * Compass points and similar orientations, based on angles.

Absolute units can't be manipulated. Absolute values can only be manipulated
to take differences between them, analogously to pointer arithmetic in C:
      Ur₁ = Ua₁ - Ua₁
      Ua₁ = Ua₁ ± Ur₁
TODO: for radians, absolute values should be computed modulo 2π

along with scalar values ("S") the following operations should be allowed:

  1. define new units:
      _unit           (produces a dimensionless unit object)
      Ur₂ = Ur₁->new('name', scale);
      Ua₂ = Ur₁->new('name', scale, offset);

  2. combine relative units to create new units
      Ur₁ * Ur₂ → Ur₃
      Ur₁ / Ur₂ → Ur₃
      Ur₁ ** I  → Ur₂  (for small integer exponents)

  3. combine a scalar with a unit to produce a value:
      S  ** Ux₁ → Vx₁ (translated adjacency)
      S  *  Ux₁ → Vx₁

  4. perform computations with values:
      _scalar(S)      (produces a dimensionless value object)
      Vr₁ * Vr₂ → Vr₃
      S   * Vr₁ → Vr₁
      Vr₁ * S   → Vr₁
      Vr₁ / S   → Vr₁
      Vr₁ / Vr₂ → Vr₃
      S   / Vr₂ → Vr₃
      Vr₁ + Vr₁ → Vr₁
      Vr₁ - Vr₁ → Vr₁
      Vr₁ + Vr₁ → Vr₁

  5. verify that a value matches a unit, and convert it to a string:
      Vx₁ / Ux₁ → S

          This yields undef if the dimensions do not match, but otherwise is
          exactly the reverse of [S * Vx₁ → Ux₁].

      Vx₁ % Ux₁ → Vx₁

          This dies if dimensions do not match, but otherwise yields the same
          value, except with the remembered unit replaced by the given one.

          This is useful in two cases:
            (1) to enforce dimensional checking on assignment, like

                my $feet = $supposedly_distance % ft;

            (2) to simplify printing values, like

                printf "Mars is %s from Earth\n", $distance % Gm;

  6. stringify. Values whose construction involved only one unit remember
      that unit, and apply it by default when stringifying. That includes:
      S * Ux → Vx
      S * Vx → Vx
      Vx * S → Vx
     values constructed in other ways may or may not remember a unit. Addition and subtraction
     will generally remember the unit of the left operand, if any.

Addition and subtraction are only permitted between values with the same
dimensions, subject to the additional limitation that values with fixed
references (especially Celsius) can only be added to relative values
(resulting in another fixed-ref value), or subtracted from another fixed-ref
value (resulting in a relative value).


Multiplication results in addition of dimensions.

We also track when values have fixed reference values, like Celsius,
having an

however we
additionally track whether a value is "absolute", in which case only
abs+rel, rel+abs, rel+rel, abs-abs and abs-rel are permitted.

We also track relativism: all units can indicate the difference between two
states, but some such as Celsius can also have an absolute reference.
For these units, an appended Δ indicates that it's non-absolute.

(This also applies to dimensionless numbers, to differentiate cardinals from
ordinals.)




from https://www.ece.utoronto.ca/canadian-metric-association/si-derived-units/

Physical Quantity                 Name        Symbol      Expressed in SI Base Units
frequency                         hertz       Hz                      s⁻¹
force                             newton      N                       m·kg·s⁻²
pressure, stress                  pascal      Pa          N·m⁻²       m⁻¹·kg·s⁻²
energy, work, heat                joule       J           N·m         m²·kg·s⁻²
power, radiant flux               watt        W           J·s⁻¹       m²·kg·s⁻³
electrical charge                 coulomb     C                       A·s
electrical potential,
electromotive force               volt        V           J·C⁻¹       m²·kg·s⁻³·A⁻¹
electrical resistance             ohm         Ω           V·A⁻¹       m²·kg·s⁻³·A⁻²
electric conductance              siemens     S           Ω⁻¹         m⁻²·kg⁻¹·s³·A²
electical capacitance             farad       F           C·V⁻¹       m⁻²·kg⁻¹·s⁴·A²
magnetic flux density             tesla       T           V·s·m⁻²     kg·s⁻²·A⁻¹
magnetic flux                     weber       Wb          V·s         m²·kg·s⁻²·A⁻¹
inductance                        henry       H           V·A⁻¹·s     m²·kg·s⁻²·A⁻²
luminous flux                     lumen       lm                      cd·sr
illuminance                       lux         lx                      cd·sr·m⁻²
radioactive activity              becquerel   bq                      s⁻¹
absorbed dose of radiation        gray        Gy          J·kg⁻¹      m²·s⁻²
dose equivalent of radiation      sievert     Sv          J·kg⁻¹      m²·s⁻²

plane angle                       radian      rad         1           m·m⁻¹
solid angle                       steradian   sr          1           m²·m⁻²


=cut

use 5.012;
use strict;

use utf8;

BEGIN { binmode $_, ':utf8' for *STDIN, *STDOUT, *STDERR; }

package Filter::Dimensional v0.0.1 { BEGIN { $INC{__PACKAGE__ =~ s#::#/#r . '.pm'} = __FILE__ } }

package Filter::Dimensional::Units { use parent Filter::Dimensional::; BEGIN { $INC{__PACKAGE__ =~ s#::#/#r . '.pm'} = __FILE__ }  }
package Filter::Dimensional::Values { use parent Filter::Dimensional::; BEGIN { $INC{__PACKAGE__ =~ s#::#/#r . '.pm'} = __FILE__ }  }

package Filter::Dimensional::AbsUnits { use parent Filter::Dimensional::; BEGIN { $INC{__PACKAGE__ =~ s#::#/#r . '.pm'} = __FILE__ }  }
package Filter::Dimensional::AbsValues { use parent Filter::Dimensional::; BEGIN { $INC{__PACKAGE__ =~ s#::#/#r . '.pm'} = __FILE__ }  }

package Filter::Dimensional {

use constant {
    Quantity    => 0,
    Bare        => 1,   # bare unit, so "**" operator allowed
    Offset      => 2,   # e.g. Celsius == 273.15; only Bare units can have offsets
    Name        => 3,

    MinDim      => 4,

    Data        => 4,

    Mass        => 5,
    Length      => 6,
    Time        => 7,
    Substance   => 8,   # count of molecules
    Temperature => 9,
    Current     => 10,
    Luminosity  => 11,
    Angle       => 12,

    Reserved3   => 13,
    Reserved4   => 14,
    Reserved5   => 15,
};

sub _scalar         { return shift // bless [1] }   # [Quantity]=1
sub _clone          { my $r = shift // die; return bless [@$r] }

sub _dim($$)        { my ($r, $d, $e) = @_; $r->[$d] += $e // 1; return $r }
sub _value($)       { my $v = pop; my $r = &_scalar; $r->[Quantity] *= $v; return $r }

sub _offset($)      { my $o = pop; my $r = &_scalar; $r->[Offset] += $o ; return $r }

sub _by             { my ($r, $q) = @_; $q->[$_] and $r->[$_] += $q->[$_] for MinDim..$#$q; return $r; }
sub _per            { my ($r, $q) = @_; $q->[$_] and $r->[$_] -= $q->[$_] for MinDim..$#$q; return $r; }
sub _squared        { my ($r) = @_; $r->[$_] and $r->[$_] *= 2 for MinDim..$#$r; return $r; }
sub _cubed          { my ($r) = @_; $r->[$_] and $r->[$_] *= 3 for MinDim..$#$r; return $r; }

#sub _fixed          { (&_scalar)->_dim(Fixed) }

# Base dimensions

sub _Radian         { (&_scalar)->_dim(Angle) }
sub _Ampere         { (&_scalar)->_dim(Current) }
sub _Bit            { (&_scalar)->_dim(Data) }
sub _Metre          { (&_scalar)->_dim(Length) }
sub _Candela        { (&_scalar)->_dim(Luminosity) }
sub _Kilogram       { (&_scalar)->_dim(Mass) }
sub _Mol            { (&_scalar)->_dim(Substance) }
sub _Kelvin         { (&_scalar)->_dim(Temperature) }
sub _Second         { (&_scalar)->_dim(Time) }

# Common powers of units

sub _SquareMetre    { (&_scalar)->_by(_Metre->_squared) }
sub _CubicMetre     { (&_scalar)->_by(_Metre->_cubed) }
sub _Steradian      { (&_scalar)->_by(_Radian->_squared) }

# Composite units

sub _Hertz          { (&_scalar)->_per(_Second) }
sub _Baud           { (&_scalar)->_Bit->_per(_Second) }

sub _speed          { (&_scalar)->_Metre->_per(_Second) }
sub _acceleration   { (&_scalar)->_speed->_per(_Second) }
sub _momentum       { (&_scalar)->_Kilogram->_speed }
sub _Newton         { (&_scalar)->_Kilogram->_acceleration }
sub _Joule          { (&_scalar)->_Newton->_Metre }
sub _Watt           { (&_scalar)->_Joule->_per(_Second) }

sub _Pascal         { (&_scalar)->_Newton->_per(_SquareMetre) }

sub _Coulomb        { (&_scalar)->_Ampere->_Second }

sub _Volt           { (&_scalar)->_Joule->_per(_Coulomb) }
sub _Ohm            { (&_scalar)->_Volt->_per(_Ampere) }
sub _Siemen         { (&_scalar)->_per(_Ohm) }
sub _Farad          { (&_scalar)->_Coulomb->_per(_Volt) }

sub _Weber          { (&_scalar)->_Volt->_Second }
sub _Tesla          { (&_scalar)->_Weber->_per(_SquareMetre) }
sub _Henry          { (&_scalar)->_Weber->_per(_Ampere) }

sub _Lumen          { (&_scalar)->_Candela->_per(_Steradian) }
sub _Lux            { (&_scalar)->_Lumen->_per(_SquareMetre) }

sub _radiation_dose { (&_scalar)->_Joule->_per(_Kilogram) }
sub _Becquerel      { (&_scalar)->_per(_Second) }

# Scaled values

sub _Byte           { (&_scalar)->_Bit->_value(8) }

sub _minutes        { (&_scalar)->_Second->_value(60) }
sub _hours          { (&_scalar)->_minutes->_value(60) }
sub _days           { (&_scalar)->_hours->_value(24) }
sub _weeks          { (&_scalar)->_days->_value(7) }
sub _Degrees        { (&_scalar)->_Radian->_value(atan2(1,1)/45) }

my %MetricUnits = (
    A           => _Ampere,
    C           => _Coulomb,
    F           => _Farad,
    Gy          => _radiation_dose,
    H           => _Henry,
    Hz          => _Hertz,
    J           => _Joule,
    K           => _Kelvin->_offset(0),
    L           => _CubicMetre->_value(1E-3),   # litre = 0.001 m³
    N           => _Newton,
    Pa          => _Pascal,
    S           => _Siemen,                     # aka "Mho"
    Sv          => _radiation_dose,
    T           => _Tesla,
    V           => _Volt,
    W           => _Watt,
    Wb          => _Weber,
    bq          => _Becquerel,
    cd          => _Candela,
    g           => _Kilogram->_value(1E-3),     # gram = 0.001 kg
    lm          => _Lumen,
    lx          => _Lux,
   'm'          => _Metre,
    mol         => _Mol,
    s           => _Second,
    sr          => _Steradian,
   'Ω'          => _Ohm,
);

my %MetricScaleDown = (
    z           => 1E-24,
    y           => 1E-21,
    a           => 1E-18,
    f           => 1E-15,
    p           => 1E-12,
    n           => 1E-9,
    'µ'         => 1E-6,
    'µ'         => 1E-6,
    'm'         => 1E-3,
    c           => 1E-2,
    d           => 1E-1,
    ''          => 1,
);

my %MetricScaleUp = (
    ''          => 1,
    da          => 1E+1,
    h           => 1E+2,
    k           => 1E+3,
    K           => 1E+3,
    M           => 1E+6,
    G           => 1E+9,
    T           => 1E+12,
    P           => 1E+15,
    E           => 1E+18,
    Y           => 1E+21,
    Z           => 1E+24,
);

my %MetricScale = (
    %MetricScaleDown,
    %MetricScaleUp,
);

my $metric_league = _Metre->_value(4000);  # 4km

my %BinaryScale = (
    ki          => 2**10,
    Ki          => 2**10,
    Mi          => 2**20,
    Gi          => 2**30,
    Ti          => 2**40,
    Pi          => 2**50,
    Ei          => 2**60,
    Yi          => 2**70,
    Zi          => 2**80,
);

my %BinaryUnits = (
    b           => (&_scalar)->_dim(Data),
    B           => (&_scalar)->_dim(Data)->_value(8),
    o           => (&_scalar)->_dim(Data)->_value(8),
);

my $inch        = _Metre->_value(0.00254);
my $foot        = $inch * 12;
my $yard        = $foot * 3;
my $chain       = $yard = 220;
my $link        = $chain / 100;
my $furlong     = $chain * 10;
my $mile        = $furlong * 8;
my $league      = $mile * 3;

my $acre        = $chain * $furlong;

my $pound       = _Kilogram->_value(0.453592);
my $ounce       = $pound / 16;
my $stone       = $pound * 14;

my %MiscUnits = (
    M           => _Metre,     # because 'm' is a reserved symbol in Perl

    ha          => _SquareMetre->_value(1E4),

    sec         => _Second,
    second      => _Second,
    seconds     => _Second,
    secs        => _Second,
    min         => _minutes,
    mins        => _minutes,
    minutes     => _minutes,
    minute      => _minutes,
    h           => _hours,
    hr          => _hours,
    hour        => _hours,
    hours       => _hours,
    days        => _days,
    day         => _days,
    weeks       => _weeks,
    week        => _weeks,

    kn          => _Metre->_per(_Second)->_value(1851/3600),
    r           => _Radian,
    rad         => _Radian,
    radian      => _Radian,
    radians     => _Radian,
    '°'         => _Degrees,
    '°C'        => _Kelvin->_offset(273.15),
    '°CΔ'       => _Kelvin,
    '°F'        => _Kelvin->_value(5/9)->_offset(273.15-32*5/9),
    '°FΔ'       => _Kelvin->_value(5/9),
    '°R'        => _Kelvin->_value(5/9),

    chain       => $chain,
    chains      => $chain,
    ch          => $chain,
    foot        => $foot,
    feet        => $foot,
    ft          => $foot,
    furlong     => $furlong,
    furlongs    => $furlong,
    fl          => $furlong,
    inch        => $inch,
    inches      => $inch,
    in          => $inch,
    league      => $league,
    leagues     => $league,
    lg          => $league,
    link        => $link,
    links       => $link,
    mi          => $mile,
    mile        => $mile,
    miles       => $mile,
    yard        => $yard,
    yards       => $yard,
    yd          => $yard,

    acre        => $acre,

    ounce       => $ounce,
    ounces      => $ounce,
    oz          => $ounce,
    pound       => $pound,
    pounds      => $pound,
    lb          => $pound,
    st          => $stone,
    stone       => $stone,
    stones      => $stone,

    kmh         => _speed->_value(1000/3600),
    mph         => _speed->_value(1609.344/3600),

);

sub _cross_set(\%\%) {
    my ($prefixes, $units) = @_;
    map {
        my $u = $_;
        map {
            my $p = $_;
            ( $p.$u => $units->{$u}->_clone->_value($prefixes->{$p}) )
        } keys %$prefixes;
    } keys %$units;
}

my %Units = (
    _cross_set(%MetricScaleUp, %BinaryUnits),
    _cross_set(%BinaryScale, %BinaryUnits), %BinaryUnits,
    _cross_set(%MetricScale, %MetricUnits), %MetricUnits,
    %MiscUnits,
);
my $units_pattern = join '|', reverse sort keys %Units;
$units_pattern = qr/$units_pattern/;

use Data::Dumper;

sub ParseUnit($) {
    my ($unit) = @_;

    warn sprintf "FILTER:CODE ParseUnit(%s)\n", $unit;
    warn sprintf "\t%s\n", "@{[ caller $_ ]}" for 0..6;

    my $r = _scalar;

    my @parts = ('·', split qr{([·/]+)}, $unit);
    for (my $pnum = 0; $pnum <= $#parts; $pnum+=2) {
        my $invert = $parts[$pnum] =~ qr{/};
        my $part = $parts[$pnum+1];
        warn sprintf "FILTER:CODE part=%s", $part;

        my $exponent = ($part =~ s{ [⁺⁻]?[⁰¹²³⁴-⁹]+ $ }{}x) ? $& : 0;
        #warn sprintf "FILTER:CODE part=%s exponent=%s", $part, $exponent // "(undef)";
        $exponent //= 1;
        #warn sprintf "FILTER:CODE exponent=%s", $exponent // "(undef)";
        $exponent =~ tr{⁻⁺⁰¹²³⁴-⁹}
                       {-+0-9};
        #warn sprintf "FILTER:CODE exponent=%s", $exponent // "(undef)";
        $exponent += 0;
        $exponent = -$exponent if $invert;

        #warn sprintf "FILTER:CODE exponent=%s", $exponent // "(undef)";

        my $u = $Units{$part} // do {
            warn "$part is not a known unit, ignoring";
            return undef;
        };

        $r->[Quantity] *= $u->[Quantity] ** $exponent;
        $r->[Name] = undef;

        if (defined $u->[Offset]) {
            if ($#parts > 1 || $exponent != 1) {
                die "Can't make a composite unit from an offset unit";
                return undef;
            }
            $r->[Offset] = $u->[Offset];
        }

        $r->[$_] += $u->[$_] * $exponent for MinDim .. $#$u;
        warn sprintf "FILTER:CODE part=%s", Dumper($u);
        warn sprintf "FILTER:CODE cumulative=%s", Dumper($r);
    }
    return $r;
}

sub FilterConv($$) {
    my ($before, $matched) = @_;

    if ($before eq '' and $matched =~ /^m\b/) {
        warn "bare 'm' is probably m/.../; use M instead";
        return undef
    }

    if ( $matched =~ m/^[⁺⁻]?[⁰¹²³⁴-⁹]+$/ ) {
        my $exponent = $matched;
        $exponent =~ tr{⁻⁺⁰¹²³⁴-⁹}
                       {-+0-9};
        $exponent += 0;
        return "$before ** $exponent";
    }
    my $r = ParseUnit($matched);
    $r->[Bare] = 1;

    # Generate a name for this combination of dimensions
    my $name = join '_',
                    'DU',
                    ( map { my $o = $r->[$_]; $o != 1    ? unpack "H*", pack "C0d>", $_ : '' } Quantity ),
                    ( map { my $o = $r->[$_]; defined $o ? unpack "H*", pack "C0d>", $_ : '' } Offset ),
                    ( map { my $o = $r->[$_]; $o         ? unpack "H*", pack 'C0s>', $_ : '' } MinDim..$#$r );
    $name =~ s/_+$//;
    # Create a "use constant"
    $Filter::Dimensional::Units::{$name} //= \$r;

    $before .= ' ** ' if $before;
    return "${before}Filter::Dimensional::Units::$name";
}

#
# Note that we hijack the '**' operator and overload it, so that
#
#   my $speed = 36km / 2h;
#
# gets translated to
#
#   my $speed = 36**ParseUnit('km') / 2**ParseUnit('h');
#
# which is then treated as
#
#   my $speed = (36*ParseUnit('km')) / (2*ParseUnit('h'));
#
# so that proper numeric AND unit quotients will result:
#
#   (5 m·s⁻¹)
#
# The results of ParseUnit are the same type as a scaled value, but are
# tagged so that the exponentiation operator is allowed (and treated as a
# high-precedence multiplication).
#
# (The naive approach of translating to '*' (multiplication) results in the
# wrong precedence)
#

use Filter::Simple;

#warn "Units pattern is $units_pattern\n";

FILTER_ONLY code => sub {
    utf8::decode($_) or die "Couldn't read bytestream as UTF-8\n";
    warn sprintf "FILTERING %u bytes of code [%.128s]\n", length $_, quotemeta $_;
    warn sprintf "\t%s\n", "@{[ caller $_ ]}" for 0..3;
    s{
        \b
        ( 0x[0-9a-fA-F]+ \s*
        | \d+(?:\.\d*|)(?:[Ee][-+]?\d+|) \s*
        | \w+ \s+
        |
        )(
            $units_pattern [⁺⁻]?[⁰¹²³⁴-⁹]*
          (?:
            [·/]+
            $units_pattern [⁺⁻]?[⁰¹²³⁴-⁹]*
          )*
        )(?=$|\W)
    }{
        my ($pre, $match, $orig) = ($1,$2, $&);
        warn sprintf "FILTER:CODE pre=[%s] match=[%s]\n", quotemeta $pre, quotemeta $match;
        FilterConv($pre,$match)//$orig;
    }gex;
    warn sprintf "FILTER gave replacement [%.128s]\n", quotemeta $_;
};

{
my @BaseUnits;
$BaseUnits[Time]        = 's';
$BaseUnits[Length]      = 'm';
$BaseUnits[Mass]        = 'kg';
$BaseUnits[Substance]   = 'mol';
$BaseUnits[Temperature] = 'K';
$BaseUnits[Current]     = 'A';
$BaseUnits[Luminosity]  = 'cd';
$BaseUnits[Angle]       = 'rad';

sub _fill_name {
    my ($x) = @_;
    $x->[Name] = join '·', map {
        my $e = $x->[$_];
        my $n = $BaseUnits[$_];
        $e == 1 ? $n :
        $e == 0 ? () : do {
            $e =~ tr{-+0-9}
                    {⁻⁺⁰¹²³⁴-⁹};
            $n.$e }
    } MinDim .. $#$x;
}
}

sub as_str {
    my ($x) = @_;
    $x->[Name] || $x->_fill_name;
    ($x->[Bare] ? '(bbb)' : $x->[Quantity]).$x->[Name];
}

sub power {
    my ($b, $e, $rev) = @_;
    if ($rev) {
        # something-to-the-power-of a unit
        ! ref $e && $b->[Bare] or die "Can't raise something to the power of a dimensioned value";
        my $r = $b->_clone->_value($e);
        my $o = delete $r->[Offset];
        $r->[Quantity] += $o if $o;
        delete $r->[Name] if $o;    # will fill name later
        delete $r->[Bare];
        return $r;
    }
    if ($e == 0) { return 1 }
    if ($e == 1) { return $b }
    if ($e != int $e) { die "Can't raise a unit to a fractional power" }
    if ($b->[Offset]) { die "Can't raise an offset unit to any power (except 0 or 1)" }
    my $r = $b->_clone;
    $r->[Quantity] **= $e;
    $r->[$_]        *= $e for MinDim .. $#$r;
    delete $r->[Name];  # will fill name later
    return $r;
}

sub multiply {
    my ($b, $c, undef) = @_;    # don't care about reversal
    my $r = $b->_clone;
    if (!ref $c && $c == 1) { return $b }
    if ($b->[Offset]) { die "Can't multiply an offset unit by any factor (except 1)" }
    if (ref $c) {
        if ($c->[Offset]) { die "Can't multiply an offset unit by any factor (except 1)" }
        $r->[Quantity] *= $c->[Quantity];
        $r->[$_] += $c->[$_] for MinDim .. $#$c;
        delete $r->[Name];  # will fill name later
        delete $r->[Bare] if !$c->[Bare];
      # $r->[Name] .= '·'.$c->[Name]
    } else {
        $r->[Quantity] *= $c;
    }
    if ( not grep {$_} @$r[MinDim..$#$r] ) { return $r->[Quantity] }
    return $r;
}

sub divide {
    my ($b, $c, $rev) = @_;
    my $r;
    if ($rev) {
        $r = ref $c ? $c->_clone : _scalar;
        $c = $b;
    } else {
        $r = $b->_clone;
    }
    if ($r->[Offset]) { die "Can't divide an offset unit by any factor (except 1)" }
    if (ref $c) {
        if ($c->[Offset]) { die "Can't divide an offset unit by any factor (except 1)" }
        $r->[Quantity] /= $c->[Quantity];
        $r->[$_] -= $c->[$_] for MinDim .. $#$c;
        delete $r->[Name];  # will fill name later
        delete $r->[Bare] if !$c->[Bare];
      # $r->[Name] .= '/('.$c->[Name].')'
    } else {
        $r->[Quantity] /= $c;
    }
    if ( not grep { $r->[$_] } MinDim..$#$r ) { return $r->[Quantity] }
    return $r;
}

sub plus {
    my ($b, $c, $rev) = @_;
    if (!ref $c) {
        die "Can't add a scalar to a dimensioned value";
    }
    if ($#$b != $#$c or grep { ($b->[$_] // 0) != ($c->[$_] // 0) } MinDim .. $#$b) {
        die "Can't add differently-dimensioned values";
    }
    if ($b->[Bare] || $c->[Bare]) {
        die "Can't add a bare dimension to anything";
    }
    if ($b->[Offset] || $c->[Offset]) {
        die "Can't add offset-dimensioned values";
    }
    if ($rev) {
        #no-op
    }
    my $r = $b->_clone;
    $r->[Quantity] += $c->[Quantity];
    return $r;
}

sub minus {
    my ($b, $c, $rev) = @_;
    if (!ref $c) {
        die "Can't subtract a scalar from a dimensioned value or vice versa";
    }
    if ($#$b != $#$c or grep { ($b->[$_] // 0) != ($c->[$_] // 0) } MinDim .. $#$b) {
        die "Can't subtract differently-dimensioned values";
    }
    if ($b->[Bare] || $c->[Bare]) {
        die "Can't subtract a bare dimension to anything";
    }
    if ($b->[Offset] || $c->[Offset]) {
        die "Can't subtract offset-dimensioned values";
    }
    if ($rev) {
        my $r = $c->_clone;
        $r->[Quantity] -= $b->[Quantity];
        return $r;
    }
    my $r = $b->_clone;
    $r->[Quantity] -= $c->[Quantity];
    return $r;
}

use overload
    '""'    => \&as_str,
    '**'    => \&power,
    '*'     => \&multiply,
    '/'     => \&divide,
    '%'     => \&modulo,
    '+'     => \&plus,
    '-'     => \&minus,
    ;

};
1;
