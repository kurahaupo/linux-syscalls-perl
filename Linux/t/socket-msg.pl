#!/usr/bin/perl

use 5.016;
use strict;
use warnings;

my $num_errors = 0;

use Socket ();

use Linux::Syscalls;

for my $t (qw(

    MSG_OOB
    MSG_PEEK
    MSG_DONTROUTE
    MSG_TRYHARD
    MSG_CTRUNC
    MSG_PROXY
    MSG_TRUNC
    MSG_DONTWAIT
    MSG_EOR
    MSG_WAITALL
    MSG_FIN
    MSG_SYN
    MSG_CONFIRM
    MSG_RST
    MSG_ERRQUEUE
    MSG_NOSIGNAL
    MSG_MORE
    MSG_WAITFORONE
    MSG_FASTOPEN
    MSG_CMSG_CLOEXEC

)) {

    no strict 'refs';
    my $ff = "Socket::$t";
    my $lf = "Linux::Syscalls::$t";
    my $fv = eval { &$ff; };
    my $lv = eval { &$lf; };
    if ( defined $fv ) {
        if ( defined $lv  ) {
            if ( $fv == $lv ) {
                printf "\e[32;1mOK\e[39;22m   %28s = %#9.6x = %s\n", $lf, $fv, $ff;
                next;
            }
        } else {
            printf "\e[33;1mMISS\e[39;22m %28s = undef BUT %-19s = %#9.6x\n", $lf, $ff, $fv;
            ++$num_errors;
            next;
        }
    } else {
        # If the constant is not defined by Socket then the value, if any,
        # provided by Linux::Syscalls cannot be ruled "wrong": assume its value
        # is correct, but ignore it if it's undefined.
        if ( defined $lv  ) {
            printf "\e[32mPASS\e[39;22m %28s = %#9.6x BUT %-19s = (undef)\n", $lf, $lv, $ff;
        } else {
            printf "\e[38;2;99;99;99mIGNR %28s = (undef)     = %s\e[39m\n", $lf, $ff;
        }
        next;
    }

    ++$num_errors;
    $_ = defined $_ ? sprintf '%#9.7x', $_ : '  (undef)' for $fv, $lv;
    printf "\e[31;1mBAD\e[39;22m  %28s = %s BUT %-19s = %s\n", $lf, $lv, $ff, $fv, ;
}

exit $num_errors == 0 ? 0 : 1;

__END__
