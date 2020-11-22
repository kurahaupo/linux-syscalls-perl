#!/usr/bin/perl

use 5.018;
use strict;
use warnings;
use diagnostics;

use lib $ENV{HOME}.'/lib/perl';

use Linux::Syscalls qw( :proc waitid_ );
use Data::Dumper;
use Getopt::Long qw( :config auto_abbrev permute );

my $options;
my $with_siginfo;
my $with_rusage;

use constant {
    WM_IGNORE   => 0,
    WM_WAIT     => 1,
    WM_WAITPID  => 2,
    WM_WAIT3    => 3,
    WM_WAIT4    => 4,
    WM_WAITID   => 5,
    WM_WAITID5  => 6,
};

my $waitmode = WM_WAIT;

sub N($) { my $r = \$_[0]; return sub { $$r = ! $_[1] } }
sub O($) { my $v = $_[0]; return sub { if ($_[1]) { $options |= $v } else { $options &=~ $v } } }
GetOptions
  # 'wall'                => sub { $options = ~0 },
    'wdefault'            => sub { $options = 0 },
    'wnohang!'            => O WNOHANG,
    'wstopped|wuntraced!' => O WSTOPPED,
    'wexited!'            => O WEXITED,
    'wcontinued!'         => O WCONTINUED,
    'wnowait!'            => O WNOWAIT,
    'wnothread!'          => O WNOTHREAD,
    'wallchildren!'       => O WALLCHILDREN,
    'wclone!'             => O WCLONE,
    'with-siginfo!'       => \$with_siginfo,
    'with-rusage!'        => \$with_rusage,
    'without-siginfo!'    => N$with_siginfo,
    'without-rusage!'     => N$with_rusage,
    'wait'                => sub { $waitmode = WM_WAIT },
    'wait3'               => sub { $waitmode = WM_WAIT3 },
    'wait4'               => sub { $waitmode = WM_WAIT4 },
    'waitid'              => sub { $waitmode = WM_WAITID },
    'waitid5'             => sub { $waitmode = WM_WAITID5 },
    'waitpid'             => sub { $waitmode = WM_WAITPID },
    'wignore'             => sub { $waitmode = WM_IGNORE },
    or exit 64;

$with_siginfo   //= 1;
$with_rusage    //= 1;

my $cpid = fork;

defined $cpid or die "Can't fork; $!\n";

if ($cpid) {
    warn "Waiting for $cpid\n";
    my @r;
    my $ex;
    if      ($waitmode == WM_IGNORE) {
    } elsif ($waitmode == WM_WAIT) {
        my $r = wait;
        if ($r < 0) {
            @r = ();
        } else {
            @r = ($r, $ex = $?);
        }
    } elsif ($waitmode == WM_WAITPID) {
        my $r = waitpid($cpid, $options);
        if ($r < 0) {
            @r = ();
        } else {
            @r = ($r, $ex = $?);
        }
    } elsif ($waitmode == WM_WAIT3) {
        my $r = wait3(\$ex, $options, $with_rusage);
        if ($r < 0) {
            @r = ();
        } else {
            @r = ($r, $ex);
        }
    } elsif ($waitmode == WM_WAIT4) {
        my $r = wait4($cpid, \$ex, $options, $with_rusage);
        if ($r < 0) {
            @r = ();
        } else {
            @r = ($r, $ex);
        }
    } elsif ($waitmode == WM_WAITID) {
        @r = waitid P_PID, $cpid, $options;
    } elsif ($waitmode == WM_WAITID5) {
        @r = waitid5 P_PID, $cpid, $options;
    } else {
        @r = waitid_ P_PID, $cpid, $options, $with_siginfo, $with_rusage;
    }

    #my $options = WNOHANG|WUNTRACED|WCONTINUED;
    #$options = 0;
    @r or die "Couldn't wait for $cpid; $!\n";
    warn "Results:\n".Dumper(\@r);

} else {
    sleep 1;
    Exit int(0x1234567);
    die "exit failed; $!\n";
}
