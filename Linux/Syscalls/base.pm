#! /module/for/perl

use strict;
use warnings;

package Linux::Syscalls::base;

sub ximport {
    printf "import %s into %s\n", __PACKAGE__, join ", ", caller if $^W || $^C;
    goto &Exporter::import;
}

1;
