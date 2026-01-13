#!/usr/bin/perl

use v5.20;
use lib '.';
use lib '..';

require Linux::IpRoute2::rtnetlink;
say "loaded rtnetlink";
require Linux::IpRoute2;
say "loaded Linux::IpRoute2";
#Linux::IpRoute2::->TEST('enp1s0');      # was eth0
Linux::IpRoute2::->TEST('wlp0s20f3');   # was wlan0

1;
