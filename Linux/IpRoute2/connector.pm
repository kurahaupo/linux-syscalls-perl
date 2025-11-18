#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

no warnings 'once';

package Linux::IpRoute2::connector;

use Carp qw( carp croak );

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

use Linux::IpRoute2::message::_base;

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

    @_ == 1 || @_ == 2 or croak 'Wrong number of args; expected 1 or 2, but got '.(0+@_).' (excluding invocant)';

    my ($group_subs, $protocol) = @_;
    $group_subs //= 0;
    $protocol //= NETLINK_ROUTE;

    my $port_id = 0;

    socket my $sock, PF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, $protocol       or die "Cannot create NETLINK socket";

    $self = bless {
            sock => $sock,
        }, $class;

    $self->set_sndbufsz(def_sendbuf_size);
    $self->set_rcvbufsz(def_recvbuf_size);
    $self->set_netlink_opt(NETLINK_EXT_ACK, 1);
    bind $sock, pack 'SSQ', AF_NETLINK, $port_id, $group_subs           or die "Cannot bind(AF_LENLINK, port_id=$port_id, groups=$group_subs for $self";

    my $rta = $self->get_sockinfo;
    my ($rta_type, $rta_pid, $rta_groups) = unpack "L3", $rta;
    warn sprintf "open_route(self=$self, class=$class, group_subs=$group_subs, protocol=$protocol)\n"
                ."\tGot data=[%s]\n"
                ."\t    rta_type=%s rta_pid=%#x rta_groups=%s\n"
                ."\t",
                    unpack( "H*", $rta =~ s/........(?=.)/$&./gr ),
                    $rta_type, $rta_pid, $rta_groups
        if $Linux::IpRoute2::ShowConnection;

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

    state $verify_requests = do {
        [

        "\x38\x00\x00\x00\x12\x00\x01\x00" .
        "\x13\x60\x1c\x69\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x08\x00\x1d\x00\x09\x00\x00\x00" .
        "\x0e\x00\x03\x00" . "wlp0s20f3\0\0\0", # Change this line to suit whichever device is being used for testing

        "\x28\x00\x00\x00\x12\x00\x01\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x0a\x00\x00\x00\x03\x00\x00\x00" .
        "\x00\x00\x00\x00\x00\x00\x00\x00" .
        "\x08\x00\x1d\x00\x09\x00\x00\x00"

    ] };

    if (my $wanted = shift @$verify_requests) {
        my $std = $msg;
        s/^........\K..../XXXX/ for $std, $wanted;
        if ( $std ne $wanted ) {
            croak sprintf "\e[22mIncorrect \e[1moutgoing\e[22m request\n"
                        . "\tgot    [%s]\n"
                        . "\tstd    [%s]\n"
                        . "\twanted [%s]\n"
                        . "\t",
                        map {
                            unpack('H*', $_) =~ s/^.{16}\K......../--------/r
                                             =~ s/........(?=.)/$&./gr
                        } $msg, $std, $wanted;
        } else {
            carp  sprintf "\e[42;22mCorrect \e[1moutgoing\e[22m request\n"
                        . "\tgot    [%s]\n\tstd    [%s]\n"
                        . "\twanted [%s]\n"
                        . "\t",
                        map {
                            unpack('H*', $_) =~ s/^.{16}\K......../--------/r
                                             =~ s/........(?=.)/$&./gr
                        } $msg, $std, $wanted
                if $Linux::IpRoute2::ShowComposition;
        }
    }

    my $r = sendmsg $sock, $flags, $msg, $ctrl, $name;

    Linux::IpRoute2::message::_base::_show_msg
        dirn => Linux::IpRoute2::message::_base::DirnSend | Linux::IpRoute2::message::_base::DirnSockMethod,
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
    Linux::IpRoute2::message::_base::_show_msg
        dirn    => Linux::IpRoute2::message::_base::DirnRecv
                 | Linux::IpRoute2::message::_base::DirnSockMethod
                 | ( $flags & MSG_PEEK && Linux::IpRoute2::message::_base::DirnSockMethod ),
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

1;
