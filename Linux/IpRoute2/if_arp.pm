#!/module/for/perl

use v5.10;
use strict;
use warnings;

package Linux::IpRoute2::if_arp v0.0.1;

# Copied and adapted from <linux/if_arp.h>
#             /usr/include/linux/if_arp.h
#  [iproute2]/include/uapi/linux/if_arp.h

use Exporter 'import';

use Linux::Syscalls ();

sub _B($) { 1 << pop }

## ARP protocol HARDWARE identifiers.
use constant {
    ARPHRD_NETROM                       =>     0,       # from KA9Q: NET/ROM pseudo
    ARPHRD_ETHER                        =>     1,       # Ethernet 10Mbps
    ARPHRD_EETHER                       =>     2,       # Experimental Ethernet
    ARPHRD_AX25                         =>     3,       # AX.25 Level 2
    ARPHRD_PRONET                       =>     4,       # PROnet token ring
    ARPHRD_CHAOS                        =>     5,       # Chaosnet
    ARPHRD_IEEE802                      =>     6,       # IEEE 802.2 Ethernet/TR/TB
    ARPHRD_ARCNET                       =>     7,       # ARCnet
    ARPHRD_APPLETLK                     =>     8,       # APPLEtalk
    ARPHRD_DLCI                         =>    15,       # Frame Relay DLCI
    ARPHRD_ATM                          =>    19,       # ATM
    ARPHRD_METRICOM                     =>    23,       # Metricom STRIP (new IANA id)
    ARPHRD_IEEE1394                     =>    24,       # IEEE 1394 IPv4 - RFC 2734
    ARPHRD_EUI64                        =>    27,       # EUI-64
    ARPHRD_INFINIBAND                   =>    32,       # InfiniBand

    ## Dummy types for non ARP hardware
    ARPHRD_SLIP                         =>   256,
    ARPHRD_CSLIP                        =>   257,
    ARPHRD_SLIP6                        =>   258,
    ARPHRD_CSLIP6                       =>   259,
    ARPHRD_RSRVD                        =>   260,       # Notional KISS type
    ARPHRD_ADAPT                        =>   264,
    ARPHRD_ROSE                         =>   270,
    ARPHRD_X25                          =>   271,       # CCITT X.25
    ARPHRD_HWX25                        =>   272,       # Boards with X.25 in firmware
    ARPHRD_CAN                          =>   280,       # Controller Area Network
    ARPHRD_MCTP                         =>   290,
    ARPHRD_PPP                          =>   512,
    ARPHRD_CISCO                        =>   513,       # Cisco HDLC
    ARPHRD_HDLC                         =>   513,   # == ARPHRD_CISCO,
    ARPHRD_LAPB                         =>   516,       # LAPB
    ARPHRD_DDCMP                        =>   517,       # Digital's DDCMP protocol
    ARPHRD_RAWHDLC                      =>   518,       # Raw HDLC
    ARPHRD_RAWIP                        =>   519,       # Raw IP

    ARPHRD_TUNNEL                       =>   768,       # IPIP tunnel
    ARPHRD_TUNNEL6                      =>   769,       # IP6IP6 tunnel
    ARPHRD_FRAD                         =>   770,       # Frame Relay Access Device
    ARPHRD_SKIP                         =>   771,       # SKIP vif
    ARPHRD_LOOPBACK                     =>   772,       # Loopback device
    ARPHRD_LOCALTLK                     =>   773,       # Localtalk device
    ARPHRD_FDDI                         =>   774,       # Fiber Distributed Data Interface
    ARPHRD_BIF                          =>   775,       # AP1000 BIF
    ARPHRD_SIT                          =>   776,       # sit0 device - IPv6-in-IPv4
    ARPHRD_IPDDP                        =>   777,       # IP over DDP tunneller
    ARPHRD_IPGRE                        =>   778,       # GRE over IP
    ARPHRD_PIMREG                       =>   779,       # PIMSM register interface
    ARPHRD_HIPPI                        =>   780,       # High Performance Parallel Interface
    ARPHRD_ASH                          =>   781,       # Nexus 64Mbps Ash
    ARPHRD_ECONET                       =>   782,       # Acorn Econet
    ARPHRD_IRDA                         =>   783,       # Linux-IrDA

    ## ARP works differently on different FC media .. so
    ARPHRD_FCPP                         =>   784,       # Point to point fibrechannel
    ARPHRD_FCAL                         =>   785,       # Fibrechannel arbitrated loop
    ARPHRD_FCPL                         =>   786,       # Fibrechannel public loop
    ARPHRD_FCFABRIC                     =>   787,       # Fibrechannel fabric
                                        ##   787..799 reserved for fibrechannel media types
    ARPHRD_IEEE802_TR                   =>   800,       # Magic type ident for TR
    ARPHRD_IEEE80211                    =>   801,       # IEEE 802.11
    ARPHRD_IEEE80211_PRISM              =>   802,       # IEEE 802.11 + Prism2 header
    ARPHRD_IEEE80211_RADIOTAP           =>   803,       # IEEE 802.11 + radiotap header
    ARPHRD_IEEE802154                   =>   804,
    ARPHRD_IEEE802154_MONITOR           =>   805,       # IEEE 802.15.4 network monitor

    ARPHRD_PHONET                       =>   820,       # PhoNet media type
    ARPHRD_PHONET_PIPE                  =>   821,       # PhoNet pipe header
    ARPHRD_CAIF                         =>   822,       # CAIF media type
    ARPHRD_IP6GRE                       =>   823,       # GRE over IPv6
    ARPHRD_NETLINK                      =>   824,       # Netlink header
    ARPHRD_6LOWPAN                      =>   825,       # IPv6 over LoWPAN
    ARPHRD_VSOCKMON                     =>   826,       # Vsock monitor header

    ARPHRD_NONE                         => 0xfffe,      # zero header length
    ARPHRD_VOID                         => 0xffff,      # Void type, nothing is known
};

{
my @names;
$names[eval 'ARPHRD_'.uc $_] = $_ for qw(
    netrom ether eether ax25 pronet chaos ieee802 arcnet appletlk dlci atm
    metricom ieee1394 eui64 infiniband slip cslip slip6 cslip6 rsrvd adapt rose
    x25 hwx25 can mctp ppp hdlc lapb ddcmp rawhdlc rawip tunnel tunnel6 frad
    skip loopback localtlk fddi bif sit ipddp ipgre pimreg hippi ash econet
    irda fcpp fcal fcpl fcfabric ieee802_tr ieee80211 ieee80211_prism
    ieee80211_radiotap ieee802154 ieee802154_monitor phonet phonet_pipe caif
    ip6gre netlink 6lowpan vsockmon none void
);
sub ARPHRD_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub ARPHRD_to_name($) { return &ARPHRD_to_label // "code#$_[0]" }
}

## ARP protocol opcodes.
use constant {
    ARPOP_REQUEST                       =>    1,        # ARP request
    ARPOP_REPLY                         =>    2,        # ARP reply
    ARPOP_RREQUEST                      =>    3,        # RARP request
    ARPOP_RREPLY                        =>    4,        # RARP reply
    ARPOP_InREQUEST                     =>    8,        # InARP request
    ARPOP_InREPLY                       =>    9,        # InARP reply
    ARPOP_NAK                           =>   10,        # (ATM)ARP NAK
};

{
my @names = (undef, qw(
    request
    reply
    rrequest
    rreply ), (undef) x 3, qw(
    inrequest
    inreply
    nak )
);
sub ARPOP_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub ARPOP_to_name($) { return &ARPOP_to_label // "code#$_[0]" }
}

    ## ARP ioctl request.
    #   struct arpreq {
    #       struct sockaddr     arp_pa;         # protocol address
    #       struct sockaddr     arp_ha;         # hardware address
    #       int                 arp_flags;      # flags
    #       struct sockaddr     arp_netmask;    # netmask (only for proxy arps)
    #       char                arp_dev[IFNAMSIZ];
    #   };

    ## old ARP ioctl request.
    #   struct arpreq_old {
    #       struct sockaddr     arp_pa;         # protocol address
    #       struct sockaddr     arp_ha;         # hardware address
    #       int                 arp_flags;      # flags
    #       struct sockaddr     arp_netmask;    # netmask (only for proxy arps)
    #   };

## ARP Flag values.
use constant {
    ATF_COM                             =>  _B 1,   # 0x02  completed entry (ha valid)
    ATF_PERM                            =>  _B 2,   # 0x04  permanent entry
    ATF_PUBL                            =>  _B 3,   # 0x08  publish entry
    ATF_USETRAILERS                     =>  _B 4,   # 0x10  has requested trailers
    ATF_NETMASK                         =>  _B 5,   # 0x20  want to use a netmask (only for proxy entries)
    ATF_DONTPUB                         =>  _B 6,   # 0x40  don't answer this addresses
};

{
my @names = (undef, qw( com perm publ usetrailers netmask dontpub ));
sub ATF_to_desc($) {
    splice @_, 1, 0, \@names;
    goto &Linux::Syscalls::_bits_to_desc;
}
}

##
##  This structure defines an ethernet arp header.
##

use constant {
    struct_arphdr_pack                  => 'nnCCn',
    struct_arphdr_len                   =>     8,
};

    #   struct arphdr {
    #       __be16              ar_hrd;         # format of hardware address
    #       __be16              ar_pro;         # format of protocol address
    #       unsigned char       ar_hln;         # length of hardware address
    #       unsigned char       ar_pln;         # length of protocol address
    #       __be16              ar_op;          # ARP opcode (command)
    #

# The following are not based <linux/if_arp.h> but rather are synthesized to
# perform what C cannot do.

# struct for 8-bit MAC addresses
use constant {
    struct_arpdata8_pack                => '(a1a4)2',
    struct_arpdata8_len                 =>    10,
};
# struct for 16-bit MAC addresses
use constant {
    struct_arpdata16_pack               => '(a2a4)2',
    struct_arpdata16_len                =>    12,
};
# struct for 32-bit MAC addresses
use constant {
    struct_arpdata32_pack               => '(a4a4)2',
    struct_arpdata32_len                =>    16,
};
# struct for 48-bit MAC addresses ← THIS IS STANDARD for Ethernet and WiFi
use constant {
    struct_arpdata48_pack               => '(a6a4)2',
    struct_arpdata48_len                =>    20,
};
# struct for 64-bit MAC addresses
use constant {
    struct_arpdata64_pack               => '(a8a4)2',
    struct_arpdata64_len                =>    24,
};

    #   # Ethernet looks somewhat like this, except ETH_ALEN is not a constant
    #   struct arpdata {
    #       unsigned char               ar_sha[ETH_ALEN];       ## sender hardware address
    #       unsigned char               ar_sip[4];              ## sender IP address
    #       unsigned char               ar_tha[ETH_ALEN];       ## target hardware address
    #       unsigned char               ar_tip[4];              ## target IP address
    #   };

our %EXPORT_TAGS = (
    arphrd => [qw[
        ARPHRD_6LOWPAN
        ARPHRD_ADAPT
        ARPHRD_APPLETLK
        ARPHRD_ARCNET
        ARPHRD_ASH
        ARPHRD_ATM
        ARPHRD_AX25
        ARPHRD_BIF
        ARPHRD_CAIF
        ARPHRD_CAN
        ARPHRD_CHAOS
        ARPHRD_CSLIP
        ARPHRD_CSLIP6
        ARPHRD_DDCMP
        ARPHRD_DLCI
        ARPHRD_ECONET
        ARPHRD_EETHER
        ARPHRD_ETHER
        ARPHRD_EUI64
        ARPHRD_FCAL
        ARPHRD_FCFABRIC
        ARPHRD_FCPL
        ARPHRD_FCPP
        ARPHRD_FDDI
        ARPHRD_FRAD
        ARPHRD_HDLC
        ARPHRD_HIPPI
        ARPHRD_HWX25
        ARPHRD_IEEE1394
        ARPHRD_IEEE802
        ARPHRD_IEEE80211
        ARPHRD_IEEE80211_PRISM
        ARPHRD_IEEE80211_RADIOTAP
        ARPHRD_IEEE802154
        ARPHRD_IEEE802154_MONITOR
        ARPHRD_IEEE802_TR
        ARPHRD_INFINIBAND
        ARPHRD_IP6GRE
        ARPHRD_IPDDP
        ARPHRD_IPGRE
        ARPHRD_IRDA
        ARPHRD_LAPB
        ARPHRD_LOCALTLK
        ARPHRD_LOOPBACK
        ARPHRD_MCTP
        ARPHRD_METRICOM
        ARPHRD_NETLINK
        ARPHRD_NETROM
        ARPHRD_NONE
        ARPHRD_PHONET
        ARPHRD_PHONET_PIPE
        ARPHRD_PIMREG
        ARPHRD_PPP
        ARPHRD_PRONET
        ARPHRD_RAWHDLC
        ARPHRD_RAWIP
        ARPHRD_ROSE
        ARPHRD_RSRVD
        ARPHRD_SIT
        ARPHRD_SKIP
        ARPHRD_SLIP
        ARPHRD_SLIP6
        ARPHRD_TUNNEL
        ARPHRD_TUNNEL6
        ARPHRD_VOID
        ARPHRD_VSOCKMON
        ARPHRD_X25
        ARPHRD_to_label
        ARPHRD_to_name
    ]],
    arpop => [qw[
        ARPOP_InREPLY
        ARPOP_InREQUEST
        ARPOP_NAK
        ARPOP_REPLY
        ARPOP_REQUEST
        ARPOP_RREPLY
        ARPOP_RREQUEST
        ARPOP_to_label
        ARPOP_to_name
    ]],
    atf => [qw[
        ATF_COM
        ATF_PERM
        ATF_PUBL
        ATF_USETRAILERS
        ATF_NETMASK
        ATF_DONTPUB
        ATF_to_desc
    ]],
    pack => [qw[
        struct_arphdr_pack
        struct_arphdr_len

        struct_arpdata16_len
        struct_arpdata16_pack
        struct_arpdata32_len
        struct_arpdata32_pack
        struct_arpdata48_len
        struct_arpdata48_pack
        struct_arpdata64_len
        struct_arpdata64_pack
        struct_arpdata8_len
        struct_arpdata8_pack
    ]],
);

my @export_compat = qw(
    ARPHRD_CISCO
);

my %seen;
our @EXPORT_OK = grep { ! $seen{$_}++ }
                    @export_compat,
                    map { @$_ } values %EXPORT_TAGS;

$EXPORT_TAGS{ALL} = \@EXPORT_OK;

1;
