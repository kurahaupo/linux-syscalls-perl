#!/usr/bin/perl

use 5.008;
use strict;
use warnings;

use POSIX;

#require "syscall.ph";
BEGIN { require 'asm/unistd_32.ph' };

{
package FS::base;
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
#use constant size => undef;
use constant kern => undef;

}

my @S;

BEGIN {

@S = qw( fork
            fstatfs fstatfs64
            statfs  statfs64
            statvfs statvfs64 );

for my $s (@S) {
    my $p = 'FS::'.$s;
    my $k = '__NR_'.$s;
    my $kk = eval "exists &$k && $k()" // 0;
    #my $kk = eval "exists &$k" ? eval "$k()" : 0;
    my $s = $p =~ /64/ ? 128 : 64;

#   warn sprintf "Checking %-32s %-32s %s\n", $p, $k, $kk;

    eval qq{
        package $p;
        our \@ISA = FS::base::;
    };
    eval qq{
        package $p;
        use constant kern => $kk;
        use constant size => $s;
    } if $kk;
#   eval qq{
#       package $p;
#   };
}
}

#   package FS::fork;
#   our @ISA = FS::base::;
#   use constant kern => ::__NR_fork()    || warn( "Can't ::__NR_fork" ) && 0;
#   use constant size => 64;

#   package FS::statfs;
#   our @ISA = FS::base::;
#   use constant kern => ::__NR_statfs()    || warn( "Can't ::__NR_statfs" ) && 0;
#   use constant size => 64;

#   package FS::statfs64;
#   our @ISA = FS::base::;
#   use constant kern => ::__NR_statfs64()  || warn( "Can't ::__NR_statfs64" ) && 0;
#   use constant size => 128;

#   package FS::statvfs;
#   our @ISA = FS::base::;
#   use constant kern => ::__NR_statvfs()   || warn( "Can't ::__NR_statvfs" ) && 0;
#   use constant size => 128;

#   package FS::statvfs64;
#   our @ISA = FS::base::;
#   use constant kern => ::__NR_statvfs64() || warn( "Can't ::__NR_statvfs64" ) && 0;
#   use constant size => 128;

for my $t (@S) {
    print " -> ", "FS::$t"->ok ? " CAN " : "can't", " $t\n";
}

for my $argv (@ARGV) {
    eval {
        my $res = FS::statfs::->st($argv);
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
        warn "statfs $argv: $!\n" if FS::statfs->ok;

    eval {
        my $res = FS::statfs64::->st($argv);
        printf STDERR "statfs64 [%s]\n", unpack "H*", $res;
        $res =~ s/(?:\0\0\0\0)+$//;
        my ($type, @r) = unpack "L*", $res;
        print "$argv: type=$type, r=[@r]\n";
        1;
    } or
        warn "statfs64 $argv: $!\n"
        if FS::statfs64->ok;

    eval {
        my $res = FS::statvfs::->st($argv);
        printf STDERR "statvfs [%s]\n", unpack "H*", $res;
        $res =~ s/(?:\0\0\0\0)+$//;
        my ($type, @r) = unpack "L*", $res;
        print "$argv: type=$type, r=[@r]\n";
        1;
    } or
        warn "statvfs $argv: $!\n"
        if FS::statvfs->ok;

    eval {
        my $res = FS::statvfs64::->st($argv);
        printf STDERR "statvfs64 [%s]\n", unpack "H*", $res;
        $res =~ s/(?:\0\0\0\0)+$//;
        my ($type, @r) = unpack "L*", $res;
        print "$argv: type=$type, r=[@r]\n";
        1;
    } or
        warn "statvfs64 $argv: $!\n"
        if FS::statvfs64->ok;
}

1;
