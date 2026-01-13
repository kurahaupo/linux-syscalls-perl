#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

use Data::Dumper;

package Linux::IpRoute2::default_unpack;

use Carp qw( carp confess );

sub round_up($) {
    my ($l) = @_;
    return -(-$l & ~3);
}

sub new_attr {
    my ($self, $type) = @_;

    my $class = $self->_attr_type_to_pkg($type)
        or die "No attribute class for child of " . (ref $self || $self) . " with type code $type\n\t";

    my $attr = bless [], $class;

    $attr->attr_type == $type or die 'Type mismatch';

    return $attr;
}

sub _unpack_hex($) {
    my ($data) = @_;
    return unpack("H*", $data)  =~ s/\w{16}/\n\t\t$&/r
                                =~ s/\w{64}(?=\w)/$&\n\t\t/gr
                                =~ s/\w{8}(?=\w)/$& /gr;
}

sub unpack_self {
    my ($self, $data) = @_;

    ref $self
        or die 'Invocant is not an object reference';

    $self->isa('ARRAY')
        or die 'Base type is not an array';

    if ($self->can('packpat')) {
        my $pp = $self->packpat;
        my @v;
        eval {
            @v = unpack $pp.'x![l]a*', $data;
            $data = pop @v;
            1;
        } or eval {
            @v = unpack $pp, $data;
            $data = undef;
            1;
        } or confess sprintf "\e[41mUnpack failure\e[m\n"
                        ."\tpattern=%s\n"
                        ."\tdata={%s}\n",
                        $pp . 'x![l]a*',
                        _unpack_hex $data;
        push @$self, @v;
    }

    if (defined $data) {
        if ($self->can('new_attr')) {
            my $len_data = length $data;
            for ( my $len, my $offset = 0 ; $offset < $len_data ; $offset += round_up $len ) {
                ($len, my $type) = unpack '@'.$offset.'SS', $data;
                defined $type && defined $len &&
                $len >= 4 && $offset + $len <= $len_data
                    or confess sprintf  "\e[1mAttribute sync failure\e[m\e[K, noticed weird values\n"
                                      . "\toffset=%s + length=%s / size=%s\n"
                                      . "\tpackpat=%s\n"
                                      . "\torigdata={%s}\n"
                                      . "\tdata={%s}\n"
                                      . "\tself=%s\n"
                                      , $offset // '(undef)' || '(empty)'
                                      , $len // '(undef)' || '(empty)'
                                      , $len_data
                                      , eval { $self->packpat } // '(none)' || '(empty)'
                                      , unpack( "H*", $_[1] )
                                      , unpack( "H*", $data )
                                      , Data::Dumper->new([$self],[qw[self]])->Indent(0)->Useqq(1)->Dump;
                my $attr = $self->new_attr($type);
                $attr->unpack_self(substr $data, $offset+4, $len-4);
                printf STDERR "\t\e[36mUnpacking attr offset=%s len=%s type=%s\e[m\n",
                                $offset,
                                $len,
                                $type
                    if $Linux::IpRoute2::ShowDecomposition;
                push @$self, $attr;
            }
        }
        $self->unpack_residue($data) if $data ne '';
    }

    printf STDERR "\e[35m%s::\e[1munpack_self\e[m(\e[36m%s\e[m, data={%s})\n"
                . "\t packpat={SS%s}\n"
                . "\t attr_type=%s\n"
                . "\t result => {%s}\n"
                . "\tCALLED",
            __PACKAGE__,
            ref $self,
            _unpack_hex $data,
            eval { $self->packpat } // '',
            eval { $self->attr_type } // '(none)',
            Data::Dumper->new([$self],[qw[self]])->Indent(0)->Dump
        if $Linux::IpRoute2::ShowDecomposition;

    return $self;   # allow chaining
}

sub unpack_residue {
    my ($self, $data) = @_;
    push @$self, unpack 'H*', $data;
}

sub get_pack {
    my ($self) = @_;
    my $res = pack $self->packpat, @$self;

    $res .= join '', map { $_->get_pack } $self->attrs if $self->can('attrs');

    $res = pack 'SSa*x![L]', length($res)+4, $self->attr_type, $res;

    printf STDERR "\e[33m%s::\e[1mget_pack\e[m(\e[36m%s\e[m)\n"
                . "\t packpat={SS%s}\n"
                . "\t attr_type=%s\n"
                . "\t self=%s\n"
                . "\t result => {%s}\n"
                . "\tCALLED",
            __PACKAGE__,
            ref $self,
            $self->packpat,
            $self->attr_type,
            Data::Dumper->new([$self],[qw[self]])->Indent(0)->Dump,
            _unpack_hex $res
        if $Linux::IpRoute2::ShowDecomposition;
    return $res;
}

1;
