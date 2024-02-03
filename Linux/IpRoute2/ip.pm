#!/module/for/perl

use 5.010;
use strict;
use warnings;

package Linux::IpRoute2::ip v0.0.1;

use Exporter 'import';

sub _B($) { 1 << pop }

# Copied and adapted from /usr/include/linux/ip.h

# SPDX-License-Identifier: GPL-2.0+ WITH Linux-syscall-note */
#
# INET          An implementation of the TCP/IP protocol suite for the LINUX
#               operating system.  INET is implemented using the  BSD Socket
#               interface as the means of communication with the user level.
#
#               Definitions for the IP protocol.
#
# Version:      @(#)ip.h        1.0.2   04/28/93
#
# Authors:      Fred N. van Kempen, <waltje@uWalt.NL.Mugnet.ORG>
#
#               This program is free software; you can redistribute it and/or
#               modify it under the terms of the GNU General Public License
#               as published by the Free Software Foundation; either version
#               2 of the License, or (at your option) any later version.

#ifndef _LINUX_IP_H
#define _LINUX_IP_H
#include <linux/types.h>
#include <linux/stddef.h>
#include <asm/byteorder.h>

# Manage TOS & PREC bits ...

use constant {
    IPTOS_MINCOST               =>     1 << 1,  # 0x02
    IPTOS_RELIABILITY           =>     1 << 2,  # 0x04
    IPTOS_THROUGHPUT            =>     1 << 3,  # 0x08
    IPTOS_LOWDELAY              =>     1 << 4,  # 0x10

    IPTOS_TOS_MASK              =>  0x1e,   # all of the above
};
sub IPTOS_TOS ($) { my ($tos) = @_; $tos & IPTOS_TOS_MASK }

use constant {
    IPTOS_PREC_ROUTINE          =>     0 << 5,  # 0x00
    IPTOS_PREC_PRIORITY         =>     1 << 5,  # 0x20
    IPTOS_PREC_IMMEDIATE        =>     2 << 5,  # 0x40
    IPTOS_PREC_FLASH            =>     3 << 5,  # 0x60
    IPTOS_PREC_FLASHOVERRIDE    =>     4 << 5,  # 0x80
    IPTOS_PREC_CRITIC_ECP       =>     5 << 5,  # 0xa0
    IPTOS_PREC_INTERNETCONTROL  =>     6 << 5,  # 0xc0
    IPTOS_PREC_NETCONTROL       =>     7 << 5,  # 0xe0

    IPTOS_PREC_MASK             =>     7 << 5,  # 0xe0
};
sub IPTOS_PREC($) { my ($tos) = @_; $tos & IPTOS_PREC_MASK }

# Manage IP options ...

#  (a) copy tag
use constant {
    IPOPT_COPY                  =>  0x80,
};

#  (b) option class
use constant {
    IPOPT_CONTROL               =>     0 << 5,  # 0x00,
  # IPOPT_RESERVED1             =>     1 << 5,  # 0x20,
    IPOPT_MEASUREMENT           =>     2 << 5,  # 0x40,
  # IPOPT_RESERVED2             =>     3 << 5,  # 0x60,

    IPOPT_CLASS_MASK            =>  0x60,       # all of the above
};

# (c) option number
use constant {
    IPOPT_EOL                   =>     0 | IPOPT_CONTROL,
    IPOPT_NOP                   =>     1 | IPOPT_CONTROL,
    IPOPT_SEC                   =>     2 | IPOPT_CONTROL | IPOPT_COPY,
    IPOPT_LSRR                  =>     3 | IPOPT_CONTROL | IPOPT_COPY,
    IPOPT_TS                    =>     4 | IPOPT_MEASUREMENT,
    IPOPT_CIPSO                 =>     6 | IPOPT_CONTROL | IPOPT_COPY,
    IPOPT_RR                    =>     7 | IPOPT_CONTROL,
    IPOPT_SID                   =>     8 | IPOPT_CONTROL | IPOPT_COPY,
    IPOPT_SSRR                  =>     9 | IPOPT_CONTROL | IPOPT_COPY,
    IPOPT_RA                    =>    20 | IPOPT_CONTROL | IPOPT_COPY,

    IPOPT_NUMBER_MASK           =>  0x1f,
};

# (c*) option number aliases
use constant {
    IPOPT_END                   =>  IPOPT_EOL,
    IPOPT_NOOP                  =>  IPOPT_NOP,
    IPOPT_TIMESTAMP             =>  IPOPT_TS,
};

sub IPOPT_COPIED($) { my ($o) = @_;  $o & IPOPT_COPY }
sub IPOPT_CLASS($)  { my ($o) = @_;  $o & IPOPT_CLASS_MASK }
sub IPOPT_NUMBER($) { my ($o) = @_;  $o & IPOPT_NUMBER_MASK }

# Tell me about IPv4 addresses & routes...

use constant {
    IPVERSION                   =>     4,
};

use constant {
    # The symbols defined in <linux/ip.h> are far too generic ("MAXTTL")
    # so rename them to something less likely to collide.

    IPTTL_DEFAULT               =>    64,
    IPTTL_MAX                   =>   255,

};

# These appear to be only to help with marshalling the parts of each request &
# response, which (being Perl) we do using clever 'pack' parameters instead.
# Therefore they're not included as exported symbols.
  # IPOPT_OPTVAL                =>     0,
  # IPOPT_OLEN                  =>     1,
  # IPOPT_OFFSET                =>     2,
  # IPOPT_MINOFF                =>     4,

use constant {

    MAX_IPOPTLEN                =>    40,

};

use constant {

    IPOPT_TS_TSONLY             =>     0,   # timestamps only */
    IPOPT_TS_TSANDADDR          =>     1,   # timestamps and addresses */
    IPOPT_TS_PRESPEC            =>     3,   # specified modules only */
};

use constant {
    IPV4_BEET_PHMAXLEN          =>     8,
};

use constant {
    struct_iphdr_pack           =>  'CCnnnCCnNN',   # note that the first 'C' needs to be unpacked into (ihl:4, version:4)
    struct_iphdr_len            =>    20,           # == length pack struct_iphdr_pack, (0) x 11;
};
    #   struct iphdr {
    #   #if defined(__LITTLE_ENDIAN_BITFIELD)
    #           __u8    ihl:4,
    #                   version:4;
    #   #elif defined (__BIG_ENDIAN_BITFIELD)
    #           __u8    version:4,
    #                   ihl:4;
    #   #else
    #   #error  "Please fix <asm/byteorder.h>"
    #   #endif
    #           __u8    tos;
    #           __be16  tot_len;
    #           __be16  id;
    #           __be16  frag_off;
    #           __u8    ttl;
    #           __u8    protocol;
    #           __sum16 check;
    #<          __struct_group(/* no tag */, addrs, /* no attrs */,
    #<                  __be32  saddr;
    #<                  __be32  daddr;
    #<          );
    #>          union { \
    #>                  struct {  __be32 saddr; __be32 daddr; } ; \
    #>                  struct {  __be32 saddr; __be32 daddr; }  addrs; \
    #>          }
    #           /*The options start here. */
    #   };
    #
    #  NOTE from <linux/stddef.h>
    ##  #define __struct_group(TAG, NAME, ATTRS, MEMBERS...) \
    ##          union { \
    ##                  struct { MEMBERS } ATTRS; \
    ##                  struct TAG { MEMBERS } ATTRS NAME; \
    ##          }

use constant {
    struct_ip_auth_hdr_pack     => 'CCx![L]NNC*x![Q]',   # accepts unlimited length auth_data, but min 4
    struct_ip_auth_hdr_len      =>    12,
};
    #   struct ip_auth_hdr {
    #       __u8  nexthdr;
    #       __u8  hdrlen;           /* This one is measured in 32 bit units! */
    #       __be16 :0 /*reserved*/;
    #       __be32 spi;
    #       __be32 seq_no;          /* Sequence number */
    #       __u8  auth_data[0];     /* Variable len but >=4. Mind the 64 bit alignment! */
    #   };

use constant {
    struct_ip_esp_hdr_pack      => 'NNC0',
    struct_ip_esp_hdr_len       =>     0,
};
    #   struct ip_esp_hdr {
    #       __be32 spi;
    #       __be32 seq_no;          /* Sequence number */
    #       __u8  enc_data[0];      /* Variable len but >=8. Mind the 64 bit alignment! */
    #   };

use constant {
    struct_ip_comp_hdr_pack     => 'CCn',
    struct_ip_comp_hdr_len      =>     4,
};
    #   struct ip_comp_hdr {
    #       __u8 nexthdr;
    #       __u8 flags;
    #       __be16 cpi;
    #   };

use constant {
    struct_ip_beet_phdr_pack    =>  'CCCx',
    struct_ip_beet_phdr_len     =>     4,
};
    #   struct ip_beet_phdr {
    #       __u8 nexthdr;
    #       __u8 hdrlen;
    #       __u8 padlen;
    #       __u8 :0 /*reserved*/;
    #   };

# index values for the variables in ipv4_devconf
use constant {                                          #      0,
    IPV4_DEVCONF_FORWARDING                             =>     1,
    IPV4_DEVCONF_MC_FORWARDING                          =>     2,
    IPV4_DEVCONF_PROXY_ARP                              =>     3,
    IPV4_DEVCONF_ACCEPT_REDIRECTS                       =>     4,
    IPV4_DEVCONF_SECURE_REDIRECTS                       =>     5,
    IPV4_DEVCONF_SEND_REDIRECTS                         =>     6,
    IPV4_DEVCONF_SHARED_MEDIA                           =>     7,
    IPV4_DEVCONF_RP_FILTER                              =>     8,
    IPV4_DEVCONF_ACCEPT_SOURCE_ROUTE                    =>     9,
    IPV4_DEVCONF_BOOTP_RELAY                            =>    20,
    IPV4_DEVCONF_LOG_MARTIANS                           =>    21,
    IPV4_DEVCONF_TAG                                    =>    22,
    IPV4_DEVCONF_ARPFILTER                              =>    23,
    IPV4_DEVCONF_MEDIUM_ID                              =>    24,
    IPV4_DEVCONF_NOXFRM                                 =>    25,
    IPV4_DEVCONF_NOPOLICY                               =>    26,
    IPV4_DEVCONF_FORCE_IGMP_VERSION                     =>    27,
    IPV4_DEVCONF_ARP_ANNOUNCE                           =>    28,
    IPV4_DEVCONF_ARP_IGNORE                             =>    29,
    IPV4_DEVCONF_PROMOTE_SECONDARIES                    =>    30,
    IPV4_DEVCONF_ARP_ACCEPT                             =>    31,
    IPV4_DEVCONF_ARP_NOTIFY                             =>    32,
    IPV4_DEVCONF_ACCEPT_LOCAL                           =>    33,
    IPV4_DEVCONF_SRC_VMARK                              =>    34,
    IPV4_DEVCONF_PROXY_ARP_PVLAN                        =>    35,
    IPV4_DEVCONF_ROUTE_LOCALNET                         =>    36,
    IPV4_DEVCONF_IGMPV2_UNSOLICITED_REPORT_INTERVAL     =>    37,
    IPV4_DEVCONF_IGMPV3_UNSOLICITED_REPORT_INTERVAL     =>    38,
    IPV4_DEVCONF_IGNORE_ROUTES_WITH_LINKDOWN            =>    39,
    IPV4_DEVCONF_DROP_UNICAST_IN_L2_MULTICAST           =>    40,
    IPV4_DEVCONF_DROP_GRATUITOUS_ARP                    =>    41,
    IPV4_DEVCONF_BC_FORWARDING                          =>    42,
  # IPV4_DEVCONF_MAX                                    =>    43 - 1 | 0,
};

our %EXPORT_TAGS = (

    iptos => [qw[
        IPTOS_LOWDELAY
        IPTOS_MINCOST
        IPTOS_RELIABILITY
        IPTOS_THROUGHPUT
        IPTOS_TOS_MASK

       &IPTOS_TOS
    ]],

    ipprec => [qw[
        IPTOS_PREC_CRITIC_ECP
        IPTOS_PREC_FLASH
        IPTOS_PREC_FLASHOVERRIDE
        IPTOS_PREC_IMMEDIATE
        IPTOS_PREC_INTERNETCONTROL
        IPTOS_PREC_MASK
        IPTOS_PREC_NETCONTROL
        IPTOS_PREC_PRIORITY
        IPTOS_PREC_ROUTINE
       &IPTOS_PREC
    ]],

    ipopt_copy => [qw[
        IPOPT_COPY
       &IPOPT_COPIED
    ]],

    ipopt_class => [qw[
        IPOPT_CONTROL
        IPOPT_MEASUREMENT

        IPOPT_CLASS_MASK
       &IPOPT_CLASS
    ]],

    ipopt_num => [qw[
        IPOPT_EOL
        IPOPT_NOP
        IPOPT_SEC
        IPOPT_LSRR
        IPOPT_TS
        IPOPT_CIPSO
        IPOPT_RR
        IPOPT_SID
        IPOPT_SSRR
        IPOPT_RA

        IPOPT_NUMBER_MASK
       &IPOPT_NUMBER
    ]],

    ipopt_len => [qw[
        MAX_IPOPTLEN
    ]],

    # all the ipopt above combined
    ipopt => [qw[

        IPOPT_CIPSO
        IPOPT_CONTROL
        IPOPT_EOL
        IPOPT_LSRR
        IPOPT_MEASUREMENT
        IPOPT_MINOFF
        IPOPT_NOP
        IPOPT_OFFSET
        IPOPT_OLEN
        IPOPT_OPTVAL
        IPOPT_RA
        IPOPT_RR
        IPOPT_SEC
        IPOPT_SID
        IPOPT_SSRR
        IPOPT_TS
        IPOPT_TS_PRESPEC
        IPOPT_TS_TSANDADDR
        IPOPT_TS_TSONLY

       &IPOPT_CLASS
        IPOPT_CLASS_MASK

       &IPOPT_COPIED
        IPOPT_COPY

       &IPOPT_NUMBER
        IPOPT_NUMBER_MASK

        MAX_IPOPTLEN
    ]],


    # MAXTTL
    ipttl => [qw[
        IPTTL_DEFAULT
        IPTTL_MAX
    ]],


    ipv4_devconf => [qw[

        IPV4_DEVCONF_ACCEPT_LOCAL
        IPV4_DEVCONF_ACCEPT_REDIRECTS
        IPV4_DEVCONF_ACCEPT_SOURCE_ROUTE
        IPV4_DEVCONF_ARPFILTER
        IPV4_DEVCONF_ARP_ACCEPT
        IPV4_DEVCONF_ARP_ANNOUNCE
        IPV4_DEVCONF_ARP_IGNORE
        IPV4_DEVCONF_ARP_NOTIFY
        IPV4_DEVCONF_BC_FORWARDING
        IPV4_DEVCONF_BOOTP_RELAY
        IPV4_DEVCONF_DROP_GRATUITOUS_ARP
        IPV4_DEVCONF_DROP_UNICAST_IN_L2_MULTICAST
        IPV4_DEVCONF_FORCE_IGMP_VERSION
        IPV4_DEVCONF_FORWARDING
        IPV4_DEVCONF_IGMPV2_UNSOLICITED_REPORT_INTERVAL
        IPV4_DEVCONF_IGMPV3_UNSOLICITED_REPORT_INTERVAL
        IPV4_DEVCONF_IGNORE_ROUTES_WITH_LINKDOWN
        IPV4_DEVCONF_LOG_MARTIANS
        IPV4_DEVCONF_MC_FORWARDING
        IPV4_DEVCONF_MEDIUM_ID
        IPV4_DEVCONF_NOPOLICY
        IPV4_DEVCONF_NOXFRM
        IPV4_DEVCONF_PROMOTE_SECONDARIES
        IPV4_DEVCONF_PROXY_ARP
        IPV4_DEVCONF_PROXY_ARP_PVLAN
        IPV4_DEVCONF_ROUTE_LOCALNET
        IPV4_DEVCONF_RP_FILTER
        IPV4_DEVCONF_SECURE_REDIRECTS
        IPV4_DEVCONF_SEND_REDIRECTS
        IPV4_DEVCONF_SHARED_MEDIA
        IPV4_DEVCONF_SRC_VMARK
        IPV4_DEVCONF_TAG

    ]],

    pack => [qw[

        struct_ip_auth_hdr_len
        struct_ip_auth_hdr_pack
        struct_ip_beet_phdr_len
        struct_ip_beet_phdr_pack
        struct_ip_comp_hdr_len
        struct_ip_comp_hdr_pack
        struct_ip_esp_hdr_len
        struct_ip_esp_hdr_pack
        struct_iphdr_len
        struct_iphdr_pack

    ]],
);

# Singletons that don't belong to any group
my @export_allowed = qw(
    IPVERSION
);

# Old names that are discouraged in new code
my @export_deprecated = qw(
    IPV4_BEET_PHMAXLEN

    IPOPT_END
    IPOPT_NOOP
    IPOPT_TIMESTAMP
);

my %seen;
our @EXPORT_OK = grep { ! $seen{$_}++ }
                    @export_allowed,
                    @export_deprecated,
                    map { @$_ } values %EXPORT_TAGS;

$EXPORT_TAGS{everything} = \@EXPORT_OK;

1;
