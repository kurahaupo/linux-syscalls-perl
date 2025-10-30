#!/module/for/perl

use v5.18.2;
use strict;
use warnings;

package Units::Scales 0.0.1 {

use Exporter 'import';

our @EXPORT_OK;
our @EXPORT;

my @si_up = qw( '' k m g t p e z y );
my %si_up_scales = (
    ''  =>  1,
    d   =>  10,
    da  =>  10,
    h   =>  100,
    map {
        my $s = $si_up[$_];
        (
            $s      => 1E3 ** $_,
            $s.'i'  => ldexp(1, $_*10),
        )
    } 1 .. $#si_up
);
my $si_up_regex = join '|', keys @si_up_scales;
$si_up_regex = qr[$si_up_regex];
sub SI($;$$) {
    my $r = \$_[0];
    my $d = $_[1] || 1;
    my $t = $_[2] || qr/oct\w*|oc|o|byt\w*|by|b/;
    $d = $si_up{lc $d} || $d;
    sub {
        warn Dumper("SI:", \@_);
        my $v = shift;
        my $s = $d;
        if ($v =~ s/\D+$//) {
            $s = lc $&;
            $s =~ s/$t$//;  # trim off 'bytes', 'octets', etc
            $s = $si_up{$s} // die "Invalid scale '$s'\n";
        }
        $$r = $v * $s;
    }
}
sub bytes($) { push @_;      goto &SI; }
sub B($)     { push @_;      goto &SI; }
sub KB($)    { push @_, 'k'; goto &SI; }
push @EXPORT_OK, 'SI';


my @si_down = qw( '' m µ n p f a z y );
my %si_down_scales = (
    ''  =>  1,
    map {
        my $s = $si_down[$_];
        (
            $s      => 1E3 ** -$_,
            $s.'i'  => ldexp(1, -$_*10),
        )
    } 1 .. $#si_down
);
$si_down_scales{μ}  = $si_down_scales{u}  = $si_down_scales{µ};
$si_down_scales{μi} = $si_down_scales{ui} = $si_down_scales{µi};
my $si_down_regex = join '|', keys @si_down_scales;
$si_down_regex = qr[$si_down_regex];
sub SJ($;$$) {
    my $r = \$_[0];
    my $d = $_[1] || 1;
    my $t = $_[2] || qr/sec\w*|se|s/;
    $d = $si_down{lc $d} || $d;
    sub {
        warn Dumper("SI:", \@_);
        my $v = shift;
        my $s = $d;
        if ($v =~ s/\D+$//) {
            $s = lc $&;
            $s =~ s/$t$//;  # trim off 'seconds', etc
            $s = $si_down{$s} // die "Invalid scale '$s'\n";
        }
        $$r = $v * $s;
    }
}
push @EXPORT_OK, 'SJ';
}

1;
