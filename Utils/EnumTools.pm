#!/module/for/perl

use 5.010;
use strict;
use warnings;

package Utils::EnumTools v0.1.0;

use Scalar::Util qw( looks_like_number );

sub bits_to_desc($$) {
    my ($flags, $names) = @_;
    $flags // (return 'undef') || return 'none';
    looks_like_number $flags or return "invalid[$flags]";
    my @knowns = map {
                    my $n = $names->[$_];
                    $n && 0+$flags != ($flags &=~ (1 << $_)) ? $n : ()
                } 0 .. $#$names;
    return join '+', @knowns,
                     $flags ? printf '%#.*x', ($#$names|3>>2)+1, $flags : ()
}

sub _B($) { 1 << pop }

use Exporter 'import';
our @EXPORT_OK = qw( bits_to_desc _B );

1;

=pod

=head1 Utils::EnumTools

System calls and compact data structures often pack multiple flags into a
single C<int> value. C<Utils::EnumTools> provides functions that help with
defining and displaying such sets of flags.

=over

=item *
C<_B($x)> is a shorthand for C<<< (1<<($x)) >>>, which is useful for
declaring bitwise constants:

    use constant {
        Foo     =>  _B 0,
        Fox     =>  _B 1,
        Bar     =>  _B 2,
        No_Oof  =>  _B 15,
    };

=item *
C<bits_to_desc> converts a numeric value to a readable string
indicating each "set" bit.

It returns a string of the form C<I<name1>+I<name2>+I<name3>...>
where each I<name> indicates a known set bit.

If there are any set unknown bits, the end of the list is a zero-padded
hexadecimal number C<I<name1>+I<name2>+I<name3>...+I<remainder>>.

If the original value is undefined or zero, 'undef' or 'none' is returned.

It is intended as a base for your own 'custom_bits_to_desc'; you provide the
bit-set to be described and an array with the symbolic name for each bit, and
we do the rest.

This example:

    my @bitnames = ("foo",  "fox", "bar", undef,
                    undef,  undef,  undef,  undef,
                    "zot",  undef,  undef,  undef,
                    undef,  undef,  undef,  "no-oof");

    for my $x ( 1, 2, 4, 8, 0x0010, 0x8000,
                ~0,
                0x123,
                0, undef, [] ) {
        printf "%#s = %s\n", $x // 'undef', bits_to_desc $x, \@bitnames;
    }

should output:

    1 = foo
    2 = fox
    4 = bar
    8 = 008
    16 = 010
    32768 = no-oof
    -1 = foo+fox+bar+zot+no-oof+ffffffffffff7ef8
    0x123 = foo+fox+zot+0020
    0 = none
    undef = undef
    ARRAY(0xf92f30) = invalid[ARRAY(0xf92f30)]

=back

=end
