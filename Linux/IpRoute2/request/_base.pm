#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

use Data::Dumper;

package Linux::IpRoute2::request::_base;

use Linux::IpRoute2::rtnetlink qw( struct_nlmsghdr_pack );

sub get_pack($;$$) {
    my ($self, $seq, $pid) = @_;
    my ($code, $flags) = @{ $self->{header} };
    warn sprintf "get_pack(seq=%s, pid=%s)\n"
                ."\twith %s\n"
                ."\t     code=%d, flags=%#x,\n",
        $seq, $pid,
        Data::Dumper->new([$self],['self'])->Indent(0)->Useqq(1)->Dump,
        $code, $flags,
        if $Linux::IpRoute2::ShowComposition;
    my $request = pack struct_nlmsghdr_pack,
                        0,              # length, to be filled in...
                        $code,
                        $flags,
                        $seq // 0,      # sequence (dummy)
                        $pid // 0;      # port-id

    # Concatenate the packed base request and all the packed attrs,
    # inserting padding so that each has 4-byte alignment.
    $request = pack '(a*x![L])*',
                    $request,
                    $self->get_subhead_pack // '',
                    map { $_->get_pack }
                        @{ $self->{attrs} };

    # ... now fill in length;  4 == sizeof(uint32_t), where uint32_t is the result of pack 'L'
    substr $request, 0, 4, pack L => length $request;
    warn __PACKAGE__."::get_pack(@_) => ".unpack "H*", $request
        if $Linux::IpRoute2::ShowComposition;
    return $self->{data} = $request;
}

sub get_subhead_pack { '' }

1;
