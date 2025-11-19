#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

package Linux::IpRoute2::attr::_int;

use parent 'Linux::IpRoute2::attr::_base';

use Carp qw( confess );

#
# Decode an integer value that occupies the whole record.
#
# Note: this only works when *DECODING* data, when the first element of the
# array is the raw received data, including the 4-byte attribute header.
#
# If an attribute will have different sizes at run time, define a method
# C<_variably_sized> in the subclass to suppress warnings about this.
#

my @IntPat = (undef, 'C', 'S', undef, 'L', undef, undef, undef, 'Q');
my %once;

sub packpat {
    my ($self) = @_;
    my $class = ref $self or confess "Can't choose data size without an object ref\n";
    my $d = $self->[0] // confess "Can't choose data size without data";
    my $dl = length($d) - 4;
    my $pp = $IntPat[$dl];

    if ($once{$class . $dl}++) {
        if ($pp) {
            warn "\nNOTE: packpat for class $class appears to be $pp; please modify the source to remove this"
                if not $d->can('_variably_sized');
        } else {
            confess "packpat for class $class cannot be determined for size $dl";
        }
    }

    return 'C' if $dl == 1;
    return 'S' if $dl == 2;
    return 'L' if $dl == 4;
    return 'Q' if $dl == 8;
    confess "Can't choose data size when data length $dl is not a power of two";
}

1;
