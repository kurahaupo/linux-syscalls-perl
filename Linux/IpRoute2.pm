#!/module/for/perl

use v5.10;
use strict;
use warnings;

package Linux::IpRoute2 v0.0.1;

package Linux::IpRoute2::connector {

    use Linux::Syscalls qw( :msg );

    use Socket qw(
        SOCK_CLOEXEC
        SOCK_RAW
    );

    # from [iproute2]include/uapi/linux/netlink.h
    use Linux::IpRoute2::rtnetlink qw(
        NETLINK_ROUTE
        NETLINK_EXT_ACK
    );
    # Socket should have these but doesn't ...
    use constant {
        AF_NETLINK              =>  16,

        SO_SNDBUF               =>   7,
        SO_RCVBUF               =>   8,

        SOL_SOCKET              =>   1,
        SOL_NETLINK             => 270,
    };
    use constant {
        PF_NETLINK              =>  AF_NETLINK,
    };

    my %af_names = map {
        ( ( my $x = $_ ) =~ s/^AF_(.*)/\L$1/ => eval $_ )
    } qw{ AF_NETLINK };
    my @af_names;
    $af_names[$af_names{$_}] = $_ for keys %af_names;

    # Built-in functions:
    #   getsockname
    #   setsockopt
    #   socket

    use constant {
        def_sendbuf_size    =>    0x8000,   #   32768
        def_recvbuf_size    =>  0x100000,   # 1048576
    };

    sub new {
        my $self = shift;
        my $class = ref $self || $self;
        socket my $sock, PF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, NETLINK_ROUTE   or die "Cannot create NETLINK socket";

        $self = bless {
                sock => $sock,
            }, $class;

        $self->set_sndbufsz(def_sendbuf_size);
        $self->set_rcvbufsz(def_recvbuf_size);
        $self->set_netlink_opt(NETLINK_EXT_ACK, 1);
        bind $sock, pack 'S@12', AF_NETLINK, 0, 0                           or die "Cannot bind 4 for $self";

        my $rta = $self->get_sockinfo;
        warn sprintf "Got data=[%s]\n", unpack "H*", $rta;
        my ($rta_type, $rta_pid, $rta_groups) = unpack "L3", $rta;
        warn sprintf "Got rta_type=%s rta_pid=%#x rta_groups=%s\n", $rta_type, $rta_pid, $rta_groups;

        $self->{sockname_hex} = unpack "H*", $rta;
        $self->{sockname} = { type => $rta_type, pid => $rta_pid, groups => $rta_groups };


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
        return sendmsg $sock, $flags, $msg, $ctrl, $name;
      # sendmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"4\0\0\0\22\0\1\0\23\326\224e\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 52}], msg_controllen=0, msg_flags=0}, 0) = 52
    }

    sub mrecv {
        my ($self, $flags, $maxmsglen, $maxctrllen, $maxnamelen) = @_;
        my $sock = $self->{sock};
        return recvmsg $sock, $flags, $maxmsglen, $maxctrllen, $maxnamelen;
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
    );

    BEGIN { *DESTROY = \&close };
}

use Linux::Syscalls qw( :msg );
use Linux::IpRoute2::rtnetlink qw( NETLINK_GET_STRICT_CHK );

BEGIN { *AF_NETLINK = \&Linux::IpRoute2::connector::AF_NETLINK }

use constant {
    netlink_socket_name => pack('S@12', AF_NETLINK),
};

sub _show_msg($$$$$$) {
    my ($direction, $status, $flags, $data, $ctrl, $name) = @_;

    printf "%s:\n", $direction ? "\e[1;34mReply" : "\e[1;35mRequest";
    printf " status %d (maybe length of packet)\n", $status if defined $status;
    if ( defined $flags ) {
        my $of = $flags;
        my $sf = join ',',
                    grep  {
                        $of ^ ($of &= ~ eval 'MSG_' . uc $_)
                    } qw(
                        oob         peek        dontroute   ctrunc      proxy
                        trunc       dontwait    eor         waitall     fin
                        syn         confirm     rst         errqueue    nosignal
                        more        waitforone  fastopen    cmsg_cloexec
                    );
        $sf = join '+', $sf || (), $of || ();
        $sf ||= 'none';
        printf "  flags %#x (%s)\n", $flags, $sf;
    }
    printf "   data [%s]\n",                          defined $data ? unpack("H*", $data) : "(none)";
    printf "   ctrl [%s]\n",                          defined $ctrl ? unpack("H*", $ctrl) : "(none)";
    printf " %6s [%s]\n", $direction ? "from" : "to", defined $name ? unpack("H*", $name) : "(unspecified)";
    printf "\e[m\n";
}

sub iprt2_connect {
    $< == 0 or die "Must be root";
    my $c3 = Linux::IpRoute2::connector::->new(@_);

    $c3->set_netlink_opt(NETLINK_GET_STRICT_CHK, 1);

    my $c4 = Linux::IpRoute2::connector::->new(@_);

    # sendmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"4\0\0\0\22\0\1\0\23\326\224e\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 52}], msg_controllen=0, msg_flags=0}, 0) = 52
    my $request_flags = 0;
    my $request = pack 'LSSq@52', 0x34, 18, 1, $^T+1;
        # HINT: 0x34 appears to be the size of the reply received later
        # No idea why the current time ($^T) needs to be in the packet, but it matches the observed behaviour.
    my $request_to = netlink_socket_name;
    _show_msg 0, undef, $request_flags, $request, undef, $request_to;
    $c4->msend($request_flags, $request, undef, $request_to) or die "Could not send";;

    # recvmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{NULL, 0}], msg_controllen=0, msg_flags=MSG_TRUNC}, MSG_PEEK|MSG_TRUNC) = 1020
    my ($rlen, $reply_flags, $reply, $reply_ctrl, $reply_from) = $c4->mrecv(MSG_PEEK|MSG_TRUNC, 0, 0, 0x400);
    _show_msg 1, $rlen, $reply_flags, $reply, $reply_ctrl, $reply_from;

    return bless {
        c3 => $c3,
        c4 => $c4,
    };
}

use Exporter 'import';
our @EXPORT = qw( iprt2_connect );

1;

__END__

socket(PF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, NETLINK_ROUTE) = 3
setsockopt(3, SOL_SOCKET, SO_SNDBUF, [32768], 4) = 0
setsockopt(3, SOL_SOCKET, SO_RCVBUF, [1048576], 4) = 0
setsockopt(3, SOL_NETLINK, 11, [1], 4)  = 0
bind(3, {sa_family=AF_NETLINK, pid=0, groups=00000000}, 12) = 0
getsockname(3, {sa_family=AF_NETLINK, pid=24411, groups=00000000}, [12]) = 0

setsockopt(3, SOL_NETLINK, 12, [1], 4)  = 0

socket(PF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, NETLINK_ROUTE) = 4
setsockopt(4, SOL_SOCKET, SO_SNDBUF, [32768], 4) = 0
setsockopt(4, SOL_SOCKET, SO_RCVBUF, [1048576], 4) = 0
setsockopt(4, SOL_NETLINK, 11, [1], 4)  = 0
bind(4, {sa_family=AF_NETLINK, pid=0, groups=00000000}, 12) = 0
getsockname(4, {sa_family=AF_NETLINK, pid=-1964018289, groups=00000000}, [12]) = 0


sendmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"4\0\0\0\22\0\1\0\23\326\224e\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 52}], msg_controllen=0, msg_flags=0}, 0) = 52
recvmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{NULL, 0}], msg_controllen=0, msg_flags=MSG_TRUNC}, MSG_PEEK|MSG_TRUNC) = 1020
brk(NULL)                               = 0x1337000
brk(0x1360000)                          = 0x1360000
recvmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"\374\3\0\0\20\0\0\0\23\326\224e\217u\357\212\0\0\1\0\2\0\0\0C\20\1\0\0\0\0\0"..., 32768}], msg_controllen=0, msg_flags=0}, 0) = 1020
close(4)                                = 0

sendmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"(\0\0\0\22\0\1\0\23\326\224e\0\0\0\0\n\0\0\0\2\0\0\0\0\0\0\0\0\0\0\0"..., 40}], msg_controllen=0, msg_flags=0}, 0) = 40
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{NULL, 0}], msg_controllen=0, msg_flags=MSG_TRUNC}, MSG_PEEK|MSG_TRUNC) = 1020
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"\374\3\0\0\20\0\0\0\23\326\224e[_\0\0\0\0\1\0\2\0\0\0C\20\1\0\0\0\0\0"..., 32768}], msg_controllen=0, msg_flags=0}, 0) = 1020
sendto(3, "\30\0\0\0\26\0\1\3\24\326\224e\0\0\0\0\n\0\0\0\2\0\0\0\0\0\0\0\0\0\0\0"..., 152, 0, NULL, 0) = 152
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{NULL, 0}], msg_controllen=0, msg_flags=MSG_TRUNC}, MSG_PEEK|MSG_TRUNC) = 144
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"H\0\0\0\24\0\"\0\24\326\224e[_\0\0\n@\0\0\2\0\0\0\24\0\1\0$\3X\n"..., 32768}], msg_controllen=0, msg_flags=0}, 0) = 144
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{NULL, 0}], msg_controllen=0, msg_flags=MSG_TRUNC}, MSG_PEEK|MSG_TRUNC) = 20
recvmsg(3, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"\24\0\0\0\3\0\"\0\24\326\224e[_\0\0\0\0\0\0", 32768}], msg_controllen=0, msg_flags=0}, 0) = 20
