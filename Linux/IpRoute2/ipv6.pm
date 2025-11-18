#!/module/for/perl

use 5.010;
use strict;
use warnings;

package Linux::IpRoute2::ipv6 v0.0.1;

use Exporter 'import';

BEGIN { say "loading ".__PACKAGE__ }

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
    IPV6_SRCRT_TYPE_3           =>     3,   # RPL Segment Routing with IPv6
    IPV6_SRCRT_TYPE_4           =>     4,   # Segment Routing with IPv6
    IPV6_SRCRT_MAX              =>     5 - 1 | 0,
};

{
my @names = qw(
    type_0
    strict
    type_2
    type_3
    type_4
);
sub IPV6_SRCRT_to_label($) { return $_[0] >= 0 && $names[$_[0]] || () }
sub IPV6_SRCRT_to_name($) { return &IPV6_SRCRT_to_label || "code#$_[0]" }
}

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
    IPV6_OPT_ROUTERALERT_MLD    =>     0,  # MLD(RFC2710)
    IPV6_OPT_MAX                =>     1 - 1 | 0,
};

{
my @names = qw( routeralert_mld );
sub IPV6_OPT_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub IPV6_OPT_to_name($) { return &IPV6_OPT_to_label // "code#$_[0]" }
}

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
    DEVCONF_MIN                                 =>      0,
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
    DEVCONF_DROP_UNICAST_IN_L2_MULTICAST        =>     40,
    DEVCONF_DROP_UNSOLICITED_NA                 =>     41,
    DEVCONF_KEEP_ADDR_ON_DOWN                   =>     42,
    DEVCONF_RTR_SOLICIT_MAX_INTERVAL            =>     43,
    DEVCONF_SEG6_ENABLED                        =>     44,
    DEVCONF_SEG6_REQUIRE_HMAC                   =>     45,
    DEVCONF_ENHANCED_DAD                        =>     46,
    DEVCONF_ADDR_GEN_MODE                       =>     47,
    DEVCONF_DISABLE_POLICY                      =>     48,
    DEVCONF_ACCEPT_RA_RT_INFO_MIN_PLEN          =>     49,
    DEVCONF_NDISC_TCLASS                        =>     50,
    DEVCONF_RPL_SEG_ENABLED                     =>     51,
    DEVCONF_RA_DEFRTR_METRIC                    =>     52,
    DEVCONF_IOAM6_ENABLED                       =>     53,
    DEVCONF_IOAM6_ID                            =>     54,
    DEVCONF_IOAM6_ID_WIDE                       =>     55,
    DEVCONF_NDISC_EVICT_NOCARRIER               =>     56,
    DEVCONF_ACCEPT_UNTRACKED_NA                 =>     57,
    DEVCONF_ACCEPT_RA_MIN_LFT                   =>     58,
    DEVCONF_MAX                                 =>     59 - 1 | 0,
};

{
my @names = qw(
    forwarding hoplimit mtu6 accept_ra accept_redirects autoconf dad_transmits
    rtr_solicits rtr_solicit_interval rtr_solicit_delay use_tempaddr
    temp_valid_lft temp_prefered_lft regen_max_retry max_desync_factor
    max_addresses force_mld_version accept_ra_defrtr accept_ra_pinfo
    accept_ra_rtr_pref rtr_probe_interval accept_ra_rt_info_max_plen proxy_ndp
    optimistic_dad accept_source_route mc_forwarding disable_ipv6 accept_dad
    force_tllao ndisc_notify mldv1_unsolicited_report_interval
    mldv2_unsolicited_report_interval suppress_frag_ndisc accept_ra_from_local
    use_optimistic accept_ra_mtu stable_secret use_oif_addrs_only
    accept_ra_min_hop_limit ignore_routes_with_linkdown
    drop_unicast_in_l2_multicast drop_unsolicited_na keep_addr_on_down
    rtr_solicit_max_interval seg6_enabled seg6_require_hmac enhanced_dad
    addr_gen_mode disable_policy accept_ra_rt_info_min_plen ndisc_tclass
    rpl_seg_enabled ra_defrtr_metric ioam6_enabled ioam6_id ioam6_id_wide
    ndisc_evict_nocarrier accept_untracked_na accept_ra_min_lft
);
sub DEVCONF_to_label($) { return $_[0] >= 0 ? $names[$_[0]] : () }
sub DEVCONF_to_name($) { return &DEVCONF_to_label // "code#$_[0]" }
}

our %EXPORT_TAGS = (

    devconf => [qw[
        DEVCONF_ACCEPT_DAD
        DEVCONF_ACCEPT_RA
        DEVCONF_ACCEPT_RA_DEFRTR
        DEVCONF_ACCEPT_RA_FROM_LOCAL
        DEVCONF_ACCEPT_RA_MIN_HOP_LIMIT
        DEVCONF_ACCEPT_RA_MIN_LFT
        DEVCONF_ACCEPT_RA_MTU
        DEVCONF_ACCEPT_RA_PINFO
        DEVCONF_ACCEPT_RA_RTR_PREF
        DEVCONF_ACCEPT_RA_RT_INFO_MAX_PLEN
        DEVCONF_ACCEPT_RA_RT_INFO_MIN_PLEN
        DEVCONF_ACCEPT_REDIRECTS
        DEVCONF_ACCEPT_SOURCE_ROUTE
        DEVCONF_ACCEPT_UNTRACKED_NA
        DEVCONF_ADDR_GEN_MODE
        DEVCONF_AUTOCONF
        DEVCONF_DAD_TRANSMITS
        DEVCONF_DISABLE_IPV6
        DEVCONF_DISABLE_POLICY
        DEVCONF_DROP_UNICAST_IN_L2_MULTICAST
        DEVCONF_DROP_UNSOLICITED_NA
        DEVCONF_ENHANCED_DAD
        DEVCONF_FORCE_MLD_VERSION
        DEVCONF_FORCE_TLLAO
        DEVCONF_FORWARDING
        DEVCONF_HOPLIMIT
        DEVCONF_IGNORE_ROUTES_WITH_LINKDOWN
        DEVCONF_IOAM6_ENABLED
        DEVCONF_IOAM6_ID
        DEVCONF_IOAM6_ID_WIDE
        DEVCONF_KEEP_ADDR_ON_DOWN
        DEVCONF_MAX
        DEVCONF_MAX_ADDRESSES
        DEVCONF_MAX_DESYNC_FACTOR
        DEVCONF_MC_FORWARDING
        DEVCONF_MIN
        DEVCONF_MLDV1_UNSOLICITED_REPORT_INTERVAL
        DEVCONF_MLDV2_UNSOLICITED_REPORT_INTERVAL
        DEVCONF_MTU6
        DEVCONF_NDISC_EVICT_NOCARRIER
        DEVCONF_NDISC_NOTIFY
        DEVCONF_NDISC_TCLASS
        DEVCONF_OPTIMISTIC_DAD
        DEVCONF_PROXY_NDP
        DEVCONF_RA_DEFRTR_METRIC
        DEVCONF_REGEN_MAX_RETRY
        DEVCONF_RPL_SEG_ENABLED
        DEVCONF_RTR_PROBE_INTERVAL
        DEVCONF_RTR_SOLICITS
        DEVCONF_RTR_SOLICIT_DELAY
        DEVCONF_RTR_SOLICIT_INTERVAL
        DEVCONF_RTR_SOLICIT_MAX_INTERVAL
        DEVCONF_SEG6_ENABLED
        DEVCONF_SEG6_REQUIRE_HMAC
        DEVCONF_STABLE_SECRET
        DEVCONF_SUPPRESS_FRAG_NDISC
        DEVCONF_TEMP_PREFERED_LFT
        DEVCONF_TEMP_VALID_LFT
        DEVCONF_USE_OIF_ADDRS_ONLY
        DEVCONF_USE_OPTIMISTIC
        DEVCONF_USE_TEMPADDR
        DEVCONF_to_label
        DEVCONF_to_name
    ]],

    ipv6_opt => [qw[
        IPV6_OPT_MAX
        IPV6_OPT_ROUTERALERT_MLD
        IPV6_OPT_to_label
        IPV6_OPT_to_name
    ]],

    labels => [qw[
        DEVCONF_to_label
        IPV6_OPT_to_label
        IPV6_SRCRT_to_label
    ]],

    limits => [qw[
        DEVCONF_MAX
        DEVCONF_MIN
        IPV6_OPT_MAX
        IPV6_SRCRT_MAX
    ]],

    names => [qw[
        DEVCONF_to_name
        IPV6_OPT_to_name
        IPV6_SRCRT_to_name
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

    ipv6_srcrt => [qw[
        IPV6_SRCRT_MAX
        IPV6_SRCRT_TYPE_2
        IPV6_SRCRT_TYPE_3
        IPV6_SRCRT_TYPE_4
        IPV6_SRCRT_to_label
        IPV6_SRCRT_to_name
    ]],

);

# Items that don't belong to any group
my @export_allowed = qw(
    IPV6_MIN_MTU
    IPV6_OPT_ROUTERALERT_MLD
);

# Items that shouldn't be used in new code
my @export_deprecated = qw(
    IPV6_SRCRT_STRICT
    IPV6_SRCRT_TYPE_0
);

my %seen;
our @EXPORT_OK = grep { ! $seen{$_}++ }
                    @export_allowed,
                    @export_deprecated,
                    map { @$_ } values %EXPORT_TAGS;

$EXPORT_TAGS{everything} = \@EXPORT_OK;

1;
