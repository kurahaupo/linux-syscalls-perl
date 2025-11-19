#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

package Linux::IpRoute2::message::link;

use Carp qw( confess cluck croak carp );

use parent 'Linux::IpRoute2::message::_base';

use Linux::IpRoute2::if_link qw( IFLA_to_label IFLA_MAX );
use Linux::IpRoute2::rtnetlink qw( struct_ifinfomsg_pack struct_ifinfomsg_len );
use Linux::IpRoute2::attr::_int;

#
# Kinds of attributes that can be incorporated within a Linux::IpRoute2::message::link (RTM_LINK)
#

package Linux::IpRoute2::attr::link::_base                  { use parent Linux::IpRoute2::attr::_base::; }

package Linux::IpRoute2::attr::link::unspec                 { use constant packpat => ''; }                                                     #  0
package Linux::IpRoute2::attr::link::address                {}                                                                                  #  1
package Linux::IpRoute2::attr::link::broadcast              { use parent -norequire => Linux::IpRoute2::attr::link::address::; }                #  2
package Linux::IpRoute2::attr::link::ifname                 { use constant packpat => 'Z*';  use Linux::IpRoute2::struct qw( name ); }          #  3
package Linux::IpRoute2::attr::link::mtu                    { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( bytes ); }         #  4
package Linux::IpRoute2::attr::link::qdisc                  { use constant packpat => 'Z*';  use Linux::IpRoute2::struct qw( name ); }          #  6
package Linux::IpRoute2::attr::link::stats                  { use constant packpat => 'l24'; use Linux::IpRoute2::struct qw( :more=stats ); }   #  7 int32_t[24]
package Linux::IpRoute2::attr::link::txqlen                 { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( bytes ); }         # 13
package Linux::IpRoute2::attr::link::map                    { use constant packpat => '(L2)*'; use Linux::IpRoute2::struct qw( :more=map ); }   # 14
package Linux::IpRoute2::attr::link::operstate              { use constant packpat => 'C';   use Linux::IpRoute2::struct qw( state ); }         # 16
package Linux::IpRoute2::attr::link::linkmode               { use constant packpat => 'C';   use Linux::IpRoute2::struct qw( mode ); }          # 17
package Linux::IpRoute2::attr::link::ifalias                { use constant packpat => 'Z*';  use Linux::IpRoute2::struct qw( name ); }          # 20
package Linux::IpRoute2::attr::link::num_vf                 { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( count ); }         # 21
package Linux::IpRoute2::attr::link::stats64                { use constant packpat => 'q*';  use Linux::IpRoute2::struct qw( :more=stats ); }   # 23 int64_t[24]
package Linux::IpRoute2::attr::link::af_spec                { use parent -norequire => 'Linux::IpRoute2::attr::af_spec'; }                      # 26  (RECURSIVE?)
package Linux::IpRoute2::attr::link::group                  { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( group ); }         # 27
package Linux::IpRoute2::attr::link::ext_mask               { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( mask ); }          # 29
package Linux::IpRoute2::attr::link::promiscuity            { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( flag ); }          # 30
package Linux::IpRoute2::attr::link::num_tx_queues          { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( count ); }         # 31
package Linux::IpRoute2::attr::link::num_rx_queues          { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( count ); }         # 32
package Linux::IpRoute2::attr::link::carrier                { use constant packpat => 'C';                                 }                    # 33
package Linux::IpRoute2::attr::link::carrier_changes        { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( count ); }         # 35
package Linux::IpRoute2::attr::link::phys_port_name         { use constant packpat => 'Z*';  use Linux::IpRoute2::struct qw( name ); }          # 38
package Linux::IpRoute2::attr::link::proto_down             { use constant packpat => 'C';   use Linux::IpRoute2::struct qw( state ); }         # 39
package Linux::IpRoute2::attr::link::gso_max_segs           { use constant packpat => 'L';   use Linux::IpRoute2::struct qw( count ); }         # 40
package Linux::IpRoute2::attr::link::gso_max_size           { use constant packpat => 'L';   use Linux::IpRoute2::struct qw( bytes ); }         # 41
package Linux::IpRoute2::attr::link::xdp                    {}                                                                                  # 43    (NESTED)
package Linux::IpRoute2::attr::link::carrier_up_count       { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( count ); }         # 47
package Linux::IpRoute2::attr::link::carrier_down_count     { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( count ); }         # 48
package Linux::IpRoute2::attr::link::new_ifindex            { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( index ); }         # 49
package Linux::IpRoute2::attr::link::min_mtu                { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( bytes ); }         # 50
package Linux::IpRoute2::attr::link::max_mtu                { use constant packpat => 'l';   use Linux::IpRoute2::struct qw( bytes ); }         # 51
package Linux::IpRoute2::attr::link::alt_ifname             { use constant packpat => 'Z*';  use Linux::IpRoute2::struct qw( name ); }          # 53
package Linux::IpRoute2::attr::link::perm_address           { use parent -norequire => Linux::IpRoute2::attr::link::address::; }                # 54
package Linux::IpRoute2::attr::link::parent_dev_name        { use constant packpat => 'Z*';  use Linux::IpRoute2::struct qw( name ); }          # 56
package Linux::IpRoute2::attr::link::parent_dev_bus_name    { use constant packpat => 'Z*';  use Linux::IpRoute2::struct qw( name ); }          # 57
package Linux::IpRoute2::attr::link::gro_max_size           { use constant packpat => 'L';   use Linux::IpRoute2::struct qw( max_size ); }      # 58
package Linux::IpRoute2::attr::link::tso_max_size           { use constant packpat => 'L';   use Linux::IpRoute2::struct qw( max_size ); }      # 59
package Linux::IpRoute2::attr::link::tso_max_segs           { use constant packpat => 'L';   use Linux::IpRoute2::struct qw( max_segs ); }      # 60
package Linux::IpRoute2::attr::link::allmulti               { use constant packpat => 'L';   use Linux::IpRoute2::struct qw( count ); }         # 61

BEGIN {
    my @link_attr_pkg_map;
    for my $ifla ( 0 .. IFLA_MAX ) {
        my $cnam = IFLA_to_label($ifla) // next;
        next unless $cnam && $cnam =~ /^\w+$/;
        my $rpkg = 'Linux::IpRoute2::attr::link::'.$cnam;
        $link_attr_pkg_map[$ifla] = eval qq{
            package $rpkg {
                use parent -norequire =>
                           Linux::IpRoute2::attr::link::_base::;
                use constant {
                    attr_type => $ifla,
                    msg_class => Linux::IpRoute2::message::link::,
                };
            }
            ${rpkg}::;
        };
    }
    sub _attr_type_to_pkg {
        my ($self, $attr_code) = @_;
        @_ == 2 || confess "Wrong number of args; expected 2, got " . scalar@_;
        ref $self || croak "Expecting an object";
        $self->isa('Linux::IpRoute2::message::link') || croak "Wrong type of invocant; want Linux::IpRoute2::message::link or subclass, got ".ref $self;
        defined $attr_code || croak "Expecting an attribute type";

        return $link_attr_pkg_map[$attr_code] ||
            confess sprintf "\e[22m%s::_attr_type_to_pkg(%s) no class package\e[m\e[K for attr_code=%s\n"
                        . "\tLinux::IpRoute2::attr::link::...\n"
                        . "\tattr_pkg_map has %d elements\n"
                        . "\tMAX_IFLA=%s\n"
                        . "\t",
                    __PACKAGE__,
                    ref $self,
                    $attr_code,
                    scalar @link_attr_pkg_map,
                    IFLA_MAX;
    }
}

sub round_up($) {
    my ($l) = @_;
    return -(-$l & ~3);
}

sub unpack_self {
    my ($self, $body) = @_;

    warn "\e[1;33m⇒Into " . __PACKAGE__ . "::unpack_self($self)\e[m";

    # splice the IFINFO header off
    my (
        $ifi_family,
        $ifi_type,
        $ifi_index,
        $ifi_flags,
        $ifi_change,
        $data,
    ) = my @resp_args = unpack struct_ifinfomsg_pack . 'x![L]a*', $body;
    @resp_args  == 6 or confess 'Unpack response failed!';

    warn "\t\e[33m packfmt={" . struct_ifinfomsg_pack . 'x![L]a*' . "} packlen=" . struct_ifinfomsg_len . "\e[m\n";

    $self->{ifi_family} = $ifi_family;
    $self->{ifi_type}   = $ifi_type;
    $self->{ifi_index}  = $ifi_index;
    $self->{ifi_flags}  = $ifi_flags;
    $self->{ifi_change} = $ifi_change;

    warn "\e[1;33m⇐From " . __PACKAGE__ . "::unpack_self\e[m returning " . Data::Dumper->new([$self],[qw[self]])->Indent(0)->Useqq(1)->Dump;
    warn sprintf "\e[43;30munpack_self taking %d bytes and returning %d\e[m\n", length($body), length($data);
    warn sprintf "\e[33m\t\tin={%s}\e[m\n", unpack("H*", $body);
    warn sprintf "\e[33m\t\tback={%s}\e[m\n", unpack("H*", $data);

    return $data;
}

package Linux::IpRoute2::attr::link::address {
    # This package also implements:
    #   Linux::IpRoute2::attr::link::broadcast
    #   Linux::IpRoute2::attr::link::perm_address
    # Store as a string of 12 or 16 hex digits (without punctuation) so
    # that we can use the inherited unpack_self and getpack.
    use constant packpat => 'H*';
    use Linux::IpRoute2::struct qw( macaddr_compat );
    sub macaddr { return $_[0]->macaddr_compat =~ s/\w\w(?=\w)/$&:/gr }
}

package Linux::IpRoute2::attr::af_spec {
    use Carp qw( croak confess );

    use Socket qw( AF_INET AF_INET6 );
    use Linux::Socket::Extras qw( AF_NETLINK );

    #
    # Kinds of sub-attributes that can be incorporated within a
    # Linux::IpRoute2::attr::af_spec (IFLA_AF_SPEC) attribute within a
    # Linux::IpRoute2::message::link (RTM_LINK) message
    #
    package Linux::IpRoute2::attr::af_spec::_base {
        use parent 'Linux::IpRoute2::attr::_base';
    }

    BEGIN {
        my @afspec_names;
        $afspec_names[0]            = 'unspec';
        $afspec_names[AF_INET6]     = 'inet6';
        $afspec_names[AF_INET]      = 'inet';
        $afspec_names[AF_NETLINK]   = 'netlink';

        my @afspec_attr_pkg_map;
        for my $af (keys @afspec_names) {
            my $cnam = $afspec_names[$af];
            next unless $cnam && $cnam =~ /^\w+$/;
            my $rpkg = 'Linux::IpRoute2::attr::af_spec::'.$cnam;
            $afspec_attr_pkg_map[$af] = eval qq{
                package $rpkg {
                    use parent -norequire => Linux::IpRoute2::attr::af_spec::_base::;
                    use constant attr_type => $af;
                }
                ${rpkg}::;
            };
        }

        sub _attr_type_to_pkg {
            my ($self, $attr_code) = @_;
            @_ == 2 || confess "Wrong number of args; expected 2, got " . scalar@_;
            ref $self || croak "Expecting an object";
            $self->isa('Linux::IpRoute2::attr::af_spec') || croak "Wrong type of invocant; want Linux::IpRoute2::attr::af_spec or subclass, got ".ref $self;
            defined $attr_code || croak "Expecting an attribute type";

            return $afspec_attr_pkg_map[$attr_code] ||
                confess sprintf "\e[22m%s::_attr_type_to_pkg(%s) no class package\e[m\e[K for attr_code=%s\n"
                            . "\tLinux::IpRoute2::attr::ad_spec::...\n"
                            . "\tattr_pkg_map has %d elements\n"
                            . "\t",
                        __PACKAGE__,
                        ref $self,
                        $attr_code,
                        scalar @afspec_attr_pkg_map;
        }
    }
}

package Linux::IpRoute2::attr::af_spec::inet     {
    use Carp qw( confess croak );

    use Linux::IpRoute2::if_link qw( :ifla_inet );

    #
    # Kinds of sub-sub-attributes that can be incorporated within an AF_INET
    # sub-attribute within a Linux::IpRoute2::attr::af_spec (IFLA_AF_SPEC)
    # attribute within a Linux::IpRoute2::message::link (RTM_LINK) message
    #
    package Linux::IpRoute2::attr::ifla::inet::_base  {
        use parent 'Linux::IpRoute2::attr::_base';
        use constant packpat => 'L*';
    }

    package Linux::IpRoute2::attr::ifla::inet::conf   {}
    package Linux::IpRoute2::attr::ifla::inet::unspec {}

    BEGIN {
        my @ifla_pkg_map;
        for my $ifla ( 0 .. IFLA_INET_MAX ) {
            my $cnam = IFLA_INET_to_label($ifla) // next;
            next unless $cnam && $cnam =~ /^\w+$/;
            my $rpkg = 'Linux::IpRoute2::attr::ifla::inet::'.$cnam;
            $ifla_pkg_map[$ifla] = eval qq{
                package $rpkg {
                    use parent -norequire =>
                               Linux::IpRoute2::attr::ifla::inet::_base::;
                    use constant attr_type => $ifla;
                }
                ${rpkg}::;
            };
        }
        sub _attr_type_to_pkg {
            my ($self, $attr_code) = @_;
            @_ == 2 || confess "Wrong number of args; expected 2, got " . scalar@_;
            ref $self || croak "Expecting an object";
            $self->isa('Linux::IpRoute2::attr::af_spec::inet') || croak "wrong type of invocant; want Linux::IpRoute2::attr::af_spec::inet or subclass, got ".ref $self;
            defined $attr_code || croak "Expecting an attribute type";

            return $ifla_pkg_map[$attr_code] ||
                confess sprintf "\e[22m%s::_attr_type_to_pkg(%s) no class package\e[m\e[k for attr_code=%s\n"
                            . "\tlinux::iproute2::attr::af_spec::inet::...\n"
                            . "\tattr_pkg_map has %d elements\n"
                            . "\tmax_ifla=%s\n"
                            . "\t",
                        __PACKAGE__,
                        ref $self,
                        $attr_code,
                        scalar @ifla_pkg_map,
                        IFLA_INET_MAX;
        }
    }
}

#
# The Linux::IpRoute2::attr::ifla::inet::conf (IFLA_INET_CONF)
# sub-sub-attribute within an AF_INET sub-attribute within a
# Linux::IpRoute2::attr::af_spec (IFLA_AF_SPEC) attribute within a
# Linux::IpRoute2::message::link (RTM_LINK) message.
#
# It has a long list of uint32_t ("L") values corresponding to the
# IPV4_DEVCONF_* symbols.
#
package Linux::IpRoute2::attr::ifla::inet::conf   {
    use Linux::IpRoute2::ip qw( :ipv4_devconf );
    use Linux::IpRoute2::struct map { IPV4_DEVCONF_to_label $_ } IPV4_DEVCONF_MIN .. IPV4_DEVCONF_MAX;
    use constant packpat => 'L*';
}

package Linux::IpRoute2::attr::af_spec::inet6     {
    use Carp qw( confess croak );

    use Linux::IpRoute2::if_link qw( :ifla_inet6 );

    #
    # Kinds of sub-sub-attributes that can be incorporated within an AF_INET6
    # sub-attribute within a Linux::IpRoute2::attr::af_spec (IFLA_AF_SPEC)
    # attribute within a Linux::IpRoute2::message::link (RTM_LINK) message
    #
    package Linux::IpRoute2::attr::ifla::inet6::_base       {
        use parent 'Linux::IpRoute2::attr::_base';
        use constant packpat => 'L*';
    }

    package Linux::IpRoute2::attr::ifla::inet6::addr_gen_mode { use constant packpat => 'C'; }
    package Linux::IpRoute2::attr::ifla::inet6::cacheinfo   {}
    package Linux::IpRoute2::attr::ifla::inet6::conf        {}
    package Linux::IpRoute2::attr::ifla::inet6::flags       {}
    package Linux::IpRoute2::attr::ifla::inet6::icmp6stats  {}
    package Linux::IpRoute2::attr::ifla::inet6::max         {}
    package Linux::IpRoute2::attr::ifla::inet6::mcast       {}
    package Linux::IpRoute2::attr::ifla::inet6::ra_mtu      {}
    package Linux::IpRoute2::attr::ifla::inet6::stats       {}
    package Linux::IpRoute2::attr::ifla::inet6::token       {}
    package Linux::IpRoute2::attr::ifla::inet6::unspec      {}

    BEGIN {
        my @ifla_pkg_map;
        for my $ifla ( 0 .. IFLA_INET6_MAX ) {
            my $cnam = IFLA_INET6_to_label($ifla) // next;
            next unless $cnam && $cnam =~ /^\w+$/;
            my $rpkg = 'Linux::IpRoute2::attr::ifla::inet6::'.$cnam;
            $ifla_pkg_map[$ifla] = eval qq{
                package $rpkg {
                    use parent -norequire =>
                               Linux::IpRoute2::attr::ifla::inet6::_base::;
                    use constant attr_type => $ifla;
                }
                ${rpkg}::;
            };
        }
        sub _attr_type_to_pkg {
            my ($self, $attr_code) = @_;
            @_ == 2 || confess "wrong number of args; expected 2, got " . scalar@_;
            ref $self || croak "expecting an object";
            $self->isa('Linux::IpRoute2::attr::af_spec::inet6') || croak "wrong type of invocant; want Linux::IpRoute2::attr::af_spec::inet6 or subclass, got ".ref $self;
            defined $attr_code || croak "expecting an attribute type";

            return $ifla_pkg_map[$attr_code] ||
                confess sprintf "\e[22m%s::_attr_type_to_pkg(%s) no class package\e[m\e[k for attr_code=%s\n"
                            . "\tlinux::iproute2::attr::af_spec::inet6::...\n"
                            . "\tattr_pkg_map has %d elements\n"
                            . "\tmax_ifla=%s\n"
                            . "\t",
                        __PACKAGE__,
                        ref $self,
                        $attr_code,
                        scalar @ifla_pkg_map,
                        IFLA_INET6_MAX;
        }
    }
}

#
# The Linux::IpRoute2::attr::ifla::inet6::conf (IFLA_INET6_CONF)
# sub-sub-attribute within an AF_INET6 sub-attribute within a
# Linux::IpRoute2::attr::af_spec (IFLA_AF_SPEC) attribute within a
# Linux::IpRoute2::message::link (RTM_LINK) message.
#
# It has a long list of uint32_t ("L") values corresponding to the DEVCONF_*
# symbols.
#
package Linux::IpRoute2::attr::ifla::inet6::conf   {
    use Linux::IpRoute2::ipv6 qw( :devconf DEVCONF_to_label DEVCONF_MIN DEVCONF_MAX );
    use Linux::IpRoute2::struct map { DEVCONF_to_label $_ } DEVCONF_MIN .. DEVCONF_MAX;
    use constant packpat => 'L*';
}

package Linux::IpRoute2::attr::link::xdp {
    use Carp 'croak';
    use constant packpat => '(S2)*';

    package Linux::IpRoute2::attr::link::xdp::_base {
        use parent 'Linux::IpRoute2::default_unpack';
        use constant packpat => '';
    }

    use Linux::IpRoute2::if_link qw(
        IFLA_XDP_MAX
        IFLA_XDP_to_label
        XDP_ATTACHED_MAX
    );

    #
    # If any of the subattributes might need to have variably-sized integers, use this
    #   use parent -norequire => Linux::IpRoute2::attr::_base::;
    # in place
    #   use constant packpat => 'C';
    #
    {
        my @xdp_attr_pkg_map;
        for my $xdp ( 0 .. IFLA_XDP_MAX ) {
            my $cnam = IFLA_XDP_to_label($xdp) // next;
            next unless $cnam && $cnam =~ /^\w+$/;
            my $rpkg = 'Linux::IpRoute2::attr::link::xdp::'.$cnam;
            $xdp_attr_pkg_map[$xdp] = eval qq{
                package $rpkg {
                    use parent -norequire => Linux::IpRoute2::attr::link::xdp::_base::;
                    use constant attr_type => $xdp;
                }
                ${rpkg}::;
            };
        }
        sub _attr_type_to_pkg {
            my ($self, $attr_type) = @_;
            return $xdp_attr_pkg_map[$attr_type];
        }
    }

    package Linux::IpRoute2::attr::link::xdp::_base::flag {
        use parent -norequire => Linux::IpRoute2::attr::link::xdp::_base::;
        use constant packpat => 'C';
    }
    package Linux::IpRoute2::attr::link::xdp::attach {

        use  Linux::IpRoute2::if_link qw(
            IFLA_XDP_MAX
            IFLA_XDP_to_label
        );
        {
            my @xdp_attach_attr_pkg_map;
            for my $xdp ( 0 .. IFLA_XDP_MAX ) {
                my $cnam = IFLA_XDP_to_label($xdp) // next;
                next unless $cnam && $cnam =~ /^\w+$/;
                my $rpkg = 'Linux::IpRoute2::attr::link::xdp::'.$cnam;
                $xdp_attach_attr_pkg_map[$xdp] = eval qq{
                    package $rpkg {
                        use parent -norequire => Linux::IpRoute2::attr::link::xdp::_base::flag::;
                    }
                    ${rpkg}::;
                };
            }
            sub _attr_type_to_pkg {
                my ($self, $attr_type) = @_;
                return $xdp_attach_attr_pkg_map[$attr_type];
            }
        }
    }

    sub getpack {
        state %once;
        my $pkg = __PACKAGE__;
        warn "${pkg}::getpack(@_) is missing, using fallback 'H*'" if ! $once{$pkg}++;
        return 'H*';
    }

    sub xdp {
        my $self = shift;
        return @$self[1..$#$self];
    }
}

1;
