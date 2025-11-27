#!/usr/bin/perl

use 5.36.0;
use strict;

package Foo {
use Carp qw( carp croak );
use Linux::IpRoute2::struct qw( :new_min_fields=2 bar zot quox slab moo :opts );
}

use Data::Dumper;

my $foo;
my $x;
my @x;

sub check :prototype($$;$) {
    my ($cmd, $want, $msg) = @_;
    my $out = eval($cmd) // die "\e[31;1mFAIL\e[m Couldn't run $cmd\n$@\n\t";
    ref $want eq 'Regexp' ? $out =~ $want : $out eq $want
        or die "\e[31;1mFAIL\e[m Output mismatch from $cmd\n\t\e[33;1mwanted:\e[m {$want}\n\t   \e[31;1mgot:\e[m {$out}\n";
    print "\e[32;1mOK\e[m ", $msg // "$cmd \e[2mgives\e[m $out", "\n";
}

check q{Data::Dumper->new([\%Foo::],[qw[%Foo::]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump},
      q{$%Foo:: = {"AUTOLOAD" => *Foo::AUTOLOAD,"BEGIN" => *Foo::BEGIN,"STRUCT_FIELDS" => *Foo::STRUCT_FIELDS,"STRUCT_FIELDS_HASH" => *Foo::STRUCT_FIELDS_HASH,"STRUCT_FIELDS_QUIET" => *Foo::STRUCT_FIELDS_QUIET,"STRUCT_FIELDS_STRICT" => *Foo::STRUCT_FIELDS_STRICT,"bar" => *Foo::bar,"can" => *Foo::can,"carp" => *Foo::carp,"count" => *Foo::count,"croak" => *Foo::croak,"moo" => *Foo::moo,"new" => *Foo::new,"opts" => *Foo::opts,"pop" => *Foo::pop,"push" => *Foo::push,"quox" => *Foo::quox,"set" => *Foo::set,"shift" => *Foo::shift,"slab" => *Foo::slab,"splice" => *Foo::splice,"unshift" => *Foo::unshift,"zot" => *Foo::zot};},
      q{struct defined all and only the requested fields};

$foo = Foo->new (2,3);

check q{Data::Dumper->new([\$foo],[qw[foo]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump;}, q{$foo = \bless( [2,3,undef,undef,undef], 'Foo' );};

$foo->bar = 42;
$foo->zot = 19;
$foo->quox = 91;
$foo->slab = 77;
$foo->moo = 33;

check q{Data::Dumper->new([$foo],[qw[foo]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump;}, q{$foo = bless( [42,19,91,77,33], 'Foo' );};

$foo->push('a'..'e');
check q{Data::Dumper->new([$foo],[qw[foo]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump;}, q{$foo = bless( [42,19,91,77,33,"a","b","c","d","e"], 'Foo' );};

{
@x = $foo->splice(-1,-3,'m'..'s');
check q{Data::Dumper->new([$foo,\@x],[qw[foo splice(-1,-3)]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump;}, q{$foo = bless( [42,19,91,77,33,"a","m","n","o","p","q","r","s","e"], 'Foo' );$splice(-1,-3) = ["b","c","d"];};
}

{
$x = $foo->shift;
check q{Data::Dumper->new([$foo,$x],[qw[foo shifted]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump;}, q{$foo = bless( [42,19,91,77,33,"m","n","o","p","q","r","s","e"], 'Foo' );$shifted = "a";};
}

{
$x = $foo->pop;
check q{Data::Dumper->new([$foo,$x],[qw[foo popped]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump;}, q{$foo = bless( [42,19,91,77,33,"m","n","o","p","q","r","s"], 'Foo' );$popped = "e";};
}

{
@x = $foo->splice(undef,-3);
check q{Data::Dumper->new([$foo,\@x],[qw[foo splice(undef,-3)]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump;}, q{$foo = bless( [42,19,91,77,33,"m","n","o","p"], 'Foo' );$splice(undef,-3) = ["q","r","s"];};
}

{
@x = $foo->splice(-3,undef);
check q{Data::Dumper->new([$foo,\@x],[qw[foo splice(-3,undef)]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump;}, q{$foo = bless( [42,19,91,77,33,"m"], 'Foo' );$splice(-3,undef) = ["n","o","p"];};
}

eval {
@x = $foo->splice(-2,undef);
1;
} and die "\e[31;1mFAIL\e[m did not die when expected\n"
  or do {
    chomp $@ if ! ref $@;
    $@ =~ /splice.* negative start/
        or die "\e[31;1mFAIL\e[m Died but with \e[1mwrong message\e[m [$@]\n";
    print "\e[32;1mOK\e[m Correctly died \e[2mwith message\e[m [$@]\n"
  };

1;

__END__
Possible attempt to separate words with commas at Linux/IpRoute2/t/t2.pl line 38.
Possible attempt to separate words with commas at Linux/IpRoute2/t/t2.pl line 50.
Possible attempt to separate words with commas at Linux/IpRoute2/t/t2.pl line 54.
Possible attempt to separate words with commas at Linux/IpRoute2/t/t2.pl line 59.
#








Correctly died with error [can't splice with negative start at Linux/IpRoute2/t/t2.pl line 58.]
