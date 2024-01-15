#!/module/for/perl

use 5.010;
use strict;
use warnings;
no diagnostics; # they mess up backtrace from 'croak'

=head1 NAME

Verbose

=head1 SYNOPSIS

    # main.pl
    use Verbose qw( :argv :lock );
    use MyModule;

    # MyModule.pm
    package MyModule {
      use Verbose 'vvv';

      say 'Some basic info'    if v;
      say 'Some detailed info' if vv;
      say 'Routine minutiae'   if vvv;
      print 'Foo debug info:', Dumper(\%Foo)  if vvvv;
      DEBUG {
        print "Some long-winded debug info...\n";
        for my $item ( @list ) {
          printf "%s=%s\n", $item->name, $item->value;
        }
      };
    }

    # OtherModule.pm
    package OtherModule {
      use Verbose 'v';
      say "This won't be output" if v;
    }

    # command line
    myprogram --debug=MyModule=5,OtherModule=0,2

=head1 DESCRIPTION

The C<Verbose> package is intended to make it easy to write debugging
statements that don't get in the way of normal flow control, while giving you
fine-grained control to select the outputs of interest.

Each module that imports C<Verbose> gets its own I<verbosity level>, which can
be controlled from the command line without needing to add any extra logic.

The effective verbosity level for a module is given by

    I<effective_verbosity> = max( I<module_verbosity>,
                                  I<global_verbosity> + I<module_offset> )

If the I<effective_verbosity> exceeds the threshold for each C<v> or C<DEBUG>
statement, the relevant action(s) will be taken.

Module developers are free to choose their own range of verbosity settings, so
I<module_offset> exists to allow these to be re-aligned so that the single
I<global_verbosity> setting will normally produce output at similar levels of
significance from all modules. (This tends to mean that low-level modules
tend to produce less output that high-level modules.)

The I<module_verbosity> can be set in the module itself, so that its output is
enabled whenever I<global_verbosity> is high enough. Conversely
I<module_offset> can be set to a negative number to reduce the default
verbosity of external modules that also use C<Verbose>.

Settings can be obtained

=over 4

=item *

from C<--debug=I<setting,setting,setting,...>> among the program's command line
arguments; or

=item *

by calling C<set_verbose> with a value obtained from a configuration file or
database.

=item *

from C<use Verbose qw( :set=I<setting,setting,setting,...> );>

(This is intended for temporary use while developing a module.)

=back

In each case C<I<setting,setting,setting,...>> is a comma-separated list, where
each item is either C<I<tag>=I<number>> for a per-module setting, or just
I<number> for the global setting.

For example, invoking your program as

    myprogram --debug=MyModule=5,2

will cause the I<C<v> functions> within MyModule to respond with 1 (true) up to
level 5, while those elsewhere will respond with with 1 only up to level 2.

imports several condition flags (C<v>, C<vv>, C<vvv>, etc,
collectively called I<C<v> functions>) into each module that uses it; these are
intended to select "levels" of output, although you can use these condition
flags to control I<any> activities.

In this case, debugging will be enabled for MyModule, but not for any other
modules, and the C<--debug> option will be removed from the command line before
C<main> sees it.

By default debug is selected based on the current package, however you can
choose any tags you find useful; they can be shared across multiple modules,
and you can use several in one module (* this isn't implemented yet).

=head1 IMPORTABLE ITEMS

=head2 Generally applicable items

=head3 C<v> functions

C<v> C<vv> C<vvv> C<vvvv> ...

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

You can add C<=I<number>> to control the trigger level for C<DEBUG> in the
current package.

=head2 Control tags for all packages

=head3 :all

Import all exported symbols into your package.

=head3 :debug, :none and :set=

(Intended for debugging only.)

C<:debug> and C<:none> force all C<v> functions in the current package to yield
C<true> or C<false> respectively, and for C<DEBUG> to have the corresponding
behaviour.

C<:set=I<setting>,I<setting>,I<setting>,...>

=head2 Control tags for main::

These will normally only be used by C<main::>.

=head3 set_verbose

(C<set_verbose> only needs to be specified if you want to import it into a
package I<other> than C<main::>. It's automatically exported into C<main::>
because that's where C<GetOptions> is normally used.)

If setting the verbosity via the command line is not convenient -- say, you
want to set it based on a configuration file -- then you can call
C<set_verbose I<$control_string>> directly.

The control string is in the same format as for the C<--debug> command line
option.  Obviously you want to do this fairly early in the execution of your
program, as it will remain silent until then.

=head3 :argv

Find, process, and remove any C<--debug=I<string>> parameters in C<@ARGV>.
Combined with C<:lock>, this enables the C<v> functions to be reduced to
constants, allowing Perl's compilation phase to perform constant folding and
other optimisations.

Importing :argv will only cause this to be done once, even if it occurs in
multiple C<import> statements. If you need to process C<@ARGV> separately for
each C<import> statement, simply pass an array ref C<\@ARGV> instead of
C<:argv>.

The array is modified in-place, so that C<--debug=...> is not present when
later processed by C<GetOptions>.

(This method can be used to process arrays other than C<@ARGV>. However it is
difficult to envisage a situation where this would be useful, so if you have a
practical example using this, please contact this module's maintainer.)

=head3 :lock

Prohibit further calls to C<set_verbose>, enabling optimisations that assume
that verbosity levels cannot change. Useful in conjunction with C<:argv>.

Do not use this option if you may want to change the verbosity settings while
the program is running; for example, if they can be read from a configuration
file.

=head3 :nocompat

This prevents generation of the compatibility-mode version of C<v> in all
modules; the version presented expects I<no> arguments (and providing one will
produce a compile-time error).

=head1 COPYRIGHT

This package was originally written by Martin Kealey in 2003 and released under
the GNU Public Licence version 2.

This help section was completely rewritten by Martin Kealey between 2016 and
2023, replacing a previous help section written by Ihug in 2008.

The :nocompat mode was actually implemented by Martin Kealey in 2019; also
improved the efficiency of the test functions by having the "global level"
simply be a matter of setting *all* the tagged levels.

=cut

package Verbose;

our @VERSION = 1.002;

use constant compat_verbose_level  => 1;   # level at which compat-mode v is true without an arg
use constant default_debug_level   => 5;   # default level at which DEBUG blocks run

my %level_for;
my %offset_for;
my $global_level = 0;

my $seen_nocompat;      # set to 1 when :nocompat is imported
my $seen_compat;        # set to module name that last used compat mode
my $locked;             # set_verbose no longer allowed

sub steal_argv_debug(;\@);

sub _croak_or_die {
    my ($e) = @_;
    our @CARP_NOT = (__PACKAGE__);  # this is probably redundant
    croak($e) if eval "use Carp 'croak'; 1;";
    die $e;
}

package Verbose::Errors:: {
    use overload '""' => sub { return $_[0]->{msg} };
}

my $have_stolen_argv;

# GetOptions can be called in 3 ways:
# + by user code, with 1 parameter: the option value (enforced by the prototype)
# + by GetOptions, with 2 parameters: the option name, and the option value
# + during importing, with 3 or 4 parameters: a reason, an optional caller
#   depth, the option name, and the option value.
# (The option name and reason are only used for error reporting)
sub set_verbose($) {
    my $arg = pop;
    if ($locked) {
        my ($opkg, $ofilename, $olineno) = @$locked;
        my  $opt = pop;     # Arg name that caused set_verbose to be invoked
        my  $why = shift    # General reason why we were called
                 // ($opt && 'GetOpts')
                 // 'Direct';
        my $depth = pop // ( $why eq 'Stealing' ? 3 : $why eq 'Using' ? 2 : 1 );
        die bless {
            why     => 'TooLate'.$why,
            option  => $opt,
            arg     => $arg,
            msg     => "Cannot change verbosity after lock was set at line $olineno in $ofilename",
            where   => [caller $depth+1],
        }, Verbose::Errors::;
    }
    my @o = split ',', $arg;
    for my $o (@o) {
        if ( $o =~ /=/ ) {
            $level_for{$`} = $';
        } elsif ( $o =~ /^\d+$/ ) {
            $global_level = $o;
            for my $k ( keys %level_for ) {
                $level_for{$k} = $o - $offset_for{$k};
            }
        } else {
            my  $opt = pop;     # Arg name that caused set_verbose to be invoked
            my  $why = shift;   # General reason why we were called
                $why //= $opt && 'GetOpts' // 'Direct';
            my  $msg = "Invalid value '$o'";
                $msg .= " as part of '$arg'" if $o ne $arg;
                $msg .= " for option $opt" if $opt;
                $msg .= " ($why)";
            my $depth = pop // ( $why eq 'Stealing' ? 3 : $why eq 'Using' ? 2 : 1 );
            die bless {
                why     => 'Bad'.$why,
                option  => $opt,
                arg     => $arg,
                values  => \@o,
                value   => $o,
                msg     => $msg,
                where   => [caller $depth+1],
            }, Verbose::Errors::;
        }
    }
}

sub vdebug(;$) { 1 }
sub vsilent(;$) { 0 }

sub import {
    my $self = shift;
    my ($pkg) = caller;
    my $tag = $pkg;

    # what to export
    my $export_debug = 1;
    my $export_sv = $pkg eq 'main';
    my $export_v = 1;
    my %exports;

    #
    my $debug_level = default_debug_level;
    my $offset_from_global = 0;
    my $override;
    my $want_compat;

    my $will_lock;  # delay locking until all args are processed

    for (@_) {
        if    ( ref($_) eq 'ARRAY'      ) { steal_argv_debug @$_ }
        elsif ( $_ eq ':all'            ) { $export_debug = $export_sv = 1; $export_v ||= 1 }
        elsif ( $_ eq ':argv'           ) { steal_argv_debug if ! $have_stolen_argv++ }
        elsif ( $_ eq 'DEBUG'           ) { $export_debug = 1 }
        elsif (      /^DEBUG=(\d+)$/    ) { $export_debug = 1; $debug_level = $1 }
        elsif ( $_ eq ':debug'          ) { $override = \&vdebug; $debug_level = 0; }
        elsif ( $_ eq ':none'           ) { $export_debug = $export_sv = $export_v = 0; $debug_level = 1E99; }
        elsif ( $_ eq 'set_verbose'     ) { $export_sv = 1 }
        elsif ( $_ eq ':silent'         ) { $override = \&vsilent }
        elsif ( $_ eq ':nocompat'       ) { $want_compat = 0; $seen_nocompat ||= "$pkg explicitly"; }
        elsif ( $_ eq ':compat'         ) { $want_compat = 1 }
        elsif (      /^=|^:set=/        ) { &set_verbose('Using', 1, $pkg, $') }
        elsif (      /^v+$/             ) { $export_v = length $_ }
        elsif (      /^:offset=[-+]?\d+$/ ) { $offset_from_global = 0+$_ }
        elsif (      /^\w+(::\w+)*$/    ) { $tag = $_ }
        else { _croak_or_die "Don't understand $_"; }
    }

    $locked = [caller] if $will_lock;

    if ($tag) {
        $tag =~ s/::$//;
        $offset_for{$tag} = $offset_from_global if ! exists $offset_for{$tag};
        my $new_level = $global_level - $offset_from_global;
        if ( ! exists $level_for{$tag} || $new_level < $level_for{$tag} ) {
            $level_for{$tag} = $new_level;
        }
        $tag = \$level_for{$tag};
    } else {
        if ($offset_from_global) {
            _croak_or_die "Can't have an offset from the global level without having a tag";
        }
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
            # compatibility mode ("v" is a unary function with default parameter of compat_verbose_level)
            $exports{v} = $override // sub(;$) {
                return $$tag >= (shift // compat_verbose_level);
            };
        } else {
            # modern mode ("v" is a nonary function)
            for my $l ( 1 .. $export_v ) {
                my $ll = $l;
                my $v = $override // sub() { return $$tag >= $ll; };
                $exports{ 'v' x $l } = $v;
            }
        }
    }

    if ( $export_debug ) {
        $exports{DEBUG} = $override ? &$override ? sub(&) { my $f = shift; goto &$f; }
                                                 : sub(&) {}
                                    : sub(&) { my $f = shift; goto &$f if $$tag >= $debug_level; };
    }

    if ( $export_sv ) {
        $exports{'set_verbose'} = \&set_verbose;
    }

    my $rpkg = do {
        no strict 'refs';
        \%{ $pkg.'::' };
    };
    for my $sym ( keys %exports ) {
        my $val = $exports{$sym};
        local $SIG{__DIE__} = sub {
            printf STDERR "thrown=%s\n"
                        . "pkg=%s\nrpkg=%s\nsym=%s\nval=%s\n"
                        . "rpkg{sym}=%s\n",
                        $@,
                        $pkg, $rpkg, $sym, $val,
                        $rpkg->{$sym} // '(undef)';
            $SIG{__DIE__} = undef;  # just in case a DESTROY dies on the way out
            exit 1;
        };
        if (exists $rpkg->{$sym} && ref \$rpkg->{$sym} eq 'GLOB') {
            # The symbol table entry already exists as a typeglob, so we must
            # use one of its slots - we can't use the inline optimizer trick.
            #
            # The "exists" precondition is necessary because taking "\" of
            # something will force it to exist, and that would defeat the
            # optimizer.
            #
            # There's a simpler test but it's quite arcane: if ${pkg::{$sym}}
            # exists but its ref is falsish, then it's a typeglob.
            if ( ! ref $val ) {
                # If we wanted to export a constant, wrap it as a generator
                # function; equivalent to pessimized "use constant".
                my $xval = $val;
                $val = sub { $xval };
            }
            # typeglob slot automatically selected by ref of $val; any of
            # SCALAR, ARRAY, HASH, CODE, IO, and FMT.
            *{$rpkg->{$sym}} = $val;
        } else {
            if ( ref $val ) {
                no strict 'refs';
                # Automagically create a typeglob
                *{ $pkg.'::'.$sym } = $val;
            } else {
                # Equivalent to "use constant"
                $rpkg->{$sym} = \$val;
            }
        }
    }

}

sub steal_argv_debug(;\@) {
    my ($argv) = @_;
    $argv ||= \@::ARGV;
    my $nomore = 0;
    @$argv = grep {
                    if ( ! $nomore && /^--debug=/ ) {
                        &set_verbose( 'Stealing', 2, 'debug', $' );
                        0;
                    } else {
                        ( $_ eq '--' || ! /^-/ ) and ++$nomore;
                        1;
                    }
                } @$argv;
}

sub showguts() {
    require Data::Dumper;
    warn "Verbose::showguts\n". Data::Dumper::->Dump([
        \%level_for,
        \%offset_for,
        $global_level,
        $seen_nocompat,
        $seen_compat,
    ], [
        "level_for: ",
        "offset_for: ",
        "global_level: ",
        "seen_nocompat: ",
        "seen_compat: ",
    ]);
}

1;

=head1 BUGS & LIMITATIONS

=over 4

=item

This module uses its own hand-crafter exporter, because it needs to change what
gets exported when a given symbol is asked for. This means it needs to mimic
some rather complex parts of the standard C<Exporter> module, and in
particular, exporting scalar constants requires some in-depth knowledge of how
symbol tables work. If C<Exporter> ever changes, this module is likely to
break.

=item

Used as intended this module should be straightforward, but if you start trying
to do tricky things you will quickly find yourself having to deal with the
interplay between the BEGIN and RUN phases. I've tried to document the
important aspects of that here, but no doubt I've missed some subtler points
that you'll need to discover for yourself.

=back

=head1 PLANS & TODO

=over 4

=item

Make functionality match description. Some stuff doesn't work quite right.

(Getting there.)

=back

=cut
