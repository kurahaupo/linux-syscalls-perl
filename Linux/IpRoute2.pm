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

    use Linux::IpRoute2::rtnetlink qw(
        :pack
    );

    #
    # In principle there can be multiple interleaved conversations going on the
    # same socket, in which case the port_id and subscription_groups might be
    # useful, but for this simple linear program just set them both to 0.
    #
    use constant {
        FixedSocketName => pack('S@12', AF_NETLINK),    # port_ID=0, groups=0x0000000000000000
    };

    {
    my @dirn = ( "\e[1;35mRequest", "\e[1;36mReply", "\e[1;34mPeek" );

    sub _show_msg($$$$$$) {
        my ($direction, $status, $flags, $data, $ctrl, $name) = @_;

        printf "%s:\n", $dirn[$direction] || "\e[1;31mMessage";
        printf " status %d (maybe length of packet)\n", $status if defined $status;
        if ( defined $flags ) {
            my $rf = $flags;
            my $sf = join ',',
                        map { s/.*_//r }
                        grep  {
                            my $bb = 0;
                            eval('$bb = '.$_);
                            0+$rf != ($rf &=~ $bb);
                        } qw( MSG_OOB MSG_PEEK MSG_DONTROUTE MSG_CTRUNC MSG_PROXY
                              MSG_TRUNC MSG_DONTWAIT MSG_EOR MSG_WAITALL MSG_FIN
                              MSG_SYN MSG_CONFIRM MSG_RST MSG_ERRQUEUE MSG_NOSIGNAL
                              MSG_MORE MSG_WAITFORONE MSG_FASTOPEN MSG_CMSG_CLOEXEC );
            $sf = join '+', $sf || (), $rf || ();
            $sf ||= 'none';
            printf "  flags %#x (%s)\n", $flags, $sf;
        }
        printf "   data [%s]\n",                          defined $data ? unpack("H*", $data) : "(none)";
        printf "   ctrl [%s]\n",                          defined $ctrl ? unpack("H*", $ctrl) : "(none)";
        printf " %6s [%s]\n", $direction ? "from" : "to", defined $name ? unpack("H*", $name) : "(unspecified)";
        printf "\e[m\n";
    }
    }

    sub _make_rtattr($$@) {
        my ($type, $pack_fmt, @pack_args) = @_;
        my $body = pack $pack_fmt, @pack_args;
        $body ne '' or die "Pack result was empty; probably insufficient args?\nfmt=$pack_fmt, args=".(0+@pack_args)."[@pack_args]\n";
        return pack 'SSa*x![L]', 4+length($body), $type, $body;
    }

    sub _set_len(\$) {
        my ($ref) = @_;
        substr($$ref, 0, 4) = pack 'L', length $$ref;
    }

    use constant {
        ctrl_size   =>     0,       # always discard
        name_size   =>  0x40,       # normally 12, but allow space in case it grows
    };

    my @verify_requests = (
        "\x34\0\0\0\x12\0\x01\0XXXX\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x08\0\x1d\0\x09\0\0\0\x09\0\x03\0\x65\x74\x68\x30\0\0\0\0",
        "(\0\0\0\22\0\1\0XXXX\0\0\0\0\n\0\0\0\2\0\0\0\0\0\0\0\0\0\0\0\10\0\35\0\t\0\0\0",
    );

    sub talk {
        my $self = shift;

        my ($request_flags, $reqcode, $flags) = splice @_, 0, 3;

        my $request = pack struct_nlmsghdr_pack . 'x![L]',
                            0,              # length, to be filled in later
                            $reqcode,
                            $flags,
                            ++$self->{seq},
                            $self->{port_id};

        my ($type_pack, $type_args,) = splice @_, 0, 2;
        $request   .= pack $type_pack . 'x![L]', @$type_args;

        while (@_) {
            my ($opt, $pack, $args) = splice @_, 0, 3;
            $request .= _make_rtattr $opt, $pack, @$args;
        }

        # overwrite length at beginning of request
        _set_len $request;
      # substr($request, 0, 4) = pack 'L', length $request;     # 4 == length pack 'L', ...

        if (my $cr = shift @verify_requests) {
            my $trq = $request =~ s/^........\K..../XXXX/r;
            $trq eq $cr or do {
                $_ = unpack 'H*', $_ for $request, $trq, $cr;
                s/^.{16}\K.{8}/--------/ for $trq, $cr;
                die sprintf "Incorrect request\n    got [%s]\n wanted [%s]\n  match [%s]",
                            $request, $trq, $cr;
            }
        }

        _show_msg 0, undef, $request_flags, $request, undef, FixedSocketName;
        my $rlen0 = $self->msend($request_flags, $request, undef, FixedSocketName) or die "Could not send";;
        if ($rlen0 != length $request) {
            warn "sendmsg() returned $rlen0 when expecting ".length($request);
            return;
        }
        #$rlen0 == 52 or warn "sendmsg() returned $rlen0 when expecting 52"; # implied by matching the entire request against a 52-byte string, above

        my $accept_reply_size = 0x3fc;

        my ($rlen, $reply_flags, $reply, $reply_ctrl, $reply_from);
        for (;;) {
            ($rlen, $reply_flags, $reply, $reply_ctrl, $reply_from) = $self->mrecv(MSG_PEEK|MSG_TRUNC, $accept_reply_size, ctrl_size, name_size);
            _show_msg 2, $rlen, $reply_flags, $reply, $reply_ctrl, $reply_from;
            last if $rlen > 0;
            sleep 0.5;
        }

        $rlen == 1020 or warn "recvmsg(PEEK) returned len=$rlen when expecting 1020";
        $reply_from eq FixedSocketName or warn "recvmsg(PEEK) returned from=[".(unpack 'H*', $reply_from)."] when expecting [".(unpack 'H*', FixedSocketName)."]";

        if ($reply_flags & MSG_TRUNC) {
            # still need to get reply
            ($rlen, $reply_flags, $reply, $reply_ctrl, $reply_from) = $self->mrecv(0, $rlen, ctrl_size, name_size);
        } else {
            # already got reply, just need to pop it from the queue
            my @r = $self->mrecv(MSG_TRUNC, 0, 0, 0x400);
            &_show_msg( 3, @r);
        }

        _show_msg 1, $rlen, $reply_flags, $reply, $reply_ctrl, $reply_from;

        $rlen == 1020 or warn "recvmsg() returned len=$rlen when expecting 1020";
        $reply_from eq FixedSocketName or warn "recvmsg() returned from=[".(unpack 'H*', $reply_from)."] when expecting [".(unpack 'H*', FixedSocketName)."]";

        my @r = $self->mrecv(MSG_TRUNC|MSG_DONTWAIT, 0, 0, 0x400);
        unless (!@r && $!{EAGAIN}) {
            warn "unexpected response after message; $!";
            &_show_msg( 3, @r);
            die;
        }

        my ( $xrlen, $xreqcode, $xflags, $xseq, $xport_id, $xreply ) = unpack struct_nlmsghdr_pack . 'x![L] a*', $reply;

        $xrlen = length $reply or die "Reply length mismatch got $xrlen, expected ".length($reply)."\n";

        return $reply;
    }
}

BEGIN { *AF_NETLINK = \&Linux::IpRoute2::connector::AF_NETLINK }

#use Linux::Syscalls qw( :msg );

use Linux::IpRoute2::rtnetlink qw(
    NETLINK_GET_STRICT_CHK
    NLM_F_REQUEST
    RTEXT_FILTER_SKIP_STATS
    RTEXT_FILTER_VF
    RTM_GETLINK
    struct_ifinfomsg_pack
);
use Linux::IpRoute2::if_link qw(
    IFLA_EXT_MASK
    IFLA_IFNAME
);

sub iprt2_connect_route {
    my $self = shift;
    my $class = ref $self || $self;

    my ($group_subs) = @_;

    $< == 0 or die "Must be root";
    my $f3 = Linux::IpRoute2::connector::->open_route($group_subs);

    my $f4 = Linux::IpRoute2::connector::->open_route($group_subs);

    $self = bless {
        F3 => $f3,  # not yet clear why there's more than one...
        F4 => $f4,
    }, $class;
    return $self;
}

sub TEST {
    use Data::Dumper;

    my $self = __PACKAGE__->iprt2_connect_route(0);
    say Dumper($self);

    # sendmsg(4,
    #         { msg_name(12)={ sa_family=AF_NETLINK, pid=0, groups=00000000 },
    #           msg_iov(1)=[{ "4\0\0\0"     "\22\0\1\0"     #  nlmsghdr:(msglen(0x34), type(RTM_GETLINK=18), flags(NLM_F_REQUEST=1),
    #                         "i\362\230e"  "\0\0\0\0"      #            seq(time), port_id(0))
    #                         "\0\0\0\0"    "\0\0\0\0"      #  ifinfomsg:(ifi_family(ANY=0), ifi_type(ANY=0), ifi_index(ANY=0),
    #                         "\0\0\0\0"    "\0\0\0\0"      #             ifi_flags(0), ifi_change(0))
    #                         "\10\0\35\0"  "\t\0\0\0"      #  ifla:(len(8), type(IFLA_EXT_MASK=29), u32(RTEXT_FILTER_VF|RTEXT_FILTER_SKIP_STATS=9))
    #                         "\t\0\3\0"    "eth0\0\0\0\0", #  ifla:(len(9), type(IFLA_IFNAME=3), str("eth0\0"), pad:3)
    #                         52 }],
    #           msg_controllen=0,
    #           msg_flags=0 },
    #         0) = 52
    my $request_flags = 0;
    my $iface_name  = 'eth0';
    my $ifi_family  = 0;    # AF_UNSPEC
    my $ifi_type    = 0;    # ARPHRD_*
    my $ifi_index   = 0;    # Link index; 0 == all/unrestricted
    my $ifi_flags   = 0;    # IFF_* flags
    my $ifi_change  = 0;    # IFF_* change mask

    # Compose & send an iplink_req

    my $reply1 = $self->{F4}->talk( $request_flags, RTM_GETLINK, NLM_F_REQUEST,
                            struct_ifinfomsg_pack, [ $ifi_family, $ifi_type, $ifi_index,
                                                     $ifi_flags, $ifi_change, ],
                            IFLA_EXT_MASK, 'L',   [ RTEXT_FILTER_VF | RTEXT_FILTER_SKIP_STATS ],
                            IFLA_IFNAME,   'a*x', [ $iface_name ],
                           );

    # sendmsg(3,
    #         { msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000},
    #           msg_iov(1)=[{ "(\0\0\0"     "\22\0\1\0"     #  nlmsghdr:(msglen (0x28), type (RTM_GETLINK=18), flags (NLM_F_REQUEST=1),
    #                         "\3273\246e"  "\0\0\0\0"      #            seq (time), port_id(0)
    #                         "\n\0\0\0"    "\2\0\0\0"      #  ifinfomsg:(ifi_family(10), ifi_type(0), ifi_index(2),
    #                         "\0\0\0\0"    "\0\0\0\0"      #             ifi_flags(0), ifi_change(0)
    #                         "\10\0\35\0"  "\t\0\0\0",     #  ifla:(len(8), type(IFLA_EXT_MASK=29), u32(RTEXT_FILTER_VF|RTEXT_FILTER_SKIP_STATS=9))
    #                         40 }],
    #           msg_controllen=0,
    #           msg_flags=0 },
    #         0) = 40
    # 00000000  28 00 00 00 12 00 01 00  d7 33 a6 65 00 00 00 00  |(........3.e....|
    # 00000010  0a 00 00 00 02 00 00 00  00 00 00 00 00 00 00 00  |................|
    # 00000020  08 00 1d 00 09 00 00 00                           |........|

    $ifi_family = 10;   # AF_INET6
    $ifi_index = 2;     # somehow extracted from previous reply?

    $self->{F3}->set_netlink_opt(NETLINK_GET_STRICT_CHK, 1);

    my $reply2 = $self->{F3}->talk( $request_flags, RTM_GETLINK, NLM_F_REQUEST,
                              struct_ifinfomsg_pack, [ $ifi_family, $ifi_type, $ifi_index,
                                                       $ifi_flags, $ifi_change, ],
                              IFLA_EXT_MASK, 'L',   [ RTEXT_FILTER_VF | RTEXT_FILTER_SKIP_STATS ],
                             );

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
