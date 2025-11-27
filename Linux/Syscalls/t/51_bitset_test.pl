#!/usr/bin/perl

use 5.020;
use strict;
use warnings;

use Exporter 'import';

use Linux::Syscalls::bitset qw{ OPTION :min :max :none :all :sep=| :empty=
    ZERO
    -
    TWO
    THREE
    -
    FIVE
};

use Data::Dumper;

sub check($$;$) {
    my ($cmd, $want, $msg) = @_;
    my $out = eval($cmd) // die "\e[31;1mFAIL\e[m Couldn't run $cmd\n$@\n\t";
    $out eq $_[1] or die "\e[31;1mFAIL\e[m Output mismatch from $cmd\n\t\e[33;1mwanted:\e[m {$want}\n\t   \e[31;1mgot:\e[m {$out}\n";
    say "\e[32;1mOK\e[m ", $msg // "$cmd \e[2mgives\e[m $out";
}

check q{OPTION_to_desc 0}, q{0x00};
check q{OPTION_to_desc 1}, q{zero};
check q{OPTION_to_desc 2}, q{0x02};
check q{OPTION_to_desc 3}, q{zero|0x02};
check q{OPTION_to_desc 4}, q{two};
check q{OPTION_to_desc 8}, q{three};
check q{OPTION_to_desc 16}, q{0x10};
check q{OPTION_to_desc 31}, q{zero|two|three|0x12};
check q{OPTION_to_desc 32}, q{five};
check q{OPTION_to_desc 45}, q{zero|two|three|five};

check q{join ",", OPTION_indeces}, q{0,2,3,5};
check q{join ",", OPTION_range},   q{0,1,2,3,4,5};

check q{OPTION_min},   q{0};
check q{OPTION_none},  q{0};
check q{OPTION_shift}, q{0};
check q{OPTION_max},   q{5};
check q{OPTION_next},  q{6};

check q{OPTION_ZERO},  q{1};
check q{OPTION_TWO},   q{4};
check q{OPTION_THREE}, q{8};
check q{OPTION_FIVE},  q{32};
check q{OPTION_all},   q{45};

check q{exists &OPTION_MIN  ? "yes" : "no"},q{no}, q{does not define OPTION_MIN};
check q{exists &OPTION_MAX  ? "yes" : "no"},q{no}, q{does not define OPTION_MAX};
check q{exists &OPTION_NONE ? "yes" : "no"},q{no}, q{does not define OPTION_NONE};
check q{exists &OPTION_ALL  ? "yes" : "no"},q{no}, q{does not define OPTION_ALL};

check q{Data::Dumper->new([ \ our @EXPORT ], [qw[ @EXPORT ]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump},
      q{$@EXPORT = [];},
      q{@EXPORT list is empty};

check q{Data::Dumper->new([ \ our @EXPORT_OK ], [qw[ @EXPORT_OK ]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump},
      q{$@EXPORT_OK = [];},
      q{@EXPORT_OK list is empty};

our @EXPORT;
our @EXPORT_OK;
our %EXPORT_TAGS;
@$_ = sort @$_ for \@EXPORT, \@EXPORT_OK, values %EXPORT_TAGS;

check q{Data::Dumper->new([ \ our %EXPORT_TAGS ], [qw[ %EXPORT_TAGS ]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump},
      q{$%EXPORT_TAGS = {"descriptions" => ["OPTION_to_desc"],"limits" => ["OPTION_all","OPTION_indeces","OPTION_max","OPTION_min","OPTION_next","OPTION_none","OPTION_range","OPTION_shift"],"option" => ["OPTION_FIVE","OPTION_THREE","OPTION_TWO","OPTION_ZERO","OPTION_all","OPTION_indeces","OPTION_max","OPTION_min","OPTION_next","OPTION_none","OPTION_range","OPTION_shift","OPTION_to_desc"]};},
      q{@EXPORT_TAGS contains all and only requested items};

1;
