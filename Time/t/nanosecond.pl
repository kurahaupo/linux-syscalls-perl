#!/usr/bin/perl

use 5.016;
use strict;
use warnings;

my $num_errors = 0;

use POSIX ();

use Time::Nanosecond qw( new_timespec new_timeval localtime gmtime strftime );

for my $t (
    sub {
        exists &new_timespec or die "Missing &new_timespec";
        exists &new_timeval  or die "Missing &new_timeval";
        exists &localtime    or die "Missing &localtime";
        exists &gmtime       or die "Missing &gmtime";
        exists &strftime     or die "Missing &strftime";
    },
    sub {
        my $x = new_timespec(1E9,0);
        warn sprintf "Got s=%s n=%s\n", "$x", +$x;
        $x == 1E9 or die "Expected; 1E9"
    },
) {
    eval { $t->(); } or do { ++$num_errors; warn $@ }

}

exit $num_errors == 0 ? 0 : 1;

__END__
