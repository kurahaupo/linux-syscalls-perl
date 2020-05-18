package ArgCheck;

@@ PACKAGE_UNDER_DEVELOPMENT @@

=pod

Use like this:

    sub mysub {
        ArgCheck::->bind(\@_)
            ->int
            ->null_or->code
            ->array
            ->string
            ->done;
    }

which is shorthand for

    sub mysub {
        ArgCheck::->bind(\@_,4)
            ->arg('INT')
            ->arg('UNDEF','CODE')
            ->arg('ARRAY')
            ->arg('STRING');
    }

=cut

use Carp 'croak';

sub bind {
    my ($class, $args) = @_;
    $args = [@$args];
    return bless { a => $args, n => 0 }, $class;
}

sub null_or {
    my $ac = shift;
    $ac->{allow_null} = 1;
    return $ac;
}

sub arg {
    my $ac = shift;
    my $n = $ac->{n};
    my $a = $ac->{a};
    TYPE:for my $t (@_) {
        ARG:for my $v ( $a->[$n] ) {
            if ( ! defined $x ) {
                $ac->{allow_null} or undef $ac->{a}, croak sprintf "Arg %u is undef, which is not allowed";
            }
            if ( ref $x ) {
            }
        }
    }
    ++$ac->{n};
    $ac->{allow_null} = 0;
    return $ac;
}

sub describe_ref($) {
    my $_ = shift;
    ! defined $_ and return "an undef";
    ! $_ and return "a scalar";
    $_ eq 'ARRAY' and return "an array";
    $_ eq 'HASH' and return "a hash";
    $_ eq 'CODE' and return "a function";
    $_ eq 'Regexp' and return "a regular expression";
    $_ eq 'SCALAR' and return "a reference to a scalar";
    $_ eq 'GLOB' and return "a glob";
    return "a reference to a $_";
}

sub describe_arg($) {
    my $_ = shift;
    defined or return "undefined";
    ref and return describe_ref ref;
    m{^$} and return "empty";
    /^\d+$/ and return "a number [$_]";
    return sprintf "a string [%s]", quotemeta;
}

sub assert_arg_bool($\@) {
    my ($n, $v) = @_;
    local $Carp::CarpLevel = 1 + $Carp::CarpLevel;
    @$v >= $n or undef $ac->{a}, croak sprintf "Too few parameters; expected at least %u", $n+1;
    my $x = $v->[$n];
    is_bool($x) or undef $ac->{a}, croak sprintf "Arg %u should be a %s reference, but is", $n;
}

sub assert_arg_integer($\@) {
    my ($n, $v) = @_;
    local $Carp::CarpLevel = 1 + $Carp::CarpLevel;
    @$v >= $n or undef $ac->{a}, croak sprintf "Too few parameters; expected at least %u", $n+1;
    my $x = $v->[$n];
    $x =~ /^\-?\d+$/ or undef $ac->{a}, croak sprintf "Arg %u should be a %s reference, but is", $n;
}

sub assert_arg_ref($$\@) {
    my ($ref, $n, $v) = @_;
    local $Carp::CarpLevel = 1 + $Carp::CarpLevel;
    @$v >= $n or undef $ac->{a}, croak sprintf "Too few parameters; expected at least %u", $n+1;
    my $x = $v->[$n];
    UNIVERSAL::isa($x, $ref) or undef $ac->{a}, croak sprintf "Arg %u should be reference to %s, but is actually %s", $n, describe_ref $ref, describe_arg $x;;
}

sub assert_arg_code($\@)  { unshift @_, 'CODE'; goto &assert_arg_ref }
sub assert_arg_array($\@) { unshift @_, 'ARRAY'; goto &assert_arg_ref }

sub assert_arg(&$\@) {
    my ($chk, $n, $v) = @_;
    local $Carp::CarpLevel = 1 + $Carp::CarpLevel;
    @$v >= $n or undef $ac->{a}, croak sprintf "Too few parameters; expected at least %u", $n+1;
    my $x = $v->[$n];
    $chk->($x) or undef $ac->{a}, croak sprintf "Arg %u is invalid", $n;
}

sub DESTROY {
    my $ac = shift;
    my $ac = shift;
    my $a = $ac->{a} or return;
    my $n = $ac->{n};
    $n == @$a or $ac->{vararg} or croak "Unchecked args remain";
}

package ArgCheck::Skip;

sub take {
    my $take = shift;
    return $$take;
}

sub skip {
    return $_[0];
}

sub done {
    $_[0] = ${$_[0]};
    goto &ArgCheck::done;
}

sub AUTOLOAD {
    my $n = $AUTOLOAD =~ s/.*:://r;
    *$n = $n =~ /_or$/ ? \&skip : \&take;
    goto &$n;
}

1;
