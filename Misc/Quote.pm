#!perl-module
#
# In 2007 Martin D Kealey wrote and released this code to the public domain.
# Attribution would be appreciated, but is not required; you may use or adapt
# it however you see fit.

use 5.008;
use strict;
use warnings;

package Misc::Quote;

sub qcmd(@) {
    join " ",
        map {
            $_ eq "" ? '""'
                     : quotemeta($_)
        } @_
}

sub import {
    my ($self, @reqs) = @_;
    my ($package) = caller;
    for my $req(@reqs) {
        no strict 'refs';
        my $f = \&$req;
        *{$package.'::'.$req} = $f;
    }
}

1;
