#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

package Linux::IpRoute2::struct;

use Carp qw{ croak };

sub import {
    # Check & discard invocant
    my ($self, @fields) = @_;

    $self eq __PACKAGE__ or die "Class $self extends " . __PACKAGE__ . " without its own importer";

    my $quiet = ! $^W;
    my $strict = 0;

    my $class = caller;
    my $symtab = do { no strict 'refs'; \%{$class.'::'} };

    my $index = eval { $class->STRUCT_FIELD_INDEX } || 0;

    my @opts = grep { defined && ! /^\w+$/ } @fields;
    @fields = grep { ! defined || /^\w+$/ } @fields;

    my $set_end = $#fields;
    my $maxf = @fields;
    my $minf = 0;
    my $more_name;
    my $op_suffix;

    for my $f ( @opts ) {
        if ($f =~ /^:start_index=(\d+)$/) { $index = $1; next }
        if ($f =~ /^:start_index\+=(\d+)$/) { $index += $1; next }
        if ($f eq ':strict') { $strict = 1; next }
        if ($f eq ':quiet') { $quiet = 1; next }
        if ($f eq ':new_all_fields') { $strict = 1; $minf = $maxf; next }
        if ($f =~ /^:new_min_fields=(\d+)$/) { $strict = 1; $minf = $1; next }
        if ($f =~ /^:(attrs|attributes|extras|list|more|options|opts)$/) { $more_name = $1; $op_suffix = ''; next }
        if ($f =~ /^:more=(\w+)$/) { $more_name = $1; next }
        if ($f =~ /^:op=(\w+)$/) { $op_suffix = '_'.$1; next }
        if ($f =~ /^:op=$/) { $op_suffix = ''; next }
        croak "Unknown option $f";
    }

    $maxf = undef if $more_name;

    $minf <= $maxf or croak "min_fields ($minf) > max_fields ($maxf)" if defined $maxf;

    my $carp = $strict ? 'croak' : $quiet ? undef : 'carp';

    my $check_args = '';
    $check_args .= qq{ \$#_ == 0 || $carp "Args not allowed"; } if $carp;
    eval qq{
        package $class;
        use Carp qw{ $carp };
        1;
    } or die $@ if $carp && ! $class->can($carp);

    for my $f ( @fields ) {
        eval qq{
            package $class;
            sub $f :lvalue {
                $check_args
                return \$_[0]->[$index];
            }
            1;
        } || die $@
            if defined $f && ! exists $symtab->{$f};
        ++$index;
    }

    if ($more_name) {
        $op_suffix //= '_'.$more_name;

        eval qq{
            package $class;
            sub $more_name {
                my (\$self) = \@_;
                $check_args
                return \@\$self [$index .. \$#\$self];
            }
            1;
        } || die $@;

        eval qq{
            package $class;
            sub count$op_suffix {
                my (\$self) = \@_;
                $check_args
                return \@\$self - $index;
            }
            1;
        } || die $@;

        eval qq{
            package $class;
            sub pop$op_suffix {
                my (\$self) = \@_;
                $check_args
                return () if \$#\$self < $index;
                return pop \@\$self;
            }
            1;
        } || die $@;

        eval qq{
            package $class;
            sub shift$op_suffix {
                my (\$self) = \@_;
                $check_args
                return splice \@\$self, $index, 1;
            }
            1;
        } || die $@;

        eval qq{
            package $class;
            sub set$op_suffix {
                my (\$self, \@list) = \@_;
                \$#\$self = $index - 1;
                push \@\$self, \@list;
            }
            1;
        } || die $@;

        eval qq{
            package $class;
            sub push$op_suffix {
                my (\$self, \@list) = \@_;
                push \@\$self, \@list;
            }
            1;
        } || die $@;

        eval qq{
            package $class;
            sub unshift$op_suffix {
                my (\$self, \@list) = \@_;
                return splice \@\$self, $index, 0, \@list;
            }
            1;
        } || die $@;

        eval qq{
            package $class;
            sub splice$op_suffix {
                my (\$self, \$start, \$length, \@list) = \@_;
                if (! defined \$start) {
                    \$start = \@\$self;
                } elsif (\$start < 0) {
                    \$start += \@\$self;
                } else {
                    \$start += $index;
                }
                \$length //= \@\$self - \$start;
                if (\$length < 0) {
                    \$start += \$length;
                    \$length = -\$length;
                }
                \$start >= $index or croak("can't splice with negative start");
                return splice \@\$self, \$start, \$length, \@list;
            }
            1;
        } || die $@;
    }

    $check_args = '';
    if ($carp) {
        if (defined $maxf && $maxf == $minf) {
            $check_args .=
                   $maxf == 0 ? qq{ \@list == 0 || $carp "Args not allowed"; } :
                                qq{ \@list == $maxf || $carp "Wrong number of args; expected $maxf, got " . scalar \@list; };
        } else {
            $check_args .= qq{ \@list <= $maxf || $carp "Too many args; expected at most $maxf, got " . scalar \@list; } if defined $maxf;
            $check_args .= qq{ \@list >= $minf || $carp "Too few args; expected at least $minf, got " . scalar \@list; } if $minf;
        }
    }
    $check_args .= qq{ \$#list = $set_end; } if defined $set_end;

    eval qq{
        package $class;
        sub new {
            my (\$class, \@list) = \@_;
            $check_args
            return bless \\ \@list, \$class;
        }
        use constant { STRUCT_FIELD_INDEX => $index };
        1;
    } || die $@;
}

1;
