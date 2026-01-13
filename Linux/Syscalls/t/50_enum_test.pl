#!/usr/bin/perl

use 5.020;
use strict;
use warnings;

use Exporter 'import';

use Linux::Syscalls::enum qw{ PRIME :min :max
    - -
    TWO
    THREE
    -
    FIVE
    -
    SEVEN
    - - -
    ELEVEN
};

use Data::Dumper;

sub check($$;$) {
    my ($cmd, $want, $msg) = @_;
    my $out = eval($cmd) // die "\e[31;1mFAIL\e[m Couldn't run $cmd\n$@\n\t";
    ref $want eq 'Regexp' ? $out =~ $want : $out eq $want
        or die "\e[31;1mFAIL\e[m Output mismatch from $cmd\n\t\e[33;1mwanted:\e[m {$want}\n\t   \e[31;1mgot:\e[m {$out}\n";
    say "\e[32;1mOK\e[m ", $msg // "$cmd \e[2mgives\e[m $out";
}

check q{PRIME_TWO},     q{2};
check q{PRIME_THREE},   q{3};
check q{PRIME_FIVE},    q{5};
check q{PRIME_SEVEN},   q{7};
check q{PRIME_ELEVEN},  q{11};

check q{PRIME_min},     q{2};
check q{PRIME_max},     q{11};
check q{PRIME_next},    q{12};

check q{PRIME_to_label(-1) // '(undef)'}, q{(undef)};
check q{PRIME_to_label(0)  // '(undef)'}, q{(undef)};
check q{PRIME_to_label(1)  // '(undef)'}, q{(undef)};
check q{PRIME_to_label(2)  // '(undef)'}, q{two};
check q{PRIME_to_label(3)  // '(undef)'}, q{three};
check q{PRIME_to_label(4)  // '(undef)'}, q{(undef)};
check q{PRIME_to_label(5)  // '(undef)'}, q{five};
check q{PRIME_to_label(6)  // '(undef)'}, q{(undef)};
check q{PRIME_to_label(7)  // '(undef)'}, q{seven};
check q{PRIME_to_label(8)  // '(undef)'}, q{(undef)};
check q{PRIME_to_label(9)  // '(undef)'}, q{(undef)};
check q{PRIME_to_label(10) // '(undef)'}, q{(undef)};
check q{PRIME_to_label(11) // '(undef)'}, q{eleven};
check q{PRIME_to_label(12) // '(undef)'}, q{(undef)};

check q{PRIME_to_desc(-1)}, qr{prime\#0xffffffff+}; # answer depends on sizeof(int)
check q{PRIME_to_desc(0) }, q{prime#0x000000};
check q{PRIME_to_desc(1) }, q{prime#0x000001};
check q{PRIME_to_desc(2) }, q{two};
check q{PRIME_to_desc(3) }, q{three};
check q{PRIME_to_desc(4) }, q{prime#0x000004};
check q{PRIME_to_desc(5) }, q{five};
check q{PRIME_to_desc(6) }, q{prime#0x000006};
check q{PRIME_to_desc(7) }, q{seven};
check q{PRIME_to_desc(8) }, q{prime#0x000008};
check q{PRIME_to_desc(9) }, q{prime#0x000009};
check q{PRIME_to_desc(10)}, q{prime#0x00000a};
check q{PRIME_to_desc(11)}, q{eleven};
check q{PRIME_to_desc(12)}, q{prime#0x00000c};

check q{join ",", PRIME_indeces},
      q{2,3,5,7,11};
check q{join ",", PRIME_range},
      q{2,3,4,5,6,7,8,9,10,11};

check q{exists &PRIME_MIN  ? "yes" : "no"},q{no}, q{does not define PRIME_MIN};
check q{exists &PRIME_MAX  ? "yes" : "no"},q{no}, q{does not define PRIME_MAX};
check q{exists &PRIME_NONE ? "yes" : "no"},q{no}, q{does not define PRIME_NONE};
check q{exists &PRIME_ALL  ? "yes" : "no"},q{no}, q{does not define PRIME_ALL};

our @EXPORT;
our @EXPORT_OK;
our %EXPORT_TAGS;
@$_ = sort @$_ for \@EXPORT, \@EXPORT_OK, values %EXPORT_TAGS;

check q{ Data::Dumper->new([ \ our @EXPORT ], [qw[ @EXPORT ]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump },
      q{$@EXPORT = [];},
      q{@EXPORT list is empty};

check q{ Data::Dumper->new([ \ our @EXPORT_OK ], [qw[ @EXPORT_OK ]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump },
      q{$@EXPORT_OK = ["PRIME_to_name"];},
      q{@EXPORT_OK list is only "PRIME_to_name"};

check q{ Data::Dumper->new([ \ our %EXPORT_TAGS ], [qw[ %EXPORT_TAGS ]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump },
      q{$%EXPORT_TAGS = {"descriptions" => ["PRIME_to_desc"],"labels" => ["PRIME_to_label"],"limits" => ["PRIME_indeces","PRIME_max","PRIME_min","PRIME_next","PRIME_range"],"prime" => ["PRIME_ELEVEN","PRIME_FIVE","PRIME_SEVEN","PRIME_THREE","PRIME_TWO","PRIME_indeces","PRIME_max","PRIME_min","PRIME_next","PRIME_range","PRIME_to_desc","PRIME_to_label"]};},
      q{@EXPORT_TAGS contains all and only requested items};

1;
