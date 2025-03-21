#!/module/for/perl

use 5.010;
use strict;
use warnings;

#
# Linux-specific extensions to <sys/socket.h>, in particular
# AF_NETLINK.
#
# Also, a map that will show the name given an address or protocol family number.
#
# Because these are over-the-wire values that are shared everywhere, there's no
# need for hosttype-specific versions of this file.
#

package Linux::Socket::Extras v0.0.1;

use Exporter 'import';


# Most of the AF_* names are actually provided by «use Socket;» (which gets
# them from <linux/bits/socket.h>) so we only need to add this reverse
# mapping and the exceptions that Socket doesn't know about.

use constant {
    AF_NETLINK              =>  16,
    PF_NETLINK              =>  16, # synonym

    SO_SNDBUF               =>   7,
    SO_RCVBUF               =>   8,

    SOL_SOCKET              =>   1,
    SOL_NETLINK             => 270,
};

my @af_names = qw(
    unspec local inet ax25 ipx appletalk netrom bridge atmpvc x25 inet6 rose
    decnet netbeui security key netlink packet ash econet atmsvc rds sna irda
    pppox wanpipe llc ib mpls can tipc bluetooth iucv rxrpc isdn phonet
    ieee802154 caif alg nfc vsock max
);
sub AF_to_name($) { my ($c) = @_; my $n = $af_names[$c] if $c >= 0; return $n // "code#$c"; }
sub PF_to_name($);

*PF_to_name = \&AF_to_name;     # same map, same code

our %EXPORT_TAGS = (
    all     => [qw[
        AF_NETLINK
        AF_to_name
        PF_NETLINK
        PF_to_name
        SOL_NETLINK
        SOL_SOCKET
        SO_RCVBUF
        SO_SNDBUF
    ]],

    af      => [qw[ AF_NETLINK AF_to_name ]],
    pf      => [qw[ PF_NETLINK PF_to_name ]],
    netlink => [qw[ AF_NETLINK PF_NETLINK ]],
    so      => [qw[ SO_SNDBUF SO_RCVBUF ]],
    sol     => [qw[ SOL_SOCKET SOL_NETLINK ]],
);

my %seen;
our @EXPORT_OK = grep { ! $seen{$_} }
                    map { @$_ } values %EXPORT_TAGS;

$EXPORT_TAGS{ALL} = \@EXPORT_OK;

1;
