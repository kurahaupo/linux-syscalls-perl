#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

package Linux::IpRoute2::if_addr v0.0.1;

use Data::Dumper;
use Exporter 'import';
use List::Util qw( uniq );

our @EXPORT;
our @EXPORT_OK;
our %EXPORT_TAGS;
my @export_allowed = ();
my @export_obsolete = ();

use Linux::Syscalls::util qw( _B );

# Copied and adapted from <linux/if_addr.h>
#           /usr/include/linux/if_addr.h
# [iproute2]include/uapi/linux/if_addr.h

use constant {
    struct_ifaddrmsg_pack       => 'C4L',
    struct_ifaddrmsg_len        => 8,
    struct_ifaddrmsg_narg       => 5,
};
#
#       __u8    ifa_family;
#       __u8    ifa_prefixlen;  # The prefix length
#       __u8    ifa_flags;      # Flags
#       __u8    ifa_scope;      # Address scope
#       __u32   ifa_index;      # Link index
#

##
## Important comment:
## IFA_ADDRESS is prefix address, rather than local interface address.
## It makes no difference for normally configured broadcast interfaces,
## but for point-to-point IFA_ADDRESS is DESTINATION address,
## local address is supplied in IFA_LOCAL attribute.
##
## IFA_FLAGS is a u32 attribute that extends the u8 field ifa_flags.
## If present, the value from struct ifaddrmsg will be ignored.
##

use Linux::Syscalls::enum qw( IFA
    UNSPEC
    ADDRESS
    LOCAL
    LABEL
    BROADCAST
    ANYCAST
    CACHEINFO
    MULTICAST
    FLAGS
    RT_PRIORITY
    TARGET_NETNSID
    PROTO
);

# ifa_flags

use Linux::Syscalls::bitset qw( IFA_F
    SECONDARY
    NODAD
    OPTIMISTIC
    DADFAILED
    HOMEADDRESS
    DEPRECATED
    TENTATIVE
    PERMANENT
    MANAGETEMPADDR
    NOPREFIXROUTE
    MCAUTOJOIN
    STABLE_PRIVACY
);

use constant {
    IFA_F_TEMPORARY => IFA_F_SECONDARY,
};
BEGIN { push @export_obsolete, qw( IFA_F_TEMPORARY ) }

use constant {
    struct_ifa_cacheinfo_pack   => 'L4',
    struct_ifa_cacheinfo_len    => 16,
    struct_ifa_cacheinfo_narg   => 4,
};
BEGIN {
    push @{$EXPORT_TAGS{struct}}, qw(
        struct_ifa_cacheinfo_pack
        struct_ifa_cacheinfo_len
        struct_ifa_cacheinfo_narg
    );
}
#
#       __u32   ifa_prefered;
#       __u32   ifa_valid;
#       __u32   cstamp;     # created timestamp, hundredths of seconds
#       __u32   tstamp;     # updated timestamp, hundredths of seconds
#

# backwards compatibility for userspace
#define IFA_RTA(r)  ((struct rtattr*)(((char*)(r)) + NLMSG_ALIGN(sizeof(struct ifaddrmsg))))
#define IFA_PAYLOAD(n) NLMSG_PAYLOAD(n,sizeof(struct ifaddrmsg))

#/* ifa_proto */

use Linux::Syscalls::enum qw( IFA_PROTO
   UNSPEC
   KERNEL_LO
   KERNEL_RA
   KERNEL_LL
);

# backward compat names
use constant {
    IFAPROT_UNSPEC            => IFA_PROTO_UNSPEC,
    IFAPROT_KERNEL_LO         => IFA_PROTO_KERNEL_LO,
    IFAPROT_KERNEL_RA         => IFA_PROTO_KERNEL_RA,
    IFAPROT_KERNEL_LL         => IFA_PROTO_KERNEL_LL,
};

# Items that don't belong to any group
push @export_allowed, qw(
    IFAPROT_UNSPEC
    IFAPROT_KERNEL_LO
    IFAPROT_KERNEL_RA
    IFAPROT_KERNEL_LL
);

BEGIN {
    my %seen;
    @EXPORT_OK = grep { ! $seen{$_} }
                        @export_allowed,
                        @export_obsolete,
                        map { @$_ } values %EXPORT_TAGS;
    $EXPORT_TAGS{everything} = \@EXPORT_OK;
    @$_ = uniq sort @$_ for \@EXPORT, \@EXPORT_OK, values %EXPORT_TAGS;

    sub check {
        my ($cmd, $want, $msg) = @_;
        my $out = eval($cmd) // die "Couldn't run «$cmd»\n\t";
        ref $want eq 'Regexp' ? $out =~ $want : $out eq $want
            or die "Mismatch from «$cmd»\nWanted «$want»\n   Got «$out»\n\t";
        print "\e[2mOK: ", $msg // "«$cmd» produced «$out»", "\e[m\n";
        1;
    }

    if ($^C) {
        print "CHECKING:\n";

        check q{ IFA_UNSPEC         }, 0;
        check q{ IFA_ADDRESS        }, 1;
        check q{ IFA_LOCAL          }, 2;
        check q{ IFA_LABEL          }, 3;
        check q{ IFA_BROADCAST      }, 4;
        check q{ IFA_ANYCAST        }, 5;
        check q{ IFA_CACHEINFO      }, 6;
        check q{ IFA_MULTICAST      }, 7;
        check q{ IFA_FLAGS          }, 8;
        check q{ IFA_RT_PRIORITY    }, 9;
        check q{ IFA_TARGET_NETNSID }, 10;
        check q{ IFA_PROTO          }, 11;

        check q{ IFA_F_SECONDARY      }, 0x001;
        check q{ IFA_F_NODAD          }, 0x002;
        check q{ IFA_F_OPTIMISTIC     }, 0x004;
        check q{ IFA_F_DADFAILED      }, 0x008;
        check q{ IFA_F_HOMEADDRESS    }, 0x010; check q{ IFA_F_DEPRECATED     }, 0x020;
        check q{ IFA_F_TENTATIVE      }, 0x040;
        check q{ IFA_F_PERMANENT      }, 0x080;
        check q{ IFA_F_MANAGETEMPADDR }, 0x100;
        check q{ IFA_F_NOPREFIXROUTE  }, 0x200;
        check q{ IFA_F_MCAUTOJOIN     }, 0x400;
        check q{ IFA_F_STABLE_PRIVACY }, 0x800;

        check q{ Data::Dumper->new([ \%Linux::IpRoute2::if_addr:: ],[qw[ %Linux::IpRoute2::if_addr:: ]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump },
              q{$%Linux::IpRoute2::if_addr:: = {"BEGIN" => *Linux::IpRoute2::if_addr::BEGIN,"Dumper" => *Linux::IpRoute2::if_addr::Dumper,"EXPORT" => *Linux::IpRoute2::if_addr::EXPORT,"EXPORT_OK" => *Linux::IpRoute2::if_addr::EXPORT_OK,"EXPORT_TAGS" => *Linux::IpRoute2::if_addr::EXPORT_TAGS,"IFAPROT_KERNEL_LL" => \3,"IFAPROT_KERNEL_LO" => \1,"IFAPROT_KERNEL_RA" => \2,"IFAPROT_UNSPEC" => \0,"IFA_ADDRESS" => \1,"IFA_ANYCAST" => \5,"IFA_BROADCAST" => \4,"IFA_CACHEINFO" => \6,"IFA_FLAGS" => \8,"IFA_F_DADFAILED" => \8,"IFA_F_DEPRECATED" => \32,"IFA_F_HOMEADDRESS" => \16,"IFA_F_MANAGETEMPADDR" => \256,"IFA_F_MCAUTOJOIN" => \1024,"IFA_F_NODAD" => \2,"IFA_F_NOPREFIXROUTE" => \512,"IFA_F_OPTIMISTIC" => \4,"IFA_F_PERMANENT" => \128,"IFA_F_SECONDARY" => \1,"IFA_F_STABLE_PRIVACY" => \2048,"IFA_F_TEMPORARY" => \1,"IFA_F_TENTATIVE" => \64,"IFA_F_all" => \4095,"IFA_F_indeces" => *Linux::IpRoute2::if_addr::IFA_F_indeces,"IFA_F_max" => \11,"IFA_F_min" => \0,"IFA_F_next" => \12,"IFA_F_none" => \0,"IFA_F_range" => *Linux::IpRoute2::if_addr::IFA_F_range,"IFA_F_shift" => \0,"IFA_F_to_desc" => *Linux::IpRoute2::if_addr::IFA_F_to_desc,"IFA_LABEL" => \3,"IFA_LOCAL" => \2,"IFA_MULTICAST" => \7,"IFA_PROTO" => \11,"IFA_PROTO_KERNEL_LL" => \3,"IFA_PROTO_KERNEL_LO" => \1,"IFA_PROTO_KERNEL_RA" => \2,"IFA_PROTO_UNSPEC" => \0,"IFA_PROTO_indeces" => *Linux::IpRoute2::if_addr::IFA_PROTO_indeces,"IFA_PROTO_max" => \3,"IFA_PROTO_min" => \0,"IFA_PROTO_next" => \4,"IFA_PROTO_range" => *Linux::IpRoute2::if_addr::IFA_PROTO_range,"IFA_PROTO_to_desc" => *Linux::IpRoute2::if_addr::IFA_PROTO_to_desc,"IFA_PROTO_to_label" => *Linux::IpRoute2::if_addr::IFA_PROTO_to_label,"IFA_PROTO_to_name" => *Linux::IpRoute2::if_addr::IFA_PROTO_to_name,"IFA_RT_PRIORITY" => \9,"IFA_TARGET_NETNSID" => \10,"IFA_UNSPEC" => \0,"IFA_indeces" => *Linux::IpRoute2::if_addr::IFA_indeces,"IFA_max" => \11,"IFA_min" => \0,"IFA_next" => \12,"IFA_range" => *Linux::IpRoute2::if_addr::IFA_range,"IFA_to_desc" => *Linux::IpRoute2::if_addr::IFA_to_desc,"IFA_to_label" => *Linux::IpRoute2::if_addr::IFA_to_label,"IFA_to_name" => *Linux::IpRoute2::if_addr::IFA_to_name,"VERSION" => *Linux::IpRoute2::if_addr::VERSION,"_B" => *Linux::IpRoute2::if_addr::_B,"a" => *Linux::IpRoute2::if_addr::a,"b" => *Linux::IpRoute2::if_addr::b,"check" => *Linux::IpRoute2::if_addr::check,"import" => *Linux::IpRoute2::if_addr::import,"struct_ifa_cacheinfo_len" => \16,"struct_ifa_cacheinfo_narg" => \4,"struct_ifa_cacheinfo_pack" => \"L4","struct_ifaddrmsg_len" => \8,"struct_ifaddrmsg_narg" => \5,"struct_ifaddrmsg_pack" => \"C4L","uniq" => *Linux::IpRoute2::if_addr::uniq};};
        check q{ Data::Dumper->new([ \@EXPORT      ], [qw[ @EXPORT      ]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump },
              q{$@EXPORT = [];};
        check q{ Data::Dumper->new([ \@EXPORT_OK   ], [qw[ @EXPORT_OK   ]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump },
              q{$@EXPORT_OK = ["IFA_ADDRESS","IFA_ANYCAST","IFA_BROADCAST","IFA_CACHEINFO","IFA_FLAGS","IFA_F_DADFAILED","IFA_F_DEPRECATED","IFA_F_HOMEADDRESS","IFA_F_MANAGETEMPADDR","IFA_F_MCAUTOJOIN","IFA_F_NODAD","IFA_F_NOPREFIXROUTE","IFA_F_OPTIMISTIC","IFA_F_PERMANENT","IFA_F_SECONDARY","IFA_F_STABLE_PRIVACY","IFA_F_TEMPORARY","IFA_F_TENTATIVE","IFA_F_all","IFA_F_indeces","IFA_F_max","IFA_F_min","IFA_F_next","IFA_F_none","IFA_F_range","IFA_F_shift","IFA_F_to_desc","IFA_LABEL","IFA_LOCAL","IFA_MULTICAST","IFA_PROTO","IFA_PROTO_KERNEL_LL","IFA_PROTO_KERNEL_LO","IFA_PROTO_KERNEL_RA","IFA_PROTO_UNSPEC","IFA_PROTO_indeces","IFA_PROTO_max","IFA_PROTO_min","IFA_PROTO_next","IFA_PROTO_range","IFA_PROTO_to_desc","IFA_PROTO_to_label","IFA_RT_PRIORITY","IFA_TARGET_NETNSID","IFA_UNSPEC","IFA_indeces","IFA_max","IFA_min","IFA_next","IFA_range","IFA_to_desc","IFA_to_label","struct_ifa_cacheinfo_len","struct_ifa_cacheinfo_narg","struct_ifa_cacheinfo_pack"];};
        check q{ Data::Dumper->new([ \%EXPORT_TAGS ], [qw[ %EXPORT_TAGS ]])->Indent(0)->Sortkeys(1)->Useqq(1)->Dump },
              q{$%EXPORT_TAGS = {"descriptions" => ["IFA_F_to_desc","IFA_PROTO_to_desc","IFA_to_desc"],"everything" => ["IFA_ADDRESS","IFA_ANYCAST","IFA_BROADCAST","IFA_CACHEINFO","IFA_FLAGS","IFA_F_DADFAILED","IFA_F_DEPRECATED","IFA_F_HOMEADDRESS","IFA_F_MANAGETEMPADDR","IFA_F_MCAUTOJOIN","IFA_F_NODAD","IFA_F_NOPREFIXROUTE","IFA_F_OPTIMISTIC","IFA_F_PERMANENT","IFA_F_SECONDARY","IFA_F_STABLE_PRIVACY","IFA_F_TEMPORARY","IFA_F_TENTATIVE","IFA_F_all","IFA_F_indeces","IFA_F_max","IFA_F_min","IFA_F_next","IFA_F_none","IFA_F_range","IFA_F_shift","IFA_F_to_desc","IFA_LABEL","IFA_LOCAL","IFA_MULTICAST","IFA_PROTO","IFA_PROTO_KERNEL_LL","IFA_PROTO_KERNEL_LO","IFA_PROTO_KERNEL_RA","IFA_PROTO_UNSPEC","IFA_PROTO_indeces","IFA_PROTO_max","IFA_PROTO_min","IFA_PROTO_next","IFA_PROTO_range","IFA_PROTO_to_desc","IFA_PROTO_to_label","IFA_RT_PRIORITY","IFA_TARGET_NETNSID","IFA_UNSPEC","IFA_indeces","IFA_max","IFA_min","IFA_next","IFA_range","IFA_to_desc","IFA_to_label","struct_ifa_cacheinfo_len","struct_ifa_cacheinfo_narg","struct_ifa_cacheinfo_pack"],"ifa" => ["IFA_ADDRESS","IFA_ANYCAST","IFA_BROADCAST","IFA_CACHEINFO","IFA_FLAGS","IFA_LABEL","IFA_LOCAL","IFA_MULTICAST","IFA_PROTO","IFA_RT_PRIORITY","IFA_TARGET_NETNSID","IFA_UNSPEC","IFA_indeces","IFA_max","IFA_min","IFA_next","IFA_range","IFA_to_desc","IFA_to_label"],"ifa_f" => ["IFA_F_DADFAILED","IFA_F_DEPRECATED","IFA_F_HOMEADDRESS","IFA_F_MANAGETEMPADDR","IFA_F_MCAUTOJOIN","IFA_F_NODAD","IFA_F_NOPREFIXROUTE","IFA_F_OPTIMISTIC","IFA_F_PERMANENT","IFA_F_SECONDARY","IFA_F_STABLE_PRIVACY","IFA_F_TENTATIVE","IFA_F_all","IFA_F_indeces","IFA_F_max","IFA_F_min","IFA_F_next","IFA_F_none","IFA_F_range","IFA_F_shift","IFA_F_to_desc"],"ifa_proto" => ["IFA_PROTO_KERNEL_LL","IFA_PROTO_KERNEL_LO","IFA_PROTO_KERNEL_RA","IFA_PROTO_UNSPEC","IFA_PROTO_indeces","IFA_PROTO_max","IFA_PROTO_min","IFA_PROTO_next","IFA_PROTO_range","IFA_PROTO_to_desc","IFA_PROTO_to_label"],"labels" => ["IFA_PROTO_to_label","IFA_to_label"],"limits" => ["IFA_F_all","IFA_F_indeces","IFA_F_max","IFA_F_min","IFA_F_next","IFA_F_none","IFA_F_range","IFA_F_shift","IFA_PROTO_indeces","IFA_PROTO_max","IFA_PROTO_min","IFA_PROTO_next","IFA_PROTO_range","IFA_indeces","IFA_max","IFA_min","IFA_next","IFA_range"],"struct" => ["struct_ifa_cacheinfo_len","struct_ifa_cacheinfo_narg","struct_ifa_cacheinfo_pack"]};};
    }
}

1;
