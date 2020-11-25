#!/usr/bin/perl

use 5.016;
use strict;
use warnings;

my $num_errors = 0;

use Fcntl ();

my @list = qw(
    O_RDONLY O_WRONLY O_RDWR

    O_ACCMODE
    O_APPEND
    O_ASYNC
    O_CREAT
    O_DIRECT
    O_LARGEFILE
    O_DIRECTORY
    O_DSYNC
    O_EXCL
    O_NDELAY
    O_NOATIME
    O_NOCTTY
    O_NOFOLLOW
    O_NONBLOCK
    O_RSYNC
    O_SYNC
    O_TRUNC
);

use Linux::Syscalls;

for my $t (qw(
    O_RDONLY
    O_WRONLY
    O_RDWR

    O_ACCMODE
    O_CREAT
    O_EXCL
    O_NOCTTY
    O_TRUNC

    O_APPEND
    O_NDELAY
    O_NONBLOCK

    O_DSYNC
    O_ASYNC

    O_DIRECT
    O_LARGEFILE
    O_DIRECTORY
    O_NOFOLLOW

    O_NOATIME
    O_CLOEXEC
    O_RSYNC
    O_SYNC

    O_PATH

    O_FSYNC
    O_TMPFILE

)) {

    no strict 'refs';
    my $ff = "Fcntl::$t";
    my $lf = "Linux::Syscalls::$t";
    my $fv = eval { &$ff; };
    my $lv = eval { &$lf; };
    if ( defined $fv ) {
        if ( defined $lv  ) {
            if ( $fv == $lv ) {
                printf "\e[32;1mOK\e[39;22m   %28s = %#9.6x = %s\n", $lf, $fv, $ff;
                next;
            } elsif ( $fv ==0 ) {
                state %allow_zero; %allow_zero or %allow_zero = map { ($_=>1) } qw{ O_LARGEFILE };
                if ( $allow_zero{$t} ) {
                    printf "\e[38;2;99;99;99mIGNR %28s = %#9.6x & %s = %#9.6x (allowed)\e[39m\n", $lf, $lv, $ff, $fv;
                    next;
                }
            }
        } else {
            printf "\e[33;1mMISS\e[39;22m %28s = undef BUT %-19s = %#9.6x\n", $lf, $ff, $fv;
            ++$num_errors;
            next;
        }
    } else {
        # If the constant is not defined by Fcntl then the value, if any,
        # provided by Linux::Syscalls cannot be "wrong": assume its value is
        # correct, but ignore it if it's undefined.
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
