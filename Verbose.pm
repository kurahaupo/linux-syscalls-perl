#!/module/for/perl

use 5.008;
use strict;
use warnings;
no diagnostics; # they mess up backtrace from 'croak'

=head1 NAME

Verbose

=head1 SYNOPSIS

    package main;
    use Verbose ':argv';
    use MyModule;

    package MyModule;
    use Verbose;
    print "Some debug info\n" if v;
    DEBUG {
        print "Some long-winded debug info...\n";
        for my $item ( @list ) {
            printf "%s=%s\n", $item->name, $item->value;
        }
    };

    package OtherModule; use Verbose ':class';

=head1 DESCRIPTION

The C<Verbose> package is intended to make it easy to write debugging
statements that don't get in the way of normal flow control, but at the same
time to make it easy to control the output so you don't have to wade through
screeds of stuff that's not relevant to the problem you're trying to fix right
now.

Then you invoke your program with C<--debug=>I<controls>, like this:

    myprogram [--normal-options ...] --debug=MyModule=1 [--normal-options ...]

In this case, debugging will be enabled for MyModule, but not for any other
modules, and the C<--debug> option will be removed from the command line before
C<main> sees it.

By default debug is selected based on the current package, however you can
choose any tags you find useful; they can be shared across multiple modules,
and you can use several in one module (* this isn't implemented yet).

=head1 IMPORTABLE ITEMS

=head2 Generally applicable items

=head3 v vv vvv vvvv ...

Returns true or false depending on whether debug output is expected from the
current context. Typically used as

    print "Some debug output\n" if v;

    print "Some 'verbose' debug output\n" if vv;

    print "Some 'very verbose' debug output\n" if vvv;

    print "Debug output showing 'everything'\n" if vvvv;

Importing one of these symbols also gets you all the shorter ones (you can
ask for any arbitrary depth).

If you do not specify anything to import you will get "compatibility mode".

The previous version of this module provided a slightly different version of
the C<v> method, that optionally took a "level" argument. This resulted in
slower code, which is why the v/vv/vvv/vvvv approach has been taken instead.

There are additional advantages to the new approach:

=over 4

=item 1

More information is available at compile time. Since each module has to
declare its maximum level, that information can be used to optimize the
generated code.

=item 1

Making the symbols progressively longer discourages using an excessive
number of levels, which rarely have any practical value; experience has shown
that you would be better off using a wider range of tags instead.

=back

In compatibility mode you can give a "level" value (which defaults to "1") that
the control setting must exceed before debugging will be enabled for this item.

    print "Some 'verbose' debug output\n" if v 2;

    print "Some 'very verbose' debug output\n" if v 3;

An even older version of this module provided methods named v1, v2, v3 etc.
This has been discontinued as it can be confused with the 'literal byte string'
notation introduced in Perl 5.6.

See C<:nocompat> below.

=head3 DEBUG { I<BLOCK> };

Only invoke I<BLOCK> if debug output is expected from the current context.
Functionally equivalent to:

    if (vvvvv) { BLOCK }

(Because DEBUG is a unary function, the trailng semicolon is normally required.)

=head2 Control items

These will normally only be used by main.

=head3 set_verbose I<$control_string>

If setting the verbosity via the command line is not convenient -- say, you
want to set it based on a configuration file -- then you can call
C<set_verbose> directly.

The control string is in the same format as for the C<--debug> command line
option.  Obviously you want to do this fairly early in the execution of your
program, as it will remain silent until then.

=head3 :nocompat

This prevents generation of the compatibility-mode version of C<v> in all
modules; the version presented expects I<no> arguments (and providing one will
produce a compile-time error).

=head1 COPYRIGHT

This package was originally written by Martin Kealey in 2003 and released under
the GNU Public Licence version 2.

This help section was added by Ihug in 2008, replacing a previous stub help
section written in 2004.

The :nocompat mode was actually implemented by Martin Kealey in 2019; also
improved the efficiency of the test functions by having the "global level"
simply be a matter of setting *all* the tagged levels.

=cut

package Verbose;

our @VERSION = 1.002;

use constant default_verbose_level => 1;   # level at which compat-mode v is true without an arg
use constant default_debug_level   => 5;   # default level at which DEBUG blocks run

my %level_for;
my %offset_for;
my $global_level = 0;

my $seen_nocompat;      # set to 1 when :no_compat is imported
my $seen_compat;        # set to module name that last used compat mode

sub steal_argv_debug(;\@);

sub _croak_or_die {
    my ($e) = @_;
    our @CARP_NOT = (__PACKAGE__);  # this is probably redundant
    croak($e) if eval "use Carp 'croak'; 1;";
    die $e;
}

    { package Verbose::Errors::; }

sub set_verbose($) {
    my $o = $_[-1];     # GetOptions calls us with two args, and the last is the interesting one
    my @o = split ',', $o;
    for my $o (@o) {
        if ( $o =~ /=/ ) {
            $level_for{$`} = $';
        } elsif ( $o =~ /^\d+$/ ) {
            $global_level = $o;
            for my $k ( keys %level_for ) {
                $level_for{$k} = $o - $offset_for{$k};
            }
        } elsif ( @_ == 2 ) {
            # we were called from GetOptions
            die "Invalid value $o from command-line parameter $_[0]\n";
        } elsif ( @_ == 3 ) {
            # we were called from import (and thence 'use' or 'require')
            die "Invalid value $o while importing into $_[1] with :set=\n";
        } else {
            warn "invalid value $o";
            die bless { type => "BADPARAM", value => $o }, Verbose::Errors::;
        }
    }
}

sub vdebug(;$) { 1 }
sub vsilent(;$) { 0 }

sub import {
    my $self = shift;
    my ($pkg) = caller;
    my $tag = $pkg;
    my $export_debug = 1;
    my $export_v = 1;
    my $export_sv = $pkg eq 'main';
    my $override;
    my $global_offset = 0;
    my $want_compat;
    my %exports;

    warn "import: args=[@_]";
    for (@_) {
        if ( ref($_) eq 'ARRAY'         ) { steal_argv_debug @$_ }
        elsif ( $_ eq ':all'            ) { $export_debug = $export_sv = 1; $export_v ||= 1 }
        elsif ( $_ eq ':argv'           ) { steal_argv_debug }
        elsif ( $_ eq 'DEBUG'           ) { $export_debug = 1 }
        elsif ( $_ eq ':debug'          ) { $override = \&vdebug }
        elsif ( $_ eq ':none'           ) { $export_debug = $export_sv = $export_v = 0 }
        elsif ( $_ eq 'set_verbose'     ) { $export_sv = 1 }
        elsif ( $_ eq ':silent'         ) { $override = \&vsilent }
        elsif ( $_ eq ':nocompat'       ) { $want_compat = 0; $seen_nocompat ||= "$pkg explicitly"; }
        elsif ( $_ eq ':compat'         ) { $want_compat = 1 }
        elsif ( /^=|^:set=/             ) { &set_verbose(undef, $pkg, $') }
        elsif ( /^v+$/                  ) { $export_v = length $_ }
        elsif ( /^[-+]?\d+$/            ) { $global_offset = 0+$_ }
        elsif ( /^[A-Za-z]\w+(::\w+)*$/ ) { $tag = $_ }
        else { _croak_or_die "Don't understand $_"; }
    }

    if ($tag) {
        $tag =~ s/::$//;
        $offset_for{$tag} = $global_offset if ! exists $offset_for{$tag};
        my $new_level = $global_level - $global_offset;
        if ( ! exists $level_for{$tag} || $new_level < $level_for{$tag} ) {
            warn "import: Setting tag:$tag to $new_level";
            $level_for{$tag} = $new_level;
        }
        $tag = \$level_for{$tag};
    } else {
        if ($global_offset) {
            _croak_or_die "Can't have an offset from the global level without having a tag";
        }
        warn "import: Using global tag with $global_level";
        $tag = \$global_level;
    }

    if ( $export_v ) {
        if ( ! defined $want_compat ) {
            $want_compat = ! $seen_nocompat && $export_v < 2;
            $seen_compat ||= "$pkg implicitly" if $want_compat;
        } else {
            $seen_compat ||= "$pkg explicitly" if $want_compat;
        }

        if ($seen_compat && $seen_nocompat) {
            _croak_or_die "Package $seen_nocompat requires :nocompat but package $seen_compat imports :compat";
        }

        if ( $want_compat ) {
            # compatibility mode ("v" is a unary function with default parameter of default_verbose_level)
            $exports{v} = $override || sub(;$) {
                #warn "Testing $tag $$tag args=[@_] def=[".(default_verbose_level)."]";
                return $$tag >= (shift // default_verbose_level);
            };
        } else {
            # modern mode ("v" is a nonary function)
            for my $l ( 1 .. $export_v ) {
                my $ll = $l;
                my $v = $override || sub() { return $$tag >= $ll; };
                $exports{ 'v' x $l } = $v;
            }
        }
    }

    if ( $export_debug ) {
        $exports{DEBUG} = $override || sub(&) { my $f = shift; goto &$f if $$tag >= default_debug_level; };
    }

    if ( $export_sv ) {
        $exports{'set_verbose'} = \&set_verbose;
    }

    for my $sym ( keys %exports ) {
        my $r = $pkg.'::'.$sym;
        no strict 'refs';
        *$r = $exports{$sym};
    }

}

sub steal_argv_debug(;\@) {
    my ($argv) = @_;
    $argv ||= \@::ARGV;
    warn "Stealing from $argv";
    my $nomore = 0;
    @$argv = grep {
                    if ( ! $nomore && /^--debug=/ ) {
                        set_verbose $';
                        0;
                    } else {
                        ( $_ eq '--' || ! /^-/ ) and ++$nomore;
                        1;
                    }
                } @$argv;
}

sub showguts() {
    eval 'use Data::Dumper; 1;';
    warn "Verbose::showguts";
    warn "    level_for: ".Dumper(\%level_for);
    warn "    offset_for: ".Dumper(\%offset_for);
    warn "    global_level: ".($global_level);
    warn "    seen_nocompat: ".($seen_nocompat);
    warn "    seen_compat: ".($seen_compat);
}

1;

=head1 BUGS

Plans:

=over 4

=item

Make functionality match description. Some stuff doesn't work quite right.

=item

Change handling of a "global" level so that the "v" functions no longer have to
check it, they just check their respective levels, while set_verbose sets all
levels to the global level (except those which are set explicitly).

=item

Convert level comparisons into flag look-ups, which should be faster.

=back

=cut
