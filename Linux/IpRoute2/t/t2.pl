#!/usr/bin/perl

use 5.36.0;
use strict;

package Foo {
use Carp qw( carp croak );
use Linux::IpRoute2::struct qw( :new_min_fields=2 bar zot quox slab moo :opts );
}

use Data::Dumper;

BEGIN { say Dumper(\%Foo::) }

my $foo = Foo->new (2,3);
say Data::Dumper->new([\$foo],[qw[foo]])->Indent(0)->Useqq(1)->Dump;

$foo->bar = 42;
$foo->zot = 19;
$foo->quox = 91;
$foo->slab = 77;
$foo->moo = 33;
say Data::Dumper->new([$foo],[qw[foo]])->Indent(0)->Useqq(1)->Dump;

$foo->push('a'..'e');
say Data::Dumper->new([$foo],[qw[foo]])->Indent(0)->Useqq(1)->Dump;

{
my @x = $foo->splice(-1,-3,'m'..'s');
say Data::Dumper->new([$foo,\@x],[qw[foo splice(-1,-3)]])->Indent(0)->Useqq(1)->Dump;
}
{
my $x = $foo->shift;
say Data::Dumper->new([$foo,$x],[qw[foo shifted]])->Indent(0)->Useqq(1)->Dump;
}
{
my $x = $foo->pop;
say Data::Dumper->new([$foo,$x],[qw[foo popped]])->Indent(0)->Useqq(1)->Dump;
}
{
my @x = $foo->splice(undef,-3);
say Data::Dumper->new([$foo,\@x],[qw[foo splice(undef,-3)]])->Indent(0)->Useqq(1)->Dump;
}
{
my @x = $foo->splice(-3,undef);
say Data::Dumper->new([$foo,\@x],[qw[foo splice(-3,undef)]])->Indent(0)->Useqq(1)->Dump;
}
eval {
my @x = $foo->splice(-2,undef);
say Data::Dumper->new([$foo,\@x],[qw[foo splice(-2,undef)]])->Indent(0)->Useqq(1)->Dump;
1;
} and die "Failed to died with [can't splice with negative start]!\n"
  or do {
    chomp $@ if ! ref $@;
    $@ =~ /splice.* negative start/
        or die "Died but with wrong message [$@]\n";
    warn "Correctly died with error [$@]\n"
  };

1;
