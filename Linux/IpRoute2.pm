#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

# INTERNAL DATA STRUCTURES
#
# Messages and fragments are subtyped to correspond to their payload type &
# semantics.
#
# Operation codes are composed from a 2-bit opcode (NEW/DEL/GET/SET) and a
# 6-bit operand type code (LINK/ADDR/ROUTE/...)
#
# Generally operations on the same operand type will share a message class; for
# example, RTM_NEWLINK, RTM_DELLINK, RTM_GETLINK, & RTM_SETLINK are all
# communicated using
# Linux::IpRoute2::message::link, which in turn is a
# subclass
# of Linux::IpRoute2::message::_base. (In this context a "link"
# refers to a network interface.)
#
# Messages are also subtyped as "requests" and "responses"; this generally
# leads to an inheritance diamond; for example the "link" request and response
# classes are at the apexes of these inheritance graphs:
#
# ╭──────────╮     ╭─────────╮         ╭─────────╮         ╭─────────╮
# ⎪ response ⎪     ⎪  link   ⎪         ⎪  addr   ⎪         ⎪  route  ⎪      ...
# ╰────╥─────╯     ⎪ request ⎪         ⎪ request ⎪         ⎪ request ⎪
#      ║           ╰───╥─╥───╯         ╰───╥─╥───╯         ╰───╥─╥───╯
# ╭────╨────╮          ║ ║                 ║ ║                 ║ ║
# ⎪ message ⎪          ║ ║                 ║ ║                 ║ ║
# ⎪ builder ⎪          ║ ║                 ║ ║                 ║ ║
# ╰────┬────╯          ║ ║                 ║ ║                 ║ ║
#      │               ║ ║                 ║ ║                 ║ ║
#      ╰───┬───────────║─║─────┬───────────║─║─────┬───────────║─║──────────╌╌╌
#          │       ╔═══╝ ╚══╗  │       ╔═══╝ ╚══╗  │       ╔═══╝ ╚══╗
#          │  ╭────╨────╮   ║  │  ╭────╨────╮   ║  │  ╭────╨────╮   ║
#          │  ⎪  link   ⎪   ║  │  ⎪  addr   ⎪   ║  │  ⎪  route  ⎪   ║
#          ╰─►⎪ message ⎪   ║  ╰─►⎪ message ⎪   ║  ╰─►⎪ message ⎪   ║
#             ╰─┬──╥────╯   ║     ╰─┬──╥────╯   ║     ╰─┬──╥────╯   ║
#               │  ║        ╚════════════════╦══╩═══════════════════╩═══════╍╍┅
#               │  ║                │  ║     ║          │  ║
#               │  ╚════════╦══════════╩═════║═════════════╩════════════════╍╍┅
#               │           ║       │        ║          │
#               │      ╭────╨────╮  │   ╭────╨────╮     │
#               │      ⎪ message ⎪  │   ⎪ request ⎪     │
#               │      ⎪  base   ⎪  │   ⎪  base   ⎪     │
#               │      ╰─────────╯  │   ╰─────────╯     │
#               │  ╭──────────╮     │  ╭──────────╮     │  ╭───────────╮
#               │  ⎪ link msg ⎪╮    │  ⎪ addr msg ⎪╮    │  ⎪ route msg ⎪╮
#               ╰─▻⎪   attrs  ⎪⎪╮   ╰─▻⎪   attrs  ⎪⎪╮   ╰─▻⎪   attrs   ⎪⎪╮  ...
#                  ╰──────────╯⎪⎪      ╰──────────╯⎪⎪      ╰───────────╯⎪⎪
#                   ╰──────────╯⎪       ╰──────────╯⎪       ╰───────────╯⎪
#                    ╰─────╥────╯        ╰─────╥────╯        ╰─────╥─────╯
#                     ╭────╨──────╮       ╭────╨──────╮       ╭────╨──────╮
#                     ⎪ link msg  ⎪       ⎪ addr msg  ⎪       ⎪ route msg ⎪ ...
#                     ⎪ attr base ⎪       ⎪ attr base ⎪       ⎪ attr base ⎪
#                     ╰─────╥─────╯       ╰─────╥─────╯       ╰─────╥─────╯
#                           ║                   ║                   ║
#                           ╚════════╦══════════╩═══════════════════╩═══════╍╍┅
#                                    ║
#                               ╭────╨──────────╮
#                               ⎪ msg attr base ⎪
#                               ╰───────────────╯
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
# Responses comprise a "plain" message with the addition of network metadata.
#
# Unpacking is driven by C<unpack_self>.
#
# Leaf types have a C<packpat> method (actually a constant) that returns a
# control string usable by both C<pack> and C<unpack>. They are implemented
# as blessed arrays, with elements in pack/unpack order, and utilise a
# C<unpack_self> method in a common base class.
#
# Non-leaf types include a
#
# The "response" hierarchy relies on a general approach to unpacking:
#   Each class includes an "unpack_msg_self", that given an empty blessed
#   object, fills in its data by unpacking a byte stream.
#   handled by a common "unpack_self" function, that calls packpat on
#   the invocant
#   the packfmt
#   W
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
#   new_by_type - based on provided code
#   unpack_self - fill in fields of existing object, unpacked from bytestream
#

package Linux::IpRoute2 v0.1.0 {

use Carp qw( confess cluck );

our $ShowComposition = 0;
our $ShowConnection = 0;
our $ShowDecomposition = 0;
our $ShowWithDump = 0;
our $SortReceivedOptions = 0;

use Linux::IpRoute2::attr::_base;
use Linux::IpRoute2::message::_base;
use Linux::IpRoute2::request::_base;
use Linux::IpRoute2::message::link;
use Linux::IpRoute2::request::get_link;
use Linux::IpRoute2::response;
use Linux::IpRoute2::connector;

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

sub TEST {
    my ($this, $iface_name) = @_;
    use Data::Dumper;
    local $SIG{__DIE__} = sub {
        defined $^S or return;  # Normal handling during parsing
        $^S and return;         # Silence if going to be caught
        ref or chomp for @_ = @_;
        print STDERR "\e[1;41m\e[KDying...\e[22m\e[J\n";
        cluck @_;
        print STDERR "\e[0m\n\e[J\n";
        exit 1
    };

    my $self = __PACKAGE__->iprt2_connect_route(0);
    printf STDERR "\e[36;1mConnected\e[22m: %s\e[m\n",
                Data::Dumper->new([$self], [qw[connector]])->Indent(0)->Useqq(1)->Dump
        if $ShowConnection;

    my $sendmsg_flags = 0;

    my $ifi_family  = 0;    # AF_UNSPEC
    my $ifi_type    = 0;    # ARPHRD_*
    my $ifi_index   = 0;    # Link index; 0 == all/unrestricted
    my $ifi_flags   = 0;    # IFF_* flags
    my $ifi_change  = 0;    # IFF_* change mask

    # Compose & send an iplink_req

    my $req = Linux::IpRoute2::request::get_link::
            ->compose( $ifi_family, $ifi_type, $ifi_index, $ifi_flags, $ifi_change )
            ->add_ifla( IFLA_EXT_MASK, RTEXT_FILTER_VF | RTEXT_FILTER_SKIP_STATS )
            ->add_ifla( IFLA_IFNAME,   $iface_name )
            ->send( $self->{F4}, $sendmsg_flags ) or die "Bad send; $!";

    my ( $response, $recv_flags, $recv_ctrl, $recv_from ) =
        Linux::IpRoute2::response::->recv_new($self->{F4});

    $response->show( dirn => Linux::IpRoute2::message::_base::DirnRecv | Linux::IpRoute2::message::_base::DirnMesgMethod );

    $response->show;

    ## Use previous answers as parameters to the next question

    $ifi_family  = AF_INET6;    # 10
    $ifi_type    = 0;           # ARPHRD_*
    $ifi_index   = $response->{ifi_index} || confess "Did not get an interface index from first query";
    $ifi_flags   = 0;           # IFF_* flags
    $ifi_change  = 0;           # IFF_* change mask

    ## Tweak socket settings

    $self->{F3}->set_netlink_opt(NETLINK_GET_STRICT_CHK, 1);

    $req = Linux::IpRoute2::request::get_link::
            ->compose( $ifi_family, $ifi_type, $ifi_index, $ifi_flags, $ifi_change )
            ->add_ifla( IFLA_EXT_MASK, RTEXT_FILTER_VF | RTEXT_FILTER_SKIP_STATS )
            ->send( $self->{F3}, $sendmsg_flags ) or die "Bad send; $!";

    my ( $response2, $recv_flags2, $recv_ctrl2, $recv_from2 ) =
        Linux::IpRoute2::response::->recv_new($self->{F3});

    $response2->show( dirn => Linux::IpRoute2::message::_base::DirnRecv | Linux::IpRoute2::message::_base::DirnMesgMethod );
}

use Exporter 'import';
our @EXPORT = qw( iprt2_connect );

our %EXPORT_TAGS;
$EXPORT_TAGS{ALL} = \@EXPORT;
}

1;
