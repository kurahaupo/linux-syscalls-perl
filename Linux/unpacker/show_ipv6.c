#include <sys/types.h>
#include <sys/timex.h>

#include <stddef.h>         /* offsetof */
#include <stdint.h>         /* intmax_t */
#include <stdio.h>          /* printf, stdout, stderr */
#include <string.h>

//#define __UAPI_DEF_IN6_PKTINFO // should be on, but set these if they're not
//#define __UAPI_DEF_IP6_MTUINFO

#include <linux/stddef.h>   /* required by <linux/ip.h> */
#include <linux/ipv6.h>     /* what we're testing */

#include "die.h"
#include "show_struct.h"

void Pin6_pktinfo(void) {
    puts("");
   #define T struct in6_pktinfo
    Begin();
    Fblob(ipi6_addr);
    F(ipi6_ifindex);
    End();
   #undef T
}

void Pip6_mtuinfo(void) {
    puts("");
   #define T struct ip6_mtuinfo
    Begin();
    Fblob(ip6m_addr);
    F(ip6m_mtu);
    End();
   #undef T
}

void Pin6_ifreq(void) {
    puts("");
   #define T struct in6_ifreq
    Begin();
    Fblob(ifr6_addr);
    F(ifr6_prefixlen);
    F(ifr6_ifindex);
    End();
   #undef T
}

void Pipv6_rt_hdr(void) {
    puts("");
   #define T struct ipv6_rt_hdr
    Begin();
    F(nexthdr);
    F(hdrlen);
    F(type);
    F(segments_left);
    End();
   #undef T
}

void Pipv6_opt_hdr(void) {
    puts("");
   #define T struct ipv6_opt_hdr
    Begin();
    F(nexthdr);
    F(hdrlen);
    End();
   #undef T
}

void Prt0_hdr(void) {
    puts("");
   #define T struct rt0_hdr
    Begin();
    Fblob(rt_hdr);
    Fblob(addr);
    End();
   #undef T
}

void Prt2_hdr(void) {
    puts("");
   #define T struct rt2_hdr
    Begin();
    Fblob(rt_hdr);
    Fblob(addr);
    End();
   #undef T
}

void Pipv6_destopt_hao(void) {
    puts("");
   #define T struct ipv6_destopt_hao
    Begin();
    F(type);
    F(length);
    Fblob(addr);
    End();
   #undef T
}

void Pipv6hdr(void) {
    puts("");
   #define T struct ipv6hdr
    Begin();
    Field(&tracker, 0, 1, 1, FM_unsigned, "prio:4, version:4",
          "/* unpack into ihl with \"C\", then decode as version = prio>>4, prio&=15 */");
    FA(flow_lbl);
    F(payload_len);
    F(nexthdr);
    F(hop_limit);
    Fblob(saddr);
    Fblob(daddr);
    End();
   #undef T
}


int main() {
    Pin6_pktinfo();
    Pip6_mtuinfo();
    Pin6_ifreq();
    Pipv6_rt_hdr();
    Pipv6_opt_hdr();
    Prt0_hdr();
    Prt2_hdr();
    Pipv6_destopt_hao();
    Pipv6hdr();
    ;
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
