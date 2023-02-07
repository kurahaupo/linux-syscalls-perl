#!/module/for/perl

use strict;
use warnings;

use 5.020;

package Math::Gcd;

use Exporter 'import';

our @EXPORT;

sub gcd {
  @_ = grep { defined && $_ != 1 } map { abs } @_ or return 1;
  my $r = pop;
  for my $q (@_) {
    next if $q == 1;
    my $s = $q;
    while ($s) {
      ($s, $r) = ($r % $s, $s)
    }
    last if $r == 1;
  }
  return $r;
}

push @EXPORT, 'gcd';

1;
