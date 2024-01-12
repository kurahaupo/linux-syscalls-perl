
#include <sys/types.h>
#include <sys/timex.h>

#include <stddef.h>     /* offsetof */
#include <stdint.h>     /* intmax_t */
#include <stdio.h>      /* printf, stdout, stderr */
#include <string.h>

#include <linux/if_link.h>      /* what we're testing */

#include "die.h"
#include "show_struct.h"

void Prtnl_link_stats32(void) {
    puts("");

   #define T struct rtnl_link_stats
    Begin();
    F(rx_packets);
    F(tx_packets);
    F(rx_bytes);
    F(tx_bytes);
    F(rx_errors);
    F(tx_errors);
    F(rx_dropped);
    F(tx_dropped);
    F(multicast);
    F(collisions);
    F(rx_length_errors);
    F(rx_over_errors);
    F(rx_crc_errors);
    F(rx_frame_errors);
    F(rx_fifo_errors);
    F(rx_missed_errors);
    F(tx_aborted_errors);
    F(tx_carrier_errors);
    F(tx_fifo_errors);
    F(tx_heartbeat_errors);
    F(tx_window_errors);
    F(rx_compressed);
    F(tx_compressed);
    F(rx_nohandler);
    End();
   #undef T
}

void Prtnl_link_stats64(void) {
    puts("");

   #define T struct rtnl_link_stats64
    Begin();
    F(rx_packets);
    F(tx_packets);
    F(rx_bytes);
    F(tx_bytes);
    F(rx_errors);
    F(tx_errors);
    F(rx_dropped);
    F(tx_dropped);
    F(multicast);
    F(collisions);
    F(rx_length_errors);
    F(rx_over_errors);
    F(rx_crc_errors);
    F(rx_frame_errors);
    F(rx_fifo_errors);
    F(rx_missed_errors);
    F(tx_aborted_errors);
    F(tx_carrier_errors);
    F(tx_fifo_errors);
    F(tx_heartbeat_errors);
    F(tx_window_errors);
    F(rx_compressed);
    F(tx_compressed);
    F(rx_nohandler);
    End();
   #undef T
}

void Prtnl_link_ifmap(void) {
    puts("");

   #define T struct rtnl_link_ifmap
    Begin();
    F(mem_start);
    F(mem_end);
    F(base_addr);
    F(irq);
    F(dma);
    F(port);
    End();
   #undef T
}

void Pifla_bridge_id(void) {
    puts("");
   #define T struct ifla_bridge_id
    Begin();
    Fblob(prio);
    Fblob(addr);
    End();
   #undef T
}

void Pifla_cacheinfo (void) {
    puts("");
   #define T struct ifla_cacheinfo
    Begin();
    F(max_reasm_len);
    F(tstamp);
    F(reachable_time);
    F(retrans_time);
    End();
   #undef T
}

void Pifla_vlan_flags(void) {
   #define T   struct ifla_vlan_flags
    Begin();
    F(flags);
    F(mask);
    End();
   #undef T
};

void Pifla_vlan_qos_mapping(void) {
    puts("");
   #define T struct ifla_vlan_qos_mapping
    Begin();
    F(from);
    F(to);
    End();
   #undef T
}

void Pifla_vxlan_port_range(void) {
    puts("");
   #define T   struct ifla_vxlan_port_range
    Begin();
    F(low);
    F(high);
    End();
   #undef T
}

void Pifla_vf_mac(void) {
    puts("");
   #define T struct ifla_vf_mac
    Begin();
    F(vf);
    Fblob(mac);
    End();
   #undef T
}

void Pifla_vf_broadcast(void) {
    puts("");
   #define T struct ifla_vf_broadcast
    Begin();
    Fblob(broadcast);
    End();
   #undef T
}

void Pifla_vf_vlan(void) {
    puts("");
   #define T struct ifla_vf_vlan
    Begin();
    F(vf);
    F(vlan);
    F(qos);
    End();
   #undef T
}

void Pifla_vf_vlan_info(void) {
    puts("");
   #define T struct ifla_vf_vlan_info
    Begin();
    F(vf);
    F(vlan);
    F(qos);
    F(vlan_proto);
    End();
   #undef T
}


void Pifla_vf_tx_rate(void) {
    puts("");
   #define T struct ifla_vf_tx_rate
    Begin();
    F(vf);
    F(rate);
    End();
   #undef T
}


void Pifla_vf_rate(void) {
    puts("");
   #define T struct ifla_vf_rate
    Begin();
    F(vf);
    F(min_tx_rate);
    F(max_tx_rate);
    End();
   #undef T
}


void Pifla_vf_spoofchk(void) {
    puts("");
   #define T struct ifla_vf_spoofchk
    Begin();
    F(vf);
    F(setting);
    End();
   #undef T
}


void Pifla_vf_guid(void) {
    puts("");
   #define T struct ifla_vf_guid
    Begin();
    F(vf);
    F(guid);
    End();
   #undef T
}

void Pifla_vf_link_state(void) {
    puts("");
   #define T struct ifla_vf_link_state
    Begin();
    F(vf);
    F(link_state);
    End();
   #undef T
}


void Pifla_vf_rss_query_en(void) {
    puts("");
   #define T struct ifla_vf_rss_query_en
    Begin();
    F(vf);
    F(setting);
    End();
   #undef T
}


void Pifla_vf_trust(void) {
    puts("");
   #define T struct ifla_vf_trust
    Begin();
    F(vf);
    F(setting);
    End();
   #undef T
}

void Pifla_port_vsi(void) {
    puts("");
   #define T struct ifla_port_vsi
    Begin();
    F(vsi_mgr_id);
    FA(vsi_type_id);
    F(vsi_type_version);
    End();
   #undef T
}

void Pif_stats_msg(void) {
    puts("");
   #define T struct if_stats_msg
    Begin();
    F(family);
    F(ifindex);
    F(filter_mask);
    End();
   #undef T
}

void Pifla_rmnet_flags(void) {
    puts("");
   #define T struct ifla_rmnet_flags
    Begin();
    F(flags);
    F(mask);
    End();
   #undef T
}

int main() {
    Prtnl_link_stats32();
    Prtnl_link_stats64();
    Prtnl_link_ifmap();
    Pifla_bridge_id();
    Pifla_cacheinfo();
    Pifla_vlan_flags();
    Pifla_vlan_qos_mapping();
    Pifla_vxlan_port_range();
    Pifla_vf_mac();
    Pifla_vf_broadcast();
    Pifla_vf_vlan();
    Pifla_vf_vlan_info();
    Pifla_vf_tx_rate();
    Pifla_vf_rate();
    Pifla_vf_spoofchk();
    Pifla_vf_guid();
    Pifla_vf_link_state();
    Pifla_vf_rss_query_en();
    Pifla_vf_trust();
    Pifla_port_vsi();
    Pif_stats_msg();
    Pifla_rmnet_flags();

}

/*

void P(void) {
    puts("");
   #define T
    Begin();

    End();
   #undef T
}


*/
