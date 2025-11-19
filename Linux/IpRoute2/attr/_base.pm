#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

package Linux::IpRoute2::attr::_base;

#
# Stuff that's common to attributes in all message types
#

use parent 'Linux::IpRoute2::default_unpack';

1;
