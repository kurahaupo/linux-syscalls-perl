#!/module/for/perl

use 5.010;
use strict;
use warnings;

package Linux::IpRoute2::rtnetlink v0.0.1;

use Exporter 'import';

use Linux::Syscalls ();

sub _B($) { 1 << pop }

# Copied and adapted from /usr/include/linux/rtnetlink.h
#       also from [iproute2]include/uapi/linux/netlink.h

use constant {
    RTNL_FAMILY_IPMR    =>   128,
    RTNL_FAMILY_IP6MR   =>   129,
  # RTNL_FAMILY_MAX     =>   129 | 0,
};

{
my @names = ((undef) x 128, qw( ipmr ip6mr ));
sub RTNL_FAMILY_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub RTNL_FAMILY_to_name($) { return &RTNL_FAMILY_to_label // "code#$_[0]" }
}

use constant {
    RTM_TMIN            =>     4,
};

# The 0~3 are skipped, possibly to avoid clashing with the op values
my @RTM_types;
BEGIN {
@RTM_types = ((undef) x RTM_TMIN, qw(
                    link
                    addr
                    route
                    neigh
                    rule
                    qdisc
                    tclass
                    tfilter
                    action
                    prefix
                    multicast
                    anycast
                    neightbl
                    nduseropt
                    addrlabel
                    dcb
                    netconf
                    mdb
                    nsid
                ));
}

use constant {
    RTM_TMAX            =>  $#RTM_types,
    RTM_TSHIFT          =>     2,       # type shift
};
use constant {
    RTM_TMASK           =>  ~0 << RTM_TSHIFT,
};

my @RTM_ops;
BEGIN {
@RTM_ops = qw(
                    new
                    del
                    get
                    set
                );
}

use constant {
    RTM_OMASK           =>  ~RTM_TMASK, # operation mask
    RTM_OSHIFT          =>     0,       # operation shift
};

use constant {
    RTM_BASE            =>  RTM_TMIN      << RTM_TSHIFT,               # 16 == min, rounded down
    RTM_MAX             =>  RTM_TMAX      << RTM_TSHIFT | RTM_OMASK,   # 91 == max, rounded up
};

# Define composite symbols like RTM_{NEW,DEL,GET,SET}{LINK,ADDR,ROUTE...NSID}
my @RTM_op_types;
my @RTM_symbols;
{
    # The following magic string limits the list of exported composites to only
    # those defined in /usr/include/linux/rtnetlink.h
    my $q = pack 'h*', '0000f77777777144d17c577';
    my %n;
    for my $type (RTM_TMIN .. $#RTM_types) {
        my $tsym = $RTM_types[$type] // next;
        for my $op (0..$#RTM_ops) {
            my $code = $type << RTM_TSHIFT | $op;
            vec($q, $code, 1) || next;
            my $sym = $RTM_ops[$op].$tsym;
            $RTM_op_types[$code] = $sym;
            $n{'RTM_'.uc $sym} = $code;
        }
        $n{'RTM_'.uc $tsym} = $type;
    }
    for my $op (0..$#RTM_ops) {
        $n{'RTM_'.uc $RTM_ops[$op]} = $op;
    }
    constant::->import(\%n);
    @RTM_symbols = keys %n;
}

sub RTM_op_to_label($) { return $_[0] >= 0 ? $RTM_ops[$_[0]] : () }
sub RTM_op_to_name($) { return &RTM_op_to_label // "op#$_[0]" }

sub RTM_type_to_label($) { return $_[0] >= 0 ? $RTM_types[$_[0]] : () }
sub RTM_type_to_name($) { return &RTM_type_to_label // "type#$_[0]" }

sub RTM_to_name($) {
    my ($c) = @_;
    my $on = $RTM_ops[$c & RTM_OMASK];  # Cannot fail
    my $t = $c >> RTM_TSHIFT;
    if ($c >= 0) {
        my $tn = $RTM_types[$t];
        return lc($on.$tn) if $tn;
    }
    return sprintf '%s#%u', lc $on, $t;
}

# Generic structure for encapsulation of optional route information.
# It is reminiscent of sockaddr, but with sa_family replaced
# with attribute type.

use constant {
    struct_rtattr_pack  =>  'SS',
    struct_rtattr_narg  =>     2,
    struct_rtattr_len   =>     4,
};

    #   struct rtattr {
    #       unsigned short  rta_len;
    #       unsigned short  rta_type;
    #   };

##
## Definitions used in routing table administration.
##

use constant {
    struct_rtmsg_pack   => 'C9x3',
    struct_rtmsg_narg   =>     9,
    struct_rtmsg_len    =>     9,
};

    #   struct rtmsg {
    #       unsigned char           rtm_family;
    #       unsigned char           rtm_dst_len;
    #       unsigned char           rtm_src_len;
    #       unsigned char           rtm_tos;
    #
    #       unsigned char           rtm_table;
    #       unsigned char           rtm_protocol;
    #       unsigned char           rtm_scope;
    #       unsigned char           rtm_type;
    #
    #       unsigned                rtm_flags;
    #   };

use constant {
    RTN_UNSPEC          =>     0,
    RTN_UNICAST         =>     1,   # Gateway or direct route
    RTN_LOCAL           =>     2,   # Accept locally
    RTN_BROADCAST       =>     3,   # Accept locally as broadcast, send as broadcast
    RTN_ANYCAST         =>     4,   # Accept locally as broadcast, but send as unicast
    RTN_MULTICAST       =>     5,   # Multicast route
    RTN_BLACKHOLE       =>     6,   # Drop
    RTN_UNREACHABLE     =>     7,   # Destination is unreachable
    RTN_PROHIBIT        =>     8,   # Administratively prohibited
    RTN_THROW           =>     9,   # Not in this table
    RTN_NAT             =>    10,   # Translate this address
    RTN_XRESOLVE        =>    11,   # Use external resolver

  # RTN_MAX             =>    11 | 1, # max, rounded up
};

{
my @names = qw(
    unspec unicast local broadcast anycast multicast blackhole unreachable
    prohibit throw nat xresolve
);
sub RTN_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub RTN_to_name($) { return &RTN_to_label // "code#$_[0]" }
}

## rtm_protocol
use constant {

    RTPROT_UNSPEC       =>     0,
    RTPROT_REDIRECT     =>     1,   # Route installed by ICMP redirects; not used by current IPv4
    RTPROT_KERNEL       =>     2,   # Route installed by kernel
    RTPROT_BOOT         =>     3,   # Route installed during boot
    RTPROT_STATIC       =>     4,   # Route installed by administrator

    # Values of protocol >= RTPROT_STATIC are not interpreted by kernel; they
    # could be used by hypothetical multiple routing daemons, so they are just
    # passed from user and back unchanged.
    #
    # Note: protocol values should be standardized in order to avoid conflicts.
    RTPROT_GATED        =>     8,   # Apparently, GateD
    RTPROT_RA           =>     9,   # RDISC/ND router advertisements
    RTPROT_MRT          =>    10,   # Merit MRT
    RTPROT_ZEBRA        =>    11,   # Zebra
    RTPROT_BIRD         =>    12,   # BIRD
    RTPROT_DNROUTED     =>    13,   # DECnet routing daemon
    RTPROT_XORP         =>    14,   # XORP
    RTPROT_NTK          =>    15,   # Netsukuku
    RTPROT_DHCP         =>    16,   # DHCP client
    RTPROT_MROUTED      =>    17,   # Multicast daemon
    RTPROT_BABEL        =>    42,   # Babel daemon

};

{
my @names;
$names[eval 'RTPROT_'.uc $_] = $_ for qw(
    unspec redirect kernel boot static gated ra mrt zebra bird dnrouted xorp
    ntk dhcp mrouted babel );
sub RTPROT_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub RTPROT_to_name($) { return &RTPROT_to_label // "code#$_[0]" }
}

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
    RT_SCOPE_UNIVERSE   =>     0,

    # Remainder are user-defined in the sense that the kernel doesn't care, but
    RT_SCOPE_GLOBAL     =>     0,   # == RT_SCOPE_UNIVERSE, not in rtnetlink.h
    RT_SCOPE_SITE       =>   200,
    RT_SCOPE_LINK       =>   253,
    RT_SCOPE_HOST       =>   254,

    # nowhere is a custom scope
    RT_SCOPE_NOWHERE    =>   255,
};

{
my @names;
$names[eval 'RT_SCOPE_'.uc $_] = $_ for qw(
    universe global site link host nowhere );
sub RT_SCOPE_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub RT_SCOPE_to_name($) { return &RT_SCOPE_to_label // "code#$_[0]" }
}

# rtm_flags
use constant {
    RTM_F_NOTIFY        => _B  8,   #  0x100    Notify user of route change
    RTM_F_CLONED        => _B  9,   #  0x200    This route is cloned
    RTM_F_EQUALIZE      => _B 10,   #  0x400    Multipath equalizer: NI
    RTM_F_PREFIX        => _B 11,   #  0x800    Prefix addresses
    RTM_F_LOOKUP_TABLE  => _B 12,   # 0x1000    set rtm_table to FIB lookup result
};

{
my @names = ((undef) x 8, qw( notify cloned equalize prefix lookup ));
sub RTMF_to_desc($) {
    splice @_, 1, 0, \@names;
    goto &Linux::Syscalls::_bits_to_desc
}
}

use constant {
    # Reserved table identifiers
    RT_TABLE_UNSPEC     =>     0,

    # User defined values
    RT_TABLE_COMPAT     =>   252,
    RT_TABLE_DEFAULT    =>   253,
    RT_TABLE_MAIN       =>   254,
    RT_TABLE_LOCAL      =>   255,
  # RT_TABLE_MAX        =>   0xFFFFFFFF
};

{
my @names;
$names[eval 'RT_TABLE_'.uc $_] = $_ for qw(
    unspec compat default main local
);
sub RT_TABLE_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub RT_TABLE_to_name($) { return &RT_TABLE_to_label // "code#$_[0]" }
}

use constant {
    # Routing message attributes rtattr_type_t

    RTA_UNSPEC          =>     0,
    RTA_DST             =>     1,
    RTA_SRC             =>     2,
    RTA_IIF             =>     3,
    RTA_OIF             =>     4,
    RTA_GATEWAY         =>     5,
    RTA_PRIORITY        =>     6,
    RTA_PREFSRC         =>     7,
    RTA_METRICS         =>     8,
    RTA_MULTIPATH       =>     9,
    RTA_PROTOINFO       =>    10, #  no longer used
    RTA_FLOW            =>    11,
    RTA_CACHEINFO       =>    12,
    RTA_SESSION         =>    13, #  no longer used
    RTA_MP_ALGO         =>    14, #  no longer used
    RTA_TABLE           =>    15,
    RTA_MARK            =>    16,
    RTA_MFC_STATS       =>    17,
    RTA_VIA             =>    18,
    RTA_NEWDST          =>    19,
    RTA_PREF            =>    20,
    RTA_ENCAP_TYPE      =>    21,
    RTA_ENCAP           =>    22,
  # RTA_MAX             =>    22 | 1,
};

{
my @names = qw( unspec dst src iif oif gateway priority prefsrc metrics
    multipath protoinfo flow cacheinfo session mp_algo table mark mfc_stats via
    newdst pref encap_type encap );
sub RTA_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub RTA_to_name($) { return &RTA_to_label // "code#$_[0]" }
}

# RTM_MULTIPATH --- array of struct rtnexthop.
#
# "struct rtnexthop" describes all necessary nexthop information,
# i.e. parameters of path to a destination via this nexthop.
#
# At the moment it is impossible to set different prefsrc, mtu, window
# and rtt for different paths from multipath.

use constant {
    struct_rtnexthop_pack   => 'SCCi',
    struct_rtnexthop_narg   =>     3,
    struct_rtnexthop_len    =>     8,
};
    #   struct rtnexthop {
    #       unsigned short		rtnh_len;
    #       unsigned char		rtnh_flags;
    #       unsigned char		rtnh_hops;
    #       int			rtnh_ifindex;
    #   };

use constant {
    RTNH_F_DEAD         =>  _B 0,   #  1    Nexthop is dead (used by multipath)
    RTNH_F_PERVASIVE    =>  _B 1,   #  2    Do recursive gateway lookup
    RTNH_F_ONLINK       =>  _B 2,   #  4    Gateway is forced on link
    RTNH_F_OFFLOAD      =>  _B 3,   #  8    offloaded route
    RTNH_F_LINKDOWN     =>  _B 4,   # 16    carrier-down on nexthop
    RTNH_COMPARE_MASK   =>    25,   # == RTNH_F_DEAD | RTNH_F_LINKDOWN | RTNH_F_OFFLOAD
};

{
my @names = qw( dead pervasive onlink offload linkdown );
sub RTNHF_to_desc($) {
    splice @_, 1, 0, \@names;
    goto &Linux::Syscalls::_bits_to_desc;
}
}

# Macros to handle hexthops

## use constant RTNH_ALIGNTO =>  4;
## sub RTNH_ALIGN($)  { my ($len) = @_; (($len)+RTNH_ALIGNTO-1) & ~(RTNH_ALIGNTO-1) }
## sub RTNH_OK($$)    { my ($rtnh,$len) = @_; (($rtnh)->rtnh_len >= struct_rtnexthop_len && ((int)($rtnh)->rtnh_len) <= ($len)) }
## sub RTNH_NEXT($)   { my ($rtnh) = @_; ((struct rtnexthop*)(((char*)($rtnh)) + RTNH_ALIGN(($rtnh)->rtnh_len))) }
## sub RTNH_LENGTH($) { my ($len) = @_; (RTNH_ALIGN(sizeof(struct rtnexthop)) + ($len)) }
## sub RTNH_SPACE($)  { my ($len) = @_; RTNH_ALIGN(RTNH_LENGTH($len)) }
## sub RTNH_DATA($)   { my ($rtnh) = @_;   ((struct rtattr*)(((char*)($rtnh)) + RTNH_LENGTH(0))) }

use constant {
    struct_rtvia_pack       =>  'SA*',
    struct_rtvia_narg       =>      2,
    struct_rtvia_len        =>  undef,   # does not have a fixed value, use 'length' instead
};

    # RTA_VIA
    #   struct rtvia {
    #       uint16_t    rtvia_family;  /* (__kernel_sa_family_t = unsigned short) */
    #       uint8_t     rtvia_addr[];  /* FAM - flexible array member, extending to end of allocated space beyond the containing struct */
    #   };

# RTM_CACHEINFO

use constant {
    struct_rta_cacheinfo_pack   =>  'LLlLLLLL',
    struct_rta_cacheinfo_narg   =>     8,
    struct_rta_cacheinfo_len    =>    32,     # = length pack struct_rta_cacheinfo_pack, (0) x 8;
};

    #   struct rta_cacheinfo {
    #       uint32_t    rta_clntref;
    #       uint32_t    rta_lastuse;
    #       int32_t     rta_expires;
    #       uint32_t    rta_error;
    #       uint32_t    rta_used;
    #       uint32_t    rta_id;
    #       uint32_t    rta_ts;
    #       uint32_t    rta_tsage;
    #   };

use constant {
    RTNETLINK_HAVE_PEERINFO =>     1,
};

{
my @names = qw( have_peerinfo );
sub RTNETLINKF_to_desc($) {
    splice @_, 1, 0, \@names;
    goto &Linux::Syscalls::_bits_to_desc;
}
}

# RTM_METRICS --- array of struct rtattr with types of RTAX_*

use constant {
    RTAX_UNSPEC         =>     0,
    RTAX_LOCK           =>     1,
    RTAX_MTU            =>     2,
    RTAX_WINDOW         =>     3,
    RTAX_RTT            =>     4,
    RTAX_RTTVAR         =>     5,
    RTAX_SSTHRESH       =>     6,
    RTAX_CWND           =>     7,
    RTAX_ADVMSS         =>     8,
    RTAX_REORDERING     =>     9,
    RTAX_HOPLIMIT       =>    10,
    RTAX_INITCWND       =>    11,
    RTAX_FEATURES       =>    12,
    RTAX_RTO_MIN        =>    13,
    RTAX_INITRWND       =>    14,
    RTAX_QUICKACK       =>    15,
    RTAX_CC_ALGO        =>    16,

  # RTAX_MAX            =>    16 | 0,
};


{
my @names = qw( unspec lock mtu window rtt rttvar ssthresh cwnd advmss
                     reordering hoplimit initcwnd features rto_min initrwnd
                     quickack cc_algo );
sub RTAX_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub RTAX_to_name($) { return &RTAX_to_label // "code#$_[0]" }
}

use constant {
    RTAX_FEATURE_ECN        => _B  0,
    RTAX_FEATURE_SACK       => _B  1,
    RTAX_FEATURE_TIMESTAMP  => _B  2,
    RTAX_FEATURE_ALLFRAG    => _B  3,

    RTAX_FEATURE_MASK       =>    15,     # == RTAX_FEATURE_ECN | RTAX_FEATURE_SACK | RTAX_FEATURE_TIMESTAMP | RTAX_FEATURE_ALLFRAG,
};

{
my @names = qw( ecn sack timestamp allfrag );
sub RTAXF_to_desc($) {
    splice @_, 1, 0, \@names;
    goto &Linux::Syscalls::_bits_to_desc;
}
}

use constant {
    struct_rta_session_pack         =>  'Cx7',
    struct_rta_session_narg         =>     1,
    struct_rta_session_pack_ports   =>  'Cx3SS',
    struct_rta_session_narg_ports   =>     3,
    struct_rta_session_pack_icmpt   =>  'Cx3CCS',
    struct_rta_session_narg_icmpt   =>     4,
    struct_rta_session_pack_spi     =>  'Cx3L',
    struct_rta_session_narg_spi     =>     2,
    struct_rta_session_len          =>     8,   # == 1+1+2+2+2 == 1+1+2+1+1+2 = 1+1+2+4
};

    #   struct rta_session {
    #       uint8_t    proto;
    #       uint8_t    pad1;
    #       uint16_t   pad2;
    #
    #       union {
    #           struct {
    #               uint16_t   sport;
    #               uint16_t   dport;
    #           } ports;
    #
    #           struct {
    #               uint8_t    type;
    #               uint8_t    code;
    #               uint16_t   ident;
    #           } icmpt;
    #
    #           uint32_t           spi;
    #       } u;
    #   };

use constant {
    struct_rta_mfc_stats_pack   =>  'QQQ',
    struct_rta_mfc_stats_narg   =>     3,
    struct_rta_mfc_stats_len    =>    24,   # == 8+8+8
};

    #   struct rta_mfc_stats {
    #       uint64_t    mfcs_packets;
    #       uint64_t    mfcs_bytes;
    #       uint64_t    mfcs_wrong_if;
    #   };

################################################################
#####           General form of address family dependent message.
#####

# common prefix of all msg types

use constant {
    struct_rtgenmsg_pack        => 'Cx3',
    struct_rtgenmsg_narg        =>     1,
    struct_rtgenmsg_len         =>     4,   # == 1+3
};

    #   struct rtgenmsg {
    #       uint8_t     rtgen_family; /* (unsigned char) */
    #   };

################################################################
#               Link layer specific messages.
#

## struct ifinfomsg
## passes link level specific information, not dependent
## on network protocol.

use constant {
    struct_ifinfomsg_pack       =>  'CxSiII',
    struct_ifinfomsg_narg       =>     5,
    struct_ifinfomsg_len        =>    16,   # == 1+1+2+4+4+4
};

    #   struct ifinfomsg {
    #       unsigned char   ifi_family;
    #       unsigned char   __ifi_pad;
    #       unsigned short  ifi_type;          // ARPHRD_*             from <linux/if_arp.h> (0 for any)
    #       int             ifi_index;         // Link index           (as previously determined; 0 for unknown)
    #       unsigned        ifi_flags;         // IFF_* flags          from <linux/if.h>
    #       unsigned        ifi_change;        // IFF_* change mask    from <linux/if.h>
    #   };

################################################################
#               prefix information
#

use constant {
    struct_prefixmsg_pack       =>  'CxSiCCCC',
    struct_prefixmsg_narg       =>     7,
    struct_prefixmsg_len        =>    12,   # == 1+1+2+4+1+1+1+1
};

    #   struct prefixmsg {
    #       unsigned char  prefix_family;
    #       unsigned char  prefix_pad1;
    #       unsigned short prefix_pad2;
    #       int       prefix_ifindex;
    #       unsigned char  prefix_type;
    #       unsigned char  prefix_len;
    #       unsigned char  prefix_flags;
    #       unsigned char  prefix_pad3;
    #   };

use constant {
    PREFIX_UNSPEC       =>     0,
    PREFIX_ADDRESS      =>     1,
    PREFIX_CACHEINFO    =>     2,

  # PREFIX_MAX          =>     2 | 0,
};


{
my @names = qw( unspec address cacheinfo );
sub PREFIX_FAMILY_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub PREFIX_FAMILY_to_name($) { return &PREFIX_FAMILY_to_label // "code#$_[0]" }
}
use constant {
    struct_prefix_cacheinfo_pack    =>  'LL',
    struct_prefix_cacheinfo_narg    =>     2,
    struct_prefix_cacheinfo_len     =>     8,   # == 4+4
};
    #   struct prefix_cacheinfo {
    #        uint32_t   preferred_time;
    #        uint32_t   valid_time;
    #   };


################################################################
#               Traffic control messages.
#

use constant {
    struct_tcmsg_pack           => 'CCSix![L]LLL',
    struct_tcmsg_narg           =>     7,
    struct_tcmsg_len            =>    20,   # == 1+1+2+4+4+4+4
};
    #   struct tcmsg {
    #       unsigned char      tcm_family;
    #       unsigned char      tcm__pad1;
    #       unsigned short     tcm__pad2;
    #       int                tcm_ifindex;
    #       uint32_t           tcm_handle;
    #       uint32_t           tcm_parent;
    #       uint32_t           tcm_info;
    #   };

use constant {
    TCA_UNSPEC      =>     0,
    TCA_KIND        =>     1,
    TCA_OPTIONS     =>     2,
    TCA_STATS       =>     3,
    TCA_XSTATS      =>     4,
    TCA_RATE        =>     5,
    TCA_FCNT        =>     6,
    TCA_STATS2      =>     7,
    TCA_STAB        =>     8,

  # TCA_MAX         =>     8 | 0,
};

{
my @names = qw( unspec kind options stats xstats rate fcnt stats2 stab );
sub TCA_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub TCA_to_name($) { return &TCA_to_label // "code#$_[0]" }
}

#define TCA_RTA(r)  ((struct rtattr*)(((char*)(r)) + NLMSG_ALIGN(sizeof(struct tcmsg))))
#define TCA_PAYLOAD(n) NLMSG_PAYLOAD(n,sizeof(struct tcmsg))

################################################################
#               Neighbor Discovery userland options
#

use constant {
    struct_nduseroptmsg_pack    => 'CxSiCCSI',
    struct_nduseroptmsg_narg    =>     7,
    struct_nduseroptmsg_len     =>    16,
};

    #   struct nduseroptmsg {
    #        unsigned char   nduseropt_family;
    #        unsigned char   nduseropt_pad1;
    #        unsigned short  nduseropt_opts_len;     # Total length of options
    #        int             nduseropt_ifindex;
    #        uint8_t            nduseropt_icmp_type;
    #        uint8_t            nduseropt_icmp_code;
    #        unsigned short  nduseropt_pad2;
    #        unsigned int    nduseropt_pad3;
    #        # Followed by one or more ND options
    #   };

use constant {
    NDUSEROPT_UNSPEC    =>     0,
    NDUSEROPT_SRCADDR   =>     1,

  # NDUSEROPT_MAX       =>     1 | 0,
};

{
my @names = qw( unspec srcaddr );
sub NDUSEROPT_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub NDUSEROPT_to_name($) { return &NDUSEROPT_to_label // "code#$_[0]" }
}

# RTnetlink multicast groups - backwards compatibility for userspace
use constant {
    RTMGRP_LINK                 => _B  0,  # =       1
    RTMGRP_NOTIFY               => _B  1,  # =       2
    RTMGRP_NEIGH                => _B  2,  # =       4
    RTMGRP_TC                   => _B  3,  # =       8

    RTMGRP_IPV4_IFADDR          => _B  4,  # =    0x10
    RTMGRP_IPV4_MROUTE          => _B  5,  # =    0x20
    RTMGRP_IPV4_ROUTE           => _B  6,  # =    0x40
    RTMGRP_IPV4_RULE            => _B  7,  # =    0x80

    RTMGRP_IPV6_IFADDR          => _B  8,  # =   0x100
    RTMGRP_IPV6_MROUTE          => _B  9,  # =   0x200
    RTMGRP_IPV6_ROUTE           => _B 10,  # =   0x400
    RTMGRP_IPV6_IFINFO          => _B 11,  # =   0x800

    RTMGRP_DECnet_IFADDR        => _B 12,  # =  0x1000
    RTMGRP_DECnet_ROUTE         => _B 14,  # =  0x4000

    RTMGRP_IPV6_PREFIX          => _B 17,  # = 0x20000
};

# RTnetlink multicast groups (enum rtnetlink_groups)
use constant {
    RTNLGRP_NONE                =>     0,
    RTNLGRP_LINK                =>     1,
    RTNLGRP_NOTIFY              =>     2,
    RTNLGRP_NEIGH               =>     3,
    RTNLGRP_TC                  =>     4,
    RTNLGRP_IPV4_IFADDR         =>     5,
    RTNLGRP_IPV4_MROUTE         =>     6,
    RTNLGRP_IPV4_ROUTE          =>     7,
    RTNLGRP_IPV4_RULE           =>     8,
    RTNLGRP_IPV6_IFADDR         =>     9,
    RTNLGRP_IPV6_MROUTE         =>    10,
    RTNLGRP_IPV6_ROUTE          =>    11,
    RTNLGRP_IPV6_IFINFO         =>    12,
    RTNLGRP_DECnet_IFADDR       =>    13,
    RTNLGRP_NOP2                =>    14,
    RTNLGRP_DECnet_ROUTE        =>    15,
    RTNLGRP_DECnet_RULE         =>    16,
    RTNLGRP_NOP4                =>    17,
    RTNLGRP_IPV6_PREFIX         =>    18,
    RTNLGRP_IPV6_RULE           =>    19,
    RTNLGRP_ND_USEROPT          =>    20,
    RTNLGRP_PHONET_IFADDR       =>    21,
    RTNLGRP_PHONET_ROUTE        =>    22,
    RTNLGRP_DCB                 =>    23,
    RTNLGRP_IPV4_NETCONF        =>    24,
    RTNLGRP_IPV6_NETCONF        =>    25,
    RTNLGRP_MDB                 =>    26,
    RTNLGRP_MPLS_ROUTE          =>    27,
    RTNLGRP_NSID                =>    28,

  # RTNLGRP_MAX                 =>    28 | 0,
};

# TC action piece
use constant {
    struct_tcamsg_pack  => 'Cx![L]',
    struct_tcamsg_narg  =>     1,
    struct_tcamsg_len   =>     4,
};
    #   struct tcamsg {
    #        unsigned char   tca_family;
    #        unsigned char   tca__pad1;
    #        unsigned short  tca__pad2;
    #   };

#define TA_RTA(r)  ((struct rtattr*)(((char*)(r)) + NLMSG_ALIGN(sizeof(struct tcamsg))))
#define TA_PAYLOAD(n) NLMSG_PAYLOAD(n,sizeof(struct tcamsg))

use constant {
    TCA_ACT_TAB                 =>     1, # attr type must be >=1

  # TCAA_MAX                    =>     1 | 0,
};

# New extended info filters for IFLA_EXT_MASK
use constant {
    RTEXT_FILTER_VF                 => _B  0,
    RTEXT_FILTER_BRVLAN             => _B  1,
    RTEXT_FILTER_BRVLAN_COMPRESSED  => _B  2,
    RTEXT_FILTER_SKIP_STATS         => _B  3,
};

{
my @names = qw( vf brvlan brvlan_comp skip_stats );
sub RTEXT_FILTER_to_desc($) {
    splice @_, 1, 0, \@names;
    goto &Linux::Syscalls::_bits_to_desc;
}
}

# End of information exported to user level

use constant {
    NETLINK_ROUTE               =>     0,   # Routing/device hook
  # NETLINK_UNUSED              =>     1,   # Unused number
    NETLINK_USERSOCK            =>     2,   # Reserved for user mode socket protocols
    NETLINK_FIREWALL            =>     3,   # Unused number, formerly ip_queue
    NETLINK_SOCK_DIAG           =>     4,   # socket monitoring
    NETLINK_NFLOG               =>     5,   # netfilter/iptables ULOG
    NETLINK_XFRM                =>     6,   # ipsec
    NETLINK_SELINUX             =>     7,   # SELinux event notifications
    NETLINK_ISCSI               =>     8,   # Open-iSCSI
    NETLINK_AUDIT               =>     9,   # auditing
    NETLINK_FIB_LOOKUP          =>    10,   #
    NETLINK_CONNECTOR           =>    11,
    NETLINK_NETFILTER           =>    12,   # netfilter subsystem
    NETLINK_IP6_FW              =>    13,
    NETLINK_DNRTMSG             =>    14,   # DECnet routing messages
    NETLINK_KOBJECT_UEVENT      =>    15,   # Kernel messages to userspace
    NETLINK_GENERIC             =>    16,
    NETLINK_DM                  =>    17,
    NETLINK_SCSITRANSPORT       =>    18,   # SCSI Transports
    NETLINK_ECRYPTFS            =>    19,
    NETLINK_RDMA                =>    20,
    NETLINK_CRYPTO              =>    21,   # Crypto layer
    NETLINK_SMC                 =>    22,   # SMC monitoring
};

use constant {
    NETLINK_INET_DIAG           =>  NETLINK_SOCK_DIAG
};

{
my @names = ( 'ROUTE', undef, qw(
    USERSOCK FIREWALL SOCK_DIAG NFLOG XFRM SELINUX ISCSI AUDIT
    FIB_LOOKUP CONNECTOR NETFILTER IP6_FW DNRTMSG KOBJECT_UEVENT GENERIC DM
    SCSITRANSPORT ECRYPTFS RDMA CRYPTO SMC
));
sub NETLINK_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub NETLINK_to_name($) { return &NETLINK_to_label // "code#$_[0]" }
}

use constant {
    struct_sockaddr_nl_pack     =>  'Sx[S]LL',
    struct_sockaddr_nl_narg     =>     3,
    struct_sockaddr_nl_len      =>    12,   # 2+2+4+4 == length pack struct_sockaddr_nl_pack, (0) x 3;
};

    #   struct sockaddr_nl {
    #       uint16_t    nl_family;     /* set to AF_NETLINK (__kernel_sa_family_t = unsigned short) */
    #       uint16_t    [[0_pad]];     /* padding to align next field to u32 */
    #       uint32_t    nl_pid;        /* port ID  */
    #       uint32_t    nl_groups;     /* multicast groups mask */
    #   };

use constant {
    struct_nlmsghdr_pack        =>  'LSSLL',
    struct_nlmsghdr_narg        =>     5,
    struct_nlmsghdr_len         =>    16,   # 4+2+2+4+4 == length pack struct_nlmsghdr_pack, (0) x 5;
};
    #   struct nlmsghdr {
    #       uint32_t    nlmsg_len;      /* Length of message including header */
    #       uint16_t    nlmsg_type;     /* Message content */
    #       uint16_t    nlmsg_flags;    /* Additional flags */
    #       uint32_t    nlmsg_seq;      /* Sequence number */
    #       uint32_t    nlmsg_pid;      /* Sending process port ID */
    #   };

# Flags values
use constant {
    NLM_F_REQUEST               => _B  0,   #   0x1     It is request message.
    NLM_F_MULTI                 => _B  1,   #   0x2     Multipart message, terminated by NLMSG_DONE
    NLM_F_ACK                   => _B  2,   #   0x4     Reply with ack, with zero or error code
    NLM_F_ECHO                  => _B  3,   #   0x8     Echo this request
    NLM_F_DUMP_INTR             => _B  4,   #  0x10     Dump was inconsistent due to sequence change
    NLM_F_DUMP_FILTERED         => _B  5,   #  0x20     Dump was filtered as requested

    # Modifiers to GET request
    NLM_F_ROOT                  => _B  8,   # 0x100     Specify tree root
    NLM_F_MATCH                 => _B  9,   # 0x200     Return all matching
    NLM_F_DUMP                  =>            0x300,    # == NLM_F_ROOT | NLM_F_MATCH,
    NLM_F_ATOMIC                => _B 10,   # 0x400     Atomic GET

    # Modifiers to NEW request
    NLM_F_REPLACE               => _B  8,   # 0x100     Override existing
    NLM_F_EXCL                  => _B  9,   # 0x200     Do not touch, if it exists
    NLM_F_CREATE                => _B 10,   # 0x400     Create, if it does not exist
    NLM_F_APPEND                => _B 11,   # 0x800     Add to end of list

    # Modifiers to DELETE request
    NLM_F_NONREC                => _B  8,   # 0x100     Do not delete recursively

    # Flags for ACK message
    NLM_F_CAPPED                => _B  8,   # 0x100     Request was capped
    NLM_F_ACK_TLVS              => _B  9,   # 0x200     Extended ACK TVLs were included
};

use constant {
    NETLINK_ADD_MEMBERSHIP      =>     1,
    NETLINK_DROP_MEMBERSHIP     =>     2,
    NETLINK_PKTINFO             =>     3,
    NETLINK_BROADCAST_ERROR     =>     4,
    NETLINK_NO_ENOBUFS          =>     5,
    NETLINK_RX_RING             =>     6,
    NETLINK_TX_RING             =>     7,
    NETLINK_LISTEN_ALL_NSID     =>     8,
    NETLINK_LIST_MEMBERSHIPS    =>     9,
    NETLINK_CAP_ACK             =>    10,
    NETLINK_EXT_ACK             =>    11,
    NETLINK_GET_STRICT_CHK      =>    12,
};

use constant {
    struct_nl_pktinfo_pack      =>   'L',
    struct_nl_pktinfo_narg      =>     1,
    struct_nl_pktinfo_len       =>     4,   # == length pack struct_nl_pktinfo_pack, 0;
};

    #   struct nl_pktinfo {
    #       uint32_t group;
    #   };

use constant {
    struct_nl_mmap_req_pack     =>  'I4',
    struct_nl_mmap_req_narg     =>     4,
    struct_nl_mmap_req_len      =>    16,   # == length pack struct_nl_mmap_req_pack, (0) x 4;
};

    #   struct nl_mmap_req {
    #       unsigned int nm_block_size;
    #       unsigned int nm_block_nr;
    #       unsigned int nm_frame_size;
    #       unsigned int nm_frame_nr;
    #   };

use constant {
    struct_nl_mmap_hdr_pack     =>  'IILL3',
    struct_nl_mmap_hdr_narg     =>     6,
    struct_nl_mmap_hdr_len      =>    24,   # == length pack struct_nl_mmap_hdr_pack, (0) x 6;
};

    #   struct nl_mmap_hdr {
    #       unsigned int nm_status;
    #       unsigned int nm_len;
    #       uint32_t nm_group;
    #       /* credentials */
    #       uint32_t  nm_pid;
    #       uint32_t  nm_uid;
    #       uint32_t  nm_gid;
    #   };

# (enum nl_mmap_status)
use constant {
    NL_MMAP_STATUS_UNUSED       =>     0,
    NL_MMAP_STATUS_RESERVED     =>     1,
    NL_MMAP_STATUS_VALID        =>     2,
    NL_MMAP_STATUS_COPY         =>     3,
    NL_MMAP_STATUS_SKIP         =>     4,
};

# NLMSG_ALIGNTO         4U      /* == sizeof(uint32_t) */
# NLMSG_ALIGN(len)      ( ((len)+NLMSG_ALIGNTO-1) & ~(NLMSG_ALIGNTO-1) )
# NLMSG_HDRLEN          ((int) NLMSG_ALIGN(sizeof(struct nlmsghdr)))
# NLMSG_LENGTH(len)     ((len) + NLMSG_HDRLEN)
# NLMSG_SPACE(len)      NLMSG_ALIGN(NLMSG_LENGTH(len))
# NLMSG_DATA(nlh)       ((void *)(((char *)nlh) + NLMSG_HDRLEN))
# NLMSG_NEXT(nlh,len)   ((len) -= NLMSG_ALIGN((nlh)->nlmsg_len), (struct nlmsghdr *)(((char *)(nlh)) + NLMSG_ALIGN((nlh)->nlmsg_len)))
# NLMSG_OK(nlh,len)     ((len) >= (int)sizeof(struct nlmsghdr) && (nlh)->nlmsg_len >= sizeof(struct nlmsghdr) && (nlh)->nlmsg_len <= (len))
# NLMSG_PAYLOAD(nlh,len) ((nlh)->nlmsg_len - NLMSG_SPACE((len)))

use constant {
    NLMSG_NOOP                  =>     1,    # Nothing.
    NLMSG_ERROR                 =>     2,    # Error
    NLMSG_DONE                  =>     3,    # End of a dump
    NLMSG_OVERRUN               =>     4,    # Data lost

  # NLMSG_MIN_TYPE              =>  0x10,   # < 0x10: reserved control messages
};

# NL_MMAP_MSG_ALIGNMENT       NLMSG_ALIGNTO
# NL_MMAP_MSG_ALIGN(sz)       __ALIGN_KERNEL(sz, NL_MMAP_MSG_ALIGNMENT)
# NL_MMAP_HDRLEN              NL_MMAP_MSG_ALIGN(sizeof(struct nl_mmap_hdr))

use constant {
    NET_MAJOR                   =>  36,         # Major 36 is reserved for networking
};

use constant {
    NETLINK_UNCONNECTED => 0,
    NETLINK_CONNECTED   => 1,
};

our %EXPORT_TAGS = (

    pack => [qw[

        struct_ifinfomsg_pack
        struct_ifinfomsg_len

        struct_nduseroptmsg_pack
        struct_nduseroptmsg_len

        struct_nl_mmap_hdr_pack
        struct_nl_mmap_hdr_len

        struct_nl_mmap_req_pack
        struct_nl_mmap_req_len

        struct_nl_pktinfo_pack
        struct_nl_pktinfo_len

        struct_nlmsghdr_pack
        struct_nlmsghdr_len

        struct_prefix_cacheinfo_pack
        struct_prefix_cacheinfo_len

        struct_prefixmsg_pack
        struct_prefixmsg_len

        struct_rta_cacheinfo_pack
        struct_rta_cacheinfo_len

        struct_rta_mfc_stats_len
        struct_rta_mfc_stats_pack

        struct_rta_session_pack_icmpt
        struct_rta_session_pack_ports
        struct_rta_session_pack_spi
        struct_rta_session_len

        struct_rtgenmsg_pack
        struct_rtgenmsg_len

        struct_rtattr_pack
        struct_rtattr_len

        struct_rtmsg_pack
        struct_rtmsg_len

        struct_rtnexthop_pack
        struct_rtnexthop_len

        struct_rtvia_pack

        struct_sockaddr_nl_pack
        struct_sockaddr_nl_len

        struct_tcamsg_pack
        struct_tcamsg_len

        struct_tcmsg_pack
        struct_tcmsg_len
    ]],

    nduseropt => [qw[
        NDUSEROPT_SRCADDR
        NDUSEROPT_UNSPEC
        NDUSEROPT_to_name
    ]],

    netlink => [qw[
        NETLINK_AUDIT
        NETLINK_CONNECTOR
        NETLINK_CRYPTO
        NETLINK_DM
        NETLINK_DNRTMSG
        NETLINK_ECRYPTFS
        NETLINK_FIB_LOOKUP
        NETLINK_FIREWALL
        NETLINK_GENERIC
        NETLINK_INET_DIAG
        NETLINK_IP6_FW
        NETLINK_ISCSI
        NETLINK_KOBJECT_UEVENT
        NETLINK_NETFILTER
        NETLINK_NFLOG
        NETLINK_RDMA
        NETLINK_ROUTE
        NETLINK_SCSITRANSPORT
        NETLINK_SELINUX
        NETLINK_SMC
        NETLINK_SOCK_DIAG
        NETLINK_USERSOCK
        NETLINK_XFRM
        NETLINK_to_name
    ]],

    netlink_options => [qw[
        NETLINK_ADD_MEMBERSHIP
        NETLINK_BROADCAST_ERROR
        NETLINK_CAP_ACK
        NETLINK_DROP_MEMBERSHIP
        NETLINK_EXT_ACK
        NETLINK_GET_STRICT_CHK
        NETLINK_LISTEN_ALL_NSID
        NETLINK_LIST_MEMBERSHIPS
        NETLINK_NO_ENOBUFS
        NETLINK_PKTINFO
        NETLINK_RX_RING
        NETLINK_TX_RING
    ]],

    netlink_state => [qw[
        NETLINK_UNCONNECTED
        NETLINK_CONNECTED
    ]],

    nlm_status => [qw[
        NL_MMAP_STATUS_COPY
        NL_MMAP_STATUS_RESERVED
        NL_MMAP_STATUS_SKIP
        NL_MMAP_STATUS_UNUSED
        NL_MMAP_STATUS_VALID
    ]],

    nlm_types => [qw[
        NLMSG_DONE
        NLMSG_ERROR
        NLMSG_NOOP
        NLMSG_OVERRUN
    ]],

    nlm_flags => [qw[
        NLM_F_ACK
        NLM_F_DUMP_FILTERED
        NLM_F_DUMP_INTR
        NLM_F_ECHO
        NLM_F_MULTI
        NLM_F_REQUEST

        NLM_F_ATOMIC
        NLM_F_DUMP
        NLM_F_MATCH
        NLM_F_ROOT

        NLM_F_APPEND
        NLM_F_CREATE
        NLM_F_EXCL
        NLM_F_REPLACE

        NLM_F_NONREC

        NLM_F_ACK_TLVS
        NLM_F_CAPPED
    ]],

    rtm => [sort qw[
        RTM_BASE
        RTM_MAX
        RTM_OMASK
        RTM_OSHIFT
        RTM_TMASK
        RTM_TMAX
        RTM_TMIN
        RTM_TSHIFT
        RTM_to_name
        RTM_op_to_label
        RTM_op_to_name
        RTM_type_to_label
        RTM_type_to_name
        ],
        @RTM_symbols,
        ],

    rtm_flags => [qw[
        RTM_F_CLONED
        RTM_F_EQUALIZE
        RTM_F_LOOKUP_TABLE
        RTM_F_NOTIFY
        RTM_F_PREFIX
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
        RTN_to_name
    ]],

    rtnl_family => [qw[
        RTNL_FAMILY_IPMR
        RTNL_FAMILY_IP6MR
        RTNL_FAMILY_to_name
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
        RTPROT_to_name
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
        RTNHF_to_desc
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
        RTAX_to_name
    ]],

    rtax_features => [qw[
        RTAX_FEATURE_ALLFRAG
        RTAX_FEATURE_ECN
        RTAX_FEATURE_MASK
        RTAX_FEATURE_SACK
        RTAX_FEATURE_TIMESTAMP
        RTAXF_to_desc
    ]],

    prefix => [qw[
        PREFIX_ADDRESS
        PREFIX_CACHEINFO
        PREFIX_UNSPEC
        PREFIX_FAMILY_to_label
        PREFIX_FAMILY_to_name
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
        TCA_to_name
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

#   tca_act => [qw[
#       TCA_ACT_TAB
#   ]],

    rtext => [qw[
        RTEXT_FILTER_BRVLAN
        RTEXT_FILTER_BRVLAN_COMPRESSED
        RTEXT_FILTER_SKIP_STATS
        RTEXT_FILTER_VF
        RTEXT_FILTER_to_desc
    ]],
);

# Items that don't belong to any group
my @export_allowed = qw(
    NET_MAJOR
    RTNETLINK_HAVE_PEERINFO
    TCA_ACT_TAB
);

{
my %seen;
our @EXPORT_OK = grep { ! $seen{$_} }
                    @export_allowed,
                    map { @$_ } values %EXPORT_TAGS;

$EXPORT_TAGS{ALL} = \@EXPORT_OK;
}

1;
