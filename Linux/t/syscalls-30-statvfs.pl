#!/usr/bin/perl

use 5.008;
use strict;
use warnings;

use POSIX;

#require "syscall.ph";
BEGIN { require 'asm/unistd_32.ph' };

package Linux::Syscalls::test::fs::base {
sub ok { not ! shift->kern }
sub st {
    my $self = shift;
    my ($path) = @_;
    my $kern = $self->kern || return;
    $! = 0;
    my $res = "\0" x $self->size;
    syscall( $kern, $path, $res ) == -1 && $! and die $!;
    $res;
}
use constant size => 4096;
use constant kern => undef;
}

package Linux::Syscalls::test::fs::statfs    {}
package Linux::Syscalls::test::fs::statfs64  {}
package Linux::Syscalls::test::fs::statvfs   {}
package Linux::Syscalls::test::fs::statvfs64 {}

{
my @S;

BEGIN {

@S = qw(
        fstatfs fstatfs64
        statfs  statfs64
       );

for my $s (@S) {
    my $p = 'Linux::Syscalls::test::fs::'.$s;
    my $k = '__NR_'.$s;
    my $kk = eval "exists &$k && $k()" // 0;
    #my $kk = eval "exists &$k" ? eval "$k()" : 0;
    my $s = $p =~ /64/ ? 128 : 64;

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

for my $argv (@ARGV) {
    eval {
        my $res = Linux::Syscalls::test::fs::statfs::->st($argv);
    #   $res =~ s/(?:\0\0\0\0)+$//;
        printf STDERR "statfs [%s]\n", unpack "H*", $res;
        my @R = unpack "L*", $res;
        my $type = shift @R;
        my $bsize1 = shift @R;
        my $btotal = shift @R;
        my $bfree  = shift @R;
        my $bavail = shift @R;
        my $itotal = shift @R;
        my $ifree  = shift @R;
        my @r = splice @R, 0, 0;
        my @fsid = splice @R, 0, 2;
        my $maxnamlen = shift @R;
        my $bsize2 = shift @R;
        my $iavail = $ifree - shift @R;  # might not be anything there?
        @R == 0 or warn "Remaining junk after 11th item for $argv\n";
        printf "%s: type=%#x, maxlen=%u, blocks=[size=%u/%u, total=%u, free=%u, avail=%u], inodes=[total=%u, free=%u, avail=%u], fsid=%#x:%#x, r=[%s]; len=%u\n",
                $argv, $type, $maxnamlen,
                $bsize1, $bsize2,
                $btotal, $bfree, $bavail,
                $itotal, $ifree, $iavail,
                @fsid, "@r",
                length($res);
        1;
    } or
        warn "statfs $argv: $!\n" if Linux::Syscalls::test::fs::statfs::->ok;

    eval {
        my $res = Linux::Syscalls::test::fs::statfs64::->st($argv);
        printf STDERR "statfs64 [%s]\n", unpack "H*", $res;
        $res =~ s/(?:\0\0\0\0)+$//;
        my ($type, @r) = unpack "L*", $res;
        print "$argv: type=$type, r=[@r]\n";
        1;
    } or
        warn "statfs64 $argv: $!\n"
        if Linux::Syscalls::test::fs::statfs64::->ok;

    eval {
        my $res = Linux::Syscalls::test::fs::statvfs::->st($argv);
        printf STDERR "statvfs [%s]\n", unpack "H*", $res;
        $res =~ s/(?:\0\0\0\0)+$//;
        my ($type, @r) = unpack "L*", $res;
        print "$argv: type=$type, r=[@r]\n";
        1;
    } or
        warn "statvfs $argv: $!\n"
        if Linux::Syscalls::test::fs::statvfs::->ok;

    eval {
        my $res = Linux::Syscalls::test::fs::statvfs64::->st($argv);
        printf STDERR "statvfs64 [%s]\n", unpack "H*", $res;
        $res =~ s/(?:\0\0\0\0)+$//;
        my ($type, @r) = unpack "L*", $res;
        print "$argv: type=$type, r=[@r]\n";
        1;
    } or
        warn "statvfs64 $argv: $!\n"
        if Linux::Syscalls::test::fs::statvfs64::->ok;
}

1;
