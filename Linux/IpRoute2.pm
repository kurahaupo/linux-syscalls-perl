#!/module/for/perl

use v5.10;
use strict;
use warnings;

package Linux::IpRoute2 v0.0.1;

package Linux::IpRoute2::connector {

    use Carp 'croak';

    use Linux::Syscalls qw( :msg );

    use Socket qw(
        SOCK_CLOEXEC
        SOCK_RAW
    );

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
        return sendmsg $sock, $flags, $msg, $ctrl, $name;
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
use Linux::IpRoute2::rtnetlink qw(
    :pack
    NETLINK_GET_STRICT_CHK
    NLM_F_REQUEST
    RTM_GETLINK
    RTEXT_FILTER_VF
    RTEXT_FILTER_SKIP_STATS
);
use Linux::IpRoute2::if_link qw(
    IFLA_EXT_MASK
    IFLA_IFNAME
);

BEGIN { *AF_NETLINK = \&Linux::IpRoute2::connector::AF_NETLINK }

use constant {
    netlink_socket_name => pack('S@12', AF_NETLINK),    # port_ID=0, groups=0x0000000000000000
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

sub _add_rtattr(\$$$@) {
    my ($ref, $type, $pack_fmt, @pack_args) = @_;
  # warn "adding attribute type=$type to message len=".length($$ref)." bytes; packfmt=$pack_fmt, args=[@pack_args]\n";
    my $body = pack $pack_fmt, @pack_args;
  # warn "\tattribute [".unpack('H*', $body)."]\n";
    my $add = pack 'SSa*x![L]', 4+length($body), $type, $body;
  # warn "\tadding [".unpack('H*', $add)."]\n";
    $$ref .= $add;
  # warn "\tafter addition [".unpack('H*', $$ref)."]\n";
}

sub _set_len(\$) {
    my ($ref) = @_;
    substr($$ref, 0, 4) = pack 'L', length $$ref;
}

sub iprt2_connect_route {
    my $self = shift;
    my $class = ref $self || $self;

    my ($group_subs) = @_;

    $< == 0 or die "Must be root";
    my $f3 = Linux::IpRoute2::connector::->open_route($group_subs);

    $f3->set_netlink_opt(NETLINK_GET_STRICT_CHK, 1);

    my $f4 = Linux::IpRoute2::connector::->open_route($group_subs);

    # sendmsg(4,
    #         { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
    #           msg_iov(1)=[{ "4\0\0\0"     "\22\0\1\0"     #  struct nlmsghdr: msglen (0x34), type (18), flags (1),
    #                         "i\362\230e"  "\0\0\0\0"      #                   seq (time), port_id
    #                         "\0\0\0\0"    "\0\0\0\0"      #  struct ifinfomsg ifi_family ifi_type, ifi_index
    #                         "\0\0\0\0"    "\0\0\0\0"      #                   ifi_flags ifi_change
    #                         "\10\0\35\0"  "\t\0\0\0"      #  ifla:(len(8), type(IFLA_EXT_MASK=29), u32(RTEXT_FILTER_VF | RTEXT_FILTER_SKIP_STATS == 9))
    #                         "\t\0\3\0"    "eth0\0\0\0\0", #  ifla:(len(9), type(IFLA_IFNAME=3), str("eth0\0"), pad(3))
    #                         52}],
    #           msg_controllen=0,
    #           msg_flags=0 },
    #         0) = 52
    my $request_flags = 0;
    my $iface_name = 'eth0';
    my $request = pack struct_nlmsghdr_pack . struct_ifinfomsg_pack,
                       struct_nlmsghdr_len  + struct_ifinfomsg_len, RTM_GETLINK, NLM_F_REQUEST, ++$f4->{seq}, $f4->{port_id},
                       (0) x 5;
    length($request) == 32 or warn "Partial request should be 32 bytes but is ".length($request);
    _add_rtattr $request, IFLA_EXT_MASK, 'L', RTEXT_FILTER_VF | RTEXT_FILTER_SKIP_STATS;
    length($request) == 40 or warn "Partial request should be 40 bytes but is ".length($request);
    _add_rtattr $request, IFLA_IFNAME, 'a*x', $iface_name;
    length($request) == 52 or warn "Partial request should be 52 bytes but is ".length($request);
    _set_len $request;
  # warn "Request after correcting length [".unpack('H*', $request)."]\n";

    #$request = "\x34\x00\x00\x00\x12\x00\x01\x00\xc1\x58\xa1\x65\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08\x00\x1d\x00\x09\x00\x00\x00\x09\x00\x03\x00\x65\x74\x68\x30\x00\x00\x00\x00";

        # HINT: 0x34 appears to be the size of the reply received later
        # The current time ($^T) appears to act as a seed for a sequence number.
    my $request_to = netlink_socket_name;
    _show_msg 0, undef, $request_flags, $request, undef, $request_to;
    my $rlen0 = $f4->msend($request_flags, $request, undef, $request_to) or die "Could not send";;
    $rlen0 == 52 or warn "sendmsg() returned $rlen0 when expecting 52";

    # recvmsg(4,
    #         {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000},
    #          msg_iov(1)=[{NULL, 0}],
    #          msg_controllen=0,
    #          msg_flags=MSG_TRUNC},
    #         MSG_PEEK|MSG_TRUNC) = 1020
    my ($rlen1, $reply_flags, $reply, $reply_ctrl, $reply_from) = $f4->mrecv(MSG_PEEK|MSG_TRUNC, 0, 0, 0x400);
    _show_msg 1, $rlen1, $reply_flags, $reply, $reply_ctrl, $reply_from;

    $rlen1 == 1020 or warn "recvmsg(PEEK) returned len=$rlen1 when expecting 1020";
    $reply_from eq $request_to or warn "recvmsg(PEEK) returned from=[".(unpack 'H*', $reply_from)."] when expecting [".(unpack 'H*', $request_to)."]";

    $rlen1 > 0 or do { warn "Couldn't peek!"; return };
    # recvmsg(4,
    #         {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000},
    #          msg_iov(1)=[{"\374\3\0\0\20\0\0\0\23\326\224e\217u\357\212\0\0\1\0\2\0\0\0C\20\1\0\0\0\0\0"..., 32768}],
    #          msg_controllen=0,
    #          msg_flags=0},
    #         0) = 1020
    (my $rlen2, $reply_flags, $reply, $reply_ctrl, $reply_from) = $f4->mrecv(0, 0x8000, 0, 0x400);
    _show_msg 1, $rlen2, $reply_flags, $reply, $reply_ctrl, $reply_from;

    $rlen2 == 1020 or warn "recvmsg() returned len=$rlen2 when expecting 1020";;
    $reply_from eq $request_to or warn "recvmsg() returned from=[".(unpack 'H*', $reply_from)."] when expecting [".(unpack 'H*', $request_to)."]";

    return bless {
        F3 => $f3,  # not yet clear why there's more than one...
        F4 => $f4,
    }, $class;
}

sub TEST {
    use Data::Dumper;
    say Dumper(__PACKAGE__->iprt2_connect_route(0));
}

use Exporter 'import';
our @EXPORT = qw( iprt2_connect );

1;

__END__

Note: "pid" in this context is "port ID".

+ strace -s 4096 -e socket,bind,connect,setsockopt,getsockopt,getsockname,sendmsg,recvmsg,shutdown,close ip -6 addr show eth0
...

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
