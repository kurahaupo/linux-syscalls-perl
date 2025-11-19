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

our $ShowComposition = 1;
our $ShowWithDump = 1;
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
    #local $SIG{__WARN__} = \&cluck;
    local $SIG{__DIE__} = sub {
        @_ = @_;
        ref or chomp for @_;
        if ($^S) {
            # Silence if going to be caught
            return;
            print STDERR "\e[2mthrow(@_) will be caught\e[m\n";
        } elsif (defined $^S) {
            print STDERR "\e[1;41m\e[K⇒Dying: @_\e[0m\e[K\n";
            cluck '(here)';
            print STDERR "\e[1;41m\e[K⇐Dead:  @_\e[0m\e[K\n";
        } else {
            # Normal handling during parsing
            return;
            warn "\e[1;41m\e[KDeath while parsing: @_\e[0m\e[K\n";
        }
    };

    my $self = __PACKAGE__->iprt2_connect_route(0);
    printf STDERR "\e[36;1mConnected\e[22m: %s\e[m\n", Data::Dumper->new([$self], [qw[connector]])->Indent(0)->Useqq(1)->Dump;

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

            #$unpackrecurse[32820]               = \&show_0x8034;                                                                                   # 52|0x8000 = 32820

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
