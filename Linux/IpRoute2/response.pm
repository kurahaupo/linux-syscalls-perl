#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

no warnings 'once';

use Data::Dumper;

package Linux::IpRoute2::response;

use parent 'Linux::IpRoute2::message::_base';

use Carp qw( confess cluck );

use Linux::IpRoute2::rtnetlink qw(
                                   :nlm_types :rtm
                                   struct_nlmsghdr_pack
                                   struct_sockaddr_nl_pack
                                 );

use Linux::Syscalls qw( MSG_PEEK MSG_TRUNC MSG_DONTWAIT );   # :msg

use constant {
    ctrl_size   =>     0,       # always discard
    name_size   =>  0x40,       # normally 12, but allow space in case it grows
};

sub recv_new {
    my $self = shift;
    my $class = ref $self || $self;

    my $sock = shift or confess "Missing 'sock' arg";

    $#_%2 or confess "Odd args";
    my %opts = @_;

    my $accept_reply_size = $opts{size} // 0x800;

    my ($rlen, $recv_flags, $reply, $recv_ctrl, $recv_from);
    for (;;) {
        ($rlen, $recv_flags, $reply, $recv_ctrl, $recv_from) = $sock->mrecv(MSG_PEEK|MSG_TRUNC, $accept_reply_size, ctrl_size, name_size);
        last if $rlen > 0;
        sleep 0.005;
        warn "Retrying recvmsg..."
            if $Linux::IpRoute2::ShowConnection;
    }

    if (my $expect_reply_from = $opts{sent_to}) {
        $recv_from eq $expect_reply_from
            or warn "recvmsg(PEEK) returned from=[".(unpack 'H*', $recv_from)."]"
                . " when expecting [".(unpack 'H*', $expect_reply_from)."]"
            if $Linux::IpRoute2::ShowDecomposition;
    }

    if ($recv_flags & MSG_TRUNC) {
        # still need to get reply
        ($rlen, $recv_flags, $reply, $recv_ctrl, $recv_from) = $sock->mrecv(0, $rlen, ctrl_size, name_size);
    } else {
        # already got reply, just need to pop it from the queue
        () = $sock->mrecv(MSG_TRUNC, 0, 0, 0x400); # discard answer
    }

    $recv_from eq $opts{expect_reply_from}
            or warn "recvmsg() returned from=[".(unpack 'H*', $recv_from)."]"
                 . " when expecting [".(unpack 'H*', $opts{expect_reply_from})."]"
        if $opts{expect_reply_from} && $Linux::IpRoute2::ShowDecomposition;

    my @r = $sock->mrecv(MSG_TRUNC|MSG_DONTWAIT, 0, 0, 0x400);
    unless (!@r && $!{EAGAIN}) {
        die "Unexpected response after message; $!\n";
    }

    my $msg = $self->unpack_new_msg($reply);

    $msg->{ctrl} = $recv_ctrl if $recv_ctrl;

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

        $msg->{from} = $recv_from;
    }

    if ($msg->{seq} != $sock->{seq}) {
        confess "Out-of-order response; got reply to #$msg->{seq} but expected #$sock->{seq}";
        # This code should eventually be avoided, since out-of-order responses
        # are technically permitted if there's more than one outstanding
        # query.
    }

    return $msg if not wantarray;
    return $msg, $recv_flags, $recv_ctrl, $recv_from;
}

sub unpack_new_msg {
    my (undef, $packed_recv) = @_;

    my ( $reply_len2, $msg_code, $flags, $seq, $port_id, $packed_msg ) = unpack struct_nlmsghdr_pack . 'x![L] a*', $packed_recv;

    $reply_len2 = length $packed_recv or die "Reply length mismatch got $reply_len2, expected ".length($packed_recv)."\n";

    my $msg_type;
    my $msg_class;

    if ($msg_code < NLMSG_MIN_TYPE) {
        $msg_type = 0;
        $msg_class = Linux::IpRoute2::nlmsg::_nlmsg_code_to_class($msg_code)
            // die "Cannot pick a type for code=$msg_code (".RTM_to_name($msg_code)."), msg_type=$msg_type (".RTM_type_to_name($msg_type).")";
        # One of:
        #   NLMSG_DONE
        #   NLMSG_ERROR
        #   NLMSG_NOOP
        #   NLMSG_OVERRUN

    } else {

        $msg_type = $msg_code >> RTM_TSHIFT;
        $msg_class = Linux::IpRoute2::message::_base::_msg_type_to_class($msg_type)
            // die "Cannot pick a type for code=$msg_code (".RTM_to_name($msg_code)."), msg_type=$msg_type (".RTM_type_to_name($msg_type).")";
    }

    my $msg = bless {
        code        => $msg_code,
        flags       => $flags,
        port_id     => $port_id,
        packed_recv => $packed_recv,
        seq         => $seq,
        type        => $msg_type,
    }, $msg_class;

    warn sprintf "\nAttempting to unpack\n\t%s\n\t",
            Data::Dumper->new([$packed_msg],[qw[ packed_msg ]])->Indent(0)->Useqq(1)->Dump
        if $Linux::IpRoute2::ShowDecomposition;
    $msg->unpack_msg_self($packed_msg);
    warn " ... \e[1;46mafter unpack\e[m"
        if $Linux::IpRoute2::ShowDecomposition;

    return $msg;
}

1;
