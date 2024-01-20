#!/module/for/perl

use 5.010;
use strict;
use warnings;

package Utils::EnumTools v0.1.0;

# bits_to_desc is intended as a base for your own 'custom_bits_to_desc'; you
# provide the bit-set to be described and an array with the symbolic name for
# each bit, and we do the rest.
# We return a list of the form name1+name2+name3... with the name for each
# known bit. If there are any unknown bits set, that's added at the end of the
# list as a hexadecimal number. (This number is zero-padded to a width that can
# show the highest known bit.) If the value is zero, 'none' is returned.
sub bits_to_desc($$) {
    my ($flags, $names) = @_;
    $flags || return 'none';
    my @knowns =
                 grep  {
                    my $n = $names->[$_];
                    my $bb = 1 << $_;
                    $n and 0+$flags != ($flags &=~ $bb)
                } 0 .. $#$names;
    my $res = join ',',map { $names->[$_] } @knowns;
    return join '+', $res || (),
                     $flags ? printf '%#.*x', ($#$names|3>>2)+1, $flags : ()
}

# _B is a shorthand for declaring constants in a bitmask.
#   use constant {
#       foo     =>  _B 0,
#       foody   =>  _B 1,
#       foobar  =>  _B 2,
#       no_oof  =>  _B 15,
#   }

sub _B($) { 1 << pop }

use Exporter 'import';
our @EXPORT_OK = qw( bits_to_desc _B );

1;
