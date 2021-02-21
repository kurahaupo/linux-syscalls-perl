#!/usr/bin/perl

use 5.018;
use strict;
use warnings;

use lib $ENV{HOME}.'/lib/perl';

use Linux::Syscalls qw( :proc waitid_ );
use Data::Dumper;
use Getopt::Long qw( :config auto_abbrev permute );

my $options;
my $with_siginfo;
my $with_rusage;
my $all_modes = 0;

use constant {
    WM_ALL      => -1,
    WM_NONE     => 0,
    WM_WAITPID2 => 2,
    WM_WAIT3    => 3,
    WM_WAIT4    => 4,
    WM_WAITID   => 5,
    WM_WAITID5  => 6,
    WM_WAITIDX  => 7,
    WM_WAIT_BUILTIN     => 8,
    WM_WAITPID_BUILTIN  => 9,

    WM_first    => 2,
    WM_last     => 9,
};

my $waitmode = WM_WAIT_BUILTIN;

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
    'wait-builtin'        => sub { $waitmode = WM_WAIT_BUILTIN },
    'waitpid-builtin'     => sub { $waitmode = WM_WAITPID_BUILTIN },
    'wait3'               => sub { $waitmode = WM_WAIT3 },
    'wait4'               => sub { $waitmode = WM_WAIT4 },
    'waitid'              => sub { $waitmode = WM_WAITID },
    'waitid5'             => sub { $waitmode = WM_WAITID5 },
    'waitidx'             => sub { $waitmode = WM_WAITIDX },
    'waitpid2'            => sub { $waitmode = WM_WAITPID2 },
    'none'                => sub { $waitmode = WM_NONE },
    'all'                 => sub { $waitmode = WM_ALL },
    or exit 64;

$with_siginfo   //= 1;
$with_rusage    //= 1;

use constant {
    WU_none         => 0,
    WU_pid_stat     => 1,
    WU_siginfo      => 2,
    WU_rusage       => 4,
};

sub one($) {
    my $waitmode = $_[0];

    my $cpid = fork;

    defined $cpid or die "Can't fork; $!\n";

    if ($cpid) {
        my $unpack_mode = WU_none;

        warn "Waiting for $cpid\n";
        my @r = 'NOSYS';
        $! = 38; #ENOSYS;
        if      ($waitmode == WM_NONE) {
            @r = 'NOWAIT';
            $! = 0;
        } elsif ($waitmode == WM_WAIT_BUILTIN) {
            my $r = wait;
            if ($r < 0) {
                @r = ();
            } else {
                @r = ($r, $?);
                $unpack_mode = WU_pid_stat;
            }
        } elsif ($waitmode == WM_WAITPID_BUILTIN) {
            $options //= 0;
            my $r = waitpid $cpid, $options;
            if ($r < 0) {
                @r = ();
            } else {
                @r = ($r, $?);
                $unpack_mode = WU_pid_stat;
            }
        } elsif ($waitmode == WM_WAITPID2) {
            $options //= 0;
            @r = waitpid2($cpid, $options) if exists &waitpid2;
            $unpack_mode = WU_pid_stat;
        } elsif ($waitmode == WM_WAIT3) {
            $options //= 0;
            @r = wait3($options) if exists &wait3;
            $unpack_mode = WU_pid_stat | WU_rusage;
        } elsif ($waitmode == WM_WAIT4) {
            $options //= 0;
            @r = wait4($cpid, $options) if exists &wait4;
            $unpack_mode = WU_pid_stat | WU_rusage;
        } elsif ($waitmode == WM_WAITID) {
            $options //= WEXITED;
            @r = waitid P_PID, $cpid, $options;
            $unpack_mode = WU_siginfo | WU_rusage;
        } elsif ($waitmode == WM_WAITID5) {
            $options //= WEXITED;
            @r = waitid5 P_PID, $cpid, $options;
            $unpack_mode = WU_siginfo | WU_rusage;
        } elsif ($waitmode == WM_WAITIDX) {
            $options //= WEXITED;
            @r = waitid_ P_PID, $cpid, $options, $with_rusage, $with_siginfo;
            $unpack_mode = WU_siginfo | WU_rusage;
        } else {
            die "Can't happen: waitmode=$waitmode";
        }

        @r or die "Couldn't wait for $cpid using wm=$waitmode; $!\n";

        my ( $rpid, $status )
            = splice @r, 0, 2
            if $unpack_mode & WU_pid_stat;
        my ( $si_pid, $si_uid, $si_signo, $si_status, $si_code )
            = splice @r, 0, 5
            if $unpack_mode & WU_siginfo;
        my ( $ru_utime, $ru_stime, $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
             $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
             $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw )
            = splice @r, 0, 16
            if $unpack_mode & WU_rusage;

        #my $options = WNOHANG|WUNTRACED|WCONTINUED;
        #$options = 0;
        warn "Results:\n".Dumper(\@r);
        warn sprintf "\trpid=%d, status=%#x\n", $rpid, $status;
        warn sprintf "\tsiginfo: si_pid=%d, si_uid=%d, si_signo=%d, si_status=%d, si_code=%d\n",
                    $si_pid, $si_uid, $si_signo, $si_status, $si_code
            if defined $si_pid;
        warn sprintf  "\trusage: utime=%.9f, stime=%.9f\n"
                     ."\t\tru_maxrss=%d, ru_ixrss=%d, ru_idrss=%d, ru_isrss=%d,\n"
                     ."\t\tru_minflt=%d, ru_majflt=%d, ru_nswap=%d, ru_inblock=%d, ru_oublock=%d,\n"
                     ."\t\tru_msgsnd=%d, ru_msgrcv=%d, ru_nsignals=%d, ru_nvcsw=%d, ru_nivcsw=%d,\n",
                    $ru_utime, $ru_stime,
                    $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
                    $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
                    $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw,
          if defined $ru_utime;

    } else {
        sleep 1;
        Exit int(0x1234567);
        die "exit failed; $!\n";
    }
}

if ($waitmode == WM_ALL) {
    my $errors = 0;
    eval { one $_; 1 } or ++$errors for WM_first .. WM_last;
    0;
    1 if $errors == 0;
} else {
    one $waitmode;
    1;
}
