#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

use Data::Dumper;

package Linux::IpRoute2::request::get_link;

use parent 'Linux::IpRoute2::message::link',
           'Linux::IpRoute2::request::_base';
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
    my $opt = $self->new_attr_by_type(@_);
    push @{ $self->{attrs} }, $opt;
    if ($Linux::IpRoute2::ShowComposition) {
        require Data::Dumper;
        warn "add_ifla\n"
           . "\tAdding option $opt\n"
           . "\t" . Data::Dumper->new([$opt], [qw[opt]])->Indent(0)->Useqq(1)->Dump;
    }
    return $self;
}

sub getpack($;$$) {
    my ($self, $seq, $pid) = @_;
    my ($code, $flags) = @{ $self->{header} };
    warn sprintf "getpack(seq=%s, pid=%s)\n"
                ."\twith %s\n"
                ."\t     code=%d, flags=%#x,\n",
        $seq, $pid,
        Data::Dumper->new([$self],['self'])->Indent(0)->Useqq(1)->Dump,
        $code, $flags,
        ;
    my $request = pack struct_nlmsghdr_pack,
                        0,              # length, to be filled in...
                        $code,
                        $flags,
                        $seq // 0,      # sequence (dummy)
                        $pid // 0;      # port-id

    my $ifinfomsg = pack struct_ifinfomsg_pack, @{$self->{ifinfomsg}};

    # Concatenate the packed base request and all the packed attrs,
    # inserting padding so that each has 4-byte alignment.
    $request = pack '(a*x![L])*',
                    $request,
                    $ifinfomsg,
                    map { $_->getpack }
                        @{ $self->{attrs} };

    # ... now fill in length;  4 == sizeof(uint32_t), where uint32_t is the result of pack 'L'
    substr $request, 0, 4, pack L => length $request;
    warn __PACKAGE__."::getpack(@_) => ".unpack "H*", $request;
    return $self->{data} = $request;
}

1;
