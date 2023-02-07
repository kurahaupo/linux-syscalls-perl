#!/module/for/perl

use strict;
use warnings;

use 5.020;

package Math::Lcm;

use Exporter 'import';

our @EXPORT;

sub lcm {
  @_ = grep { defined && $_ != 0 } map { abs } @_ or return 0;
  my $r = pop;
  for my $q (@_) {
    last if $r == 1;
    my $s = $q;
    my $t = $r;
    while ($s) {
      ($s, $t) = ($t % $s, $s)
    }
    $r *= $q / $t;
  }
  return $r;
}

push @EXPORT, 'lcm';

1;
