#!/module/for/perl

use 5.010;
use strict;
use warnings;

package Linux::IpRoute2::ip v0.0.1;

use Exporter 'import';

sub _B($) { 1 << pop }

# The latest drafts declared increase in minimal mtu up to 1280.

use constant {
    IPV6_MIN_MTU                =>  1280,
};

#
#    Advanced API
#    source interface/address selection, source routing, etc...
#    *under construction*
#

use constant {
    struct_in6_pktinfo_pack     => 'a16L',
    struct_in6_pktinfo_len      =>    20,
};
    #   struct in6_pktinfo {
    #       struct in6_addr ipi6_addr;
    #       int             ipi6_ifindex;
    #   };

use constant {
    struct_ip6_mtuinfo_pack     => 'a28L',
    struct_ip6_mtuinfo_len      =>    32,
};
    #   struct ip6_mtuinfo {
    #           struct sockaddr_in6     ip6m_addr;
    #           __u32                   ip6m_mtu;
    #   };


use constant {
    struct_in6_ifreq_pack       => 'a16LL',
    struct_in6_ifreq_len        =>    24,
};
    #   struct in6_ifreq {
    #           struct in6_addr ifr6_addr;
    #           __u32           ifr6_prefixlen;
    #           int             ifr6_ifindex;
    #   };

use constant {
    IPV6_SRCRT_TYPE_0           =>     0,   # Deprecated; will be removed
    IPV6_SRCRT_STRICT           =>     1,   # Deprecated; will be removed
    IPV6_SRCRT_TYPE_2           =>     2,   # IPv6 type 2 Routing Header
};

#
# routing header
#
use constant {
    struct_ipv6_rt_hdr_pack     => 'CCCC',
    struct_ipv6_rt_hdr_len      =>     4,
};
    #   struct ipv6_rt_hdr {
    #       __u8    nexthdr;
    #       __u8    hdrlen;
    #       __u8    type;
    #       __u8    segments_left;
    #       /*
    #        *  type specific data
    #        *  variable length field
    #        */
    #   };

use constant {
    struct_ipv6_opt_hdr_pack    =>  'CC',
    struct_ipv6_opt_hdr_len     =>     2,
};
    #   struct ipv6_opt_hdr {
    #       __u8    nexthdr;
    #       __u8    hdrlen;
    #       /*
    #        * TLV encoded option data follows.
    #        */
    #   } __attribute__((packed));

#define ipv6_destopt_hdr ipv6_opt_hdr
#define ipv6_hopopt_hdr  ipv6_opt_hdr

# Router Alert option values (RFC2711)
use constant {
    IPV6_OPT_ROUTERALERT_MLD    => 0x0000,  # MLD(RFC2710)
};

#
# routing header type 0 (used in cmsghdr struct)
#

use constant {
    struct_rt0_hdr_pack         => 'a4x4a*',
  # struct_rt0_hdr_len          =>     8,
};

    #   struct rt0_hdr {
    #           struct ipv6_rt_hdr      rt_hdr;
    #           __u32                   reserved;
    #           struct in6_addr         addr[0];
    #
    #   #define rt0_type                rt_hdr.type
    #   };
    #
#
# routing header type 2
#

use constant {
    struct_rt2_hdr_pack         => 'a4x4a16',
    struct_rt2_hdr_len          =>    24,
};
    #   struct rt2_hdr {
    #           struct ipv6_rt_hdr      rt_hdr;
    #           __u32                   reserved;
    #           struct in6_addr         addr;
    #
    #   #define rt2_type                rt_hdr.type
    #   };
    #

#
# home address option in destination options header
#

use constant {
    struct_ipv6_destopt_hao_pack        => 'CCa16',
    struct_ipv6_destopt_hao_len         => 18,
};

    #   struct ipv6_destopt_hao {
    #           __u8                    type;
    #           __u8                    length;
    #           struct in6_addr         addr;
    #   } __attribute__((packed));
    #

#
#  IPv6 fixed header
#
#  BEWARE, it is incorrect. The first 4 bits of flow_lbl
#  are glued to priority now, forming "class".
#


use constant {
    struct_ipv6hdr_pack             => 'Ca3nCCa16a16',
    struct_ipv6hdr_len              =>    40,
};
    #   struct ipv6hdr {
    #       __u8                priority:4,
    #                           version:4;
    #
    #       __u8                flow_lbl[3];
    #
    #       __be16              payload_len;
    #       __u8                nexthdr;
    #       __u8                hop_limit;
    #
    #       struct      in6_addr        saddr;
    #       struct      in6_addr        daddr;
    #   };


# index values for the variables in ipv6_devconf
use constant {
    DEVCONF_FORWARDING                          =>      0,
    DEVCONF_HOPLIMIT                            =>      1,
    DEVCONF_MTU6                                =>      2,
    DEVCONF_ACCEPT_RA                           =>      3,
    DEVCONF_ACCEPT_REDIRECTS                    =>      4,
    DEVCONF_AUTOCONF                            =>      5,
    DEVCONF_DAD_TRANSMITS                       =>      6,
    DEVCONF_RTR_SOLICITS                        =>      7,
    DEVCONF_RTR_SOLICIT_INTERVAL                =>      8,
    DEVCONF_RTR_SOLICIT_DELAY                   =>      9,
    DEVCONF_USE_TEMPADDR                        =>     10,
    DEVCONF_TEMP_VALID_LFT                      =>     11,
    DEVCONF_TEMP_PREFERED_LFT                   =>     12,
    DEVCONF_REGEN_MAX_RETRY                     =>     13,
    DEVCONF_MAX_DESYNC_FACTOR                   =>     14,
    DEVCONF_MAX_ADDRESSES                       =>     15,
    DEVCONF_FORCE_MLD_VERSION                   =>     16,
    DEVCONF_ACCEPT_RA_DEFRTR                    =>     17,
    DEVCONF_ACCEPT_RA_PINFO                     =>     18,
    DEVCONF_ACCEPT_RA_RTR_PREF                  =>     19,
    DEVCONF_RTR_PROBE_INTERVAL                  =>     20,
    DEVCONF_ACCEPT_RA_RT_INFO_MAX_PLEN          =>     21,
    DEVCONF_PROXY_NDP                           =>     22,
    DEVCONF_OPTIMISTIC_DAD                      =>     23,
    DEVCONF_ACCEPT_SOURCE_ROUTE                 =>     24,
    DEVCONF_MC_FORWARDING                       =>     25,
    DEVCONF_DISABLE_IPV6                        =>     26,
    DEVCONF_ACCEPT_DAD                          =>     27,
    DEVCONF_FORCE_TLLAO                         =>     28,
    DEVCONF_NDISC_NOTIFY                        =>     29,
    DEVCONF_MLDV1_UNSOLICITED_REPORT_INTERVAL   =>     30,
    DEVCONF_MLDV2_UNSOLICITED_REPORT_INTERVAL   =>     31,
    DEVCONF_SUPPRESS_FRAG_NDISC                 =>     32,
    DEVCONF_ACCEPT_RA_FROM_LOCAL                =>     33,
    DEVCONF_USE_OPTIMISTIC                      =>     34,
    DEVCONF_ACCEPT_RA_MTU                       =>     35,
    DEVCONF_STABLE_SECRET                       =>     36,
    DEVCONF_USE_OIF_ADDRS_ONLY                  =>     37,
    DEVCONF_ACCEPT_RA_MIN_HOP_LIMIT             =>     38,
    DEVCONF_IGNORE_ROUTES_WITH_LINKDOWN         =>     39,
    DEVCONF_MAX                                 =>     40,
};




our %EXPORT_TAGS = (

    devconf => [qw[
        DEVCONF_FORWARDING
        DEVCONF_HOPLIMIT
        DEVCONF_MTU6
        DEVCONF_ACCEPT_RA
        DEVCONF_ACCEPT_REDIRECTS
        DEVCONF_AUTOCONF
        DEVCONF_DAD_TRANSMITS
        DEVCONF_RTR_SOLICITS
        DEVCONF_RTR_SOLICIT_INTERVAL
        DEVCONF_RTR_SOLICIT_DELAY
        DEVCONF_USE_TEMPADDR
        DEVCONF_TEMP_VALID_LFT
        DEVCONF_TEMP_PREFERED_LFT
        DEVCONF_REGEN_MAX_RETRY
        DEVCONF_MAX_DESYNC_FACTOR
        DEVCONF_MAX_ADDRESSES
        DEVCONF_FORCE_MLD_VERSION
        DEVCONF_ACCEPT_RA_DEFRTR
        DEVCONF_ACCEPT_RA_PINFO
        DEVCONF_ACCEPT_RA_RTR_PREF
        DEVCONF_RTR_PROBE_INTERVAL
        DEVCONF_ACCEPT_RA_RT_INFO_MAX_PLEN
        DEVCONF_PROXY_NDP
        DEVCONF_OPTIMISTIC_DAD
        DEVCONF_ACCEPT_SOURCE_ROUTE
        DEVCONF_MC_FORWARDING
        DEVCONF_DISABLE_IPV6
        DEVCONF_ACCEPT_DAD
        DEVCONF_FORCE_TLLAO
        DEVCONF_NDISC_NOTIFY
        DEVCONF_MLDV1_UNSOLICITED_REPORT_INTERVAL
        DEVCONF_MLDV2_UNSOLICITED_REPORT_INTERVAL
        DEVCONF_SUPPRESS_FRAG_NDISC
        DEVCONF_ACCEPT_RA_FROM_LOCAL
        DEVCONF_USE_OPTIMISTIC
        DEVCONF_ACCEPT_RA_MTU
        DEVCONF_STABLE_SECRET
        DEVCONF_USE_OIF_ADDRS_ONLY
        DEVCONF_ACCEPT_RA_MIN_HOP_LIMIT
        DEVCONF_IGNORE_ROUTES_WITH_LINKDOWN
    ]],

    limits => [qw[
        DEVCONF_MAX
    ]],

    pack => [qw[
        struct_in6_ifreq_len
        struct_in6_ifreq_pack
        struct_in6_pktinfo_len
        struct_in6_pktinfo_pack
        struct_ip6_mtuinfo_len
        struct_ip6_mtuinfo_pack
        struct_ipv6_destopt_hao_len
        struct_ipv6_destopt_hao_pack
        struct_ipv6_opt_hdr_len
        struct_ipv6_opt_hdr_pack
        struct_ipv6_rt_hdr_len
        struct_ipv6_rt_hdr_pack
        struct_ipv6hdr_len
        struct_ipv6hdr_pack
        struct_rt0_hdr_pack
        struct_rt2_hdr_len
        struct_rt2_hdr_pack
    ]],

);

my @export_allowed = qw(
    IPV6_SRCRT_TYPE_2
    IPV6_MIN_MTU
    IPV6_OPT_ROUTERALERT_MLD
);

my @export_deprecated = qw(
    IPV6_SRCRT_STRICT
    IPV6_SRCRT_TYPE_0
);

our @EXPORT_OK = (@export_allowed,
                  @export_deprecated,
                  map { @$_ } values %EXPORT_TAGS);

$EXPORT_TAGS{everything} = \@EXPORT_OK;

1;
