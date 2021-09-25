#!/module/for/perl

use strict;
use utf8;

package Units::Area;

# The point of this module is to facilitate conversion between units, both in
# terms of program literals, and converting inputs (and sometimes outputs).
#
# A subroutine or constant cannot be named with one of the quoting operators: q
# qq qr qx s tr y and in particular m, which is unfortunate for "metre".

use constant SqMicron => 1E-12;
use constant SqMetre  => 1;

use constant {
    'fm²'   =>            SqMetre / 100**18,
    'am²'   =>            SqMetre / 100**15,
    'pm²'   =>            SqMetre / 100**12,
    'nm²'   =>            SqMetre / 100**9,
    'µm²'   =>            SqMetre / 100**6,
    'μm²'   =>            SqMetre / 100**6,
    'mm²'   =>            SqMetre / 100**3,
    'cm²'   =>            SqMetre / 100**2,
    'dm²'   =>            SqMetre / 100**1,
    'm²'    =>  100**0  * SqMetre,
    'dam²'  =>  100**1  * SqMetre,
    'hm²'   =>  100**2  * SqMetre,
    'km²'   =>  100**3  * SqMetre,
    'Mm²'   =>  100**6  * SqMetre,
    'Gm²'   =>  100**9  * SqMetre,
    'Tm²'   =>  100**12 * SqMetre,
};

1;
