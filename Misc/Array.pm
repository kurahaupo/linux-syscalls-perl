#!perl-module
#
# In 2007 Martin D Kealey wrote and released this code to the public domain.
# Attribution would be appreciated, but is not required; you may use or adapt
# it however you see fit.

use 5.008;
use strict;
use warnings;

package Misc::Array;

# A trivial list constructor. Almost certainly NOT useful to call by name (just
# use \@A or [@A] instead) but useful to pass as a function to other functions.
# See the implementation of zip(transpose) using zipwith.
sub array(@) { \@_ }

sub xmap(&@) {
    my $f = shift;
    my %r;
    for my $v (@_) {
        my $x = do { local $_ = $v; &$f };
        defined $x or next;
        push @{$r{$x}}, $v;
    }
    return \%r;
}

sub fold(&@) {
    my $f = shift;
    local $a = shift;
    for $b (@_) {
        $a = &$f
    }
    $a;
}

# Although the follow do work, they are inefficient. They are here to serve as
# documentation by way of worked examples.
sub max(@) { fold { $a > $b ? $a : $b } @_ }
sub min(@) { fold { $a < $b ? $a : $b } @_ }
sub sum(@) { fold { $a + $b } @_ }

sub zipwith(&@) {
    my $f = shift;
    map {
            my $r = $_;
            $f->(map { $_[$_][$r] } 0 .. $#_)
        } 0 .. max map { $#$_ } @_;
}

sub transpose(@) {
    unshift @_, \&array; &zipwith
}

sub zip(\@\@) { &transpose }

sub cross(@) {
    my $a = shift;

    sub _crosstail($@);
    sub _crosstail($@) {
        my $b = shift;
        @_ or return $b;
        my $c = shift;
        map { _crosstail [ @$b, $_ ], @_ } @$c;
    }

    map { _crosstail [$_], @_ } @$a;
}

sub null() {()}

my @zipfuncs = \&null;
my @zipwithfuncs = \&null;

sub import {
    my ($self, @reqs) = @_;
    my ($package) = caller;
    #my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);
    #warn "Importing from $self into $package: [@reqs]\n";
    for my $req(@reqs) {
        no strict 'refs';
        my $f = $req =~ /^zip(\d+)$/ ? do {
                    $zipfuncs[$1] ||= eval "sub(".('\@' x $1).") { &transpose }";
                } : $req =~ /^zipwith(\d+)$/ ? do {
                    $zipwithfuncs[$1] ||= eval "sub(&".('\@' x $1).") { &zipwith }";
                } : \&$req;
        *{$package.'::'.$req} = $f;
    }
}

1;
