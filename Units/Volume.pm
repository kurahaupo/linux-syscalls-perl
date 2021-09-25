#!/module/for/perl

use strict;
use utf8;

package Units::Area;

# The point of this module is to facilitate conversion between units, both in
# terms of program literals, and converting inputs (and sometimes outputs).
#
# A subroutine or constant cannot be named with one of the quoting operators: q
# qq qr qx s tr y and in particular m, which is unfortunate for "metre".

use constant CuMicron => 1E-18;
use constant CuMetre  => 1;

use constant {
    'fm³'   =>            CuMetre / 1000**18,
    'am³'   =>            CuMetre / 1000**15,
    'pm³'   =>            CuMetre / 1000**12,
    'nm³'   =>            CuMetre / 1000**9,
    'µm³'   =>            CuMetre / 1000**6,
    'μm³'   =>            CuMetre / 1000**6,
    'mm³'   =>            CuMetre / 1000**3,
    'cm³'   =>            CuMetre / 1000**2,
    'dm³'   =>            CuMetre / 1000**1,
    'm³'    =>            CuMetre,
    'dam³'  => 1000**1  * CuMetre,
    'hm³'   => 1000**2  * CuMetre,
    'km³'   => 1000**3  * CuMetre,
    'Mm³'   => 1000**6  * CuMetre,
    'Gm³'   => 1000**9  * CuMetre,
    'Tm³'   => 1000**12 * CuMetre,
},

1;
