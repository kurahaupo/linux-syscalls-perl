#!/module/for/perl

use v5.18.2;
use strict;
use warnings;

use Exporter;

our @EXPORT_OK;
our @EXPORT;

{
    my @si = qw( '' k m g t p e z y );
    my %si_scales = (
        ''  =>  1,
        d   =>  10,
        da  =>  10,
        h   =>  100,
        map {
            my $s = $si[$_];
            (
                $s      => 1E3 ** $_,
                $s.'i'  => ldexp(1, $_*10),
            )
        } 1 .. $#si
    );
    my $sir = join '|', keys @si_scales;
    $sir = qr[$sir];
    sub SI($;$$) {
        my $r = \$_[0];
        my $d = $_[1] || 1;
        my $t = $_[2] || qr/oct\w*|oc|o|byt\w*|by|b/;
        $d = $si{lc $d} || $d;
        sub {
            warn Dumper("SI:", \@_);
            my $v = shift;
            my $s = $d;
            if ($v =~ s/\D+$//) {
                $s = lc $&;
                $s =~ s/$t$//;  # trim off 'bytes', 'octets', etc
                $s = $si{$s} // die "Invalid scale '$s'\n";
            }
            $$r = $v * $s;
        }
    }
    sub bytes($) { push @_, 1, qr/oct\w*|oc|o|byt\w*|by|b/; goto &SI; }
    sub B($) { push @_, 1, qr/oct\w*|oc|o|byt\w*|by|b/; goto &SI; }
    sub KB($) { push @_, 'k', qr/oct\w*|oc|o|byt\w*|by|b/; goto &SI; }
    push @EXPORT_OK, 'SI';
}

{
    my @si = qw( '' m µ n p f a z y );
    my %si_scales = (
        ''  =>  1,
        map {
            my $s = $si[$_];
            (
                $s      => 1E3 ** -$_,
                $s.'i'  => ldexp(1, -$_*10),
            )
        } 1 .. $#si
    );
    $si_scales{μ}  = $si_scales{u}  = $si_scales{µ};
    $si_scales{μi} = $si_scales{ui} = $si_scales{µi};
    my $sir = join '|', keys @si_scales;
    $sir = qr[$sir];
    sub SJ($;$$) {
        my $r = \$_[0];
        my $d = $_[1] || 1;
        my $t = $_[2] || qr/sec\w*|se|s/;
        $d = $si{lc $d} || $d;
        sub {
            warn Dumper("SI:", \@_);
            my $v = shift;
            my $s = $d;
            if ($v =~ s/\D+$//) {
                $s = lc $&;
                $s =~ s/$t$//;  # trim off 'seconds', etc
                $s = $si{$s} // die "Invalid scale '$s'\n";
            }
            $$r = $v * $s;
        }
    }
    push @EXPORT_OK, 'SJ';
}

1;
