#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

use Data::Dumper;

package Linux::IpRoute2::request::get_link;

use parent 'Linux::IpRoute2::request::_base',
           'Linux::IpRoute2::message::link';
use Carp 'confess';
use Linux::IpRoute2::rtnetlink qw( RTM_GETLINK NLM_F_REQUEST );

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

use Linux::IpRoute2::rtnetlink qw( struct_ifinfomsg_pack );

sub get_subhead_pack {
    my ($self) = @_;
    my $ifinfomsg = $self->{ifinfomsg};
    return pack struct_ifinfomsg_pack, @$ifinfomsg;
}

1;
