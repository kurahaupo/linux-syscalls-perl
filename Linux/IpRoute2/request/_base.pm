#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

# Not sure if this class is actually necessary; clients invoke "compose"
# in the subclass directly.

package Linux::IpRoute2::request::_base;

1;
