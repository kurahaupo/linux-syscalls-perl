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
#           return Linux::Syscalls::bitset::_bits_to_desc( $names, @_ );
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

sub _bits_to_desc :prototype(\@$;$$$);

push our @EXPORT_OK, qw( _bits_to_desc  );

sub import {
    @_ >= 3 or croak 'At least one label required; got @_='."{@_}";
    my ($class, $prefix, @labels) = @_;

    my $c = caller;

    if ($prefix eq ':import') {
        return $class->export_to_level(1, $c, @labels);
    }

    my $sep = '+';
    my $empty;
    my $nfmt;
    my %opt = (
        min    => 1,    MIN    => 0,
        max    => 1,    MAX    => 0,
                       'MAX+1' => 0,
        next   => 1,

        all    => 1,    ALL    => 0,
        none   => 1,    NONE   => 0,
        shift  => 1,
    );

    for (;$labels[0] && $labels[0] =~ /^:/; shift @labels) {
        if (exists $opt{$'}) { ++$opt{$'}; next }
        if ($labels[0] =~ /^:no:/i && exists $opt{$'}) { $opt{$'} = 0; next }
        if ($labels[0] =~ /^:sep=(.*)/  ) { $sep   = $1; next }
        if ($labels[0] =~ /^:empty=(.*)/) { $empty = $1; next }
        if ($labels[0] =~ /^:nfmt=(.*)/ ) { $nfmt  = $1; next }
        croak "bad option $labels[0]\n\t";
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

    $nfmt //= sprintf '0x%%.%ux', $max + 4 >> 2;
    #            like "0x%.3x"
    $empty //= $opt{none} || $opt{NONE} ? 'none' : '0';

#   printf STDERR "Importing bitset into %s\n", $c if $^C;

    my %Alias;
    my %Con;
    my %Sub;

    for my $i (@indeces) {
        $Con{ $labels[$i] } = [ 1 << $i + $offset ];
    }

    # Make all the labels lowercase
    $_ = lc $_ for @labels[@indeces];

    my $all = reduce { $a | $b } map { 1 << $_+$offset } @indeces if $opt{all}
                                                                  || $opt{ALL};

    $Con{ALL}   = [ $all,    'limits' ] if $opt{ALL};
    $Con{all}   = [ $all,    'limits' ] if $opt{all};
    $Con{NONE}  = [ 0,       'limits' ] if $opt{NONE};
    $Con{none}  = [ 0,       'limits' ] if $opt{none};
    $Con{shift} = [ $offset, 'limits' ] if $opt{shift} >= ($offset == 0);

    $Con{MIN}   = [ $min,   'limits' ] if $opt{MIN};
    $Con{min}   = [ $min,   'limits' ] if $opt{min};
    $Con{MAX}   = [ $max,   'limits' ] if $opt{MAX};
    $Con{MAX}   = [ $max+1, 'limits' ] if $opt{'MAX+1'};
    $Con{max}   = [ $max,   'limits' ] if $opt{max};
    $Con{next}  = [ $max+1, 'limits' ] if $opt{next};

    my $export_tags = eval qq{ \\  %${c}::EXPORT_TAGS };
    my $export_ok   = eval qq{ \\ \@${c}::EXPORT_OK };

    $Sub{indeces}  = [ '()',   qq{ return \@indeces; },      'limits' ];    # exclude gaps
    $Sub{range}    = [ '()',   qq{ return \$min .. \$max; }, 'limits' ];    # include gaps
    $Sub{to_desc}  = [ '($)', qq{
                \@_ = (\\ \@labels, \$_[0], \$sep, \$empty, \$nfmt);
                # Use 'goto &FUNC' so that 'croak' will report correct caller
                goto &Linux::Syscalls::bitset::_bits_to_desc;
            }, 'descriptions' ];

    for my $k ( keys %Con ) {
        my ($v, @tags) = @{ $Con{$k} };
        my $name = $prefix.'_'.$k;
        eval qq{ package $c { use constant $name => $v } 1 }
            or confess $@ || "failed to define constant ${c}::$k => $v\n\t";
        push @{ $export_tags->{$_} }, $name for $lprefix, @tags;
    }

    for my $k (keys %Sub) {
        my ($name, $proto, $body, @tags) = ( $prefix.'_'.$k, @{ $Sub{$k} } );
        $proto = ' :prototype'.$proto if $proto;
        eval qq{ package $c { sub $name $proto { $body } } 1 }
            or confess $@ || "failed to define sub ${c}::$name\n\t";
        push @{ $export_tags->{$_} }, $name for $lprefix, @tags;
    }

    for my $to (keys %Alias) {
        my $from = $prefix.'_'.$Alias{$to};
        my $name = $prefix.'_'.$to;
        eval qq{ package $c { *$name = \\&$from } 1 }
            or confess $@ || "failed to define alias ${c}::$name for ${c}::$from\n\t";
        push @$export_ok, $name;
    }
}

################################################################################

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

sub _bits_to_desc :prototype(\@$;$$$) {
    my ($names, $flags, $sep, $empty, $nfmt) = @_;
    $flags or return $empty if $empty ne '';
    my @knowns;
    if ($names && @$names) {
        push @knowns,
            map {
                    my $n = $names->[$_];
                    my $bb = 1 << $_;
                    $n && 0+$flags != ($flags &=~ $bb)
                        ? $n
                        : ()
                } 0 .. $#$names;
    }
    push @knowns, sprintf $nfmt // '%#x', $flags
        if $flags || !@knowns;
    return join $sep // '+', @knowns;
}

1;
