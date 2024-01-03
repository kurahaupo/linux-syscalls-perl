#!/module/for/perl

use 5.010;
use strict;
use warnings;

package Linux::IpRoute2::rtnetlink v0.0.1;

# Copied and adapted from /usr/include/linux/rtnetlink.h

use constant {
    RTNL_FAMILY_IPMR    => 128,
    RTNL_FAMILY_IP6MR   => 129,
  # RTNL_FAMILY_MAX     => 129 | 0,
};

use constant {
  # RTM_BASE            =>  16,

    RTM_NEWLINK         =>  16,
    RTM_DELLINK         =>  17,
    RTM_GETLINK         =>  18,
    RTM_SETLINK         =>  19,
    RTM_NEWADDR         =>  20,
    RTM_DELADDR         =>  21,
    RTM_GETADDR         =>  22,
    RTM_NEWROUTE        =>  24,
    RTM_DELROUTE        =>  25,
    RTM_GETROUTE        =>  26,
    RTM_NEWNEIGH        =>  28,
    RTM_DELNEIGH        =>  29,
    RTM_GETNEIGH        =>  30,
    RTM_NEWRULE         =>  32,
    RTM_DELRULE         =>  33,
    RTM_GETRULE         =>  34,
    RTM_NEWQDISC        =>  36,
    RTM_DELQDISC        =>  37,
    RTM_GETQDISC        =>  38,
    RTM_NEWTCLASS       =>  40,
    RTM_DELTCLASS       =>  41,
    RTM_GETTCLASS       =>  42,
    RTM_NEWTFILTER      =>  44,
    RTM_DELTFILTER      =>  45,
    RTM_GETTFILTER      =>  46,
    RTM_NEWACTION       =>  48,
    RTM_DELACTION       =>  49,
    RTM_GETACTION       =>  50,
    RTM_NEWPREFIX       =>  52,
    RTM_GETMULTICAST    =>  58,
    RTM_GETANYCAST      =>  62,
    RTM_NEWNEIGHTBL     =>  64,
    RTM_GETNEIGHTBL     =>  66,
    RTM_SETNEIGHTBL     =>  67,
    RTM_NEWNDUSEROPT    =>  68,
    RTM_NEWADDRLABEL    =>  72,
    RTM_DELADDRLABEL    =>  73,
    RTM_GETADDRLABEL    =>  74,
    RTM_GETDCB          =>  78,
    RTM_SETDCB          =>  79,
    RTM_NEWNETCONF      =>  80,
    RTM_GETNETCONF      =>  82,
    RTM_NEWMDB          =>  84,
    RTM_DELMDB          =>  85,
    RTM_GETMDB          =>  86,
    RTM_NEWNSID         =>  88,
    RTM_DELNSID         =>  89,
    RTM_GETNSID         =>  90,

  # RTM_MAX             =>  90 | 3, # max, rounded up
};

use constant {
    RTN_UNSPEC          =>   0,
    RTN_UNICAST         =>   1,     # Gateway or direct route
    RTN_LOCAL           =>   2,     # Accept locally
    RTN_BROADCAST       =>   3,     # Accept locally as broadcast, send as broadcast
    RTN_ANYCAST         =>   4,     # Accept locally as broadcast, but send as unicast
    RTN_MULTICAST       =>   5,     # Multicast route
    RTN_BLACKHOLE       =>   6,     # Drop
    RTN_UNREACHABLE     =>   7,     # Destination is unreachable
    RTN_PROHIBIT        =>   8,     # Administratively prohibited
    RTN_THROW           =>   9,     # Not in this table
    RTN_NAT             =>  10,     # Translate this address
    RTN_XRESOLVE        =>  11,     # Use external resolver

  # RTN_MAX             =>  11 | 1, # max, rounded up
};

## rtm_protocol
use constant {

    RTPROT_UNSPEC       =>   0,
    RTPROT_REDIRECT     =>   1,     # Route installed by ICMP redirects; not used by current IPv4
    RTPROT_KERNEL       =>   2,     # Route installed by kernel
    RTPROT_BOOT         =>   3,     # Route installed during boot
    RTPROT_STATIC       =>   4,     # Route installed by administrator

    # Values of protocol >= RTPROT_STATIC are not interpreted by kernel; they
    # could be used by hypothetical multiple routing daemons, so they are just
    # passed from user and back unchanged.
    #
    # Note: protocol values should be standardized in order to avoid conflicts.
    RTPROT_GATED        =>   8,     # Apparently, GateD
    RTPROT_RA           =>   9,     # RDISC/ND router advertisements
    RTPROT_MRT          =>  10,     # Merit MRT
    RTPROT_ZEBRA        =>  11,     # Zebra
    RTPROT_BIRD         =>  12,     # BIRD
    RTPROT_DNROUTED     =>  13,     # DECnet routing daemon
    RTPROT_XORP         =>  14,     # XORP
    RTPROT_NTK          =>  15,     # Netsukuku
    RTPROT_DHCP         =>  16,     # DHCP client
    RTPROT_MROUTED      =>  17,     # Multicast daemon
    RTPROT_BABEL        =>  42,     # Babel daemon

};

## rtm_scope
#
# Really it is not scope, but sort of distance to the destination.
# NOWHERE are reserved for nonexistent destinations, HOST is for our local
# addresses, LINK is for peers on directly attached links, and
# UNIVERSE/GLOBAL is everywhere.
#
# GLOBAL, SITE, LINK and HOST have the meanings defined by IETF for IPv6
# addresses; other values are also possible e.g. internal routes could be
# assigned values between SITE and LINK; continent or region routes could be
# assigned values between SITE and UNIVERSE.

use constant {
    RT_SCOPE_UNIVERSE   =>   0,

    # Remainder are user-defined in the sense that the kernel doesn't care, but
    RT_SCOPE_GLOBAL     =>   0, # == RT_SCOPE_UNIVERSE, not in rtnetlink.h
    RT_SCOPE_SITE       => 200,
    RT_SCOPE_LINK       => 253,
    RT_SCOPE_HOST       => 254,

    # nowhere is a custom scope
    RT_SCOPE_NOWHERE    => 255,
};

# rtm_flags
use constant {
    RTM_F_NOTIFY        => 0x100,   # Notify user of route change
    RTM_F_CLONED        => 0x200,   # This route is cloned
    RTM_F_EQUALIZE      => 0x400,   # Multipath equalizer: NI
    RTM_F_PREFIX        => 0x800,   # Prefix addresses
    RTM_F_LOOKUP_TABLE  => 0x1000,  # set rtm_table to FIB lookup result
};

use constant {
    # Reserved table identifiers
    RT_TABLE_UNSPEC     =>  0,

    # User defined values
    RT_TABLE_COMPAT     =>  252,
    RT_TABLE_DEFAULT    =>  253,
    RT_TABLE_MAIN       =>  254,
    RT_TABLE_LOCAL      =>  255,
  # RT_TABLE_MAX        =>  0xFFFFFFFF
};


use constant {
    # Routing message attributes rtattr_type_t

    RTA_UNSPEC          =>   0,
    RTA_DST             =>   1,
    RTA_SRC             =>   2,
    RTA_IIF             =>   3,
    RTA_OIF             =>   4,
    RTA_GATEWAY         =>   5,
    RTA_PRIORITY        =>   6,
    RTA_PREFSRC         =>   7,
    RTA_METRICS         =>   8,
    RTA_MULTIPATH       =>   9,
    RTA_PROTOINFO       =>  10, #  no longer used
    RTA_FLOW            =>  11,
    RTA_CACHEINFO       =>  12,
    RTA_SESSION         =>  13, #  no longer used
    RTA_MP_ALGO         =>  14, #  no longer used
    RTA_TABLE           =>  15,
    RTA_MARK            =>  16,
    RTA_MFC_STATS       =>  17,
    RTA_VIA             =>  18,
    RTA_NEWDST          =>  19,
    RTA_PREF            =>  20,
    RTA_ENCAP_TYPE      =>  21,
    RTA_ENCAP           =>  22,
  # RTA_MAX             =>  22 | 1,
};


use constant {
    RTNH_F_DEAD                 =>   1,     # Nexthop is dead (used by multipath)
    RTNH_F_PERVASIVE            =>   2,     # Do recursive gateway lookup
    RTNH_F_ONLINK               =>   4,     # Gateway is forced on link
    RTNH_F_OFFLOAD              =>   8,     # offloaded route
    RTNH_F_LINKDOWN             =>  16,     # carrier-down on nexthop
    RTNH_COMPARE_MASK           =>  25,     # == RTNH_F_DEAD | RTNH_F_LINKDOWN | RTNH_F_OFFLOAD
};

#qw{

# Macros to handle hexthops

## use constant RTNH_ALIGNTO =>  4;
## sub RTNH_ALIGN($)  { my ($len) = @_; (($len)+RTNH_ALIGNTO-1) & ~(RTNH_ALIGNTO-1) }
## sub RTNH_OK($$)    { my ($rtnh,$len) = @_; (($rtnh)->rtnh_len >= sizeof(struct rtnexthop) && ((int)($rtnh)->rtnh_len) <= ($len)) }
## sub RTNH_NEXT($)   { my ($rtnh) = @_; ((struct rtnexthop*)(((char*)($rtnh)) + RTNH_ALIGN(($rtnh)->rtnh_len))) }
## sub RTNH_LENGTH($) { my ($len) = @_; (RTNH_ALIGN(sizeof(struct rtnexthop)) + ($len)) }
## sub RTNH_SPACE($)  { my ($len) = @_; RTNH_ALIGN(RTNH_LENGTH($len)) }
## sub RTNH_DATA($)   { my ($rtnh) = @_;   ((struct rtattr*)(((char*)($rtnh)) + RTNH_LENGTH(0))) }

# RTA_VIA
#struct rtvia {
#        __kernel_sa_family_t    rtvia_family;
#        __u8                    rtvia_addr[0];
#};

# RTM_CACHEINFO

#struct rta_cacheinfo {
#        __u32   rta_clntref;
#        __u32   rta_lastuse;
#        __s32   rta_expires;
#        __u32   rta_error;
#        __u32   rta_used;
#
##define RTNETLINK_HAVE_PEERINFO 1
#        __u32   rta_id;
#        __u32   rta_ts;
#        __u32   rta_tsage;
#};

# RTM_METRICS --- array of struct rtattr with types of RTAX_*

use constant {
    RTAX_UNSPEC         =>   0,
    RTAX_LOCK           =>   1,
    RTAX_MTU            =>   2,
    RTAX_WINDOW         =>   3,
    RTAX_RTT            =>   4,
    RTAX_RTTVAR         =>   5,
    RTAX_SSTHRESH       =>   6,
    RTAX_CWND           =>   7,
    RTAX_ADVMSS         =>   8,
    RTAX_REORDERING     =>   9,
    RTAX_HOPLIMIT       =>  10,
    RTAX_INITCWND       =>  11,
    RTAX_FEATURES       =>  12,
    RTAX_RTO_MIN        =>  13,
    RTAX_INITRWND       =>  14,
    RTAX_QUICKACK       =>  15,
    RTAX_CC_ALGO        =>  16,

  # RTAX_MAX            =>  16 | 0,
};

use constant {
    RTAX_FEATURE_ECN        =>  1 << 0,
    RTAX_FEATURE_SACK       =>  1 << 1,
    RTAX_FEATURE_TIMESTAMP  =>  1 << 2,
    RTAX_FEATURE_ALLFRAG    =>  1 << 3,

    RTAX_FEATURE_MASK       =>  15,     # == RTAX_FEATURE_ECN | RTAX_FEATURE_SACK | RTAX_FEATURE_TIMESTAMP | RTAX_FEATURE_ALLFRAG,
};

#struct rta_session {
#        __u8    proto;
#        __u8    pad1;
#        __u16   pad2;
#
#        union {
#                struct {
#                        __u16   sport;
#                        __u16   dport;
#                } ports;
#
#                struct {
#                        __u8    type;
#                        __u8    code;
#                        __u16   ident;
#                } icmpt;
#
#                __u32           spi;
#        } u;
#};

#struct rta_mfc_stats {
#        __u64   mfcs_packets;
#        __u64   mfcs_bytes;
#        __u64   mfcs_wrong_if;
#};

################################################################
#####           General form of address family dependent message.
#####

#struct rtgenmsg {
#        unsigned char           rtgen_family;
#};

################################################################
#               Link layer specific messages.
#

## struct ifinfomsg
## passes link level specific information, not dependent
## on network protocol.

#struct ifinfomsg {
#        unsigned char   ifi_family;
#        unsigned char   __ifi_pad;
#        unsigned short  ifi_type;               # ARPHRD_*
#        int             ifi_index;              # Link index
#        unsigned        ifi_flags;              # IFF_* flags
#        unsigned        ifi_change;             # IFF_* change mask
#};

################################################################
#               prefix information
#

#struct prefixmsg {
#        unsigned char   prefix_family;
#        unsigned char   prefix_pad1;
#        unsigned short  prefix_pad2;
#        int             prefix_ifindex;
#        unsigned char   prefix_type;
#        unsigned char   prefix_len;
#        unsigned char   prefix_flags;
#        unsigned char   prefix_pad3;
#};

use constant {
    PREFIX_UNSPEC       =>   0,
    PREFIX_ADDRESS      =>   1,
    PREFIX_CACHEINFO    =>   2,

  # PREFIX_MAX          =>   2 | 0,
};


#struct prefix_cacheinfo {
#        __u32   preferred_time;
#        __u32   valid_time;
#};


################################################################
#               Traffic control messages.
#

#struct tcmsg {
#        unsigned char   tcm_family;
#        unsigned char   tcm__pad1;
#        unsigned short  tcm__pad2;
#        int             tcm_ifindex;
#        __u32           tcm_handle;
#        __u32           tcm_parent;
#        __u32           tcm_info;
#};

use constant {
    TCA_UNSPEC      =>  0,
    TCA_KIND        =>  1,
    TCA_OPTIONS     =>  2,
    TCA_STATS       =>  3,
    TCA_XSTATS      =>  4,
    TCA_RATE        =>  5,
    TCA_FCNT        =>  6,
    TCA_STATS2      =>  7,
    TCA_STAB        =>  8,

  # TCA_MAX         =>  8 | 0,
};

#define TCA_RTA(r)  ((struct rtattr*)(((char*)(r)) + NLMSG_ALIGN(sizeof(struct tcmsg))))
#define TCA_PAYLOAD(n) NLMSG_PAYLOAD(n,sizeof(struct tcmsg))

################################################################
#               Neighbor Discovery userland options
#

#struct nduseroptmsg {
#        unsigned char   nduseropt_family;
#        unsigned char   nduseropt_pad1;
#        unsigned short  nduseropt_opts_len;     # Total length of options
#        int             nduseropt_ifindex;
#        __u8            nduseropt_icmp_type;
#        __u8            nduseropt_icmp_code;
#        unsigned short  nduseropt_pad2;
#        unsigned int    nduseropt_pad3;
#        # Followed by one or more ND options
#};

use constant {
    NDUSEROPT_UNSPEC    => 0,
    NDUSEROPT_SRCADDR   => 1,

  # NDUSEROPT_MAX       => 1 | 0,
};

# RTnetlink multicast groups - backwards compatibility for userspace
use constant {
    RTMGRP_LINK                 =>  1,
    RTMGRP_NOTIFY               =>  2,
    RTMGRP_NEIGH                =>  4,
    RTMGRP_TC                   =>  8,

    RTMGRP_IPV4_IFADDR          =>  0x10,
    RTMGRP_IPV4_MROUTE          =>  0x20,
    RTMGRP_IPV4_ROUTE           =>  0x40,
    RTMGRP_IPV4_RULE            =>  0x80,

    RTMGRP_IPV6_IFADDR          =>  0x100,
    RTMGRP_IPV6_MROUTE          =>  0x200,
    RTMGRP_IPV6_ROUTE           =>  0x400,
    RTMGRP_IPV6_IFINFO          =>  0x800,

    RTMGRP_DECnet_IFADDR        =>  0x1000,
    RTMGRP_DECnet_ROUTE         =>  0x4000,

    RTMGRP_IPV6_PREFIX          =>  0x20000,
};

# RTnetlink multicast groups (enum rtnetlink_groups)
use constant {
    RTNLGRP_NONE	=>   0,
    RTNLGRP_LINK	=>   1,
    RTNLGRP_NOTIFY	=>   2,
    RTNLGRP_NEIGH	=>   3,
    RTNLGRP_TC	=>   4,
    RTNLGRP_IPV4_IFADDR	=>   5,
    RTNLGRP_IPV4_MROUTE	=>   6,
    RTNLGRP_IPV4_ROUTE	=>   7,
    RTNLGRP_IPV4_RULE	=>   8,
    RTNLGRP_IPV6_IFADDR	=>   9,
    RTNLGRP_IPV6_MROUTE	=>  10,
    RTNLGRP_IPV6_ROUTE	=>  11,
    RTNLGRP_IPV6_IFINFO	=>  12,
    RTNLGRP_DECnet_IFADDR	=>  13,
    RTNLGRP_NOP2	=>  14,
    RTNLGRP_DECnet_ROUTE	=>  15,
    RTNLGRP_DECnet_RULE	=>  16,
    RTNLGRP_NOP4	=>  17,
    RTNLGRP_IPV6_PREFIX	=>  18,
    RTNLGRP_IPV6_RULE	=>  19,
    RTNLGRP_ND_USEROPT	=>  20,
    RTNLGRP_PHONET_IFADDR	=>  21,
    RTNLGRP_PHONET_ROUTE	=>  22,
    RTNLGRP_DCB	=>  23,
    RTNLGRP_IPV4_NETCONF	=>  24,
    RTNLGRP_IPV6_NETCONF	=>  25,
    RTNLGRP_MDB	=>  26,
    RTNLGRP_MPLS_ROUTE	=>  27,
    RTNLGRP_NSID	=>  28,

  # RTNLGRP_MAX                 =>  28 | 0,
};

# TC action piece
#struct tcamsg {
#        unsigned char   tca_family;
#        unsigned char   tca__pad1;
#        unsigned short  tca__pad2;
#};
#define TA_RTA(r)  ((struct rtattr*)(((char*)(r)) + NLMSG_ALIGN(sizeof(struct tcamsg))))
#define TA_PAYLOAD(n) NLMSG_PAYLOAD(n,sizeof(struct tcamsg))

use constant {
    TCA_ACT_TAB                 =>  1, # attr type must be >=1

  # TCAA_MAX                    =>  1 | 0,
};

# New extended info filters for IFLA_EXT_MASK
use constant {
    RTEXT_FILTER_VF                 =>  1 << 0,
    RTEXT_FILTER_BRVLAN             =>  1 << 1,
    RTEXT_FILTER_BRVLAN_COMPRESSED  =>  1 << 2,
    RTEXT_FILTER_SKIP_STATS         =>  1 << 3,
};

# End of information exported to user level

our @EXPORT_OK = qw(

    NDUSEROPT_SRCADDR
    NDUSEROPT_UNSPEC

    PREFIX_ADDRESS
    PREFIX_CACHEINFO
    PREFIX_UNSPEC

    RTAX_ADVMSS
    RTAX_CC_ALGO
    RTAX_CWND
    RTAX_FEATURES
    RTAX_FEATURE_ALLFRAG
    RTAX_FEATURE_ECN
    RTAX_FEATURE_MASK
    RTAX_FEATURE_SACK
    RTAX_FEATURE_TIMESTAMP
    RTAX_HOPLIMIT
    RTAX_INITCWND
    RTAX_INITRWND
    RTAX_LOCK
    RTAX_MTU
    RTAX_QUICKACK
    RTAX_REORDERING
    RTAX_RTO_MIN
    RTAX_RTT
    RTAX_RTTVAR
    RTAX_SSTHRESH
    RTAX_UNSPEC
    RTAX_WINDOW

    RTA_CACHEINFO
    RTA_DST
    RTA_ENCAP
    RTA_ENCAP_TYPE
    RTA_FLOW
    RTA_GATEWAY
    RTA_IIF
    RTA_MARK
    RTA_METRICS
    RTA_MFC_STATS
    RTA_MP_ALGO
    RTA_MULTIPATH
    RTA_NEWDST
    RTA_OIF
    RTA_PREF
    RTA_PREFSRC
    RTA_PRIORITY
    RTA_PROTOINFO
    RTA_SESSION
    RTA_SRC
    RTA_TABLE
    RTA_UNSPEC
    RTA_VIA

    RTEXT_FILTER_BRVLAN
    RTEXT_FILTER_BRVLAN_COMPRESSED
    RTEXT_FILTER_SKIP_STATS
    RTEXT_FILTER_VF

    RTMGRP_DECnet_IFADDR
    RTMGRP_DECnet_ROUTE
    RTMGRP_IPV4_IFADDR
    RTMGRP_IPV4_MROUTE
    RTMGRP_IPV4_ROUTE
    RTMGRP_IPV4_RULE
    RTMGRP_IPV6_IFADDR
    RTMGRP_IPV6_IFINFO
    RTMGRP_IPV6_MROUTE
    RTMGRP_IPV6_PREFIX
    RTMGRP_IPV6_ROUTE
    RTMGRP_LINK
    RTMGRP_NEIGH
    RTMGRP_NOTIFY
    RTMGRP_TC

    RTM_DELACTION
    RTM_DELADDR
    RTM_DELADDRLABEL
    RTM_DELLINK
    RTM_DELMDB
    RTM_DELNEIGH
    RTM_DELNSID
    RTM_DELQDISC
    RTM_DELROUTE
    RTM_DELRULE
    RTM_DELTCLASS
    RTM_DELTFILTER
    RTM_GETACTION
    RTM_GETADDR
    RTM_GETADDRLABEL
    RTM_GETANYCAST
    RTM_GETDCB
    RTM_GETLINK
    RTM_GETMDB
    RTM_GETMULTICAST
    RTM_GETNEIGH
    RTM_GETNEIGHTBL
    RTM_GETNETCONF
    RTM_GETNSID
    RTM_GETQDISC
    RTM_GETROUTE
    RTM_GETRULE
    RTM_GETTCLASS
    RTM_GETTFILTER
    RTM_NEWACTION
    RTM_NEWADDR
    RTM_NEWADDRLABEL
    RTM_NEWLINK
    RTM_NEWMDB
    RTM_NEWNDUSEROPT
    RTM_NEWNEIGH
    RTM_NEWNEIGHTBL
    RTM_NEWNETCONF
    RTM_NEWNSID
    RTM_NEWPREFIX
    RTM_NEWQDISC
    RTM_NEWROUTE
    RTM_NEWRULE
    RTM_NEWTCLASS
    RTM_NEWTFILTER
    RTM_SETDCB
    RTM_SETLINK
    RTM_SETNEIGHTBL

    RTM_F_CLONED
    RTM_F_EQUALIZE
    RTM_F_LOOKUP_TABLE
    RTM_F_NOTIFY
    RTM_F_PREFIX

    RTN_ANYCAST
    RTN_BLACKHOLE
    RTN_BROADCAST
    RTN_LOCAL
    RTN_MULTICAST
    RTN_NAT
    RTN_PROHIBIT
    RTN_THROW
    RTN_UNICAST
    RTN_UNREACHABLE
    RTN_UNSPEC
    RTN_XRESOLVE

    RTNH_COMPARE_MASK
    RTNH_F_DEAD
    RTNH_F_LINKDOWN
    RTNH_F_OFFLOAD
    RTNH_F_ONLINK
    RTNH_F_PERVASIVE

    RTNL_FAMILY_IP6MR
    RTNL_FAMILY_IPMR

    RTNLGRP_DCB
    RTNLGRP_DECnet_IFADDR
    RTNLGRP_DECnet_ROUTE
    RTNLGRP_DECnet_RULE
    RTNLGRP_IPV4_IFADDR
    RTNLGRP_IPV4_MROUTE
    RTNLGRP_IPV4_NETCONF
    RTNLGRP_IPV4_ROUTE
    RTNLGRP_IPV4_RULE
    RTNLGRP_IPV6_IFADDR
    RTNLGRP_IPV6_IFINFO
    RTNLGRP_IPV6_MROUTE
    RTNLGRP_IPV6_NETCONF
    RTNLGRP_IPV6_PREFIX
    RTNLGRP_IPV6_ROUTE
    RTNLGRP_IPV6_RULE
    RTNLGRP_LINK
    RTNLGRP_MDB
    RTNLGRP_MPLS_ROUTE
    RTNLGRP_ND_USEROPT
    RTNLGRP_NEIGH
    RTNLGRP_NONE
    RTNLGRP_NOP2
    RTNLGRP_NOP4
    RTNLGRP_NOTIFY
    RTNLGRP_NSID
    RTNLGRP_PHONET_IFADDR
    RTNLGRP_PHONET_ROUTE
    RTNLGRP_TC

    RT_SCOPE_GLOBAL
    RT_SCOPE_HOST
    RT_SCOPE_LINK
    RT_SCOPE_NOWHERE
    RT_SCOPE_SITE
    RT_SCOPE_UNIVERSE
    RT_TABLE_COMPAT
    RT_TABLE_DEFAULT
    RT_TABLE_LOCAL
    RT_TABLE_MAIN
    RT_TABLE_UNSPEC

    RTPROT_BABEL
    RTPROT_BIRD
    RTPROT_BOOT
    RTPROT_DHCP
    RTPROT_DNROUTED
    RTPROT_GATED
    RTPROT_KERNEL
    RTPROT_MROUTED
    RTPROT_MRT
    RTPROT_NTK
    RTPROT_RA
    RTPROT_REDIRECT
    RTPROT_STATIC
    RTPROT_UNSPEC
    RTPROT_XORP
    RTPROT_ZEBRA

    TCA_FCNT
    TCA_KIND
    TCA_OPTIONS
    TCA_RATE
    TCA_STAB
    TCA_STATS
    TCA_STATS2
    TCA_UNSPEC
    TCA_XSTATS

    TCA_ACT_TAB

);

our %EXPORT_TAGS = (

    rtm => [qw[
        RTM_DELACTION
        RTM_DELADDR
        RTM_DELADDRLABEL
        RTM_DELLINK
        RTM_DELMDB
        RTM_DELNEIGH
        RTM_DELNSID
        RTM_DELQDISC
        RTM_DELROUTE
        RTM_DELRULE
        RTM_DELTCLASS
        RTM_DELTFILTER
        RTM_GETACTION
        RTM_GETADDR
        RTM_GETADDRLABEL
        RTM_GETANYCAST
        RTM_GETDCB
        RTM_GETLINK
        RTM_GETMDB
        RTM_GETMULTICAST
        RTM_GETNEIGH
        RTM_GETNEIGHTBL
        RTM_GETNETCONF
        RTM_GETNSID
        RTM_GETQDISC
        RTM_GETROUTE
        RTM_GETRULE
        RTM_GETTCLASS
        RTM_GETTFILTER
        RTM_NEWACTION
        RTM_NEWADDR
        RTM_NEWADDRLABEL
        RTM_NEWLINK
        RTM_NEWMDB
        RTM_NEWNDUSEROPT
        RTM_NEWNEIGH
        RTM_NEWNEIGHTBL
        RTM_NEWNETCONF
        RTM_NEWNSID
        RTM_NEWPREFIX
        RTM_NEWQDISC
        RTM_NEWROUTE
        RTM_NEWRULE
        RTM_NEWTCLASS
        RTM_NEWTFILTER
        RTM_SETDCB
        RTM_SETLINK
        RTM_SETNEIGHTBL
    ]],

    rtm_flags => [qw[
        RTM_F_CLONED
        RTM_F_EQUALIZE
        RTM_F_LOOKUP_TABLE
        RTM_F_NOTIFY
        RTM_F_PREFIX
    ]],

    rtnl_family => [qw[
        RTNL_FAMILY_IPMR
        RTNL_FAMILY_IP6MR
    ]],

    rtn => [qw[
        RTN_ANYCAST
        RTN_BLACKHOLE
        RTN_BROADCAST
        RTN_LOCAL
        RTN_MULTICAST
        RTN_NAT
        RTN_PROHIBIT
        RTN_THROW
        RTN_UNICAST
        RTN_UNREACHABLE
        RTN_UNSPEC
        RTN_XRESOLVE
    ]],

    rt_prot => [qw[
        RTPROT_BABEL
        RTPROT_BIRD
        RTPROT_BOOT
        RTPROT_DHCP
        RTPROT_DNROUTED
        RTPROT_GATED
        RTPROT_KERNEL
        RTPROT_MROUTED
        RTPROT_MRT
        RTPROT_NTK
        RTPROT_RA
        RTPROT_REDIRECT
        RTPROT_STATIC
        RTPROT_UNSPEC
        RTPROT_XORP
        RTPROT_ZEBRA
    ]],

    rt_scope => [qw[
        RT_SCOPE_GLOBAL
        RT_SCOPE_HOST
        RT_SCOPE_LINK
        RT_SCOPE_NOWHERE
        RT_SCOPE_SITE
        RT_SCOPE_UNIVERSE
    ]],

    rta => [qw[
        RTA_CACHEINFO
        RTA_DST
        RTA_ENCAP
        RTA_ENCAP_TYPE
        RTA_FLOW
        RTA_GATEWAY
        RTA_IIF
        RTA_MARK
        RTA_METRICS
        RTA_MFC_STATS
        RTA_MP_ALGO
        RTA_MULTIPATH
        RTA_NEWDST
        RTA_OIF
        RTA_PREF
        RTA_PREFSRC
        RTA_PRIORITY
        RTA_PROTOINFO
        RTA_SESSION
        RTA_SRC
        RTA_TABLE
        RTA_UNSPEC
        RTA_VIA
    ]],

    rtt => [qw[
        RT_TABLE_COMPAT
        RT_TABLE_DEFAULT
        RT_TABLE_LOCAL
        RT_TABLE_MAIN
        RT_TABLE_UNSPEC
    ]],

    rtnh_flags => [qw[
        RTNH_COMPARE_MASK
        RTNH_F_DEAD
        RTNH_F_LINKDOWN
        RTNH_F_OFFLOAD
        RTNH_F_ONLINK
        RTNH_F_PERVASIVE
    ]],

    rtax => [qw[
        RTAX_ADVMSS
        RTAX_CC_ALGO
        RTAX_CWND
        RTAX_FEATURES
        RTAX_HOPLIMIT
        RTAX_INITCWND
        RTAX_INITRWND
        RTAX_LOCK
        RTAX_MTU
        RTAX_QUICKACK
        RTAX_REORDERING
        RTAX_RTO_MIN
        RTAX_RTT
        RTAX_RTTVAR
        RTAX_SSTHRESH
        RTAX_UNSPEC
        RTAX_WINDOW
    ]],

    rtax_features => [qw[
        RTAX_FEATURE_ALLFRAG
        RTAX_FEATURE_ECN
        RTAX_FEATURE_MASK
        RTAX_FEATURE_SACK
        RTAX_FEATURE_TIMESTAMP
    ]],

    prefix => [qw[
        PREFIX_ADDRESS
        PREFIX_CACHEINFO
        PREFIX_UNSPEC
    ]],

    tca => [qw[
        TCA_FCNT
        TCA_KIND
        TCA_OPTIONS
        TCA_RATE
        TCA_STAB
        TCA_STATS
        TCA_STATS2
        TCA_UNSPEC
        TCA_XSTATS
    ]],

    nduseropt => [qw[
        NDUSEROPT_SRCADDR
        NDUSEROPT_UNSPEC
    ]],

    rtmgrp => [qw[
        RTMGRP_DECnet_IFADDR
        RTMGRP_DECnet_ROUTE

        RTMGRP_IPV4_IFADDR
        RTMGRP_IPV4_MROUTE
        RTMGRP_IPV4_ROUTE
        RTMGRP_IPV4_RULE

        RTMGRP_IPV6_IFADDR
        RTMGRP_IPV6_IFINFO
        RTMGRP_IPV6_MROUTE
        RTMGRP_IPV6_PREFIX
        RTMGRP_IPV6_ROUTE

        RTMGRP_LINK
        RTMGRP_NEIGH
        RTMGRP_NOTIFY
        RTMGRP_TC
    ]],

    rtnlgrp => [qw[
        RTNLGRP_DCB
        RTNLGRP_DECnet_IFADDR
        RTNLGRP_DECnet_ROUTE
        RTNLGRP_DECnet_RULE
        RTNLGRP_IPV4_IFADDR
        RTNLGRP_IPV4_MROUTE
        RTNLGRP_IPV4_NETCONF
        RTNLGRP_IPV4_ROUTE
        RTNLGRP_IPV4_RULE
        RTNLGRP_IPV6_IFADDR
        RTNLGRP_IPV6_IFINFO
        RTNLGRP_IPV6_MROUTE
        RTNLGRP_IPV6_NETCONF
        RTNLGRP_IPV6_PREFIX
        RTNLGRP_IPV6_ROUTE
        RTNLGRP_IPV6_RULE
        RTNLGRP_LINK
        RTNLGRP_MDB
        RTNLGRP_MPLS_ROUTE
        RTNLGRP_ND_USEROPT
        RTNLGRP_NEIGH
        RTNLGRP_NONE
        RTNLGRP_NOP2
        RTNLGRP_NOP4
        RTNLGRP_NOTIFY
        RTNLGRP_NSID
        RTNLGRP_PHONET_IFADDR
        RTNLGRP_PHONET_ROUTE
        RTNLGRP_TC
    ]],

    tca_act => [qw[
        TCA_ACT_TAB
    ]],

    rtext => [qw[
        RTEXT_FILTER_BRVLAN
        RTEXT_FILTER_BRVLAN_COMPRESSED
        RTEXT_FILTER_SKIP_STATS
        RTEXT_FILTER_VF
    ]],
);
1;
