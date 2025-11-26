#! /module/for/perl

use 5.010;
use strict;
use warnings;
use feature 'state';

#
# Primarily this module allows us to write:
#
#   package Foo {
#       use Linux::Syscalls::enum qw( SPEED
#           DEAD_STOP
#           SLOW
#           -
#           MEDIUM
#           -
#           -
#           FAST
#       );
#   }
#
# and get the equivalent of:
#
#   package Foo {
#       use constant {
#           SPEED_min           => 0,
#           SPEED_DEAD_STOP     => 0,
#           SPEED_SLOW          => 1,
#           SPEED_MEDIUM        => 3,
#           SPEED_FAST          => 6,
#           SPEED_max           => 6,
#       };
#       sub SPEED_to_label {
#           state $names = [qw( dead_stop slow ), undef, qw( medium ), undef, undef, qw( fast )];
#           return $_[0] >= 0 ? $names[$_[0]] : ();
#       }
#       sub SPEED_to_desc { {
#           return &SPEED_to_label // "speed#${_[0]}";
#       }
#       push @{$EXPORT_TAGS{speed}}, qw{
#           SPEED_DEAD_STOP
#           SPEED_FAST
#           SPEED_MEDIUM
#           SPEED_SLOW
#           SPEED_max
#           SPEED_min
#           SPEED_to_desc
#           SPEED_to_label
#       };
#       push @{$EXPORT_TAGS{descriptions}}, qw{ SPEED_to_desc };
#       push @{$EXPORT_TAGS{labels}}, qw{ SPEED_to_label };
#       push @{$EXPORT_TAGS{limits}}, qw{ SPEED_max SPEED_min };
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

package Linux::Syscalls::enum v0.1.0;

use Carp qw{ croak confess };
use List::Util qw( reduce );
use Scalar::Util qw( looks_like_number );

sub import {
    @_ >= 3 or croak 'At least one label required; got @_='."{@_}";
    my ($class, $prefix, @labels) = @_;

    my $c = caller;

    my $offset = 0;
    if (looks_like_number $labels[0]) {
        $offset = shift @labels;
    }

    my %with = (
        min => 0,
        MIN => 0,
        max => 0,
        MAX => 0,
        'MAX+1' => 0,
    );
    for (;$labels[0] && $labels[0] =~ /^:/; shift @labels) {
        if (exists $with{$'}) { ++$with{$'}; next }
        if ($labels[0] =~ /^no/i && exists $with{$'}) { $with{$'} = 0; next }
        croak "bad option $labels[0]\n\t";
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

    my $lprefix = lc $prefix;

    printf STDERR "Importing enum into %s\n", $c;

    my %Con;
    for my $i (@indeces) {
        $Con{ $prefix.'_'.$labels[$i] } = $i + $offset;
    }
    $Con{ $prefix.'_min' } = $min if $with{min};
    $Con{ $prefix.'_max' } = $max if $with{max};
    $Con{ $prefix.'_MIN' } = $min if $with{MIN};
    $Con{ $prefix.'_MAX' } = $max if $with{MAX};
    $Con{ $prefix.'_MAX' } = $max+1 if $with{'MAX+1'};

    my $export_tags = eval qq{ \\  %${c}::EXPORT_TAGS };
    my $export_ok   = eval qq{ \\ \@${c}::EXPORT_OK };

    for my $k ( keys %Con ) {
        my $v = $Con{$k};
        eval qq{ package $c { use constant $k => $v } 1 }
            or confess $@ || "failed to define constant ${c}::$k => $v\n\t";
        push @{ $export_tags->{$lprefix} }, $k;
    }

    # Make all the labels lowercase
    $_ = lc $_ for @labels[@indeces];

    my %Sub = (
        to_label=> [ '(\$)', qq{ my \$i = \$_[-1] - $offset; return \$i >= 0 ? \$labels[\$i] : ();  }, 'labels' ],
        to_desc => [ '(\$)', qq{ return &${prefix}_to_label // "$lprefix#\${_[0]}"; },                 'descriptions' ],
        range   => [ '()',   qq{ return \$min .. \$max; },                                             'limits' ],          # include gaps
        indeces => [ '()',   qq{ return \@indeces; },                                                  'limits' ],          # exclude gaps
    );

    for my $k (keys %Sub) {
        my ($name, $proto, $body, @tags) = ( $prefix.'_'.$k, @{ $Sub{$k} } );
        $proto = ' :prototype'.$proto if $proto;
        eval qq{ package $c { sub $name $proto { $body } } 1 }
            or confess $@ || "failed to define sub ${c}::$name\n\t";
        push @{ $export_tags->{$_} }, $name for $lprefix, @tags;
    }

    my %Alias;
    $Alias{to_name} = 'to_desc' if ! $^W; # backwards compat unless hard checking

    for my $to (keys %Alias) {
        my $from = $Alias{$to};
        eval qq{ package $c { *$to = \\&$from } 1 }
            or confess $@ || "failed to define alias ${c}::$to for ${c}::$from\n\t";
        push @$export_ok, $to;
    }

    return;
}

1;
