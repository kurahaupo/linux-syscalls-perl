#!/module/for/perl

use v5.10;
use strict;
use warnings;

package Linux::IpRoute2 v0.0.1;

package Linux::IpRoute2::connector {

    use Linux::Syscalls qw( sendmsg recvmsg );

    use Socket qw(
        SOCK_CLOEXEC
        SOCK_RAW
    );

    # Socket should have these but doesn't ...
    use constant {
        AF_NETLINK          =>  16, # == PF_NETLINK
        NETLINK_ROUTE       =>   0,
        PF_NETLINK          =>  16, # == AF_NETLINK
        SOL_NETLINK         => 270,
        SOL_SOCKET          =>   1,
        SO_RCVBUF           =>   8,
        SO_SNDBUF           =>   7,
    };

    my %af_names = (
        'AF_NETLINK' => AF_NETLINK,
    );

    # Built-in functions:
    #   getsockname
    #   setsockopt
    #   socket

    sub new {
        my $self = shift;
        my $class = ref $self || $self;
        socket my $sock, PF_NETLINK, SOCK_RAW|SOCK_CLOEXEC, NETLINK_ROUTE   or die "Cannot create NETLINK socket";

        $self = bless {
                sock => $sock,
            }, $class;

        $self->set_sndbufsz(32768);
        $self->set_rcvbufsz(1048576);
        $self->set_netlink(11, 1);
        bind $sock, pack 'S@12', AF_NETLINK, 0, 0                           or die "Cannot bind 4";         # sa_family=AF_NETLINK, pid=0, groups=00000000

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

    sub set_netlink {
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
        my ($self, $msg, $flags) = @_;
        my $sock = $self->{sock};
        my $fd = fileno($sock) // die "No fd for $self";
        send $sock, $msg, $flags;
      # sendmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{"4\0\0\0\22\0\1\0\23\326\224e\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 52}], msg_controllen=0, msg_flags=0}, 0) = 52
    }

    sub mrecv {
        my ($self, $msg) = @_;
        my $sock = $self->{sock};
        my $fd = fileno($sock) // die "No fd for $self";
      # recvmsg(4, {msg_name(12)={sa_family=AF_NETLINK, pid=0, groups=00000000}, msg_iov(1)=[{NULL, 0}], msg_controllen=0, msg_flags=MSG_TRUNC}, MSG_PEEK|MSG_TRUNC) = 1020
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

sub iprt2_connect {
    $< == 0 or die "Must be root";
    my $c1 = Linux::IpRoute2::connector::->new(@_);

    $c1->set_netlink(12, 1);

    my $c2 = Linux::IpRoute2::connector::->new(@_);

    return bless {
        c1 => $c1,
        c2 => $c2,
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
