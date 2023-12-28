#!/usr/bin/perl

use 5.008;
use strict;
use warnings;

# Note: there are no *statvfs syscalls in Linux; rather, those are provided by
# libc, using the corresponding *statfs syscall instead.

use POSIX;

use constant {
    DFM_DUMP    => 0,
    DFM_BLOCKS  => 1,
    DFM_INODES  => 2,
    DFM_BOTH    => 3,
};

my $df_mode = DFM_BOTH;
my $debug = 1;

use Getopt::Long qw( :config bundling );
sub S(\$$) { my ($r, $v) = @_; return sub { $$r = $v } }
GetOptions
    'd|dump'    => S($df_mode,DFM_DUMP),
    'i|inodes'  => S($df_mode,DFM_INODES),
    'b|blocks'  => S($df_mode,DFM_BLOCKS),
    '2|both'    => S($df_mode,DFM_BOTH),
    'x|debug'   => S($debug, 1),
    'q|quiet'   => S($debug, 0),
    'h|help'    => sub { print <<EndOfHelp }, or exit 64;
$0 [options]
    -d --dump
    -i --inodes
    -b --blocks
    -2 --both
EndOfHelp

use Config;
my ($arch_hw, $arch_os, undef) = split '-', $Config{archname};
my $arch_m64 = $Config{use64bitint} && 1 || 0;

# Note: Debian for MIPS is compiled as MIPSel-o32, meaning
#   1. little endian
#   2. 32-bit registers are used to pass values in and out of the kernel
#   3. 32-bit address space.
# So always assume 32-bit for mipsel.
my $small = $arch_hw eq 'mipsel'; # && ! $arch_m64;

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
    warn sprintf "Trying syscall %u with %u-byte buffer",  $kern, length($res)
        if $debug;
    syscall( $kern, $path, $res ) == -1 && $! and die $!;
    return unpack $pfmt.'Q*', $res if wantarray;
    return $res;
}
#use constant size => 0x100;
use constant size => 0x100;
use constant kern => undef;

my $pfmt_word   = $small ? 'L'  : 'Q';
my $pfmt_bcount = $small ? 'L'  : 'Q';
my $pfmt_fsid   = $small ? 'I2' : 'I2';

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

my @S;

@S = qw(
        fstatfs
        fstatfs64
        statfs
        statfs64

        _oldoldstatfs
        _oldstatfs
        newstatfs
        oldoldstatfs
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
    } if $kk;
}

if ($debug) {
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

    print $argv, "\n" if ! $df_mode;

    for my $syscall ( @S ) {

        $syscall =~ /^f/ and next;

        my $cpkg = "Linux::Syscalls::test::fs::${syscall}::";

        exists &{$cpkg.'kern'} or next;

        my $pkg = eval $cpkg or die "Can't eval $cpkg";

        $pkg->ok or next;

        my $pfmt = $pkg->pfmt;
        my $res = eval {
            $pkg->st($argv);
        } or do { warn " $syscall FAILED $@\n\t$!"; next };

        my ($type,
            $bsize, $btotal, $bfree, $bavail,
            $itotal, $ifree,
            $fsid0, $fsid1, $maxnamlen, $io_size,
            undef, undef, undef, undef, @R) = unpack $pfmt.'Q*', $res;

        #my $iavail = $ifree;    # no reserved inodes, so not separate

        @R == 0 or warn sprintf "Remaining %u junk data points after io_size\n", 0+@R;

        if (! $df_mode || $debug) {

            printf " %-14s len=%u hex=[%s]\n", $syscall, length($res), hunp $res;
            my @ux = unpack $small ? 'L*' : 'Q*', $res;
            for my $i ( 0 .. $#ux ) {
                printf "\t\t%6u:\t%-14u (%#x)\n", $i, $ux[$i], $ux[$i]

            }
            printf "\t\tunpack=[%s]\n", $pfmt;
            printf "\t\ttype=%#x,\n"
                  ."\t\tblocks=[size=%u, total=%u, free=%u, avail=%u],\n"
                  ."\t\tinodes=[total=%u, free=%u],\n"
                  ."\t\tfsid=%#x:%#x, maxlen=%u, io_size=%u,\n"
                  ."\t\tr=[%s]\n",
                    $type,
                    $bsize,
                    $btotal, $bfree, $bavail,
                    $itotal, $ifree,
                    $fsid0, $fsid1, $maxnamlen, $io_size, join ',', @R;
        }

        $_ *= $bsize || 1 for $btotal, $bfree, $bavail;
        #Filesystem           1K-blocks      Used Available Use% Mounted on
        #overlay                 220080    137752     77492  64% /
        printf "%-20s %9u %9u %9u %6.2f%% %s\n",
            "TYPE#$type",
            $btotal/1024, ($btotal - $bfree)/1024, $bfree/1024,
            100 - 100*$bavail/$btotal,
            $argv,
            if $df_mode & DFM_BLOCKS;
        #Filesystem              Inodes      Used Available Use% Mounted on
        #overlay                      0         0         0   0% /
        printf "%-20s %9u %9u %9u %6.2f%% %s\n",
            "TYPE#$type",
            $itotal, $itotal - $ifree, $ifree,
            100 - ($itotal ? 100*$ifree/$itotal : 100),
            $argv,
            if $df_mode & DFM_INODES;



    }

    print "\n";
}

1;
