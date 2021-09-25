#!/module/for/perl

use 5.010;
use strict;
use warnings;
use utf8;
no integer; # everything here is floating point

########################################
# scale factors for sizes for PDF files

package Math::scale_factors;

use constant Point   =>     1;
use constant Pixel   =>         Point / 1.5;
use constant Inch    =>    72 * Point;
use constant Thou    =>         Inch  / 1000;
use constant Hand    =>     4 * Inch;
use constant Foot    =>    12 * Inch;
use constant Yard    =>     3 * Foot;
use constant Fathom  =>     2 * Yard;
use constant Chain   =>    22 * Yard;
use constant Link    =>         Chain / 100;
use constant Rod     =>         Chain / 4;
use constant Furlong =>    10 * Chain;
use constant Mile    =>     8 * Furlong;    # == 1760 * Yard;
use constant League  =>     3 * Mile;

use constant pt      =>         Point;
use constant px      =>         Pixel;
use constant th      =>         Thou;
use constant in      =>         Inch;
use constant ft      =>         Foot;
use constant yd      =>         Yard;
use constant ftm     =>         Fathom;
use constant ch      =>         Chain;
use constant li      =>         Link;
use constant fu      =>         Furlong;
use constant mi      =>         Mile;

use constant Micron  =>         Inch  / 25400;
use constant Metre   =>   1E6 * Micron;

use constant fm      =>         Micron / 1E12;
use constant am      =>         Micron / 1E9;
use constant pm      =>         Micron / 1E6;
use constant nm      =>         Micron / 1E3;
use constant µm      =>         Micron;         # micro symbol
use constant μm      =>         Micron;         # lower-case Greek letter mu, because Unicode v6 says that the micro symbol is deprecated
use constant mm      =>   1E3 * Micron;
use constant cm      =>   1E4 * Micron;
use constant dm      =>   1E5 * Micron;
use constant M       =>         Metre;
use constant dam     =>   1E1 * Metre;
use constant Dm      =>   1E1 * Metre;
use constant hm      =>   1E2 * Metre;
use constant Hm      =>   1E2 * Metre;
use constant km      =>   1E3 * Metre;
use constant Km      =>   1E3 * Metre;
use constant Mm      =>   1E6 * Metre;
use constant Gm      =>   1E9 * Metre;
use constant Tm      =>  1E12 * Metre;

#{ no utf8; use constant "\xb5m" => Micron;}     # in case anyone is NOT using UTF 8

my %imperial_units = (
    Thou    =>  Thou,
    th      =>  Thou,

    Point   =>  Point,
    pt      =>  Point,

    Pixel   =>  Pixel,
    px      =>  Pixel,

    Inch    =>  Inch,
    in      =>  Inch,

    Hand    =>  Hand,

    ft      =>  Foot,
    Foot    =>  Foot,
    ft      =>  Foot,

    Yard    =>  Yard,
    yd      =>  Yard,

    Fathom  =>  Fathom,
    ftm     =>  Fathom,

    Chain   =>  Chain,
    ch      =>  Chain,

    Link    =>  Link,
    li      =>  Link,

    Rod     =>  Rod,

    Furlong =>  Furlong,
    fu      =>  Furlong,

    Mile    =>  Mile,
    mi      =>  Mile,

    League  =>  League,
);

my %metric_units = (
    fm      =>  fm,
    am      =>  am,
    pm      =>  pm,
    nm      =>  nm,

    Micron  =>  Micron,
    µm      =>  Micron,
    μm      =>  Micron,   # greek lower-case mu, because Unicode v6 says we must. Natch!

    mm      =>  mm,

    cm      =>  cm,
    dm      =>  dm,

    m       =>  Metre,
    M       =>  Metre,
    Metre   =>  Metre,

    dam     =>  dam,
    Dm      =>  dam,
    hm      =>  hm,
    Hm      =>  Hm,

    km      =>  km,
    Km      =>  km,

    Mm      =>  Mm,
    Gm      =>  Gm,
    Tm      =>  Tm,
);
${Math::scale_factors::}{"\xb5m"} =
$metric_units{"\xb5m"}=  µm; # micro symbol as ISO-8859-1

my %units = (%imperial_units, %metric_units);


sub as_points($) {
    my $v = $_[0];
    if ($v =~ s/[a-zµμ]+$//) {
        $v *= $units{$&} || die "Unknown unit-of-measure $&\n";
    }
    $v;
}

use parent 'Exporter';
our @EXPORT_OK = ( 'as_points', keys %units );
our %EXPORT_TAGS = (
    si => [ keys %metric_units ],
    us => [ keys %imperial_units ],
);

#use Exporter;
#*import = \&Exporter::import;

1;
