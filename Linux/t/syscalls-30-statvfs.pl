#!/usr/bin/perl

use 5.008;
use strict;
use warnings;

# Note: there are no *statvfs syscalls in Linux; rather, those are provided by
# libc, using the corresponding *statfs syscall instead.

use POSIX;

#require "syscall.ph";
#BEGIN { require 'asm/unistd_32.ph' };
BEGIN { require 'asm/unistd.ph' };

package Linux::Syscalls::test::fs::base {
sub ok { not ! shift->kern }
sub st {
    my $self = shift;
    my ($path) = @_;
    my $kern = $self->kern || return;
    my $pfmt = $self->pfmt || return;
    $! = 0;
    my $res = pack $pfmt, (0) x 32;
    warn sprintf "Trying syscall %u with %u-byte buffer",  $kern, length($res);
    syscall( $kern, $path, $res ) == -1 && $! and die $!;
    return unpack $pfmt.'C*', $res if wantarray;
    return $res;
}
#use constant size => 0x100;
use constant size => 0x100;
use constant kern => undef;

use Config;
my ($arch_hw, $arch_os, undef) = split '-', $Config{archname};
my $arch_m64 = $Config{use64bitint} && 1 || 0;

# Note: Debian for MIPS is compiled as MIPSel-o32, meaning
#   1. little endian
#   2. 32-bit registers are used to pass values in and out of the kernel
#   3. 32-bit address space.
# So always assume 32-bit for mipsel.
my $short = $arch_hw eq 'mipsel'; # && ! $arch_m64;
my $pfmt_word   = $short ? 'L'  : 'Q';
my $pfmt_bcount = $short ? 'L'  : 'Q';
my $pfmt_fsid   = $short ? 'i2' : 'i2';

eval qq{
    use constant {
        pfmt_word   => '$pfmt_word',
        pfmt_bcount => '$pfmt_bcount',
        pfmt_fsid   => '$pfmt_fsid',
    };
};

sub pfmt {
    my ($st) = @_;
  # return 'L2Q5i2L3L4'
    my $w = $st->pfmt_word;
    my $b = $st->pfmt_bcount;
    my $f = $st->pfmt_fsid;
    return $w.'2'.$b.'5'.$f.$w.'3'.$w.'4';
}
}

package Linux::Syscalls::test::fs::fstatfs   {}
package Linux::Syscalls::test::fs::fstatfs64 {}
package Linux::Syscalls::test::fs::statfs    {}
package Linux::Syscalls::test::fs::statfs64  {}

{
my @S;

BEGIN {

@S = qw(
        fstatfs
        fstatfs64
        statfs
        statfs64

        newstatfs
        oldstatfs
        statfs32
       );

for my $s (@S) {
    my $p = 'Linux::Syscalls::test::fs::'.$s;
    my $k = '__NR_'.$s;
    my $kk = eval "exists &$k && $k()" // 0;
    #my $kk = eval "exists &$k" ? eval "$k()" : 0;
    my $s = $p =~ /32/ ? 64 : 128;

    eval qq{
        package $p;
        our \@ISA = Linux::Syscalls::test::fs::base::;
    };
    eval qq{
        package $p;
        use constant kern => $kk;
        use constant size => $s;
    } if $kk;
}
}

for my $t (@S) {
    printf " -> %5s %s\n", "Linux::Syscalls::test::fs::$t"->ok ? " CAN " : "can't", $t;
}
}

sub hunp {
    my $ures = unpack "H*", shift;
    $ures =~ s/(.{8})(.{1,8})/$1 $2  /g;
    $ures =~ s/ *$//;
    return $ures;
}

for my $argv (@ARGV) {

    print $argv, "\n";

    eval {
        my $pfmt = Linux::Syscalls::test::fs::statfs::->pfmt;
        my $res = Linux::Syscalls::test::fs::statfs::->st($argv);
    #   $res =~ s/(?:\0\0\0\0)+$//;

        printf STDERR " statfs len=%u hex=[%s]\n", length($res), hunp $res;
        printf STDERR "        unpack=[%s]\n", $pfmt;

        my ($type, $bsize1, $btotal, $bfree, $bavail, $itotal, $ifree, $fsid0,
            $fsid1, $maxnamlen, $bsize2, @R) = unpack $pfmt.'Q*', $res;

        my $iavail = $ifree - shift @R;  # might not be anything there?
        @R == 0 or warn sprintf "Remaining %u junk data points after bsize2 path=%s\n", 0+@R, $argv;

        printf "\ttype=%#x, maxlen=%u,\n"
              ."\tblocks=[size=%u/%u, total=%u, free=%u, avail=%u],\n"
              ."\tinodes=[total=%u, free=%u, avail=%u],\n"
              ."\tfsid=%#x:%#x,\n"
              ."\tr=[%s]\n",
                $type, $maxnamlen,
                $bsize1, $bsize2,
                $btotal, $bfree, $bavail,
                $itotal, $ifree, $iavail,
                $fsid0, $fsid1, join ',', @R;
        1;
    } or warn " statfs FAILED $! $@\n"
        if Linux::Syscalls::test::fs::statfs::->ok;

    eval {
        my $pfmt = Linux::Syscalls::test::fs::statfs64::->pfmt;
        my $res = Linux::Syscalls::test::fs::statfs64::->st($argv);
        printf STDERR " statfs64 len=%u, hex=[%s]\n", length($res), hunp $res;
        $res =~ s/(?:\0\0\0\0)+$//;
        my ($type, @r) = unpack "L*", $res;

        print "$argv: type=$type, r=[@r]\n";

        1;
    } or
        warn "statfs64 $argv: $!\n"
        if Linux::Syscalls::test::fs::statfs64::->ok;

}

1;
