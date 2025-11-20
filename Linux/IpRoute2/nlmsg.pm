#!/module/for/perl

use v5.10;
use strict;
use warnings;
use integer;

use Data::Dumper;
use Linux::IpRoute2::response;

package Linux::IpRoute2::nlmsg;

use Carp qw( croak );
use Linux::IpRoute2::rtnetlink qw( :nlm_types );

package Linux::IpRoute2::nlmsg::_base {
    use parent 'Linux::IpRoute2::message::_base';
    use constant type => 0;
}

package Linux::IpRoute2::nlmsg::noop        { use parent -norequire => 'Linux::IpRoute2::nlmsg::_base'; use constant code => Linux::IpRoute2::rtnetlink::NLMSG_NOOP;    }
package Linux::IpRoute2::nlmsg::error       { use parent -norequire => 'Linux::IpRoute2::nlmsg::_base'; use constant code => Linux::IpRoute2::rtnetlink::NLMSG_ERROR;   }
package Linux::IpRoute2::nlmsg::done        { use parent -norequire => 'Linux::IpRoute2::nlmsg::_base'; use constant code => Linux::IpRoute2::rtnetlink::NLMSG_DONE;    }
package Linux::IpRoute2::nlmsg::overrun     { use parent -norequire => 'Linux::IpRoute2::nlmsg::_base'; use constant code => Linux::IpRoute2::rtnetlink::NLMSG_OVERRUN; }

my @nlmsg_code_to_class = (
    undef,
    Linux::IpRoute2::nlmsg::noop::,
    Linux::IpRoute2::nlmsg::error::,
    Linux::IpRoute2::nlmsg::done::,
    Linux::IpRoute2::nlmsg::overrun::,
);

sub _nlmsg_code_to_class {
    my ($msg_code) = @_;
    my $msg_class = $msg_code >= 0 ? $nlmsg_code_to_class[$msg_code] : ();
    $msg_class
        or croak sprintf "Missing class for type=%s\n\tdump-map=%s", $msg_code,
            Data::Dumper::->new([\@nlmsg_code_to_class],
                                [qw[map]])->Indent(0)->Useqq(1)->Dump;
    return $msg_class;
}

package Linux::IpRoute2::nlmsg::error {
    sub unpack_msg_self {
        my ($self, $packed_msg) = @_;
        $self->{errno}  = unpack 'L', $packed_msg;
        $self->{msg}    = Linux::IpRoute2::response::->unpack_new_msg(substr $packed_msg, 4)
            if length($packed_msg) > 4;
        ()
    }
}

1;
