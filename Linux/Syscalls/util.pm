#! /module/for/perl

use 5.010;
use strict;
use warnings;
use feature 'state';

#
# CODA:
#   Although this package isn't Linux-specific, it's
#   Linux::Syscalls::util because it's built for internal use by
#   modules that are, especially Linux::Syscalls and by Linux::IpRoute2.
#
#   If you find any of it useful in other projects, feel free to rename and
#   adapt this package.
#

package Linux::Syscalls::util v0.1.0;

use List::Util qw( uniq );

use base 'Exporter';

#
# A quick little hack so we can write:
#
#   use constant {
#       foo => _B 0,
#       bar => _B 1,
#       zot => _B 2,
#   };
#
# to get constants representing bits:
#
#       foo == 0x0001,
#       bar == 0x0002,
#       zot == 0x0004,
#
# (This isn't called "B" because that's the Perl decompiler.)
#

sub _B :prototype($) { 1 << pop }

our %EXPORT_TAGS = (
    B => [qw[
        _B
    ]],
);

our @EXPORT_OK = uniq our @EXPORT, map { @$_ } values %EXPORT_TAGS;

$EXPORT_TAGS{everything} = \@EXPORT_OK;

1;
