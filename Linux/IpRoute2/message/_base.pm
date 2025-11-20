#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

no warnings 'once';

use Data::Dumper;

package Linux::IpRoute2::message::_base;

# Base class for all NETLINK messages

use Carp qw( croak cluck confess );
use Linux::IpRoute2::rtnetlink qw( :rtm struct_nlmsghdr_len );
use Linux::Syscalls qw( MSG_to_desc );

use parent 'Linux::IpRoute2::default_unpack';
# Override (and block) unpack_self from parent Linux::IpRoute2::default_unpack
sub unpack_self {
    my ($self) = @_;
    croak "Class ".ref($self)." fails to override 'unpack_self'";
}

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

sub round_up($) {
    my ($l) = @_;
    return -(-$l & ~3);
}

sub unpack_msg_self {
    my ($self, $body) = @_;
    warn "\e[1;33m⇒Into " . __PACKAGE__ . "::unpack_msg_self($self)\e[m"
        if $Linux::IpRoute2::ShowDecomposition;

    my $data = $self->unpack_self($body);

    warn sprintf "\e[43;30munpack_self took %d bytes and returned %d\e[m\n"
               . "\e[33m\t\tin={%s}\e[m\n"
               . "\e[33m\t\tback={%s}\e[m\n",
               length($body), length($data),
               unpack("H*", $body),
               unpack("H*", $data)
        if $Linux::IpRoute2::ShowDecomposition;

    my @resp_opts;
    for ( my $len, my $offset = 0 ; $offset < length $data ; $offset += round_up $len ) {
        ($len, my $attr_type) = unpack '@'.$offset.'SS', $data;
        my $rpkg = $self->_attr_type_to_pkg($attr_type);

        my $v = $self->new_attr($attr_type);
        $v->unpack_self(substr $data, $offset+4, $len-4);

        ref $v or die "_unpack_opt returned non-ref ($v)";
        push @resp_opts, $v;
    }
    @resp_opts = sort { $a->attr_type <=> $b->attr_type } @resp_opts
        if $Linux::IpRoute2::SortReceivedOptions;
    $self->{attrs} = \@resp_opts;

    $self->_unpack_refine if $self->can('_unpack_refine');

    warn "\e[1;33m⇐From " . __PACKAGE__ . "::unpack_msg_self\e[m returning " . Data::Dumper->new([$self],[qw[self]])->Indent(0)->Useqq(1)->Dump
        if $Linux::IpRoute2::ShowDecomposition;
}

sub _show_msg(@) {
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
    printf "   data [%s]\n",                     defined $data ? unpack("H*", $data) : "(none)";
    printf "   ctrl [%s]\n",                     defined $ctrl ? unpack("H*", $ctrl) : "(none)";
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

# Process an in-coming NLM message

#   sub unpack_self {
#       my $self = shift;
#     # $self = bless {}, $self if ! ref $self;
#       my ($data) = @_;
#       warn "\e[1;33m⇒Into " . __PACKAGE__ . "::unpack_self\e[J"
#           if $Linux::IpRoute2::ShowDecomposition;
#       $self->{body} //= shift // do {
#               my $data = $self->{data} // return;
#               substr $data, struct_nlmsghdr_len;
#           };
#       warn "\e[1;33m⇐From " . __PACKAGE__ . "::unpack_self\e[m\[J returning " . Data::Dumper->new([$self],[qw[self]])->Indent(0)->Useqq(1)->Dump
#           if $Linux::IpRoute2::ShowDecomposition;
#       return $self;
#   }

my @map_msg_type_to_class;
{
    for my $tnum ( RTM_TMIN .. RTM_TMAX ) {
        my $msg_type = RTM_type_to_label $tnum // next;
        $map_msg_type_to_class[$tnum] = eval qq{
            package Linux::IpRoute2::message::${msg_type} {
                use parent Linux::IpRoute2::message::_base::;
            }
            Linux::IpRoute2::message::${msg_type}::
        };
    }
};

sub _msg_type_to_class {
    my $msg_type = pop;
    my $msg_class = $msg_type >= 0 ? $map_msg_type_to_class[$msg_type] : ();
    $msg_class
        or croak sprintf "Missing class for type=%s\n\tdump-map=%s", $msg_type,
            Data::Dumper::->new([\@map_msg_type_to_class],
                                [qw[map]])->Indent(0)->Useqq(1)->Dump;
    return $msg_class;
}

sub start {
    my $self = shift;
    my $class = ref $self || $self;
    $#_ == 1 or confess "Wrong args";
    $self = bless {
        header => [@_],
        attrs => [],
    }, $class;
    return $self;
}

sub _set_len(\$) {
    my ($self) = shift;
    substr $self->{data}, 0, 4, pack 'L', length $self->{data};
    $self;
}
sub send {
    my ($self, $conx, $sendmsg_flags) = @_;
    $sendmsg_flags //= 0;   # optional

    my $msg = $self->get_pack(++$conx->{seq}, $conx->{port_id});

    my $rlen = $conx->msend($sendmsg_flags, $msg, undef, $conx->FixedSocketName) or die "Could not send";;

    $self->show( dirn => DirnSend | DirnMesgMethod );

    my $mlen = length $msg;
    if ($rlen != $mlen) {
        warn "sendmsg() returned $rlen when expecting $mlen";
        use POSIX 'EMSGSIZE';
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

sub new_attr_by_type {
    my ($class, $attr_type, @args) = @_;
    return bless \@args, $class->_attr_type_to_pkg($attr_type);
}

1;
