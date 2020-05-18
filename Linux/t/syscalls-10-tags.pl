#!/usr/bin/perl

use 5.016;
use strict;
use warnings;

use Linux::Syscalls qw{
    :AT_
    :_at
    :adjtime
    :adjtime_
    :adjtime_mask
    :adjtime_res
    :adjtimex
    :l_
    :res_
    :skip_syscall_ph
    :timeres_
};

1;
