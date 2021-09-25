#!/module/for/perl

use strict;
use utf8;

package Units::Length;

# The point of this module is to facilitate conversion between units, both in
# terms of program literals, and converting inputs (and sometimes outputs).
#
# A subroutine or constant cannot be named with one of the quoting operators: q
# qq qr qx s tr y and in particular m, which is unfortunate for "metre".

use constant Micron => 1E-6;
use constant Metre  => 1;

use constant {
    'fm'    =>              Metre / 10**18,
    'am'    =>              Metre / 10**15,
    'pm'    =>              Metre / 10**12,
    'nm'    =>              Metre / 10**9,
    'µm'    =>              Metre / 10**6,
    'μm'    =>              Metre / 10**6,
    'mm'    =>              Metre / 10**3,
    'cm'    =>              Metre / 10**2,
    'dm'    =>              Metre / 10**1,
    'm'     =>              Metre,
    'dam'   =>   10**1  *   Metre,
    'hm'    =>   10**2  *   Metre,
    'km'    =>   10**3  *   Metre,
    'Mm'    =>   10**6  *   Metre,
    'Gm'    =>   10**9  *   Metre,
    'Tm'    =>   10**12 *   Metre,
};

1;
