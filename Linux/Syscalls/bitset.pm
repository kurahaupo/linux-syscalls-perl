#! /module/for/perl

use 5.010;
use strict;
use warnings;
use feature 'state';

#
# Primarily this module allows us to write:
#
#   package Foo {
#       use Linux::Syscalls::bitset qw( OPTIMISE
#           -
#           QUICK
#           CHEAP
#           PROMPT
#           -
#           BUGFREE
#       );
#   }
#
# and get the equivalent of:
#
#   package Foo {
#       use constant {
#           OPTIMISE_shift      => 1,   # only if non-zero
#           OPTIMISE_QUICK      => 2,
#           OPTIMISE_CHEAP      => 4,
#           OPTIMISE_PROMPT     => 8,
#           OPTIMISE_BUGFREE    => 32,
#       };
#       sub OPTIMISE_to_desc {
#           state $names = [qw( - quick cheap prompt - bugfree )];
#           return _bits_to_desc( $_[0], $names, $_[1] //() );
#       }
#       push @{$EXPORT_TAGS{speed}}, qw{
#           OPTIMISE_shift
#           OPTIMISE_QUICK
#           OPTIMISE_CHEAP
#           OPTIMISE_PROMPT
#           OPTIMISE_BUGFREE
#           OPTIMISE_to_desc
#       };
#       push @{$EXPORT_TAGS{descriptions}}, qw{ OPTIMISE_to_desc };
#       push @{$EXPORT_TAGS{limits}}, qw{ OPTIMISE_max OPTIMISE_min };
#   }
#
#
# CODA:
#   Although this package isn't Linux-specific, it's
#   Linux::Syscalls::decorated_constant because it's built for internal use by
#   modules that are, especially Linux::Syscalls and by Linux::IpRoute2.
#
#   If you find any of it useful in other projects, feel free to rename the
#   package and/or adjust the upper-/lower-case mappings.
#

package Linux::Syscalls::bitset v0.1.0;

use Carp qw{ croak confess };
use parent 'Exporter';
use List::Util qw( reduce );
use Scalar::Util qw( looks_like_number );

sub _bits_to_desc :prototype($\@;$);

push our @EXPORT_OK, qw( _bits_to_desc  );

sub import {
    @_ >= 3 or croak 'At least one label required; got @_='."{@_}";
    my ($class, $prefix, @labels) = @_;

    my $c = caller;

    if ($prefix eq ':import') {
        return $class->export_to_level(1, $c, @labels);
    }

    my $offset = 0;
    if (looks_like_number $labels[0]) {
        $offset = shift @labels;
    }

    # Zap any '-' labels
    for my $L (@labels) {
        defined $L &&
         '-' eq $L and
          undef $L;
    }

    my @indeces = grep { defined $labels[$_] } 0 .. $#labels
        or croak 'Not enough labels supplied';
    my ($min, $max) = @indeces[0,-1];
    defined $min && defined $max
        or croak 'Empty list of labels';
    $min+$offset >= 0 && $max+$offset < 64
        or croak 'Offset out of range [0..63] and/or too many labels';

    my $lprefix = lc $prefix;

    printf STDERR "Importing bitset into %s\n", $c;

    for my $i (@indeces) {
        my $n = $labels[$i] // next;
        my $j = 1 << $i + $offset;
        my $fn = $prefix.'_'.$n;
        eval qq{
            package $c { use constant $fn => $j }
            push \@{\$${c}::EXPORT_TAGS{$lprefix}}, qw{ $fn };
            1
        } or confess $@ || "failed to define constant ${c}::$fn => $j\n\t";
    }

    eval qq{
        package $c { use constant ${prefix}_NONE => 0 }
        push \@{\$${c}::EXPORT_TAGS{$lprefix}}, qw{ ${prefix}_NONE };
        push \@{\$${c}::EXPORT_TAGS{limits}},   qw{ ${prefix}_NONE };
        1
    } or confess $@ || "failed to define constant ${c}::${prefix}_NONE = 0\n\t";

    my $all_bits = reduce { $a | $b } map { 1 << $_+$offset } keys @labels;
    eval qq{
        package $c { use constant ${prefix}_ALL => $all_bits; }
        push \@{\$${c}::EXPORT_TAGS{$lprefix}}, qw{ ${prefix}_ALL };
        push \@{\$${c}::EXPORT_TAGS{limits}},   qw{ ${prefix}_ALL };
        1
    } or confess $@ || "failed to define constant ${c}::${prefix}_ALL} => $all_bits\n\t";

    # Use 'goto &func' so that errors will report correct caller
    defined and $_ = lc $_ for @labels;
    eval qq{
        package $c {
            sub ${prefix}_to_desc :prototype(\$;\$) {
                \@_ = (\$_[0], \@labels, \$_[1] // ());
                goto &_bits_to_desc;
            }
        }
        push \@{\$${c}::EXPORT_TAGS{$lprefix}},     qw{ ${prefix}_to_desc };
        push \@{\$${c}::EXPORT_TAGS{descriptions}}, qw{ ${prefix}_to_desc };
        1
    } or confess $@ || "failed to define sub ${c}::${prefix}_to_desc\n\t";

    if ($offset != 0) {
        eval qq{
            package $c { use constant ${prefix}_shift => $offset }
            push \@{\$${c}::EXPORT_TAGS{$lprefix}}, qw{ ${prefix}_shift };
            1
        } or confess "failed to define constant ${c}::${prefix}_shift = $offset\n\t";
    }

    eval qq{
        package $c {
            sub ${prefix}_indeces :prototype() { return \@indeces; };           # exclude gaps
            sub ${prefix}_range   :prototype() { return \$min .. \$max; };      # include gaps
        }
        1
    } or confess $@ || "failed to define sub ${prefix}_indeces and/or ${prefix}_range\n\t";

    return;
}

# _bits_to_desc should only be used by custom SOMETYPE_to_desc functions, each
# of which should supply the list of names describing the bits in a SOMETYPE
# value.
#
# either:
#
#   sub SOMETYPE_to_desc($;$) {
#       return _bits_to_desc $_[0], \@list_of_bit_names, $_[1] // ();
#   }
#
# or:
#
#   sub SOMETYPE_to_desc($;$) {
#       return _bits_to_desc $_[0], \@list_of_bit_names, $_[1] // ();
#   }
#
# or:
#
#   sub SOMETYPE_to_desc($;$) {
#       splice @_, 1, 0, \@list_of_bit_names;
#       goto &_bits_to_desc;
#   }
#

sub _bits_to_desc :prototype($\@;$) {
    my ($flags, $names, $sep) = @_;
    $flags or return 'none';
    my $max_bit = 0;
    my @knowns;
    if ($names && @$names) {
        $max_bit = $#$names;
        push @knowns,
            map {
                    my $n = $names->[$_];
                    my $bb = 1 << $_;
                    $n && 0+$flags != ($flags &=~ $bb)
                        ? $n
                        : ()
                } 0 .. $max_bit;
    }
    push @knowns, sprintf '%#.*x', ($max_bit>>2)+1, $flags
        if $flags;
    return join $sep // '+', @knowns;
}

1;
