#!/module/for/perl

use 5.008;
use strict;

my $debug = 0;

package ro;
use Symbol;

sub _ro_scalar($) {
    my ($what) = @_;
    my $v = _ro $$what;
    tie my $R, ro::const::SCALAR::, \$v;
    return \$R;
}

sub _ro_array($) {
    my ($what) = @_;
    my @v = map { _ro $_ } @$what;
    tie my @R, ro::const::ARRAY::, \@v;
    return \@R;
}

sub _ro_hash($) {
    my ($what) = @_;
    my %v = %$what;
    $_ = _ro $_ for values %v;
    @v{ keys %$what } = map { _ro $_ } values %$what;
    tie my %R, ro::const::HASH::, \%v;
    return \%R;
}

sub _ro_io_handle($) {
    my ($what) = @_;
    my $sym = *$what{IO};
    tie *$sym, ro::const::IO::, $sym;
    return $sym;
}

sub _ro_glob($) {
    my ($what) = @_;
    my $sym = gensym;
    *$sym = *$what;
    *$sym = _ro_scalar    *$sym{SCALAR};
    *$sym = _ro_array     *$sym{ARRAY};
    *$sym = _ro_hash      *$sym{HASH};
    *$sym = _ro_io_handle *$sym{IO};
  # tie *$sym, ro::const::GLOB::, $sym;
    return $sym;
}

sub _ro($);
sub _ro($) {
    my ($what) = @_;
    if ( my $ref = ref $what ) {

        if ( ! UNIVERSAL::isa($what, ro::const::) ) {

            if ( UNIVERSAL::isa($what, 'GLOB') ) {
                $what = _ro_glob $what;
                undef $ref if $ref eq 'GLOB';
            }
            elsif ( UNIVERSAL::isa($what, 'SCALAR') || UNIVERSAL::isa($what, 'REF') ) {
                $what = _ro_scalar
                undef $ref if $ref eq 'SCALAR' || $ref eq 'REF';
            }
            elsif ( UNIVERSAL::isa($what, 'ARRAY') ) {
                $what = _ro_array $what;
                undef $ref if $ref eq 'ARRAY';
            }
            elsif ( UNIVERSAL::isa($what, 'HASH') ) {
                $what = _ro_hash $what;
                undef $ref if $ref eq 'HASH';
            }
            else {
                return $what;
            }
            bless $what, $ref if $ref;
        }
    }
    return $what;
}


sub import {
    my ($pkg) = caller;
    no strict 'refs';
    *{$pkg.'::ro'} = \&_ro;
    shift if UNIVERSAL::isa($_[0], __PACKAGE__);
    for my $s (@_) {
        my $r = $s;
        if ( ! ref $r && $r =~ s/^[*%@\$]// ) {
            my $t = $&;
            $r = "${pkg}::$r" if $r !~ /::/;
            $r = eval "\\$t$r";
        }
        _ro $r;
    }
}

################################################################################

package ro::const;

use Carp ('croak', 'cluck');

sub UNTIE     { cluck "UNTIE(@_)\n" if $debug; }
sub DESTROY   { cluck "DESTROY(@_)\n" if $debug; }
sub AUTOLOAD  { (my $a = our $AUTOLOAD) =~ s/.*:://; croak "can't $a (autoloaded) because value ($_[-1]) is read-only"; }

sub STORE     { croak "can't STORE because value ($_[-1]) is read-only" }
sub CLEAR     { croak "can't CLEAR because value ($_[-1]) is read-only" }
sub STORESIZE { croak "can't STORESIZE because value ($_[-1]) is read-only" }
sub EXTEND    { croak "can't EXTEND because value ($_[-1]) is read-only" }
sub DELETE    { croak "can't DELETE because value ($_[-1]) is read-only" }
sub PUSH      { croak "can't PUSH because value ($_[-1]) is read-only" }
sub POP       { croak "can't POP because value ($_[-1]) is read-only" }
sub SHIFT     { croak "can't SHIFT because value ($_[-1]) is read-only" }
sub UNSHIFT   { croak "can't UNSHIFT because value ($_[-1]) is read-only" }
sub SPLICE    { croak "can't SPLICE because value ($_[-1]) is read-only" }

################################################################################

package ro::const::SCALAR;
our @ISA = qw( ro::const SCALAR );
use Carp 'cluck';

sub TIESCALAR {
    cluck "TIESCALAR(@_)\n" if $debug;
    my ($package, $obj) = @_;
    return bless $obj
}

sub FETCH {
    cluck "FETCH(@_)\n" if $debug;
    my ($v) = @_;
    return $$v;
}

################################################################################

package ro::const::ARRAY;
our @ISA = qw( ro::const ARRAY );
use Carp 'cluck';

sub TIEARRAY {
    cluck "TIEARRAY(@_)\n" if $debug;
    my ($package, $obj) = @_;
    return bless $obj
}

sub FETCH {
    cluck "FETCH(@_)\n" if $debug;
    my ($v,$i) = @_;
    return $v->[$i];
}

sub EXISTS {
    cluck "EXISTS(@_)\n" if $debug;
    my ($v,$i) = @_;
    return exists $v->[$i];
}

sub FETCHSIZE{
    cluck "FETCHSIZE(@_)\n" if $debug;
    my ($v) = @_;
    return scalar @$v;
}

################################################################################

package ro::const::HASH;
our @ISA = qw( ro::const HASH );
use Carp 'cluck';

sub TIEHASH {
    cluck "TIEHASH(@_)\n" if $debug;
    my ($package, $obj) = @_;
    return bless $obj
}

sub FETCH {
    cluck "FETCH(@_)\n" if $debug;
    my ($v,$k) = @_;
    return $v->{$k};
}

sub EXISTS {
    cluck "EXISTS(@_)\n" if $debug;
    my ($v,$k) = @_;
    return exists $v->{$k};
}

sub FIRSTKEY {
    cluck "FIRSTKEY(@_)\n" if $debug;
    my ($v) = @_;
    scalar keys %$v;
    return each %$v;
}

sub NEXTKEY {
    cluck "NEXTKEY(@_)\n" if $debug;
    my ($v) = @_;
    return each %$v;
}

sub SCALAR {
    cluck "SCALAR(@_)\n" if $debug;
    my ($v) = @_;
    return scalar %$v;
}

################################################################################

package ro::const::IO;
our @ISA = qw( ro::const IO::Handle );
use Carp 'cluck';

sub TIESCALAR {
    cluck "TIESCALAR(@_)\n" if $debug;
    my ($package, $obj) = @_;
    return bless $obj
}

sub WRITE {
    cluck "WRITE(@_)\n" if $debug;
    cluck "read-only file handle should not be written to\n";
    my ($v, @buf, $len, $offset) = @_;
    return syswrite $$v, $buf, $len, $offset;
}

sub PRINT {
    cluck "PRINT(@_)\n" if $debug;
    cluck "read-only file handle should not be written to\n";
    my ($v, @args) = @_;
    return print $v @$args;
}

sub PRINTF {
    cluck "PRINT(@_)\n" if $debug;
    cluck "read-only file handle should not be written to\n";
    my ($v, @args) = @_;
    return printf $v @$args;
}

sub READ {
    cluck "READ(@_)\n" if $debug;
    my ($v, @buf, $len, $offset) = @_;
    return sysread $$v, $buf, $len, $offset;
}

sub READLINE {
    cluck "READLINE(@_)\n" if $debug;
    my ($v, @buf, $len, $offset) = @_;
    return readline $$v, $buf, $len, $offset;
}

sub GETC {
    cluck "GETC(@_)\n" if $debug;
    my ($v, @buf, $len, $offset) = @_;
    die;
    return getc $$v, $buf, $len, $offset;
}

sub EOF {
    cluck "EOF(@_)\n" if $debug;
    my ($v, $context) = @_;
    return eof $$v;
}

sub CLOSE {
    cluck "CLOSE(@_)\n" if $debug;
    my ($v) = @_;
    return close $$v;
}

1;
