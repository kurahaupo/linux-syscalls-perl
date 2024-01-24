#!/module/for/perl

use v5.10;
use strict;
use warnings;

package Linux::IpRoute2::if_link v0.0.1;

# Copied and adapted from <linux/if_link.h>
#           /usr/include/linux/if_link.h
# [iproute2]include/uapi/linux/if_link.h

use Exporter 'import';

use Utils::EnumTools '_B';

use constant {
    struct_rtnl_link_stats32_pack       => 'L24',
    struct_rtnl_link_stats32_len        =>    96,   # == length pack struct_rtnl_link_stats32_pack, (0) x 24;
};
    # This struct should be in sync with struct rtnl_link_stats64
    #   struct rtnl_link_stats {
    #       __u32           rx_packets;
    #       __u32           tx_packets;
    #       __u32           rx_bytes;
    #       __u32           tx_bytes;
    #       __u32           rx_errors;
    #       __u32           tx_errors;
    #       __u32           rx_dropped;
    #       __u32           tx_dropped;
    #       __u32           multicast;
    #       __u32           collisions;
    #       # detailed rx_errors:
    #       __u32           rx_length_errors;
    #       __u32           rx_over_errors;
    #       __u32           rx_crc_errors;
    #       __u32           rx_frame_errors;
    #       __u32           rx_fifo_errors;
    #       __u32           rx_missed_errors;
    #       # detailed tx_errors
    #       __u32           tx_aborted_errors;
    #       __u32           tx_carrier_errors;
    #       __u32           tx_fifo_errors;
    #       __u32           tx_heartbeat_errors;
    #       __u32           tx_window_errors;
    #       # for cslip etc
    #       __u32           rx_compressed;
    #       __u32           tx_compressed;
    #       __u32           rx_nohandler;
    #   };

use constant {
    struct_rtnl_link_stats64_pack       => 'Q24',
    struct_rtnl_link_stats64_len        =>   192,   # == length pack struct_rtnl_link_stats64_pack, (0) x 24;
};
    #   struct rtnl_link_stats64 {
    #       __u64           rx_packets;
    #       __u64           tx_packets;
    #       __u64           rx_bytes;
    #       __u64           tx_bytes;
    #       __u64           rx_errors;
    #       __u64           tx_errors;
    #       __u64           rx_dropped;
    #       __u64           tx_dropped;
    #       __u64           multicast;
    #       __u64           collisions;
    #       __u64           rx_length_errors;
    #       __u64           rx_over_errors;
    #       __u64           rx_crc_errors;
    #       __u64           rx_frame_errors;
    #       __u64           rx_fifo_errors;
    #       __u64           rx_missed_errors;
    #       __u64           tx_aborted_errors;
    #       __u64           tx_carrier_errors;
    #       __u64           tx_fifo_errors;
    #       __u64           tx_heartbeat_errors;
    #       __u64           tx_window_errors;
    #       __u64           rx_compressed;
    #       __u64           tx_compressed;
    #       __u64           rx_nohandler;
    #   };

use constant {
    struct_rtnl_link_ifmap_pack         => 'QQQSCCx![Q]',
    struct_rtnl_link_ifmap_len          =>    32,   # == length pack struct_rtnl_link_ifmap_pack, (0) x 24
};
    # The struct should be in sync with struct ifmap
    #   struct rtnl_link_ifmap {
    #       __u64           mem_start;
    #       __u64           mem_end;
    #       __u64           base_addr;
    #       __u16           irq;
    #       __u8            dma;
    #       __u8            port;
    #   };

#
# IFLA_AF_SPEC
#   Contains nested attributes for address family specific attributes.
#   Each address family may create a attribute with the address family
#   number as type and create its own attribute structure in it.
#
#   Example:
#   [IFLA_AF_SPEC] = {
#       [AF_INET] = {
#           [IFLA_INET_CONF] = ...,
#       },
#       [AF_INET6] = {
#           [IFLA_INET6_FLAGS] = ...,
#           [IFLA_INET6_CONF] = ...,
#       }
#   }
#

use constant {
    IFLA_UNSPEC                         =>     0,
    IFLA_ADDRESS                        =>     1,
    IFLA_BROADCAST                      =>     2,
    IFLA_IFNAME                         =>     3,
    IFLA_MTU                            =>     4,
    IFLA_LINK                           =>     5,
    IFLA_QDISC                          =>     6,
    IFLA_STATS                          =>     7,
    IFLA_COST                           =>     8,
    IFLA_PRIORITY                       =>     9,
    IFLA_MASTER                         =>    10,
    IFLA_WIRELESS                       =>    11,       # Wireless Extension event - see wireless.h
    IFLA_PROTINFO                       =>    12,       # Protocol specific information for a link
    IFLA_TXQLEN                         =>    13,
    IFLA_MAP                            =>    14,
    IFLA_WEIGHT                         =>    15,
    IFLA_OPERSTATE                      =>    16,
    IFLA_LINKMODE                       =>    17,
    IFLA_LINKINFO                       =>    18,
    IFLA_NET_NS_PID                     =>    19,
    IFLA_IFALIAS                        =>    20,
    IFLA_NUM_VF                         =>    21,       # Number of VFs if device is SR-IOV PF
    IFLA_VFINFO_LIST                    =>    22,
    IFLA_STATS64                        =>    23,
    IFLA_VF_PORTS                       =>    24,
    IFLA_PORT_SELF                      =>    25,
    IFLA_AF_SPEC                        =>    26,
    IFLA_GROUP                          =>    27,       # Group the device belongs to
    IFLA_NET_NS_FD                      =>    28,
    IFLA_EXT_MASK                       =>    29,       # Extended info mask, VFs, etc
    IFLA_PROMISCUITY                    =>    30,       # Promiscuity count: > 0 means acts PROMISC
    IFLA_NUM_TX_QUEUES                  =>    31,
    IFLA_NUM_RX_QUEUES                  =>    32,
    IFLA_CARRIER                        =>    33,
    IFLA_PHYS_PORT_ID                   =>    34,
    IFLA_CARRIER_CHANGES                =>    35,
    IFLA_PHYS_SWITCH_ID                 =>    36,
    IFLA_LINK_NETNSID                   =>    37,
    IFLA_PHYS_PORT_NAME                 =>    38,
    IFLA_PROTO_DOWN                     =>    39,
    IFLA_GSO_MAX_SEGS                   =>    40,
    IFLA_GSO_MAX_SIZE                   =>    41,
    IFLA_PAD                            =>    42,
    IFLA_XDP                            =>    43,
    IFLA_EVENT                          =>    44,
    IFLA_NEW_NETNSID                    =>    45,
    IFLA_TARGET_NETNSID                 =>    46,       # New name for IFLA_IF_NETNSID
    IFLA_CARRIER_UP_COUNT               =>    47,
    IFLA_CARRIER_DOWN_COUNT             =>    48,
    IFLA_NEW_IFINDEX                    =>    49,
    IFLA_MIN_MTU                        =>    50,
    IFLA_MAX_MTU                        =>    51,
    IFLA_PROP_LIST                      =>    52,
    IFLA_ALT_IFNAME                     =>    53,       # Alternative ifname
    IFLA_PERM_ADDRESS                   =>    54,
    IFLA_PROTO_DOWN_REASON              =>    55,
    IFLA_PARENT_DEV_NAME                =>    56,
    IFLA_PARENT_DEV_BUS_NAME            =>    57,
  # IFLA_MAX                            =>    58 - 1 | 0,
};

{
my @ifla_names = qw(
    unspec address broadcast ifname mtu link qdisc stats cost priority master
    wireless protinfo txqlen map weight operstate linkmode linkinfo net_ns_pid
    ifalias num_vf vfinfo_list stats64 vf_ports port_self af_spec group
    net_ns_fd ext_mask promiscuity num_tx_queues num_rx_queues carrier
    phys_port_id carrier_changes phys_switch_id link_netnsid phys_port_name
    proto_down gso_max_segs gso_max_size pad xdp event new_netnsid
    target_netnsid carrier_up_count carrier_down_count new_ifindex min_mtu
    max_mtu prop_list alt_ifname perm_address proto_down_reason parent_dev_name
    parent_dev_bus_name
);
sub IFLA_to_name($) { my $c = $_[0]; my $n = $ifla_names[$c] if $c >= 0; return $n // "code#$c"; }
}

use constant {
    # Deprecated, not exported by :ifla
    IFLA_IF_NETNSID                     =>  IFLA_TARGET_NETNSID,
};

use constant {
    IFLA_PROTO_DOWN_REASON_UNSPEC       =>     0,
    IFLA_PROTO_DOWN_REASON_MASK         =>     1,   # u32, mask for reason bits
    IFLA_PROTO_DOWN_REASON_VALUE        =>     2,   # u32, reason bit value
  # IFLA_PROTO_DOWN_REASON_MAX          =>     3 - 1 | 0,
};

# The following C macros have no corresponding method in Perl; instead we pack
# with 'x![L]' after the base and each option to force 4-byte alignment.

#define IFLA_RTA(r)  ((struct rtattr*)(((char*)(r)) + NLMSG_ALIGN(sizeof(struct ifinfomsg))))
#define IFLA_PAYLOAD(n) NLMSG_PAYLOAD(n,sizeof(struct ifinfomsg))

use constant {
    IFLA_INET_UNSPEC                    =>     0,
    IFLA_INET_CONF                      =>     1,
  # IFLA_INET_MAX                       =>     2 - 1 | 0,
};

#
# ifi_flags.
#
# IFF_* flags.
#
# The only change is:
# IFF_LOOPBACK, IFF_BROADCAST and IFF_POINTOPOINT are
# more not changeable by user. They describe link media
# characteristics and set by device driver.
#
# Comments:
# - Combination IFF_BROADCAST|IFF_POINTOPOINT is invalid
# - If neither of these three flags are set;
#   the interface is NBMA.
#
# - IFF_MULTICAST does not mean anything special:
# multicasts can be used on all not-NBMA links.
# IFF_MULTICAST means that this media uses special encapsulation
# for multicast frames. Apparently, all IFF_POINTOPOINT and
# IFF_BROADCAST devices are able to use multicasts too.
#
#
# IFLA_LINK.
# For usual devices it is equal ifi_index.
# If it is a "virtual interface" (f.e. tunnel), ifi_link
# can point to real physical interface (f.e. for bandwidth calculations),
# or maybe 0, what means, that real media is unknown (usual
# for IPIP tunnels, when route to endpoint is allowed to change)
#

# Subtype attributes for IFLA_PROTINFO
use constant {
    IFLA_INET6_UNSPEC                   =>     0,
    IFLA_INET6_FLAGS                    =>     1,       # link flags
    IFLA_INET6_CONF                     =>     2,       # sysctl parameters
    IFLA_INET6_STATS                    =>     3,       # statistics
    IFLA_INET6_MCAST                    =>     4,       # MC things. What of them?
    IFLA_INET6_CACHEINFO                =>     5,       # time values and max reasm size
    IFLA_INET6_ICMP6STATS               =>     6,       # statistics (icmpv6)
    IFLA_INET6_TOKEN                    =>     7,       # device token
    IFLA_INET6_ADDR_GEN_MODE            =>     8,       # implicit address generator mode
    IFLA_INET6_RA_MTU                   =>     9,       # mtu carried in the RA message
  # IFLA_INET6_MAX                      =>    10 - 1 | 0,
};

# enum in6_addr_gen_mode
use constant {
    IN6_ADDR_GEN_MODE_EUI64             =>     0,
    IN6_ADDR_GEN_MODE_NONE              =>     1,
    IN6_ADDR_GEN_MODE_STABLE_PRIVACY    =>     2,
    IN6_ADDR_GEN_MODE_RANDOM            =>     3,
};

# Bridge section

use constant {
    IFLA_BR_UNSPEC                      =>     0,
    IFLA_BR_FORWARD_DELAY               =>     1,
    IFLA_BR_HELLO_TIME                  =>     2,
    IFLA_BR_MAX_AGE                     =>     3,
    IFLA_BR_AGEING_TIME                 =>     4,
    IFLA_BR_STP_STATE                   =>     5,
    IFLA_BR_PRIORITY                    =>     6,
    IFLA_BR_VLAN_FILTERING              =>     7,
    IFLA_BR_VLAN_PROTOCOL               =>     8,
    IFLA_BR_GROUP_FWD_MASK              =>     9,
    IFLA_BR_ROOT_ID                     =>    10,
    IFLA_BR_BRIDGE_ID                   =>    11,
    IFLA_BR_ROOT_PORT                   =>    12,
    IFLA_BR_ROOT_PATH_COST              =>    13,
    IFLA_BR_TOPOLOGY_CHANGE             =>    14,
    IFLA_BR_TOPOLOGY_CHANGE_DETECTED    =>    15,
    IFLA_BR_HELLO_TIMER                 =>    16,
    IFLA_BR_TCN_TIMER                   =>    17,
    IFLA_BR_TOPOLOGY_CHANGE_TIMER       =>    18,
    IFLA_BR_GC_TIMER                    =>    19,
    IFLA_BR_GROUP_ADDR                  =>    20,
    IFLA_BR_FDB_FLUSH                   =>    21,
    IFLA_BR_MCAST_ROUTER                =>    22,
    IFLA_BR_MCAST_SNOOPING              =>    23,
    IFLA_BR_MCAST_QUERY_USE_IFADDR      =>    24,
    IFLA_BR_MCAST_QUERIER               =>    25,
    IFLA_BR_MCAST_HASH_ELASTICITY       =>    26,
    IFLA_BR_MCAST_HASH_MAX              =>    27,
    IFLA_BR_MCAST_LAST_MEMBER_CNT       =>    28,
    IFLA_BR_MCAST_STARTUP_QUERY_CNT     =>    29,
    IFLA_BR_MCAST_LAST_MEMBER_INTVL     =>    30,
    IFLA_BR_MCAST_MEMBERSHIP_INTVL      =>    31,
    IFLA_BR_MCAST_QUERIER_INTVL         =>    32,
    IFLA_BR_MCAST_QUERY_INTVL           =>    33,
    IFLA_BR_MCAST_QUERY_RESPONSE_INTVL  =>    34,
    IFLA_BR_MCAST_STARTUP_QUERY_INTVL   =>    35,
    IFLA_BR_NF_CALL_IPTABLES            =>    36,
    IFLA_BR_NF_CALL_IP6TABLES           =>    37,
    IFLA_BR_NF_CALL_ARPTABLES           =>    38,
    IFLA_BR_VLAN_DEFAULT_PVID           =>    39,
    IFLA_BR_PAD                         =>    40,
    IFLA_BR_VLAN_STATS_ENABLED          =>    41,
    IFLA_BR_MCAST_STATS_ENABLED         =>    42,
    IFLA_BR_MCAST_IGMP_VERSION          =>    43,
    IFLA_BR_MCAST_MLD_VERSION           =>    44,
    IFLA_BR_VLAN_STATS_PER_PORT         =>    45,
    IFLA_BR_MULTI_BOOLOPT               =>    46,
    IFLA_BR_MCAST_QUERIER_STATE         =>    47,
  # IFLA_BR_MAX                         =>    48 - 1 | 0,
};

use constant {
    struct_ifla_bridge_id_pack          => 'C2C4',
    struct_ifla_bridge_id_len           =>     6,   # == length pack struct_ifla_bridge_id_pack, (0) x 6
};
    #   struct ifla_bridge_id {
    #       __u8    prio[2];
    #       __u8    addr[6]; # ETH_ALEN
    #   };

use constant {
    BRIDGE_MODE_UNSPEC                  =>     0,
    BRIDGE_MODE_HAIRPIN                 =>     1,
};

use constant {
    IFLA_BRPORT_UNSPEC                  =>     0,
    IFLA_BRPORT_STATE                   =>     1,   # Spanning tree state
    IFLA_BRPORT_PRIORITY                =>     2,   # "             priority
    IFLA_BRPORT_COST                    =>     3,   # "             cost
    IFLA_BRPORT_MODE                    =>     4,   # mode (hairpin)
    IFLA_BRPORT_GUARD                   =>     5,   # bpdu guard
    IFLA_BRPORT_PROTECT                 =>     6,   # root port protection
    IFLA_BRPORT_FAST_LEAVE              =>     7,   # multicast fast leave
    IFLA_BRPORT_LEARNING                =>     8,   # mac learning
    IFLA_BRPORT_UNICAST_FLOOD           =>     9,   # flood unicast traffic
    IFLA_BRPORT_PROXYARP                =>    10,   # proxy ARP
    IFLA_BRPORT_LEARNING_SYNC           =>    11,   # mac learning sync from device
    IFLA_BRPORT_PROXYARP_WIFI           =>    12,   # proxy ARP for Wi-Fi
    IFLA_BRPORT_ROOT_ID                 =>    13,   # designated root
    IFLA_BRPORT_BRIDGE_ID               =>    14,   # designated bridge
    IFLA_BRPORT_DESIGNATED_PORT         =>    15,
    IFLA_BRPORT_DESIGNATED_COST         =>    16,
    IFLA_BRPORT_ID                      =>    17,
    IFLA_BRPORT_NO                      =>    18,
    IFLA_BRPORT_TOPOLOGY_CHANGE_ACK     =>    19,
    IFLA_BRPORT_CONFIG_PENDING          =>    20,
    IFLA_BRPORT_MESSAGE_AGE_TIMER       =>    21,
    IFLA_BRPORT_FORWARD_DELAY_TIMER     =>    22,
    IFLA_BRPORT_HOLD_TIMER              =>    23,
    IFLA_BRPORT_FLUSH                   =>    24,
    IFLA_BRPORT_MULTICAST_ROUTER        =>    25,
    IFLA_BRPORT_PAD                     =>    26,
    IFLA_BRPORT_MCAST_FLOOD             =>    27,
    IFLA_BRPORT_MCAST_TO_UCAST          =>    28,
    IFLA_BRPORT_VLAN_TUNNEL             =>    29,
    IFLA_BRPORT_BCAST_FLOOD             =>    30,
    IFLA_BRPORT_GROUP_FWD_MASK          =>    31,
    IFLA_BRPORT_NEIGH_SUPPRESS          =>    32,
    IFLA_BRPORT_ISOLATED                =>    33,
    IFLA_BRPORT_BACKUP_PORT             =>    34,
    IFLA_BRPORT_MRP_RING_OPEN           =>    35,
    IFLA_BRPORT_MRP_IN_OPEN             =>    36,
    IFLA_BRPORT_MCAST_EHT_HOSTS_LIMIT   =>    37,
    IFLA_BRPORT_MCAST_EHT_HOSTS_CNT     =>    38,
  # IFLA_BRPORT_MAX                     =>    39 - 1 | 0,
};

use constant {
    struct_ifla_cacheinfo_pack          =>  'L4',
    struct_ifla_cacheinfo_len           =>    16,   # == length pack struct_ifla_cacheinfo_pack, (0) x 4;
};
    #   struct ifla_cacheinfo {
    #       __u32                       max_reasm_len;
    #       __u32                       tstamp;                                                 # ipv6InterfaceTable updated timestamp
    #       __u32                       reachable_time;
    #       __u32                       retrans_time;
    #   };

use constant {
    IFLA_INFO_UNSPEC                    =>   0,
    IFLA_INFO_KIND                      =>   1,
    IFLA_INFO_DATA                      =>   2,
    IFLA_INFO_XSTATS                    =>   3,
    IFLA_INFO_SLAVE_KIND                =>   4,
    IFLA_INFO_SLAVE_DATA                =>   5,
  # IFLA_INFO_MAX                       =>   6 - 1 | 0,
};

# VLAN section

use constant {
    IFLA_VLAN_UNSPEC                    =>     0,
    IFLA_VLAN_ID                        =>     1,
    IFLA_VLAN_FLAGS                     =>     2,
    IFLA_VLAN_EGRESS_QOS                =>     3,
    IFLA_VLAN_INGRESS_QOS               =>     4,
    IFLA_VLAN_PROTOCOL                  =>     5,
  # IFLA_VLAN_MAX                       =>     6 - 1 | 0,
};

use constant {
    struct_ifla_vlan_flags_pack         =>  'LL',
    struct_ifla_vlan_flags_len          =>     8,   # == length pack struct_ifla_vlan_flags_pack, (0) x 2;
};
    #   struct ifla_vlan_flags {
    #       __u32                       flags;
    #       __u32                       mask;
    #   };

use constant {
    IFLA_VLAN_QOS_UNSPEC                =>     0,
    IFLA_VLAN_QOS_MAPPING               =>     1,
  # IFLA_VLAN_QOS_MAX                   =>     2 - 1 | 0,
};

use constant {
    struct_ifla_vlan_qos_mapping_pack   => 'LL',
    struct_ifla_vlan_qos_mapping_len    =>    8,   # == length pack struct_ifla_vlan_qos_mapping_pack, (0) x 2;
};
    #   struct ifla_vlan_qos_mapping {
    #       __u32 from;
    #       __u32 to;
    #   };

# MACVLAN section
use constant {
    IFLA_MACVLAN_UNSPEC                 =>     0,
    IFLA_MACVLAN_MODE                   =>     1,
    IFLA_MACVLAN_FLAGS                  =>     2,
    IFLA_MACVLAN_MACADDR_MODE           =>     3,
    IFLA_MACVLAN_MACADDR                =>     4,
    IFLA_MACVLAN_MACADDR_DATA           =>     5,
    IFLA_MACVLAN_MACADDR_COUNT          =>     6,
    IFLA_MACVLAN_BC_QUEUE_LEN           =>     7,
    IFLA_MACVLAN_BC_QUEUE_LEN_USED      =>     8,
  # IFLA_MACVLAN_MAX                    =>     9 - 1 | 0,
};

# enum macvlan_mode
use constant {
    MACVLAN_MODE_PRIVATE                =>     1,   # don't talk to other macvlans
    MACVLAN_MODE_VEPA                   =>     2,   # talk to other ports through ext bridge
    MACVLAN_MODE_BRIDGE                 =>     4,   # talk to bridge ports directly
    MACVLAN_MODE_PASSTHRU               =>     8,   # take over the underlying device
    MACVLAN_MODE_SOURCE                 =>    16,   # use source MAC address list to assign
};

use constant {
    MACVLAN_MACADDR_ADD                 =>     0,
    MACVLAN_MACADDR_DEL                 =>     1,
    MACVLAN_MACADDR_FLUSH               =>     2,
    MACVLAN_MACADDR_SET                 =>     3,
};

use constant {
    MACVLAN_FLAG_NOPROMISC              =>     1,
    MACVLAN_FLAG_NODST                  =>     2,   # skip dest macvlan if matching src macvlan
};

# VRF section
use constant {
    IFLA_VRF_UNSPEC                     =>     0,
    IFLA_VRF_TABLE                      =>     1,
  # IFLA_VRF_MAX                        =>     2 - 1 | 0,
};

use constant {
    IFLA_VRF_PORT_UNSPEC                =>     0,
    IFLA_VRF_PORT_TABLE                 =>     1,
  # IFLA_VRF_PORT_MAX                   =>     2 - 1 | 0,
};

# MACSEC section
use constant {
    IFLA_MACSEC_UNSPEC                  =>     0,
    IFLA_MACSEC_SCI                     =>     1,
    IFLA_MACSEC_PORT                    =>     2,
    IFLA_MACSEC_ICV_LEN                 =>     3,
    IFLA_MACSEC_CIPHER_SUITE            =>     4,
    IFLA_MACSEC_WINDOW                  =>     5,
    IFLA_MACSEC_ENCODING_SA             =>     6,
    IFLA_MACSEC_ENCRYPT                 =>     7,
    IFLA_MACSEC_PROTECT                 =>     8,
    IFLA_MACSEC_INC_SCI                 =>     9,
    IFLA_MACSEC_ES                      =>    10,
    IFLA_MACSEC_SCB                     =>    11,
    IFLA_MACSEC_REPLAY_PROTECT          =>    12,
    IFLA_MACSEC_VALIDATION              =>    13,
    IFLA_MACSEC_PAD                     =>    14,
    IFLA_MACSEC_OFFLOAD                 =>    15,
  # IFLA_MACSEC_MAX                     =>    16 - 1 | 0,
};

# XFRM section
use constant {
    IFLA_XFRM_UNSPEC                    =>     0,
    IFLA_XFRM_LINK                      =>     1,
    IFLA_XFRM_IF_ID                     =>     2,
  # IFLA_XFRM_MAX                       =>     3 - 1 | 0,
};

# enum macsec_validation_type
use constant {
    MACSEC_VALIDATE_DISABLED            =>     0,
    MACSEC_VALIDATE_CHECK               =>     1,
    MACSEC_VALIDATE_STRICT              =>     2,
  # MACSEC_VALIDATE_END                 =>     3 - 1 | 0,
};

# enum macsec_offload
use constant {
    MACSEC_OFFLOAD_OFF                  =>     0,
    MACSEC_OFFLOAD_PHY                  =>     1,
    MACSEC_OFFLOAD_MAC                  =>     2,
  # MACSEC_OFFLOAD_END                  =>     3 - 1 | 0,
};

# IPVLAN section
use constant {
    IFLA_IPVLAN_UNSPEC                  =>     0,
    IFLA_IPVLAN_MODE                    =>     1,
    IFLA_IPVLAN_FLAGS                   =>     2,
  # IFLA_IPVLAN_MAX                     =>     3 - 1 | 0,
};

#enum ipvlan_mode
use constant {
    IPVLAN_MODE_L2                      =>     0,
    IPVLAN_MODE_L3                      =>     1,
    IPVLAN_MODE_L3S                     =>     2,
  # IPVLAN_MODE_MAX                     =>     3,   # ?? usually these "_MAX" values are N-1
};

use constant {
    IPVLAN_F_PRIVATE                    =>  0x01,
    IPVLAN_F_VEPA                       =>  0x02,
};

# VXLAN section
use constant {
    IFLA_VXLAN_UNSPEC                   =>     0,
    IFLA_VXLAN_ID                       =>     1,
    IFLA_VXLAN_GROUP                    =>     2,   # group or remote address
    IFLA_VXLAN_LINK                     =>     3,
    IFLA_VXLAN_LOCAL                    =>     4,
    IFLA_VXLAN_TTL                      =>     5,
    IFLA_VXLAN_TOS                      =>     6,
    IFLA_VXLAN_LEARNING                 =>     7,
    IFLA_VXLAN_AGEING                   =>     8,
    IFLA_VXLAN_LIMIT                    =>     9,
    IFLA_VXLAN_PORT_RANGE               =>    10,   # source port
    IFLA_VXLAN_PROXY                    =>    11,
    IFLA_VXLAN_RSC                      =>    12,
    IFLA_VXLAN_L2MISS                   =>    13,
    IFLA_VXLAN_L3MISS                   =>    14,
    IFLA_VXLAN_PORT                     =>    15,   # destination port
    IFLA_VXLAN_GROUP6                   =>    16,
    IFLA_VXLAN_LOCAL6                   =>    17,
    IFLA_VXLAN_UDP_CSUM                 =>    18,
    IFLA_VXLAN_UDP_ZERO_CSUM6_TX        =>    19,
    IFLA_VXLAN_UDP_ZERO_CSUM6_RX        =>    20,
    IFLA_VXLAN_REMCSUM_TX               =>    21,
    IFLA_VXLAN_REMCSUM_RX               =>    22,
    IFLA_VXLAN_GBP                      =>    23,
    IFLA_VXLAN_REMCSUM_NOPARTIAL        =>    24,
    IFLA_VXLAN_COLLECT_METADATA         =>    25,
    IFLA_VXLAN_LABEL                    =>    26,
    IFLA_VXLAN_GPE                      =>    27,
    IFLA_VXLAN_TTL_INHERIT              =>    28,
    IFLA_VXLAN_DF                       =>    29,
    IFLA_VXLAN_FAN_MAP                  =>    33,
  # IFLA_VXLAN_MAX                      =>    34 - 1 | 0,
};

use constant {
    struct_ifla_vxlan_port_range_pack   => 'nn',    # network byte order, 16-bit
    struct_ifla_vxlan_port_range        =>    4,
};
    #   struct ifla_vxlan_port_range {
    #       __be16                      low;
    #       __be16                      high;
    #   };

# enum ifla_vxlan_df
use constant {
    VXLAN_DF_UNSET                      =>     0,
    VXLAN_DF_SET                        =>     1,
    VXLAN_DF_INHERIT                    =>     2,
  # VXLAN_DF_END                        =>     3 - 1 | 0,
};

# GENEVE section
use constant {
    IFLA_GENEVE_UNSPEC                  =>     0,
    IFLA_GENEVE_ID                      =>     1,
    IFLA_GENEVE_REMOTE                  =>     2,
    IFLA_GENEVE_TTL                     =>     3,
    IFLA_GENEVE_TOS                     =>     4,
    IFLA_GENEVE_PORT                    =>     5,   # destination port
    IFLA_GENEVE_COLLECT_METADATA        =>     6,
    IFLA_GENEVE_REMOTE6                 =>     7,
    IFLA_GENEVE_UDP_CSUM                =>     8,
    IFLA_GENEVE_UDP_ZERO_CSUM6_TX       =>     9,
    IFLA_GENEVE_UDP_ZERO_CSUM6_RX       =>    10,
    IFLA_GENEVE_LABEL                   =>    11,
    IFLA_GENEVE_TTL_INHERIT             =>    12,
    IFLA_GENEVE_DF                      =>    13,
  # IFLA_GENEVE_MAX                     =>    14 - 1 | 0,
};

# enum ifla_geneve_df
use constant {
    GENEVE_DF_UNSET                     =>     0,
    GENEVE_DF_SET                       =>     1,
    GENEVE_DF_INHERIT                   =>     2,
  # GENEVE_DF_END                       =>     3 - 1 | 0,
};

# Bareudp section
use constant {
    IFLA_BAREUDP_UNSPEC                 =>     0,
    IFLA_BAREUDP_PORT                   =>     1,
    IFLA_BAREUDP_ETHERTYPE              =>     2,
    IFLA_BAREUDP_SRCPORT_MIN            =>     3,
    IFLA_BAREUDP_MULTIPROTO_MODE        =>     4,
  # IFLA_BAREUDP_MAX                    =>     5 - 1 | 0,
};

# PPP section
use constant {
    IFLA_PPP_UNSPEC                     =>     0,
    IFLA_PPP_DEV_FD                     =>     1,
  # IFLA_PPP_MAX                        =>     2 - 1 | 0,
};

# GTP section

# enum ifla_gtp_role
use constant {
    GTP_ROLE_GGSN                       =>     0,
    GTP_ROLE_SGSN                       =>     1,
};

use constant {
    IFLA_GTP_UNSPEC                     =>     0,
    IFLA_GTP_FD0                        =>     1,
    IFLA_GTP_FD1                        =>     2,
    IFLA_GTP_PDP_HASHSIZE               =>     3,
    IFLA_GTP_ROLE                       =>     4,
  # IFLA_GTP_MAX                        =>     5 - 1 | 0,
};

# Bonding section

use constant {
    IFLA_BOND_UNSPEC                    =>     0,
    IFLA_BOND_MODE                      =>     1,
    IFLA_BOND_ACTIVE_SLAVE              =>     2,
    IFLA_BOND_MIIMON                    =>     3,
    IFLA_BOND_UPDELAY                   =>     4,
    IFLA_BOND_DOWNDELAY                 =>     5,
    IFLA_BOND_USE_CARRIER               =>     6,
    IFLA_BOND_ARP_INTERVAL              =>     7,
    IFLA_BOND_ARP_IP_TARGET             =>     8,
    IFLA_BOND_ARP_VALIDATE              =>     9,
    IFLA_BOND_ARP_ALL_TARGETS           =>    10,
    IFLA_BOND_PRIMARY                   =>    11,
    IFLA_BOND_PRIMARY_RESELECT          =>    12,
    IFLA_BOND_FAIL_OVER_MAC             =>    13,
    IFLA_BOND_XMIT_HASH_POLICY          =>    14,
    IFLA_BOND_RESEND_IGMP               =>    15,
    IFLA_BOND_NUM_PEER_NOTIF            =>    16,
    IFLA_BOND_ALL_SLAVES_ACTIVE         =>    17,
    IFLA_BOND_MIN_LINKS                 =>    18,
    IFLA_BOND_LP_INTERVAL               =>    19,
    IFLA_BOND_PACKETS_PER_SLAVE         =>    20,
    IFLA_BOND_AD_LACP_RATE              =>    21,
    IFLA_BOND_AD_SELECT                 =>    22,
    IFLA_BOND_AD_INFO                   =>    23,
    IFLA_BOND_AD_ACTOR_SYS_PRIO         =>    24,
    IFLA_BOND_AD_USER_PORT_KEY          =>    25,
    IFLA_BOND_AD_ACTOR_SYSTEM           =>    26,
    IFLA_BOND_TLB_DYNAMIC_LB            =>    27,
    IFLA_BOND_PEER_NOTIF_DELAY          =>    28,
    IFLA_BOND_AD_LACP_ACTIVE            =>    29,
  # IFLA_BOND_MAX                       =>    30 - 1 | 0,
};

use constant {
    IFLA_BOND_AD_INFO_UNSPEC            =>     0,
    IFLA_BOND_AD_INFO_AGGREGATOR        =>     1,
    IFLA_BOND_AD_INFO_NUM_PORTS         =>     2,
    IFLA_BOND_AD_INFO_ACTOR_KEY         =>     3,
    IFLA_BOND_AD_INFO_PARTNER_KEY       =>     4,
    IFLA_BOND_AD_INFO_PARTNER_MAC       =>     5,
  # IFLA_BOND_AD_INFO_MAX               =>     6 - 1 | 0,
};

use constant {
    IFLA_BOND_SLAVE_UNSPEC                      =>     0,
    IFLA_BOND_SLAVE_STATE                       =>     1,
    IFLA_BOND_SLAVE_MII_STATUS                  =>     2,
    IFLA_BOND_SLAVE_LINK_FAILURE_COUNT          =>     3,
    IFLA_BOND_SLAVE_PERM_HWADDR                 =>     4,
    IFLA_BOND_SLAVE_QUEUE_ID                    =>     5,
    IFLA_BOND_SLAVE_AD_AGGREGATOR_ID            =>     6,
    IFLA_BOND_SLAVE_AD_ACTOR_OPER_PORT_STATE    =>     7,
    IFLA_BOND_SLAVE_AD_PARTNER_OPER_PORT_STATE  =>     8,
  # IFLA_BOND_SLAVE_MAX                         =>     9 - 1 | 0,
};

# SR-IOV virtual function management section

use constant {
    IFLA_VF_INFO_UNSPEC                 =>     0,
    IFLA_VF_INFO                        =>     1,
  # IFLA_VF_INFO_MAX                    =>     2 - 1 | 0,
};

use constant {
    IFLA_VF_UNSPEC                      =>     0,
    IFLA_VF_MAC                         =>     1,  # Hardware queue specific attributes
    IFLA_VF_VLAN                        =>     2,  # VLAN ID and QoS
    IFLA_VF_TX_RATE                     =>     3,  # Max TX Bandwidth Allocation
    IFLA_VF_SPOOFCHK                    =>     4,  # Spoof Checking on/off switch
    IFLA_VF_LINK_STATE                  =>     5,  # link state enable/disable/auto switch
    IFLA_VF_RATE                        =>     6,  # Min and Max TX Bandwidth Allocation
    IFLA_VF_RSS_QUERY_EN                =>     7,  # RSS Redirection Table and Hash Key query on/off switch
    IFLA_VF_STATS                       =>     8,  # network device statistics
    IFLA_VF_TRUST                       =>     9,  # Trust VF
    IFLA_VF_IB_NODE_GUID                =>    10,  # VF Infiniband node GUID
    IFLA_VF_IB_PORT_GUID                =>    11,  # VF Infiniband port GUID
    IFLA_VF_VLAN_LIST                   =>    12,  # nested list of vlans, option for QinQ
    IFLA_VF_BROADCAST                   =>    13,  # VF broadcast
  # IFLA_VF_MAX                         =>    14 - 1 | 0,
};

use constant {
    struct_ifla_vf_mac_pack             => 'La32',
    struct_ifla_vf_mac_len              =>    36,   # == length pack struct_ifla_vf_mac_pack, 0, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
};
    #   struct ifla_vf_mac {
    #       __u32 vf;
    #       __u8 mac[32]; # MAX_ADDR_LEN
    #   };

use constant {
    struct_ifla_vf_broadcast_pack       => 'a32',
    struct_ifla_vf_broadcast_len        =>    32,
};
    #   struct ifla_vf_broadcast {
    #       __u8 broadcast[32];
    #   };

use constant {
    struct_ifla_vf_vlan_pack            => 'LLL',
    struct_ifla_vf_vlan_len             =>    12,
};
    #   struct ifla_vf_vlan {
    #       __u32 vf;
    #       __u32 vlan; # 0 - 4095, 0 disables VLAN filter
    #       __u32 qos;
    #   };

use constant {
    IFLA_VF_VLAN_INFO_UNSPEC            =>     0,
    IFLA_VF_VLAN_INFO                   =>     1,   # VLAN ID, QoS and VLAN protocol
  # IFLA_VF_VLAN_INFO_MAX               =>     2 - 1 | 0,
};

use constant {
    MAX_VLAN_LIST_LEN                   =>     1,
};

use constant {
    struct_ifla_vf_vlan_info_pack       =>  'L3nx![L]',
    struct_ifla_vf_vlan_info_len        =>    16,   # == length pack struct_ifla_vf_vlan_info_pack, (0) x 4;
};

    #   struct ifla_vf_vlan_info {
    #       __u32 vf;
    #       __u32 vlan; # 0 - 4095, 0 disables VLAN filter
    #       __u32 qos;
    #       __be16 vlan_proto; # VLAN protocol either 802.1Q or 802.1ad
    #   };

use constant {
    struct_ifla_vf_tx_rate_pack         =>  'LL',
    struct_ifla_vf_tx_rate_len          =>     8,   # == length pack
};

    #   struct ifla_vf_tx_rate {
    #       __u32 vf;
    #       __u32 rate; # Max TX bandwidth in Mbps, 0 disables throttling
    #   };

use constant {
    struct_ifla_vf_rate_pack            =>  'L3',
    struct_ifla_vf_rate_len             =>    12,
};

    #   struct ifla_vf_rate {
    #       __u32 vf;
    #       __u32 min_tx_rate; # Min Bandwidth in Mbps
    #       __u32 max_tx_rate; # Max Bandwidth in Mbps
    #   };

use constant {
    struct_ifla_vf_spoofchk_pack        =>  'LL',
    struct_ifla_vf_spoofchk_len         =>     8,
};

    #   struct ifla_vf_spoofchk {
    #       __u32 vf;
    #       __u32 setting;
    #   };

use constant {
    struct_ifla_vf_guid_pack            => 'Lx![Q]Q',
    struct_ifla_vf_guid_len             =>    16,
};

    #   struct ifla_vf_guid {
    #       __u32 vf;
    #       __u64 guid;
    #   };

use constant {
    IFLA_VF_LINK_STATE_AUTO             =>     0,   # link state of the uplink
    IFLA_VF_LINK_STATE_ENABLE           =>     1,   # link always up
    IFLA_VF_LINK_STATE_DISABLE          =>     2,   # link always down
  # IFLA_VF_LINK_STATE_MAX              =>     3,   # ??? check this, normally N-1
};

use constant {
    struct_ifla_vf_link_state_pack      =>  'LL',
    struct_ifla_vf_link_state_len       =>     8,
};

    #   struct ifla_vf_link_state {
    #       __u32 vf;
    #       __u32 link_state;
    #   };

use constant {
    struct_ifla_vf_rss_query_en_pack    =>  'LL',
    struct_ifla_vf_rss_query_en_len     =>     8,
};

    #   struct ifla_vf_rss_query_en {
    #       __u32 vf;
    #       __u32 setting;
    #   };

use constant {
    IFLA_VF_STATS_RX_PACKETS            =>     0,
    IFLA_VF_STATS_TX_PACKETS            =>     1,
    IFLA_VF_STATS_RX_BYTES              =>     2,
    IFLA_VF_STATS_TX_BYTES              =>     3,
    IFLA_VF_STATS_BROADCAST             =>     4,
    IFLA_VF_STATS_MULTICAST             =>     5,
    IFLA_VF_STATS_PAD                   =>     6,
    IFLA_VF_STATS_RX_DROPPED            =>     7,
    IFLA_VF_STATS_TX_DROPPED            =>     8,
  # IFLA_VF_STATS_MAX                   =>     9 - 1 | 0,
};

use constant {
    struct_ifla_vf_trust_pack    =>  'LL',
    struct_ifla_vf_trust_len     =>     8,
};

    #   struct ifla_vf_trust {
    #       __u32 vf;
    #       __u32 setting;
    #   };

#
# VF ports management section
#
# Nested layout of set/get msg is:
#
#  →  [IFLA_NUM_VF]
#  →  [IFLA_VF_PORTS]
#     →  [IFLA_VF_PORT]
#        →  [IFLA_PORT_*], ...
#     →  [IFLA_VF_PORT]
#        →  [IFLA_PORT_*], ...
#        ...
#  →  [IFLA_PORT_SELF]
#     →  [IFLA_PORT_*], ...
#

use constant {
    IFLA_VF_PORT_UNSPEC                 =>     0,
    IFLA_VF_PORT                        =>     1,   # nest
  # IFLA_VF_PORT_MAX                    =>     2 - 1 | 0,
};

use constant {
    IFLA_PORT_UNSPEC                    =>     0,
    IFLA_PORT_VF                        =>     1,   # __u32
    IFLA_PORT_PROFILE                   =>     2,   # string
    IFLA_PORT_VSI_TYPE                  =>     3,   # 802.1Qbg (pre-)standard VDP
    IFLA_PORT_INSTANCE_UUID             =>     4,   # binary UUID
    IFLA_PORT_HOST_UUID                 =>     5,   # binary UUID
    IFLA_PORT_REQUEST                   =>     6,   # __u8
    IFLA_PORT_RESPONSE                  =>     7,   # __u16, output only
  # IFLA_PORT_MAX                       =>     8 - 1 | 0,
};

use constant {
    PORT_PROFILE_MAX                    =>    40,
    PORT_UUID_MAX                       =>    16,
    PORT_SELF_VF                        =>    -1,
};

use constant {
    PORT_REQUEST_PREASSOCIATE           =>     0,
    PORT_REQUEST_PREASSOCIATE_RR        =>     1,
    PORT_REQUEST_ASSOCIATE              =>     2,
    PORT_REQUEST_DISASSOCIATE           =>     3,
};

use constant {
    PORT_VDP_RESPONSE_SUCCESS                           =>     0,
    PORT_VDP_RESPONSE_INVALID_FORMAT                    =>     1,
    PORT_VDP_RESPONSE_INSUFFICIENT_RESOURCES            =>     2,
    PORT_VDP_RESPONSE_UNUSED_VTID                       =>     3,
    PORT_VDP_RESPONSE_VTID_VIOLATION                    =>     4,
    PORT_VDP_RESPONSE_VTID_VERSION_VIOALTION            =>     5,
    PORT_VDP_RESPONSE_OUT_OF_SYNC                       =>     6,
    # 0x08-0xFF reserved for future VDP use
    PORT_PROFILE_RESPONSE_SUCCESS                       => 0x100,
    PORT_PROFILE_RESPONSE_INPROGRESS                    => 0x101,
    PORT_PROFILE_RESPONSE_INVALID                       => 0x102,
    PORT_PROFILE_RESPONSE_BADSTATE                      => 0x103,
    PORT_PROFILE_RESPONSE_INSUFFICIENT_RESOURCES        => 0x104,
    PORT_PROFILE_RESPONSE_ERROR                         => 0x105,
};

use constant {
    struct_ifla_port_vsi_pack    => 'CC3Cx3',
    struct_ifla_port_vsi_len     =>     8,
};

    #   struct ifla_port_vsi {
    #       __u8 vsi_mgr_id;
    #       __u8 vsi_type_id[3];
    #       __u8 vsi_type_version;
    #       __u8 pad[3];
    #   };

# IPoIB section

use constant {
    IFLA_IPOIB_UNSPEC                   =>     0,
    IFLA_IPOIB_PKEY                     =>     1,
    IFLA_IPOIB_MODE                     =>     2,
    IFLA_IPOIB_UMCAST                   =>     3,
  # IFLA_IPOIB_MAX                      =>     4 - 1 | 0,
};

use constant {
    IPOIB_MODE_DATAGRAM                 =>     0, # using unreliable datagram QPs
    IPOIB_MODE_CONNECTED                =>     1, # using connected QPs
};

# HSR/PRP section, both uses same interface

# Different redundancy protocols for hsr device
use constant {
    HSR_PROTOCOL_HSR                    =>     0,
    HSR_PROTOCOL_PRP                    =>     1,
    HSR_PROTOCOL_MAX                    =>     2,
};

use constant {
    IFLA_HSR_UNSPEC                     =>     0,
    IFLA_HSR_SLAVE1                     =>     1,
    IFLA_HSR_SLAVE2                     =>     2,
    IFLA_HSR_MULTICAST_SPEC             =>     3,   # Last byte of supervision addr
    IFLA_HSR_SUPERVISION_ADDR           =>     4,   # Supervision frame multicast addr
    IFLA_HSR_SEQ_NR                     =>     5,
    IFLA_HSR_VERSION                    =>     6,   # HSR version
    IFLA_HSR_PROTOCOL                   =>     7,   # Indicate different protocol than HSR. For example PRP.
  # IFLA_HSR_MAX                        =>     8 - 1 | 0,
};

# STATS section

use constant {
    struct_if_stats_msg_pack            => 'Cx3LL',
    struct_if_stats_msg_len             =>    12,   # length pack struct_if_stats_msg_pack, (0) x 3;
};

    #   struct if_stats_msg {
    #       __u8  family;
    #       __u8  pad1;
    #       __u16 pad2;
    #       __u32 ifindex;
    #       __u32 filter_mask;
    #   };

# A stats attribute can be netdev specific or a global stat.
# For netdev stats, lets use the prefix IFLA_STATS_LINK_*

use constant {
    IFLA_STATS_UNSPEC                   =>     0,   # also used as 64bit pad attribute
    IFLA_STATS_LINK_64                  =>     1,
    IFLA_STATS_LINK_XSTATS              =>     2,
    IFLA_STATS_LINK_XSTATS_SLAVE        =>     3,
    IFLA_STATS_LINK_OFFLOAD_XSTATS      =>     4,
    IFLA_STATS_AF_SPEC                  =>     5,
  # IFLA_STATS_MAX                      =>     6 - 1 | 0,
};

sub IFLA_STATS_FILTER_BIT($) { my ($attr) = @_; 1 << $attr - 1 }

# These are embedded into IFLA_STATS_LINK_XSTATS:
# [IFLA_STATS_LINK_XSTATS]
# -> [LINK_XSTATS_TYPE_xxx]
#    -> [rtnl link type specific attributes]

use constant {
    LINK_XSTATS_TYPE_UNSPEC             =>     0,
    LINK_XSTATS_TYPE_BRIDGE             =>     1,
    LINK_XSTATS_TYPE_BOND               =>     2,
  # LINK_XSTATS_TYPE_MAX                =>     3 - 1 | 0,
};

# These are stats embedded into IFLA_STATS_LINK_OFFLOAD_XSTATS
use constant {
    IFLA_OFFLOAD_XSTATS_UNSPEC          =>     0,
    IFLA_OFFLOAD_XSTATS_CPU_HIT         =>     1,   # struct rtnl_link_stats64
  # IFLA_OFFLOAD_XSTATS_MAX             =>     2 - 1 | 0,
};

# XDP section

use constant {
    XDP_FLAGS_UPDATE_IF_NOEXIST         =>  _B 0,
    XDP_FLAGS_SKB_MODE                  =>  _B 1,
    XDP_FLAGS_DRV_MODE                  =>  _B 2,
    XDP_FLAGS_HW_MODE                   =>  _B 3,
    XDP_FLAGS_REPLACE                   =>  _B 4,
    XDP_FLAGS_MODES                     =>  0x0e,   # XDP_FLAGS_SKB_MODE | XDP_FLAGS_DRV_MODE | XDP_FLAGS_HW_MODE,
    XDP_FLAGS_MASK                      =>  0x1f,   # XDP_FLAGS_UPDATE_IF_NOEXIST | XDP_FLAGS_MODES | XDP_FLAGS_REPLACE,
};

# These are stored into IFLA_XDP_ATTACHED on dump.
use constant {
    XDP_ATTACHED_NONE                   =>     0,
    XDP_ATTACHED_DRV                    =>     1,
    XDP_ATTACHED_SKB                    =>     2,
    XDP_ATTACHED_HW                     =>     3,
    XDP_ATTACHED_MULTI                  =>     4,
};

use constant {
    IFLA_XDP_UNSPEC                     =>     0,
    IFLA_XDP_FD                         =>     1,
    IFLA_XDP_ATTACHED                   =>     2,
    IFLA_XDP_FLAGS                      =>     3,
    IFLA_XDP_PROG_ID                    =>     4,
    IFLA_XDP_DRV_PROG_ID                =>     5,
    IFLA_XDP_SKB_PROG_ID                =>     6,
    IFLA_XDP_HW_PROG_ID                 =>     7,
    IFLA_XDP_EXPECTED_FD                =>     8,
  # IFLA_XDP_MAX                        =>     9 - 1 | 0,
};

use constant {
    IFLA_EVENT_NONE                     =>     0,
    IFLA_EVENT_REBOOT                   =>     1,   # internal reset / reboot
    IFLA_EVENT_FEATURES                 =>     2,   # change in offload features
    IFLA_EVENT_BONDING_FAILOVER         =>     3,   # change in active slave
    IFLA_EVENT_NOTIFY_PEERS             =>     4,   # re-sent grat. arp/ndisc
    IFLA_EVENT_IGMP_RESEND              =>     5,   # re-sent IGMP JOIN
    IFLA_EVENT_BONDING_OPTIONS          =>     6,   # change in bonding options
};

# tun section

use constant {
    IFLA_TUN_UNSPEC                     =>     0,
    IFLA_TUN_OWNER                      =>     1,
    IFLA_TUN_GROUP                      =>     2,
    IFLA_TUN_TYPE                       =>     3,
    IFLA_TUN_PI                         =>     4,
    IFLA_TUN_VNET_HDR                   =>     5,
    IFLA_TUN_PERSIST                    =>     6,
    IFLA_TUN_MULTI_QUEUE                =>     7,
    IFLA_TUN_NUM_QUEUES                 =>     8,
    IFLA_TUN_NUM_DISABLED_QUEUES        =>     9,
  # IFLA_TUN_MAX                        =>    10 - 1 | 0,
};

# rmnet section

use constant {
    RMNET_FLAGS_INGRESS_DEAGGREGATION   =>  _B 0,
    RMNET_FLAGS_INGRESS_MAP_COMMANDS    =>  _B 1,
    RMNET_FLAGS_INGRESS_MAP_CKSUMV4     =>  _B 2,
    RMNET_FLAGS_EGRESS_MAP_CKSUMV4      =>  _B 3,
    RMNET_FLAGS_INGRESS_MAP_CKSUMV5     =>  _B 4,
    RMNET_FLAGS_EGRESS_MAP_CKSUMV5      =>  _B 5,
};

use constant {
    IFLA_RMNET_UNSPEC                   =>     0,
    IFLA_RMNET_MUX_ID                   =>     1,
    IFLA_RMNET_FLAGS                    =>     2,
  # IFLA_RMNET_MAX                      =>     3 - 1 | 0,
};

use constant {
    struct_ifla_rmnet_flags_pack        =>  'LL',
    struct_ifla_rmnet_flags_len         =>     8,
};
    #   struct ifla_rmnet_flags {
    #       __u32                       flags;
    #       __u32                       mask;
    #   };

# MCTP section

use constant {
    IFLA_MCTP_UNSPEC                    =>     0,
    IFLA_MCTP_NET                       =>     1,
  # IFLA_MCTP_MAX                       =>     2 - 1 | 0,
};

our %EXPORT_TAGS = (
    ifla => [qw[

        IFLA_ADDRESS
        IFLA_AF_SPEC
        IFLA_ALT_IFNAME
        IFLA_BROADCAST
        IFLA_CARRIER
        IFLA_CARRIER_CHANGES
        IFLA_CARRIER_DOWN_COUNT
        IFLA_CARRIER_UP_COUNT
        IFLA_COST
        IFLA_EVENT
        IFLA_EXT_MASK
        IFLA_GROUP
        IFLA_GSO_MAX_SEGS
        IFLA_GSO_MAX_SIZE
        IFLA_IFALIAS
        IFLA_IFNAME
        IFLA_LINK
        IFLA_LINKINFO
        IFLA_LINKMODE
        IFLA_LINK_NETNSID
        IFLA_MAP
        IFLA_MASTER
        IFLA_MAX_MTU
        IFLA_MIN_MTU
        IFLA_MTU
        IFLA_NET_NS_FD
        IFLA_NET_NS_PID
        IFLA_NEW_IFINDEX
        IFLA_NEW_NETNSID
        IFLA_NUM_RX_QUEUES
        IFLA_NUM_TX_QUEUES
        IFLA_NUM_VF
        IFLA_OPERSTATE
        IFLA_PAD
        IFLA_PARENT_DEV_BUS_NAME
        IFLA_PARENT_DEV_NAME
        IFLA_PERM_ADDRESS
        IFLA_PHYS_PORT_ID
        IFLA_PHYS_PORT_NAME
        IFLA_PHYS_SWITCH_ID
        IFLA_PORT_SELF
        IFLA_PRIORITY
        IFLA_PROMISCUITY
        IFLA_PROP_LIST
        IFLA_PROTINFO
        IFLA_PROTO_DOWN
        IFLA_PROTO_DOWN_REASON
        IFLA_QDISC
        IFLA_STATS
        IFLA_STATS64
        IFLA_TARGET_NETNSID
        IFLA_TXQLEN
        IFLA_UNSPEC
        IFLA_VFINFO_LIST
        IFLA_VF_PORTS
        IFLA_WEIGHT
        IFLA_WIRELESS
        IFLA_XDP
        IFLA_to_name
    ]],

    pack => [qw[
        struct_rtnl_link_stats32_pack
        struct_rtnl_link_stats32_len
        struct_rtnl_link_stats64_pack
        struct_rtnl_link_stats64_len

        struct_ifla_bridge_id_pack
        struct_ifla_bridge_id_len
    ]],
);

our @EXPORT_OK = (qw(
                    IFLA_IF_NETNSID
                ),
                map { @$_ } values %EXPORT_TAGS);

1;
