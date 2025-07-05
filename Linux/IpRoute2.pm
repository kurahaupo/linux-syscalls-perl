#!/module/for/perl

use v5.10;
use strict;
use warnings;

# INTERNAL DATA STRUCTURES
#
# Messages and fragments are subtyped to correspond to their payload type &
# semantics. Related operation codes may share a message class; for example,
# codes RTM_NEWLINK, RTM_DELLINK, RTM_GETLINK, & RTM_SETLINK all use the same
# base data class Linux::IpRoute2::message::link, which in turn is a subclass
# of Linux::IpRoute2::message. (In this context a "link"
# refers to a network interface.)
#
# Messages are also subtyped as "requests" and "responses"; this generally
# leads to an inheritance diamond; for example the "link" request and response
# classes are at the apexes of these inheritance graphs:
#
#          ╭─────────╮                     ╭──────────╮
#          ⎪  link   ⎪                     ⎪   link   ⎪
#          ⎪ request ⎪                     ⎪ response ⎪
#          ╰────╥────╯                     ╰────╥─────╯
#               ║                               ║
#        ╔══════╩══════╗                 ╔══════╩══════╗
#        ║             ║                 ║             ║
#   ╭────╨────╮   ╭────╨────╮       ╭────╨────╮   ╭────╨─────╮
#   ⎪  link   ⎪   ⎪ request ⎪       ⎪   link  ⎪   ⎪ response ⎪
#   ⎪ message ⎪   ╰────╥────╯       ⎪ message ⎪   ╰────╥─────╯
#   ╰────╥────╯        ║            ╰────╥────╯        ║
#        ║             ║                 ║             ║
#        ╚══════╦══════╝                 ╚══════╦══════╝
#               ║                               ║
#          ╭────╨────╮                     ╭────╨────╮
#          ⎪ message ⎪                     ⎪ message ⎪
#          ╰─────────╯                     ╰─────────╯
#
# There are corresponding diamond hierachies for each message type.
#
#
# Note that the (generic) "request" and "response" classes cannot override
# methods in the (generic) "message" class because they are to the right of
# their peer, so they can only add new methods. This is not an obstacle in
# general because their additional functions relate to network transport.
#
#
# The data classes provide a "pack" method that returns a binary string,
# which can either be a whole message, or a component (attribute) to
# incorporate into a message.
#
# The "response" hierarchy includes a polymorphic "unpack_new", that
# takes a byte stream and extracts different object types from it.
#
# The base "generic message" class provides:
#
# The "request" class inherits from the base "message" class; it provides
#     - a polymorphic constructor to instantiate a request message from a
#       message code
#     - a method to add attributes
#     - a method to send to a socket (or file)
#
# These are used in two ways:
#   messages    - can be sent and received
#   attributes  - attached to a message or another attribute
#
#
# They provide polymorphic instantiation to build a new object:
#   new_by_code - based on provided code
#   unpack_new  - based on code unpacked from bytestream
#   unpack_new  - provide the type-code and the binary data

#

{
$Linux::IpRoute2::ShowComposition = 1;
$Linux::IpRoute2::ShowWithDump = 1;
}

#   package importable {
#       # Normally when you “use” a package, it first checks to see if it's already
#       # loaded, and if not, looks for a filename that's related to its package
#       # name. If it can't find that file, it simply fails.
#       #
#       # Unfornately the “is already loaded” check only works if it was previously
#       # loaded by “use” or “require”. If you simply created the package directly
#       # but in a different file, that doesn't count, which means when you try to
#       # use it (or use parent it) you get a fatal error that the filename does
#       # not exists.
#       #
#       # This mini package makes it easy to work around this obstacle, by simply
#       # writing
#       #   use importable;
#       # at the top of your package.
#       #
#       # In the specific case where C<use parent I<packagename>;> implicitly does
#       # C<use I<packagename> ();> C<use parent -norequire => I<packagename>;>.
#
#       use Carp 'carp', 'croak';
#
#       sub import {
#           (shift)->isa(__PACKAGE__) or croak "Invalid invocation" if @_;
#           @_ == 0 or croak "Extra args";
#           my ($pkg, $filename) = caller;
#           $pkg =~ s#::#/#g;   # convert package path to POSIX file path
#           $pkg .= '.pm';
#           ! $INC{$pkg} || $INC{$pkg} eq $filename
#               or croak "Package ".($pkg =~ s/\.pm$//r =~ s#/#::#gr)
#                       . " is already importable from $INC{$pkg};"
#                       . " can't make importable from $filename";
#           $INC{$pkg} = $filename;
#         # carp "making $pkg usable in $filename" if $^C && $^W;
#       }
#       # This package faces the same obstacle as those it's intending to help;
#       # invoking our own "import" resolves this.
#       BEGIN { __PACKAGE__->import }
#       # Auto-destruct this package once this file has been compiled
#       UNITCHECK { undef *importable::; }
#   }

package Linux::IpRoute2::message {
    # Base class for all NETLINK messages

    use Carp qw( confess cluck );

    use Linux::Syscalls qw( MSG_to_desc );
    use Linux::IpRoute2::rtnetlink qw( struct_nlmsghdr_len );

    sub _B($) { 1 << pop }

    use constant {
        DirnNone        => 0,
        DirnSend        => _B 0,
        DirnRecv        => _B 1,
        DirnPeek        => _B 2,
        DirnSysCall     => _B 3,
        DirnSockMethod  => _B 4,
        DirnMesgMethod  => _B 5,
    };
    {
    my @dirb = qw( Send Recv Peek SysCall SockMethod MesgMethod );
    sub DIRN_to_desc($;$) {
        splice @_, 1, 0, \@dirb;
        goto &Linux::Syscalls::_bits_to_desc;
    }
    }

    sub _show_msg(%) {
        my ($self) = shift if not $#_ % 2;
        ! defined $self || $self->isa(__PACKAGE__) || confess 'Bad invocant';
        my %args = @_;
        my $errno = $!;
        my $dirn      = delete $args{dirn};
        my $op_res    = delete $args{op_res};
        my $data      = delete $args{data};
        my $ctrl      = delete $args{ctrl};
        my $name      = delete $args{name};
        my $sflags    = delete $args{sflags};
        my $rflags    = delete $args{rflags};
        printf "%s:\n", DIRN_to_desc $dirn if $dirn;
        cluck "showing message" if ! $dirn;
        printf " result %d (maybe length of data)\n", $op_res if defined $op_res;
        printf " sflags %#x (%s)\n", $sflags, MSG_to_desc $sflags if defined $rflags;
        printf " rflags %#x (%s)\n", $rflags, MSG_to_desc $rflags if defined $rflags;
        printf "   data [%s]\n",                          defined $data ? unpack("H*", $data) : "(none)";
        printf "   ctrl [%s]\n",                          defined $ctrl ? unpack("H*", $ctrl) : "(none)";
        printf " %6s [%s]\n", $dirn ? "from" : "to", defined $name ? unpack("H*", $name) : "(unspecified)";
        if ($Linux::IpRoute2::ShowWithDump) {
            require Data::Dumper;
            my $d = Data::Dumper->new([$self]);
            print $d->Useqq(1)->Dump, "\n";
        }
        printf "  EXTRA ARG: %s = %s\n", $_, $args{$_} // '(undef)' for sort keys %args;
        printf "\e[m\n";
    }
    sub show {
        my ($self) = shift;
        _show_msg $self, data => $self->{data}, @_;
    }

    sub unpack_new {
        my $self = shift;
        $self = bless {}, $self if ! ref $self;
        my ($data) = @_;
        cluck "In unpack_new of $self";
        $self->{body} //= shift // do {
                my $data = $self->{data} // return;
                substr $data, struct_nlmsghdr_len;
            };
        return $self;
    }
    package Linux::IpRoute2::message::link {
        use parent -norequire, Linux::IpRoute2::message::;

        use Carp qw( confess cluck );

        use Linux::IpRoute2::rtnetlink qw( struct_ifinfomsg_pack );

        my @attr_pkg_map;

        #
        # Dynamically construct a message-attribute class for each possible IFLA code
        #
        package Linux::IpRoute2::fragment::link {
            package Linux::IpRoute2::fragment::link::_unknown {}

            use Carp 'croak';
            use Linux::IpRoute2::if_link qw( IFLA_to_label IFLA_to_name IFLA_MAX );

            BEGIN {
                for my $ifla ( 0 .. IFLA_MAX ) {
                    my $cnam = IFLA_to_label($ifla) // next;
                    next unless $cnam && $cnam =~ /^\w+$/;

                    my $rpkg = 'Linux::IpRoute2::fragment::link::'.$cnam;
                    $attr_pkg_map[$ifla] = eval qq{
                        package $rpkg {
                            use parent -norequire, Linux::IpRoute2::fragment::link::_unknown::;
                            use constant { code => $ifla };
                        }
                        ${rpkg}::;
                    };
                }
            }

            use constant packpat => '';

            sub unpack_new {
                my ($class, $data) = @_;
                $class = ref $class || $class;
                my ($c, @v) = unpack 'x![S]S' . $class->packpat . 'H*', $data;
                my $self = bless \@v, $class;
                $self->code == $c or die "Code mismatch in constructor";
                return $self;
            }

            sub new_by_code {
                my ($class, @args) = @_;
                $class = ref $class || $class;
                my $code = $args[0];
                my $xpkg = $attr_pkg_map[$code] || croak "new_by_code - no Linux::IpRoute2::fragment::link::... package for code $code";
                return bless \@args, $xpkg if ! $class || $xpkg->isa($class);
                $class->isa($xpkg) or croak "new_by_code($code) - requested class $xpkg is neither ancestor nor descendent of $class ";
                return bless \@args, $class;
            }

            sub code { return $_[0][0] }
            sub extra { return $_[0][-1] }

            # return packed data
            sub getpack {
                my ($self) = @_;
                my $res = pack 'x![S]S' . $self->packpat, $self->code, @$self;
                substr($res, 0, 2) = pack 'S', length $res;
                warn __PACKAGE__."::getpack(@_) => ".unpack "H*", $res;
                return $res;
            }
            package Linux::IpRoute2::fragment::link::_unknown {
                use parent -norequire, Linux::IpRoute2::fragment::link::;
                use constant packpat => 'a*';
                sub data { return unpack 'H*', $_[0][1] }
            }

            package Linux::IpRoute2::fragment::link::unspec                { use constant packpat => 'x0';                                }         #  0
            package Linux::IpRoute2::fragment::link::ifname                { use constant packpat => 'Z*';  sub name  { return $_[0][1] } }         #  3
            package Linux::IpRoute2::fragment::link::mtu                   { use constant packpat => 'l';   sub bytes { return $_[0][1] } }         #  4
            package Linux::IpRoute2::fragment::link::qdisc                 { use constant packpat => 'Z*';  sub name  { return $_[0][1] } }         #  6
            package Linux::IpRoute2::fragment::link::stats                 { use constant packpat => 'l24'; sub stats { return @{$_[1]}[1..24] } }  #  7 int32_t[24]
            package Linux::IpRoute2::fragment::link::txqlen                { use constant packpat => 'l';   sub bytes { return $_[0][1] } }         # 13
            package Linux::IpRoute2::fragment::link::map                   { use constant packpat => '(L2)*';                             }         # 14
            package Linux::IpRoute2::fragment::link::operstate             { use constant packpat => 'C';   sub state { return $_[0][1] } }         # 16
            package Linux::IpRoute2::fragment::link::linkmode              { use constant packpat => 'C';   sub mode  { return $_[0][1] } }         # 17
            package Linux::IpRoute2::fragment::link::ifalias               { use constant packpat => 'Z*';  sub name  { return $_[0][1] } }         # 20
            package Linux::IpRoute2::fragment::link::num_vf                { use constant packpat => 'l';   sub count { return $_[0][1] } }         # 21
            package Linux::IpRoute2::fragment::link::stats64               { use constant packpat => 'q24'; sub stats { return @{$_[1]}[1..24] } }  # 23 int64_t[24]
            package Linux::IpRoute2::fragment::link::af_spec               {}                                                                       # 26  (RECURSIVE?)
            package Linux::IpRoute2::fragment::link::group                 { use constant packpat => 'l';   sub group { return $_[0][1] } }         # 27
            package Linux::IpRoute2::fragment::link::ext_mask              { use constant packpat => 'l';   sub mask  { return $_[0][1] } }         # 29
            package Linux::IpRoute2::fragment::link::promiscuity           { use constant packpat => 'l';   sub flag  { return $_[0][1] } }         # 30
            package Linux::IpRoute2::fragment::link::num_tx_queues         { use constant packpat => 'l';   sub count { return $_[0][1] } }         # 31
            package Linux::IpRoute2::fragment::link::num_rx_queues         { use constant packpat => 'l';   sub count { return $_[0][1] } }         # 32
            package Linux::IpRoute2::fragment::link::carrier               { use constant packpat => 'V';                                 }         # 33
            package Linux::IpRoute2::fragment::link::carrier_changes       { use constant packpat => 'l';   sub count { return $_[0][1] } }         # 35
            package Linux::IpRoute2::fragment::link::phys_port_name        { use constant packpat => 'Z*';  sub name  { return $_[0][1] } }         # 38
            package Linux::IpRoute2::fragment::link::proto_down            { use constant packpat => 'C';   sub state { return $_[0][1] } }         # 39
            package Linux::IpRoute2::fragment::link::gso_max_segs          { use constant packpat => 'L';   sub count { return $_[0][1] } }         # 40
            package Linux::IpRoute2::fragment::link::gso_max_size          { use constant packpat => 'L';   sub bytes { return $_[0][1] } }         # 41
            package Linux::IpRoute2::fragment::link::xdp                   {}                                                                       # 43    (NESTED)
            package Linux::IpRoute2::fragment::link::carrier_up_count      { use constant packpat => 'l';   sub count { return $_[0][1] } }         # 47
            package Linux::IpRoute2::fragment::link::carrier_down_count    { use constant packpat => 'l';   sub count { return $_[0][1] } }         # 48
            package Linux::IpRoute2::fragment::link::new_ifindex           { use constant packpat => 'l';   sub index { return $_[0][1] } }         # 49
            package Linux::IpRoute2::fragment::link::min_mtu               { use constant packpat => 'l';   sub bytes { return $_[0][1] } }         # 50
            package Linux::IpRoute2::fragment::link::max_mtu               { use constant packpat => 'l';   sub bytes { return $_[0][1] } }         # 51
            package Linux::IpRoute2::fragment::link::alt_ifname            { use constant packpat => 'Z*';  sub name  { return $_[0][1] } }         # 53
            package Linux::IpRoute2::fragment::link::parent_dev_name       { use constant packpat => 'Z*';  sub name  { return $_[0][1] } }         # 56
            package Linux::IpRoute2::fragment::link::parent_dev_bus_name   { use constant packpat => 'Z*';  sub name  { return $_[0][1] } }         # 57
            #$unpackrecurse[32820]               = \&show_0x8034;                                                                                   # 52|0x8000 = 32820

            package Linux::IpRoute2::fragment::link::_macaddr {
                use parent -norequire, Linux::IpRoute2::fragment::link::;
                BEGIN {
                    # Override the 'use parent ...' previously set for each of these classes:
                    @Linux::IpRoute2::fragment::link::address::ISA             = #  1
                    @Linux::IpRoute2::fragment::link::broadcast::ISA           = #  2
                    @Linux::IpRoute2::fragment::link::perm_address::ISA        = # 54
                     __PACKAGE__;
                }
                # Store as a string of 12 or 16 hex digits (without punctuation) so
                # that we can use the inherited unpack_new and getpack.
                use constant packpat => 'H*';
              # Special version that applies a sanity check to the length
              # sub unpack_new {
              #     my $self = shift->SUPER::unpack_new(@_);
              #     given (length $self->[1]) { when (not $_ == 12 || $_ == 16) { die "Wrong length for MAC address" } }
              #     return $self;
              # }
                sub macaddr { return $_[0][1] =~ s/\w\w(?=.)/$&:/gr }
                sub macaddr_compat { return $_[0][1] }    # just the digits, no separators
            }

            package Linux::IpRoute2::fragment::link::xdp {
                use constant packpat => '(S2)*';
                my @xdp_attr_pkg_map;
                package Linux::IpRoute2::fragment::link::xdp::_base {
                    use  Linux::IpRoute2::if_link qw( IFLA_XDP_MAX IFLA_XDP_to_label );

                    BEGIN {
                        for my $xdp ( 0 .. IFLA_XDP_MAX ) {
                            my $cnam = IFLA_XDP_to_label($xdp) // next;
                            next unless $cnam && $cnam =~ /^\w+$/;

                            my $rpkg = 'Linux::IpRoute2::fragment::link::xdp::'.$cnam;
                            $xdp_attr_pkg_map[$xdp] = eval qq{
                                package $rpkg {
                                    use parent -norequire, Linux::IpRoute2::fragment::link::xdp::_base::;
                                    use constant { code => $xdp };
                                }
                                ${rpkg}::;
                            };
                        }
                    }

                    use constant packpat => '';
                    sub unpack_new {
                        my ($class, $data) = @_;
                        $class = ref $class || $class;
                        my $self = bless \(my @v), $class;
                        (my $c, @v) = unpack 'x![S]S' . $class->packpat . 'H*', $data;
                        $self->code == $c or die "Code mismatch in constructor";
                        return $self;
                    }

                    sub extra { return $_[0][-1] }

                    # return packed data
                    sub getpack {
                        my ($self) = @_;
                        my $res = pack 'x![S]S' . $self->packpat, @$self;
                        substr($res, 0, 2) = pack 'S', length $res;
                        warn __PACKAGE__."::getpack(@_) => ".unpack "H*", $res;
                        return $res;
                    }
                }

                sub unpack_new {
                    my ($class, $data) = @_;
                    $class = ref $class || $class;
                    my $self = bless \(my @v), $class;
                    (my $c, @v) = unpack 'x![S]S' . $class->packpat . 'H*', $data;
                    $self->code == $c or die "Code mismatch in constructor";

                    my @xdp_opts;
                    for ( my $len, my $offset = 0 ; $offset < length $data ; $offset += 1+($len-1|3) ) {
                        ($len, my $code) = unpack '@'.$offset.'SS', $data;
                        my $rpkg = $xdp_attr_pkg_map[$code]
                                    || Linux::IpRoute2::fragment::link::xdp::_base::;

                        my $v = $rpkg->unpack_new(substr $data, $offset, $len);

                        ref $v or die "_unpack_opt returned non-ref ($v)";
                        $xdp_opts[$code] = $v;
                    }
                    $self->{opts}       = [ sort { $a->code <=> $b->code } @xdp_opts ];

                    $self->_unpack_refine if $self->can('_unpack_refine');

                    return $self;
                }

                sub getpack {
                    die __PACKAGE__."::getpack(@_) => UNIMPLEMENTED "; #.unpack "H*", $res;
                }

                sub xdp {
                    my $self = shift;
                    return @$self[1..$#$self];
                }
            }
        }

        sub unpack_new {
            my $self = shift;
            my ($body) = @_;
            cluck "In unpack_new of $self";
            warn "\e[1;33mIn Linux::IpRoute2::message::link::unpack_new\e[m";
            $self->SUPER::unpack_new(@_);

            # splice the IFINFO header off
            my (
                $ifi_family,
                $ifi_type,
                $ifi_index,
                $ifi_flags,
                $ifi_change,
                $data,
            ) = my @resp_args = unpack struct_ifinfomsg_pack . 'x![L]a*', $body; # substr $body, 0, struct_ifinfomsg_len, '';
            @resp_args  == 6 or confess 'Unpack response failed!';

            $self->{ifi_family} = $ifi_family;
            $self->{ifi_type}   = $ifi_type;
            $self->{ifi_index}  = $ifi_index;
            $self->{ifi_flags}  = $ifi_flags;
            $self->{ifi_change} = $ifi_change;

            my @resp_opts;
            for ( my $len, my $offset = 0 ; $offset < length $data ; $offset += 1+($len-1|3) ) {
                ($len, my $code) = unpack '@'.$offset.'SS', $data;
                my $rpkg = $attr_pkg_map[$code]
                            || Linux::IpRoute2::fragment::link::;

                my $v = $rpkg->unpack_new(substr $data, $offset, $len);

                ref $v or die "_unpack_opt returned non-ref ($v)";
                push @resp_opts, $v;
            }
            $self->{opts}       = [ sort { $a->code <=> $b->code } @resp_opts ];

            $self->_unpack_refine if $self->can('_unpack_refine');

            return $self;
        }

    }

    package Linux::IpRoute2::message::addr      { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::route     { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::neigh     { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::rule      { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::qdisc     { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::tclass    { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::tfilter   { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::action    { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::prefix    { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::multicast { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::anycast   { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::neightbl  { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::nduseropt { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::addrlabel { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::dcb       { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::netconf   { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::mdb       { use parent -norequire, Linux::IpRoute2::message::; }
    package Linux::IpRoute2::message::nsid      { use parent -norequire, Linux::IpRoute2::message::; }

    use Linux::IpRoute2::rtnetlink qw( :rtm );

    my @unpack_director;
    $unpack_director[RTM_LINK]       = Linux::IpRoute2::message::link::;
    $unpack_director[RTM_ADDR]       = Linux::IpRoute2::message::addr::;
    $unpack_director[RTM_ROUTE]      = Linux::IpRoute2::message::route::;
    $unpack_director[RTM_NEIGH]      = Linux::IpRoute2::message::neigh::;
    $unpack_director[RTM_RULE]       = Linux::IpRoute2::message::rule::;
    $unpack_director[RTM_QDISC]      = Linux::IpRoute2::message::qdisc::;
    $unpack_director[RTM_TCLASS]     = Linux::IpRoute2::message::tclass::;
    $unpack_director[RTM_TFILTER]    = Linux::IpRoute2::message::tfilter::;
    $unpack_director[RTM_ACTION]     = Linux::IpRoute2::message::action::;
    $unpack_director[RTM_PREFIX]     = Linux::IpRoute2::message::prefix::;
    $unpack_director[RTM_MULTICAST]  = Linux::IpRoute2::message::multicast::;
    $unpack_director[RTM_ANYCAST]    = Linux::IpRoute2::message::anycast::;
    $unpack_director[RTM_NEIGHTBL]   = Linux::IpRoute2::message::neightbl::;
    $unpack_director[RTM_NDUSEROPT]  = Linux::IpRoute2::message::nduseropt::;
    $unpack_director[RTM_ADDRLABEL]  = Linux::IpRoute2::message::addrlabel::;
    $unpack_director[RTM_DCB]        = Linux::IpRoute2::message::dcb::;
    $unpack_director[RTM_NETCONF]    = Linux::IpRoute2::message::netconf::;
    $unpack_director[RTM_MDB]        = Linux::IpRoute2::message::mdb::;
    $unpack_director[RTM_NSID]       = Linux::IpRoute2::message::nsid::;

    sub _rebless {
        my $self = shift;
        my $code = shift // $self->{code} // return;
        my $type = $code >> RTM_TSHIFT;
        $type >= RTM_TMIN && $type <= RTM_TMAX || return;
        my $class = $unpack_director[$type] || return;
        bless $self, $class;
    }
}

package Linux::IpRoute2::request {
    use parent -norequire, Linux::IpRoute2::message::;

    use Carp 'confess';
    use POSIX 'EMSGSIZE';

    sub start {
        my $self = shift;
        my $class = ref $self || $self;
        $#_ == 1 or confess "Wrong args";
        $self = bless {
            header => [@_],
            options => [],
        }, $class;
        return $self;
    }

    sub _set_len(\$) {
        my ($self) = shift;
        substr($self->{data}, 0, 4) = pack 'L', length $self->{data};
        $self;
    }
    sub send {
        my ($self, $conx, $sendmsg_flags) = @_;
        $sendmsg_flags //= 0;   # optional

        my $msg = $self->getpack(++$conx->{seq}, $conx->{port_id});

        my $rlen = $conx->msend($sendmsg_flags, $msg, undef, $conx->FixedSocketName) or die "Could not send";;

        $self->show( dirn => Linux::IpRoute2::message::DirnSend | Linux::IpRoute2::message::DirnMesgMethod );

        my $mlen = length $msg;
        if ($rlen != $mlen) {
            warn "sendmsg() returned $rlen when expecting $mlen";
            $self->{_LAST_ERROR} = {
                errno   => ($! = EMSGSIZE), # 90 - message too long
                mlen    => $mlen,
                rlen    => $rlen,
                reason  => 'returned value does not match requested message size',
            };
            return;
        }
        return $rlen;
    }

    package Linux::IpRoute2::request::get_link {
        use parent -norequire,
                   Linux::IpRoute2::message::link::,
                   Linux::IpRoute2::request::;
        use Carp 'confess';
        use Linux::IpRoute2::rtnetlink qw( RTM_GETLINK NLM_F_REQUEST
                                           struct_ifinfomsg_pack
                                           struct_nlmsghdr_pack );
        # From first half of "talk"
        sub compose {
            my $self = shift;
            $#_ == 4 or confess "Wrong args";
            $self = $self->SUPER::start(RTM_GETLINK, NLM_F_REQUEST);
            $self->{ifinfomsg} = \@_;
            return $self;
        }
        sub add_ifla {
            my $self = shift;
            my $opt = Linux::IpRoute2::fragment::link::->new_by_code(@_);
            if ($Linux::IpRoute2::ShowComposition) {
                require Data::Dumper;
                my $d = Data::Dumper->new([$opt]);
                warn "Adding option $opt\n"
                   . "\t" . $d->Dump;
            }
            push @{ $self->{options} }, $opt;
          # my ($opt_type, @args) = @_;
          # @@@FIXUP
          # my $body = pack $pack_fmt, @args;
          # $body ne '' or confess "Pack result was empty; probably insufficient args?\nfmt=$pack_fmt, args=".(0+@args)."[@args]\n";
          # push @{ $self->{options} }, pack 'SSa*x![L]', 4+length($body), $opt_type, $body;
            return $self;
        }
        sub getpack($;$$) {
            my ($self, $seq, $pid) = @_;
            my ($code, $flags) = @{ $self->{header} };
            my $d = Data::Dumper->new([$self]);
            warn "getpack($self):\t". $d->Dump;
            my $request = pack struct_nlmsghdr_pack,
                                0,              # length, to be filled in...
                                $code,
                                $flags,
                                $seq // 0,      # sequence (dummy)
                                $pid // 0;      # port-id

            my $ifinfomsg = pack struct_ifinfomsg_pack, @{$self->{ifinfomsg}};

            # Concatenate the packed base request and all the packed options,
            # inserting padding so that each has 4-byte alignment.
            $request = pack '(a*x![L])*',
                            $request,
                            $ifinfomsg,
                            map { $_->getpack }
                                @{ $self->{options} };

            # ... now fill in length;  4 == sizeof(uint32_t), where uint32_t is the result of pack 'L'
            substr $request, 0, 4, pack L => length $request;
            warn __PACKAGE__."::getpack(@_) => ".unpack "H*", $request;
            return $self->{data} = $request;
        }
    }
}

package Linux::IpRoute2::response {
    use parent -norequire, Linux::IpRoute2::message::;

    use Carp qw( cluck confess );
    use Data::Dumper;

    # Process an in-coming NLM message

    use Linux::IpRoute2::rtnetlink qw( :rtm );

    my @unpack_director;
    BEGIN {
        for my $type (qw( link addr route neigh rule qdisc tclass tfilter
                          action prefix multicast anycast neightbl nduseropt
                          addrlabel dcb netconf mdb nsid )) {
            my $tsym = 'RTM_'.uc $type;
            eval qq{
                package Linux::IpRoute2::response::$type {
                    use parent -norequire,
                                Linux::IpRoute2::message::${type}::,
                                Linux::IpRoute2::response::;
                }
                \$unpack_director[$tsym] = Linux::IpRoute2::response::${type}::;
            };
        }
    };





    package Linux::IpRoute2::response::link      { use parent -norequire, Linux::IpRoute2::message::link::,      Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::addr      { use parent -norequire, Linux::IpRoute2::message::addr::,      Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::route     { use parent -norequire, Linux::IpRoute2::message::route::,     Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::neigh     { use parent -norequire, Linux::IpRoute2::message::neigh::,     Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::rule      { use parent -norequire, Linux::IpRoute2::message::rule::,      Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::qdisc     { use parent -norequire, Linux::IpRoute2::message::qdisc::,     Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::tclass    { use parent -norequire, Linux::IpRoute2::message::tclass::,    Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::tfilter   { use parent -norequire, Linux::IpRoute2::message::tfilter::,   Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::action    { use parent -norequire, Linux::IpRoute2::message::action::,    Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::prefix    { use parent -norequire, Linux::IpRoute2::message::prefix::,    Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::multicast { use parent -norequire, Linux::IpRoute2::message::multicast::, Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::anycast   { use parent -norequire, Linux::IpRoute2::message::anycast::,   Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::neightbl  { use parent -norequire, Linux::IpRoute2::message::neightbl::,  Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::nduseropt { use parent -norequire, Linux::IpRoute2::message::nduseropt::, Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::addrlabel { use parent -norequire, Linux::IpRoute2::message::addrlabel::, Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::dcb       { use parent -norequire, Linux::IpRoute2::message::dcb::,       Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::netconf   { use parent -norequire, Linux::IpRoute2::message::netconf::,   Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::mdb       { use parent -norequire, Linux::IpRoute2::message::mdb::,       Linux::IpRoute2::response::; }
    package Linux::IpRoute2::response::nsid      { use parent -norequire, Linux::IpRoute2::message::nsid::,      Linux::IpRoute2::response::; }
    $unpack_director[RTM_LINK]       = Linux::IpRoute2::response::link::;
    $unpack_director[RTM_ADDR]       = Linux::IpRoute2::response::addr::;
    $unpack_director[RTM_ROUTE]      = Linux::IpRoute2::response::route::;
    $unpack_director[RTM_NEIGH]      = Linux::IpRoute2::response::neigh::;
    $unpack_director[RTM_RULE]       = Linux::IpRoute2::response::rule::;
    $unpack_director[RTM_QDISC]      = Linux::IpRoute2::response::qdisc::;
    $unpack_director[RTM_TCLASS]     = Linux::IpRoute2::response::tclass::;
    $unpack_director[RTM_TFILTER]    = Linux::IpRoute2::response::tfilter::;
    $unpack_director[RTM_ACTION]     = Linux::IpRoute2::response::action::;
    $unpack_director[RTM_PREFIX]     = Linux::IpRoute2::response::prefix::;
    $unpack_director[RTM_MULTICAST]  = Linux::IpRoute2::response::multicast::;
    $unpack_director[RTM_ANYCAST]    = Linux::IpRoute2::response::anycast::;
    $unpack_director[RTM_NEIGHTBL]   = Linux::IpRoute2::response::neightbl::;
    $unpack_director[RTM_NDUSEROPT]  = Linux::IpRoute2::response::nduseropt::;
    $unpack_director[RTM_ADDRLABEL]  = Linux::IpRoute2::response::addrlabel::;
    $unpack_director[RTM_DCB]        = Linux::IpRoute2::response::dcb::;
    $unpack_director[RTM_NETCONF]    = Linux::IpRoute2::response::netconf::;
    $unpack_director[RTM_MDB]        = Linux::IpRoute2::response::mdb::;
    $unpack_director[RTM_NSID]       = Linux::IpRoute2::response::nsid::;

    sub _rebless {
        my $self = shift;
        my $code = shift // $self->{code} // return;
        my $type = $code >> RTM_TSHIFT;
        $type >= RTM_TMIN && $type <= RTM_TMAX || return;
        my $class = $unpack_director[$type] || return;
        bless $self, $class;
    }

    use Linux::IpRoute2::rtnetlink qw(
                                       struct_ifinfomsg_pack
                                       struct_nlmsghdr_pack
                                       struct_sockaddr_nl_pack
                                     );

    use constant {
        ctrl_size   =>     0,       # always discard
        name_size   =>  0x40,       # normally 12, but allow space in case it grows
    };

    use Linux::Syscalls qw( MSG_PEEK MSG_TRUNC MSG_DONTWAIT );   # :msg

    # From second half of "talk"
    sub recv_new {
        my $self = shift;
        my $class = ref $self || $self;

        my $sock = shift or confess "Missing 'sock' arg";

        $#_%2 or confess "Odd args";
        my %opts = @_;

        my $accept_reply_size = $opts{size} // 0x400;   # actually only need 0x3fc == 1020

        my ($rlen, $recv_flags, $reply, $recv_ctrl, $recv_from);
        for (;;) {
            ($rlen, $recv_flags, $reply, $recv_ctrl, $recv_from) = $sock->mrecv(MSG_PEEK|MSG_TRUNC, $accept_reply_size, ctrl_size, name_size);
            last if $rlen > 0;
            sleep 0.05;
            warn "Retrying recvmsg...";
        }

        $rlen == 1020 or warn "recvmsg(PEEK) returned len=$rlen when expecting 1020";
        if (my $expect_reply_from = $opts{sent_to}) {
            $recv_from eq $expect_reply_from
                or warn "recvmsg(PEEK) returned from=[".(unpack 'H*', $recv_from)."]"
                    . " when expecting [".(unpack 'H*', $expect_reply_from)."]";
        }

        if ($recv_flags & MSG_TRUNC) {
            # still need to get reply
            ($rlen, $recv_flags, $reply, $recv_ctrl, $recv_from) = $sock->mrecv(0, $rlen, ctrl_size, name_size);
        } else {
            # already got reply, just need to pop it from the queue
            () = $sock->mrecv(MSG_TRUNC, 0, 0, 0x400); # discard answer
        }

        $rlen == 1020 or warn "recvmsg() returned len=$rlen when expecting 1020";

        $recv_from eq $opts{expect_reply_from}
                or warn "recvmsg() returned from=[".(unpack 'H*', $recv_from)."]"
                     . " when expecting [".(unpack 'H*', $opts{expect_reply_from})."]"
            if $opts{expect_reply_from};

        my @r = $sock->mrecv(MSG_TRUNC|MSG_DONTWAIT, 0, 0, 0x400);
        unless (!@r && $!{EAGAIN}) {
            warn "unexpected response after message; $!";
            die;
        }

        $self = bless {
            data => $reply,
        }, $class;

        $self->{ctrl} = $recv_ctrl if $recv_ctrl;

        if ( $recv_from and my @nl = unpack struct_sockaddr_nl_pack, $recv_from ) {
            my (
                $nl_family,  # set to AF_NETLINK (__kernel_sa_family_t = unsigned short)
                $nl_pid,     # port ID
                $nl_groups,  # multicast groups mask
            ) = @nl;

            $recv_from = {
                    data    => $recv_from,
                    family  => $nl_family,
                    pid     => $nl_pid,
                    groups  => $nl_groups,
                };

            $self->{from} = $recv_from;
        }

        my ( $reply_len2, $code, $flags, $seq, $port_id, $body ) = unpack struct_nlmsghdr_pack . 'x![L] a*', $reply;

        $reply_len2 = length $reply or die "Reply length mismatch got $reply_len2, expected ".length($reply)."\n";

        if ($seq != $sock->{seq}) {
            confess "Out-of-order response; got reply to #$seq but expected #$sock->{seq}";
            # This code should eventually change, since out-of-order responses
            # are technically permitted if there's more than one outstanding
            # query.
        }

        $self->{code}       = $code;
        $self->{flags}      = $flags;
        $self->{seq}        = $seq;
        $self->{port_id}    = $port_id;

        $self->_rebless($code);
        my $how = $self->can('unpack_new');
        warn "\e[1;41mAttempting unpack\e[m of $self";
        #warn " using ".(*$how{NAME});
        $self->unpack_new($body);
        warn " ... \e[1;46mafter unpack\e[m to ".Dumper($self);

        $self->show( dirn => Linux::IpRoute2::message::DirnRecv | Linux::IpRoute2::message::DirnMesgMethod );

        return $self if not wantarray;
        return $self, $recv_flags, $recv_ctrl, $recv_from;
    }
}

package Linux::IpRoute2::connector {

    use Carp qw( croak );

    use Linux::Syscalls qw( :msg );

    use Socket qw(
        SOCK_CLOEXEC
        SOCK_RAW
    );
    # Socket should have these but doesn't ...
    use Linux::Socket::Extras qw( :netlink :so :sol );

    use Linux::IpRoute2::rtnetlink qw(
        NETLINK_ROUTE
        NETLINK_EXT_ACK
    );

    # Built-in functions:
    #   getsockname
    #   setsockopt
    #   socket

    use constant {
        def_sendbuf_size    =>    0x8000,   #   32768
        def_recvbuf_size    =>  0x100000,   # 1048576
    };

    #
    # In principle there can be multiple interleaved conversations going on the
    # same socket, in which case the port_id and subscription_groups might be
    # useful, but for this simple linear program just set them both to 0.
    #
    use constant {
        FixedSocketName => pack('S@12', AF_NETLINK),    # port_ID=0, groups=0x0000000000000000
    };

    sub open_route {
        my $self = shift;
        my $class = ref $self || $self;

        my ($group_subs) = @_;

        my $protocol = NETLINK_ROUTE;
        my $port_id = 0;

        @_ == 1 or croak 'Wrong number of args; expected 1 (plus "this"), but got '.(0+@_);

        $group_subs //= 0;
        $protocol //= NETLINK_ROUTE;

        socket my $sock, PF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, $protocol       or die "Cannot create NETLINK socket";

        $self = bless {
                sock => $sock,
            }, $class;

        $self->set_sndbufsz(def_sendbuf_size);
        $self->set_rcvbufsz(def_recvbuf_size);
        $self->set_netlink_opt(NETLINK_EXT_ACK, 1);
        bind $sock, pack 'SSQ', AF_NETLINK, $port_id, $group_subs           or die "Cannot bind(AF_LENLINK, port_id=$port_id, groups=$group_subs for $self";

        my $rta = $self->get_sockinfo;
        warn sprintf "Got data=[%s]\n", unpack "H*", $rta;
        my ($rta_type, $rta_pid, $rta_groups) = unpack "L3", $rta;
        warn sprintf "Got rta_type=%s rta_pid=%#x rta_groups=%s\n", $rta_type, $rta_pid, $rta_groups;

        $self->{sockname_hex} = unpack "H*", $rta;
        $self->{sockname} = { type => $rta_type, pid => $rta_pid, groups => $rta_groups };

        $self->{seq} = $^T;
        $self->{port_id} = $port_id;

        return $self;
    }

    sub set_sndbufsz {
        my ($self, $size) = @_;
        my $sock = $self->{sock};
        setsockopt $sock, SOL_SOCKET, SO_SNDBUF, pack "L", $size            or die "Cannot setsockopt SNDBUF $size for $self";
    }

    sub set_rcvbufsz {
        my ($self, $size) = @_;
        my $sock = $self->{sock};
        setsockopt $sock, SOL_SOCKET, SO_RCVBUF, pack "L", $size            or die "Cannot setsockopt RCVBUF $size for $self";
    }

    sub set_netlink_opt {
        my ($self, $opt, $value) = @_;
        my $sock = $self->{sock};
        setsockopt $sock, SOL_NETLINK, $opt, pack "L", $value               or die "Cannot setsockopt SOL_NETLINK, $opt ,$value for $self";
    }

    sub get_sockinfo {
        my ($self) = @_;
        my $sock = $self->{sock};
        getsockname $sock or die "Cannot getsockname for $self";
    }

    sub msend {
        my ($self, $flags, $msg, $ctrl, $name) = @_;
        my $sock = $self->{sock};

        state @verify_requests; @verify_requests or @verify_requests = (

            "\x34\x00\x00\x00\x12\x00\x01\x00" . 'XXXX' . "\x00\x00\x00\x00" .
                    "\x00\x00\x00\x00\x00\x00\x00\x00" .
                    "\x00\x00\x00\x00\x00\x00\x00\x00" .
                    "\x08\x00\x1d\x00\x09\x00\x00\x00" .
                    "\x09\x00\x03\x00\x65\x74\x68\x30" . "\x00\x00\x00\x00",

            "\x28\x00\x00\x00\x12\x00\x01\x00" . 'XXXX' . "\x00\x00\x00\x00" .
                    "\x0a\x00\x00\x00\x02\x00\x00\x00" .
                    "\x00\x00\x00\x00\x00\x00\x00\x00" .
                    "\x08\x00\x1d\x00\x09\x00\x00\x00"

        );

        if (my $cr = shift @verify_requests) {
            my $trq = $msg =~ s/^........\K..../XXXX/r;
            $trq eq $cr or do {
                $_ = unpack 'H*', $_ for $msg, $trq, $cr;
                s/^.{16}\K.{8}/--------/ for $trq, $cr;
                die sprintf "Incorrect request\n    got [%s]\n  match [%s]\n wanted [%s]",
                            map {
                                s/........(?=.)/$&./gr
                            } $msg, $trq, $cr;
            }
        }

        my $r = sendmsg $sock, $flags, $msg, $ctrl, $name;

        Linux::IpRoute2::message::_show_msg
            dirn => Linux::IpRoute2::message::DirnSend | Linux::IpRoute2::message::DirnSockMethod,
            sflags => $flags,
            op_res => $r,
            data => $msg,
            name => $name;

        return $r // ();
    }

    sub mrecv {
        my ($self, $flags, $maxmsglen, $maxctrllen, $maxnamelen) = @_;
        my $sock = $self->{sock};

        my @r = recvmsg $sock, $flags, $maxmsglen, $maxctrllen, $maxnamelen;

        my ($op_res, $rflags, $msg, $ctrl, $name) = @r;
        Linux::IpRoute2::message::_show_msg
            dirn    => Linux::IpRoute2::message::DirnRecv
                     | Linux::IpRoute2::message::DirnSockMethod
                     | ( $flags & MSG_PEEK && Linux::IpRoute2::message::DirnSockMethod ),
            op_res  => $op_res,
            data    => $msg,
            sflags  => $flags,
            rflags  => $rflags,
            ctrl    => $ctrl,
            name    => $name;

        return $r[0] if ! wantarray;    # just the status
        return @r;
    }

    sub close {
        my ($self) = @_;
        my $sock = delete $self->{sock} or return;
        close $sock or die "Cannot close socket $sock for ipr2 $self; #!";
    }

    use overload (
        '""' => sub {
            my ($self) = @_;
            my $r = sprintf "IPR2_rtnetlink_connector(%#p)", $self;
            if ( my $sock = $self->{sock} ) {
                my $fd = fileno($sock);
                $r .= ' fd=$fd' if defined $fd;
            }
            return $r;
        },
        '0+' => sub { return shift },
    );

    BEGIN { *DESTROY = \&close };
}

package Linux::IpRoute2 v0.0.1 {
use Socket qw( AF_INET6 );
use Linux::Socket::Extras qw( AF_NETLINK );

use Linux::IpRoute2::rtnetlink qw(
    NETLINK_GET_STRICT_CHK
    RTEXT_FILTER_SKIP_STATS
    RTEXT_FILTER_VF
);
use Linux::IpRoute2::if_link qw( IFLA_EXT_MASK IFLA_IFNAME );

sub iprt2_connect_route {
    my $self = shift;
    my $class = ref $self || $self;

    my ($group_subs) = @_;

    my $f3 = Linux::IpRoute2::connector::->open_route($group_subs);

    my $f4 = Linux::IpRoute2::connector::->open_route($group_subs);

    $self = bless {
        F3 => $f3,  # not yet clear why there's more than one...
        F4 => $f4,
    }, $class;
    return $self;
}

use Carp qw( confess );

sub TEST {
    use Data::Dumper;
    use Carp qw( confess cluck );
    $SIG{__WARN__} = \&cluck;
    $SIG{__DIE__} = sub { print "\e[1;41mDying...\e[m\n"; undef $SIG{__DIE__}; goto &confess };

    my $self = __PACKAGE__->iprt2_connect_route(0);
    say Dumper($self);

    my $sendmsg_flags = 0;
    my $iface_name  = 'eth0';

    my $ifi_family  = 0;    # AF_UNSPEC
    my $ifi_type    = 0;    # ARPHRD_*
    my $ifi_index   = 0;    # Link index; 0 == all/unrestricted
    my $ifi_flags   = 0;    # IFF_* flags
    my $ifi_change  = 0;    # IFF_* change mask

    # Compose & send an iplink_req

    Linux::IpRoute2::request::get_link::
            ->compose( $ifi_family, $ifi_type, $ifi_index, $ifi_flags, $ifi_change )
            ->add_ifla( IFLA_EXT_MASK, RTEXT_FILTER_VF | RTEXT_FILTER_SKIP_STATS )
            ->add_ifla( IFLA_IFNAME,   $iface_name )
            ->send( $self->{F4}, $sendmsg_flags ) or die "Bad send; $!";

    my ( $response, $recv_flags, $recv_ctrl, $recv_from ) =
        Linux::IpRoute2::response::->recv_new($self->{F4});

    $response->show;

    ## Use previous answers as parameters to the next question

    $ifi_family  = AF_INET6;    # 10
    $ifi_type    = 0;           # ARPHRD_*
    $ifi_index   = $response->{ifi_index} || confess "Did not get an interface index from first query";
    $ifi_flags   = 0;           # IFF_* flags
    $ifi_change  = 0;           # IFF_* change mask

    ## Tweak socket settings

    $self->{F3}->set_netlink_opt(NETLINK_GET_STRICT_CHK, 1);

    Linux::IpRoute2::request::get_link::
            ->compose( $ifi_family, $ifi_type, $ifi_index, $ifi_flags, $ifi_change )
            ->add_ifla( IFLA_EXT_MASK, RTEXT_FILTER_VF | RTEXT_FILTER_SKIP_STATS )
            ->send( $self->{F3}, $sendmsg_flags ) or die "Bad send; $!";

    my ( $response2, $recv_flags2, $recv_ctrl2, $recv_from2 ) =
        Linux::IpRoute2::response::->recv_new($self->{F3});

}

use Exporter 'import';
our @EXPORT = qw( iprt2_connect );

our %EXPORT_TAGS;
$EXPORT_TAGS{ALL} = \@EXPORT;
}

1;

__END__

Note: "pid" in this context is "port ID".

+ strace -s 4096 -e socket,bind,connect,setsockopt,getsockopt,getsockname,sendmsg,recvmsg,shutdown,close ip -6 addr show eth0
...

------
socket(PF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, NETLINK_ROUTE) = 3
setsockopt(3, SOL_SOCKET, SO_SNDBUF, [32768], 4) = 0
setsockopt(3, SOL_SOCKET, SO_RCVBUF, [1048576], 4) = 0
setsockopt(3, SOL_NETLINK, 11, [1], 4)  = 0
bind(3, {sa_family=AF_NETLINK, pid=0, groups=00000000}, 12) = 0
getsockname(3, {sa_family=AF_NETLINK, pid=9821, groups=00000000}, [12]) = 0
setsockopt(3, SOL_NETLINK, 12, [1], 4)  = 0
socket(PF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, NETLINK_ROUTE) = 4
setsockopt(4, SOL_SOCKET, SO_SNDBUF, [32768], 4) = 0
setsockopt(4, SOL_SOCKET, SO_RCVBUF, [1048576], 4) = 0
setsockopt(4, SOL_NETLINK, 11, [1], 4)  = 0
bind(4, {sa_family=AF_NETLINK, pid=0, groups=00000000}, 12) = 0
getsockname(4, {sa_family=AF_NETLINK, pid=-1047251919, groups=00000000}, [12]) = 0
sendmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"\x34\x00\x00\x00\x12\x00\x01\x00\x96\xcc\xb0\x65\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08\x00\x1d\x00\x09\x00\x00\x00\x09\x00\x03\x00\x65\x74\x68\x30\x00\x00\x00\x00", 52}], msg_controllen=0, msg_flags=0}, 0) = 52
recvmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{NULL, 0}], msg_controllen=0, msg_flags=MSG_TRUNC}, MSG_PEEK|MSG_TRUNC) = 1020
recvmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"\xfc\x03\x00\x00\x10\x00\x00\x00\x96\xcc\xb0\x65\x31\x34\x94\xc1\x00\x00\x01\x00\x02\x00\x00\x00\x43\x10\x01\x00\x00\x00\x00\x00\x09\x00\x03\x00\x65\x74\x68\x30\x00\x00\x00\x00\x08\x00\x0d\x00\xe8\x03\x00\x00\x05\x00\x10\x00\x06\x00\x00\x00\x05\x00\x11\x00\x00\x00\x00\x00\x08\x00\x04\x00\xdc\x05\x00\x00\x08\x00\x32\x00\x3c\x00\x00\x00\x08\x00\x33\x00\xdc\x05\x00\x00\x08\x00\x1b\x00\x00\x00\x00\x00\x08\x00\x1e\x00\x01\x00\x00\x00\x08\x00\x1f\x00\x05\x00\x00\x00\x08\x00\x28\x00\xff\xff\x00\x00\x08\x00\x29\x00\x00\x00\x01\x00\x08\x00\x20\x00\x05\x00\x00\x00\x05\x00\x21\x00\x01\x00\x00\x00\x07\x00\x06\x00\x6d\x71\x00\x00\x08\x00\x23\x00\x01\x00\x00\x00\x08\x00\x2f\x00\x01\x00\x00\x00\x08\x00\x30\x00\x00\x00\x00\x00\x05\x00\x27\x00\x00\x00\x00\x00\x24\x00\x0e\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x11\x00\x00\x00\x00\x00\x00\x00\x0a\x00\x01\x00\x00\x1c\x23\x0d\x76\xcc\x00\x00\x0a\x00\x02\x00\xff\xff\xff\xff\xff\xff\x00\x00\xc4\x00\x17\x00\x7c\x6b\x46\x02\x00\x00\x00\x00\x1d\xb0\x60\x01\x00\x00\x00\x00\xa5\x4f\x19\x65\x08\x00\x00\x00\x65\x54\x8a\xe8\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x48\x87\x39\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x64\x00\x07\x00\x7c\x6b\x46\x02\x1d\xb0\x60\x01\xa5\x4f\x19\x65\x65\x54\x8a\xe8\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x48\x87\x39\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08\x00\x15\x00\x00\x00\x00\x00\x0c\x00\x2b\x00\x05\x00\x02\x00\x00\x00\x00\x00\x0a\x00\x36\x00\x00\x1c\x23\x0d\x76\xcc\x00\x00\x90\x01\x1a\x00\x88\x00\x02\x00\x84\x00\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x10\x27\x00\x00\xe8\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x01\x0a\x00\x08\x00\x01\x00\x30\x00\x00\x80\x14\x00\x05\x00\xff\xff\x00\x00\x88\x1c\x00\x00\x1c\x6a\x00\x00\xe8\x03\x00\x00\xe4\x00\x02\x00\x00\x00\x00\x00\x40\x00\x00\x00\xdc\x05\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\xff\xff\xff\xff\xa0\x0f\x00\x00\xe8\x03\x00\x00\x00\x00\x00\x00\x80\x3a\x09\x00\x80\x51\x01\x00\x03\x00\x00\x00\x58\x02\x00\x00\x10\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x60\xea\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x10\x27\x00\x00\xe8\x03\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\xee\x36\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\xff\xff\x00\x00\xff\xff\xff\xff\x10\x00\x34\x80\x0b\x00\x35\x00\x65\x6e\x70\x39\x73\x30\x00\x00\x11\x00\x38\x00\x30\x30\x30\x30\x3a\x30\x39\x3a\x30\x30\x2e\x30\x00\x00\x00\x00\x08\x00\x39\x00\x70\x63\x69\x00", 32768}], msg_controllen=0, msg_flags=0}, 0) = 1020
close(4)                                = 0
sendmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"\x28\x00\x00\x00\x12\x00\x01\x00\x96\xcc\xb0\x65\x00\x00\x00\x00\x0a\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08\x00\x1d\x00\x09\x00\x00\x00", 40}], msg_controllen=0, msg_flags=0}, 0) = 40
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{NULL, 0}], msg_controllen=0, msg_flags=MSG_TRUNC}, MSG_PEEK|MSG_TRUNC) = 1020
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"\xfc\x03\x00\x00\x10\x00\x00\x00\x96\xcc\xb0\x65\x5d\x26\x00\x00\x00\x00\x01\x00\x02\x00\x00\x00\x43\x10\x01\x00\x00\x00\x00\x00\x09\x00\x03\x00\x65\x74\x68\x30\x00\x00\x00\x00\x08\x00\x0d\x00\xe8\x03\x00\x00\x05\x00\x10\x00\x06\x00\x00\x00\x05\x00\x11\x00\x00\x00\x00\x00\x08\x00\x04\x00\xdc\x05\x00\x00\x08\x00\x32\x00\x3c\x00\x00\x00\x08\x00\x33\x00\xdc\x05\x00\x00\x08\x00\x1b\x00\x00\x00\x00\x00\x08\x00\x1e\x00\x01\x00\x00\x00\x08\x00\x1f\x00\x05\x00\x00\x00\x08\x00\x28\x00\xff\xff\x00\x00\x08\x00\x29\x00\x00\x00\x01\x00\x08\x00\x20\x00\x05\x00\x00\x00\x05\x00\x21\x00\x01\x00\x00\x00\x07\x00\x06\x00\x6d\x71\x00\x00\x08\x00\x23\x00\x01\x00\x00\x00\x08\x00\x2f\x00\x01\x00\x00\x00\x08\x00\x30\x00\x00\x00\x00\x00\x05\x00\x27\x00\x00\x00\x00\x00\x24\x00\x0e\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x11\x00\x00\x00\x00\x00\x00\x00\x0a\x00\x01\x00\x00\x1c\x23\x0d\x76\xcc\x00\x00\x0a\x00\x02\x00\xff\xff\xff\xff\xff\xff\x00\x00\xc4\x00\x17\x00\x7c\x6b\x46\x02\x00\x00\x00\x00\x1d\xb0\x60\x01\x00\x00\x00\x00\xa5\x4f\x19\x65\x08\x00\x00\x00\x65\x54\x8a\xe8\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x48\x87\x39\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x64\x00\x07\x00\x7c\x6b\x46\x02\x1d\xb0\x60\x01\xa5\x4f\x19\x65\x65\x54\x8a\xe8\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x48\x87\x39\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08\x00\x15\x00\x00\x00\x00\x00\x0c\x00\x2b\x00\x05\x00\x02\x00\x00\x00\x00\x00\x0a\x00\x36\x00\x00\x1c\x23\x0d\x76\xcc\x00\x00\x90\x01\x1a\x00\x88\x00\x02\x00\x84\x00\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x10\x27\x00\x00\xe8\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x01\x0a\x00\x08\x00\x01\x00\x30\x00\x00\x80\x14\x00\x05\x00\xff\xff\x00\x00\x88\x1c\x00\x00\x1c\x6a\x00\x00\xe8\x03\x00\x00\xe4\x00\x02\x00\x00\x00\x00\x00\x40\x00\x00\x00\xdc\x05\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\xff\xff\xff\xff\xa0\x0f\x00\x00\xe8\x03\x00\x00\x00\x00\x00\x00\x80\x3a\x09\x00\x80\x51\x01\x00\x03\x00\x00\x00\x58\x02\x00\x00\x10\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x01\x00\x00\x00\x60\xea\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x10\x27\x00\x00\xe8\x03\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x80\xee\x36\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\xff\xff\x00\x00\xff\xff\xff\xff\x10\x00\x34\x80\x0b\x00\x35\x00\x65\x6e\x70\x39\x73\x30\x00\x00\x11\x00\x38\x00\x30\x30\x30\x30\x3a\x30\x39\x3a\x30\x30\x2e\x30\x00\x00\x00\x00\x08\x00\x39\x00\x70\x63\x69\x00", 32768}], msg_controllen=0, msg_flags=0}, 0) = 1020
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{NULL, 0}], msg_controllen=0, msg_flags=MSG_TRUNC}, MSG_PEEK|MSG_TRUNC) = 216
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"\x48\x00\x00\x00\x14\x00\x22\x00\x97\xcc\xb0\x65\x5d\x26\x00\x00\x0a\x40\x80\x00\x02\x00\x00\x00\x14\x00\x01\x00\x20\x01\x04\x70\x1f\x2c\x00\x7a\x00\x00\x00\x00\x00\x35\x00\x01\x14\x00\x06\x00\xff\xff\xff\xff\xff\xff\xff\xff\x08\x16\x22\x04\x1a\x8d\xb2\x08\x08\x00\x08\x00\x80\x00\x00\x00\x48\x00\x00\x00\x14\x00\x22\x00\x97\xcc\xb0\x65\x5d\x26\x00\x00\x0a\x40\x80\x00\x02\x00\x00\x00\x14\x00\x01\x00\x20\x01\x04\x70\x1f\x2c\x00\x7a\x00\x00\x00\x00\x00\x00\x00\x06\x14\x00\x06\x00\xff\xff\xff\xff\xff\xff\xff\xff\x07\x16\x22\x04\x1a\x8d\xb2\x08\x08\x00\x08\x00\x80\x00\x00\x00\x48\x00\x00\x00\x14\x00\x22\x00\x97\xcc\xb0\x65\x5d\x26\x00\x00\x0a\x40\x00\x00\x02\x00\x00\x00\x14\x00\x01\x00\x24\x03\x58\x0a\xc2\x5d\x00\x01\x02\x1c\x23\xff\xfe\x0d\x76\xcc\x14\x00\x06\x00\xcc\x36\x00\x00\x0c\x50\x01\x00\x64\xcb\x21\x04\x4e\x3a\xb2\x08\x08\x00\x08\x00\x00\x01\x00\x00", 32768}], msg_controllen=0, msg_flags=0}, 0) = 216
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{NULL, 0}], msg_controllen=0, msg_flags=MSG_TRUNC}, MSG_PEEK|MSG_TRUNC) = 20
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"\x14\x00\x00\x00\x03\x00\x22\x00\x97\xcc\xb0\x65\x5d\x26\x00\x00\x00\x00\x00\x00", 32768}], msg_controllen=0, msg_flags=0}, 0) = 20
close(4)                                = 0

------
socket(PF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, NETLINK_ROUTE) = 3
setsockopt(3, SOL_SOCKET, SO_SNDBUF, [32768], 4) = 0
setsockopt(3, SOL_SOCKET, SO_RCVBUF, [1048576], 4) = 0
setsockopt(3, SOL_NETLINK, 11, [1], 4)  = 0
bind(3, {sa_family=AF_NETLINK, pid=0, groups=00000000}, 12) = 0
getsockname(3, {sa_family=AF_NETLINK, pid=15990, groups=00000000}, [12]) = 0
setsockopt(3, SOL_NETLINK, 12, [1], 4)  = 0

socket(PF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, NETLINK_ROUTE) = 4
setsockopt(4, SOL_SOCKET, SO_SNDBUF, [32768], 4) = 0
setsockopt(4, SOL_SOCKET, SO_RCVBUF, [1048576], 4) = 0
setsockopt(4, SOL_NETLINK, 11, [1], 4)  = 0
bind(4, {sa_family=AF_NETLINK, pid=0, groups=00000000}, 12) = 0
getsockname(4, {sa_family=AF_NETLINK, pid=-774776507, groups=00000000}, [12]) = 0
sendmsg(4,
        { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
          msg_iov(1)=[{"4\0\0\0\22\0\1\0i\362\230e\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\10\0\35\0\t\0\0\0\t\0\3\0eth0\0\0\0\0", 52}],
          msg_controllen=0,
          msg_flags=0 },
        0) = 52
recvmsg(4,
        { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
          msg_iov(1)=[{NULL, 0}],
          msg_controllen=0,
          msg_flags=MSG_TRUNC },
        MSG_PEEK|MSG_TRUNC) = 1020
recvmsg(4,
        { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
          msg_iov(1)=[{"\374\3\0\0\20\0\0\0i\362\230eE\331\321\321\0\0\1\0\2\0\0\0C\20\1\0\0\0\0\0\t\0\3\0eth0\0\0\0\0\10\0\r\0\350\3\0\0\5\0\20\0\6\0\0\0\5\0\21\0\0\0\0\0\10\0\4\0\334\5\0\0\10\0002\0<\0\0\0\10\0003\0\334\5\0\0\10\0\33\0\0\0\0\0\10\0\36\0\1\0\0\0\10\0\37\0\5\0\0\0\10\0(\0\377\377\0\0\10\0)\0\0\0\1\0\10\0 \0\5\0\0\0\5\0!\0\1\0\0\0\7\0\6\0mq\0\0\10\0#\0\1\0\0\0\10\0/\0\1\0\0\0\10\0000\0\0\0\0\0\5\0'\0\0\0\0\0$\0\16\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\21\0\0\0\0\0\0\0\n\0\1\0\0\34#\rv\314\0\0\n\0\2\0\377\377\377\377\377\377\0\0\304\0\27\0\277\254\303\0\0\0\0\00074\207\0\0\0\0\0;I\233\24\2\0\0\0\233\277ug\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\246\f\35\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0d\0\7\0\277\254\303\00074\207\0;I\233\24\233\277ug\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\246\f\35\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\10\0\25\0\0\0\0\0\f\0+\0\5\0\2\0\0\0\0\0\n\0006\0\0\34#\rv\314\0\0\220\1\32\0\210\0\2\0\204\0\1\0\1\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\20'\0\0\350\3\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\4\1\n\0\10\0\1\0000\0\0\200\24\0\5\0\377\377\0\0t\31\0\0\254R\0\0\350\3\0\0\344\0\2\0\0\0\0\0@\0\0\0\334\5\0\0\1\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\377\377\377\377\240\17\0\0\350\3\0\0\0\0\0\0\200:\t\0\200Q\1\0\3\0\0\0X\2\0\0\20\0\0\0\0\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0`\352\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\20'\0\0\350\3\0\0\1\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\200\3566\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\4\0\0\0\0\0\0\377\377\0\0\377\377\377\377\20\0004\200\v\0005\0enp9s0\0\0\21\0008\0000000:09:00.0\0\0\0\0\10\0009\0pci\0", 32768}],
          msg_controllen=0,
          msg_flags=0 },
        0) = 1020
close(4)                                = 0

sendmsg(3,
        { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
          msg_iov(1)=[{"(\0\0\0\22\0\1\0i\362\230e\0\0\0\0\n\0\0\0\2\0\0\0\0\0\0\0\0\0\0\0\10\0\35\0\t\0\0\0", 40}],
          msg_controllen=0,
          msg_flags=0 },
        0) = 40
recvmsg(3,
        { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
          msg_iov(1)=[{NULL, 0}],
          msg_controllen=0,
          msg_flags=MSG_TRUNC },
        MSG_PEEK|MSG_TRUNC) = 1020
recvmsg(3,
        { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
          msg_iov(1)=[{"\374\3\0\0\20\0\0\0i\362\230ev>\0\0\0\0\1\0\2\0\0\0C\20\1\0\0\0\0\0\t\0\3\0eth0\0\0\0\0\10\0\r\0\350\3\0\0\5\0\20\0\6\0\0\0\5\0\21\0\0\0\0\0\10\0\4\0\334\5\0\0\10\0002\0<\0\0\0\10\0003\0\334\5\0\0\10\0\33\0\0\0\0\0\10\0\36\0\1\0\0\0\10\0\37\0\5\0\0\0\10\0(\0\377\377\0\0\10\0)\0\0\0\1\0\10\0 \0\5\0\0\0\5\0!\0\1\0\0\0\7\0\6\0mq\0\0\10\0#\0\1\0\0\0\10\0/\0\1\0\0\0\10\0000\0\0\0\0\0\5\0'\0\0\0\0\0$\0\16\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\21\0\0\0\0\0\0\0\n\0\1\0\0\34#\rv\314\0\0\n\0\2\0\377\377\377\377\377\377\0\0\304\0\27\0\277\254\303\0\0\0\0\00074\207\0\0\0\0\0;I\233\24\2\0\0\0\233\277ug\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\246\f\35\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0d\0\7\0\277\254\303\00074\207\0;I\233\24\233\277ug\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\246\f\35\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\10\0\25\0\0\0\0\0\f\0+\0\5\0\2\0\0\0\0\0\n\0006\0\0\34#\rv\314\0\0\220\1\32\0\210\0\2\0\204\0\1\0\1\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\20'\0\0\350\3\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\4\1\n\0\10\0\1\0000\0\0\200\24\0\5\0\377\377\0\0t\31\0\0\254R\0\0\350\3\0\0\344\0\2\0\0\0\0\0@\0\0\0\334\5\0\0\1\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0\377\377\377\377\240\17\0\0\350\3\0\0\0\0\0\0\200:\t\0\200Q\1\0\3\0\0\0X\2\0\0\20\0\0\0\0\0\0\0\1\0\0\0\1\0\0\0\1\0\0\0`\352\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\20'\0\0\350\3\0\0\1\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\200\3566\0\0\0\0\0\0\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\4\0\0\0\0\0\0\377\377\0\0\377\377\377\377\20\0004\200\v\0005\0enp9s0\0\0\21\0008\0000000:09:00.0\0\0\0\0\10\0009\0pci\0", 32768}],
          msg_controllen=0,
          msg_flags=0 },
        0) = 1020
recvmsg(3,
        { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
          msg_iov(1)=[{NULL, 0}],
          msg_controllen=0,
          msg_flags=MSG_TRUNC },
        MSG_PEEK|MSG_TRUNC) = 144
recvmsg(3,
        { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
          msg_iov(1)=[{"H\0\0\0\24\0\"\0j\362\230ev>\0\0\n@\0\0\2\0\0\0\24\0\1\0$\3X\n\302]\0\1\2\34#\377\376\rv\314\24\0\6\0\3316\0\0\31P\1\0004\3234\1MM\265\3\10\0\10\0\0\1\0\0H\0\0\0\24\0\"\0j\362\230ev>\0\0\n@\200\375\2\0\0\0\24\0\1\0\376\200\0\0\0\0\0\0\2\34#\377\376\rv\314\24\0\6\0\377\377\377\377\377\377\377\377t\31\0\0t\31\0\0\10\0\10\0\200\0\0\0", 32768}],
          msg_controllen=0,
          msg_flags=0 },
        0) = 144
recvmsg(3,
        { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
          msg_iov(1)=[{NULL, 0}],
          msg_controllen=0,
          msg_flags=MSG_TRUNC },
        MSG_PEEK|MSG_TRUNC) = 20
recvmsg(3,
        { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
          msg_iov(1)=[{"\24\0\0\0\3\0\"\0j\362\230ev>\0\0\0\0\0\0", 32768}],
          msg_controllen=0,
          msg_flags=0 },
        0) = 20

...
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    altname enp9s0
    inet6 2403:580a:c25d:1:21c:23ff:fe0d:76cc/64 scope global dynamic mngtmpaddr
       valid_lft 86041sec preferred_lft 14041sec
    inet6 fe80::21c:23ff:fe0d:76cc/64 scope link
       valid_lft forever preferred_lft forever
+++ exited with 0 +++

 IFLA_UNSPEC                0           ?
IFLA_ADDRESS                1           a6          val=[001c230d76cc]
IFLA_BROADCAST              2           a6          val=[ffffffffffff]
IFLA_IFNAME                 3           Z           val=[6574683000]
IFLA_MTU                    4           L           val=[dc050000]
                            5
IFLA_QDISC                  6           Z           val=[6d7100]
IFLA_STATS                  7           L24         val=[031c450266d15f013e9c48649c0d36e80000000000000000000000000000000012bd3800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000]
 IFLA_?                     8
 IFLA_?                     9
 IFLA_?                    10
 IFLA_?                    11
 IFLA_?                    12
IFLA_TXQLEN                13                       val=[e8030000]
IFLA_MAP                   14           (L2)*       val=[0000000000000000000000000000000000000000000000001100000000000000]
 IFLA_?                    15
IFLA_OPERSTATE             16           C           val=[06]
IFLA_LINKMODE              17           C           val=[00]
 IFLA_?                    18
 IFLA_?                    19
 IFLA_?                    20
IFLA_NUM_VF                21           L           val=[00000000]
 IFLA_?                    22
IFLA_STATS64               23           q24         val=[031c45020000000066d15f01000000003e9c4864080000009c0d36e800000000000000000000000000000000000000000000000000000000000000000000000012bd380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000]
 IFLA_?                    24
 IFLA_?                    25
IFLA_AF_SPEC               26           RECURSIVE   val=[8800020084000100010000000000000000000000010000000100000001000000010000000100000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010270000e80300000000000000000000000000000000000004010a00080001003000008014000500ffff0000881c00002c820000e8030000e40002000000000040000000dc05000001000000010000000100000001000000ffffffffa00f0000e803000000000000803a0900805101000300000058020000100000000000000001000000010000000100000060ea000000000000000000000000000000000000000000000000000001000000000000000000000010270000e8030000010000000000000000000000010000000000000000000000010000000000000000000000000000000000000080ee360000000000000000000100000000000000000000000000000000000000000000000004000000000000ffff0000ffffffff]
IFLA_GROUP                 27           L           val=[00000000]
 IFLA_?                    28
 IFLA_?                    29
IFLA_PROMISCUITY           30           L           val=[01000000]
IFLA_NUM_TX_QUEUES         31           L           val=[05000000]
IFLA_NUM_RX_QUEUES         32           L           val=[05000000]
IFLA_CARRIER               33           V           val=[01]
 IFLA_?                    34
IFLA_CARRIER_CHANGES       35           L           val=[01000000]
 IFLA_?                    36
 IFLA_?                    37
 IFLA_?                    38
IFLA_PROTO_DOWN            39           C           val=[00]
IFLA_GSO_MAX_SEGS          40           ll          val=[ffff0000]
IFLA_GSO_MAX_SIZE          41           SS          val=[00000100]
 IFLA_?                    42
IFLA_XDP                   43           S4          val=[0500020000000000]
 IFLA_?                    44
 IFLA_?                    45
 IFLA_?                    46
IFLA_CARRIER_UP_COUNT      47           l           val=[01000000]
IFLA_CARRIER_DOWN_COUNT    48           l           val=[00000000]
 IFLA_?                    51
IFLA_MIN_MTU               50           l           val=[3c000000]
IFLA_MAX_MTU               51           l           val=[dc050000]
 IFLA_?                    52
 IFLA_?                    53
IFLA_PERM_ADDRESS          54           a6          val=[001c230d76cc]
 IFLA_?                    55
IFLA_PARENT_DEV_NAME       56           Z           val=[303030303a30393a30302e3000]
IFLA_PARENT_DEV_BUS_NAME   57           l           val=[70636900]
 ...
IFLA_CODE#32820         32820=0x8034    RECURSIVE   val=[0b003500656e703973300000]

        sub show_ifla_af_spec(@);

        sub show_ifla(@) {
            my ($type, $val, $depth) = @_;
            my $lpref = "\t" x $depth;
            if ( my $rp = $unpackrecurse[$type] ) {
                printf "%sifla: type=%s (%d)\n", $lpref, IFLA_to_name($type), $type;
                for (;$val ne '';) {
                    my $l = unpack 'S', $val or die;
                    $l >= 4 && $l <= length $val or die;
                    my $opt = substr $val, 0, 1+($l-1|3), '';
                    substr($opt, $l) = '';  # trim padding
                    $rp->( unpack('x[S]Sa*', $opt), $depth+1 );
                }
            } else {
                my $um = $unpackmap[$type] || 'H*';
                printf "%sopt: type=%s (%d) val=[%s]\n", $lpref, IFLA_to_name($type), $type, join ',', unpack $um, $val;
            }
        }

        sub show_ifla_af_spec(@) {
            my ($type, $val, $depth) = @_;

            my $lpref = "\t" x $depth;
            printf "%sifla/spec: type=%s (%d)\n", $lpref, AF_to_name($type), $type;

            for (;$val ne '';) {
                my $l = unpack 'S', $val or die;
                $l >= 4 && $l <= length $val or die;
                my $opt = substr $val, 0, 1+($l-1|3), '';
                substr($opt, $l) = '';  # trim padding
                show_ifla( unpack( 'x[S]Sa*', $opt ), $depth+1 );
            }
        }

        sub show_ifi(@) {
            my ($args, $opts, $depth) = @_;
            my ( $family, $type, $index, $flags, $change ) = @$args;
            $depth //= 1;
            my $lpref = "\t" x $depth;
            printf "IFI:\n"
                     . "%sfamily  %s (%d)\n"
                     . "%stype    %s (%d)\n"
                     . "%sindex   %d\n"
                     . "%sflags   %08x/%08x\n",
                    $lpref, AF_to_name $family, $family,
                    $lpref, ARPHRD_to_name $type, $type,
                    $lpref, $index,
                    $lpref, $flags, $change;

            for my $opt (@$opts) {
                show_ifla(@$opt, $depth+1);
            }
        }
