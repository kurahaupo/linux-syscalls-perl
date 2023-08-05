#!/module/for/perl

use 5.010;
use strict;
use warnings;
use utf8;

package export;

use Carp qw( croak carp );

# $export::debug is separate from $verbose::debug and is not controlled by the
# -x/--debug command line option.
our $debug = $ENV{PERL_debug_export} // $^C;

my %typemap = (
    # These are the elements of a glob, taken in this order from "man perlref",
    # using the sigils that would normally appear in code.
    '$'  => 'SCALAR',
    '@'  => 'ARRAY',
    '%'  => 'HASH',
    '&'  => 'CODE',     # default if no type prefix is supplied
    '*'  => 'GLOB',

    # The following prefix patterns are not the same as the sigils.

    # These glob parts don't have sigils, so use fake ones:
    '|'  => 'IO',       # Since '<' and '>' are used for renaming, use the pipe symbol
    '/'  => 'IO',       # DirIO, which is hidden inside a normal IO

    '^'  => 'FORMAT',

    # These glob parts don't have sigils, and moreover cannot be imported into
    # the receiving package because they are always read-only. They are reserved
    # so that a future version of this package will allow a reference to be
    # imported into a scalar.
    '.'  => 'NAME',     # read-only
    '::' => 'PACKAGE',  # read-only

    # CODE found by searching the @ISA graph
    '->' => 'METHOD',   # This is a made up prefix, not part of "man perlref".
                        # Note that for this to work, you need to use 'use
                        # parent' (or use an equivalent method to set up @ISA
                        # at compile time) BEFORE 'use export'.

    # Constant that can be folded at compile time
    '='  => 'CONST'
);

sub import {
    my $meta = shift;
    my $not_faking = @_ && $_[0] eq '-' && shift;
    my $exportable = [@_];
    my ($epkg, $efile) = caller;
    my %optimized_exportable;
    my %exportable;
    {

    my $symtab = do { no strict 'refs'; \%{"${epkg}::"}; }
        or die "Can't connect to calling package $epkg";

    for my $e (@$exportable) {
        my $n = $e;
        my $m = '';
        my $t = '&';
        $n =~ s/^\W+// and $t = $&;
        my $ni = $n;
        $n =~ s/(.*)<// ||
        $n =~ s/>(.*)// and $ni = $1;
        $n && $ni or croak "Can't export '$e' - invalid name";
        my $tt = $typemap{$t} || croak "Can't export '$e' - unknown type '$t'";
        my $o;
        if ($tt eq 'METHOD') {
            $o = $epkg->can($n) || croak "Can't export uninherited METHOD $e from $epkg";
        } else {
            my $eg = $symtab->{$n}
                || croak "Can't export undefined $t$n from $epkg (no symbol+glob)";
            my $r = ref $eg;
            if ( $r eq 'SCALAR' ) {
                # Only reach here for "use constant" and Perl > v5.9.2, when
                # the symbol-table entry that would normally hold a glob
                # instead holds the scalar which is the optimized constant.
                # (See &constant::_CAN_PCS)
                $optimized_exportable{$ni} =
                $optimized_exportable{$n} = $eg;
                $m = " (constant)";
                # Sorry, this de-optimization will make things slow!!!
                my $const = $$eg;
                $o = sub () { $const };
            } else {
                $o = *$eg{$tt}
                    || croak "Can't export undefined $t$n from $epkg (no $tt within glob $eg)";
            }
        }
        $e = $t.$ni;
        $exportable{$t.$ni} =
        $exportable{$t.$n} = $o;
        warn "... $t$n exported (as $tt)$m\n" if $debug;
    }
    if ($debug) {
        warn sprintf "... exported from %-22s  %s\n", "$epkg:", join ", ", sort keys %exportable;
        warn sprintf "... exported constants from %-22s  %s\n", "$epkg:", join ", ", sort keys %optimized_exportable;

        if ($debug > 1) {
            use Data::Dumper;
            warn sprintf "*** exported: %s\n", Dumper(\%exportable);
            warn sprintf "*** exported constants: %s\n", Dumper(\%optimized_exportable);
        }
    }
    # Adjust %INC so that « require "Path/To/Package.pm"; » succeeds, and thus
    # « use Path::To::Package; » will call the import function created here.
    my $epath = $epkg;
        $epath =~ s#::$##;
        $epath =~ s#::#/#g;
        $epath .= '.pm';
    warn "Faking \$INC{$epath} = '$efile';\n" if $debug;
    $INC{$epath} ||= $efile;
    }

    # Create an import method for the target package
    my $im = sub {
        my $self = shift;
        my $pkg = caller;
        $epkg eq $self or croak "${epkg}::import seems to be linked to ${self}::import, which won't work";
        $epkg ne $pkg or croak "$pkg can't import from itself";
        warn "Importing from $epkg into $pkg (via export)\n" if $debug;
        for my $i (@_ ? @_ : @$exportable) {
            if ($i =~ /^#/) { carp "Ignoring export comment $i" if $debug; next }

            my $n = $i;
            my $t = '&';
            $n =~ s/^\W+// and $t = $&;
            my $ni = $n;
            $n =~ s/(.*)<// ||
            $n =~ s/>(.*)// and $ni = $1;

            my $o = $exportable{"$t$n"} or do {
                my $as = $n eq $ni ? '' : " as $t$ni";
                croak "Can't import $t$n$as into $pkg (not exported by $epkg)";
            };

            if ( $t eq '&' || $t eq '=' and my $eg = $optimized_exportable{$n} ) {
                my $pkg_ref = do { no strict 'refs'; \%{"${pkg}::"} };

                if (! exists $pkg_ref->{$ni}) {
                    $pkg_ref->{$ni} = $eg;
                    warn "... $t${epkg}::$n imported as $t${pkg}::$ni (optimized)\n" if $debug;
                    next;
                }
                if ('SCALAR' eq ref $pkg_ref->{$ni} && $pkg_ref->{$ni} == $eg) {
                    carp "... $t${epkg}::$n imported as $t${pkg}::$ni (optimized duplicate suppressed)\n" if $debug;
                    next;
                }
                warn "... $t${epkg}::$n importing as $t${pkg}::$ni (optimization failed)\n" if $debug;
                $t = '&';
            }
            {
                no strict 'refs';
                *{"${pkg}::$ni"} = $o;
            }
            warn "... $t${epkg}::$n imported as $t${pkg}::$ni\n" if $debug;
        }
    };
    warn "Creating ${epkg}::import\n" if $debug;
    { no strict 'refs'; *{"${epkg}::import"} = $im; };
}

1;
