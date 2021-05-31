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

my @wm_name = (
    'none',
    'WM1',
    'waitpid2',
    'wait3',
    'wait4',
    'waitid',
    'waitid5',
    'waitidx',
    'wait_builtin',
    'waitpid_builtin',
);

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

    if (!$cpid) {
        # Created as a dummy child
        sleep 0.125;
        Exit 0x1234567;
        die "Exit failed; $!\n";
    }

    my $unpack_mode = WU_none;

    warn "Waiting for $cpid using $waitmode $wm_name[$waitmode]\n";
    my @r;
    if      ($waitmode == WM_NONE) {
        @r = (undef, 'running in NOWAIT mode');
        $! = 0;
    } elsif ($waitmode == WM_WAIT_BUILTIN) {
        my $r = CORE::wait;
        if ($r < 0) {
            #@r = (undef, $!);
        } else {
            @r = ($r, $?);
            $unpack_mode = WU_pid_stat;
        }
    } elsif ($waitmode == WM_WAITPID_BUILTIN) {
        my $r = CORE::waitpid $cpid, $options // 0;
        if ($r < 0) {
            #@r = (undef, $!);
        } else {
            @r = ($r, $?);
            $unpack_mode = WU_pid_stat;
        }
    } elsif ($waitmode == WM_WAITPID2 && exists &waitpid2) {
        @r = waitpid2($cpid, $options // 0);
        $unpack_mode = WU_pid_stat;
    } elsif ($waitmode == WM_WAIT3 && exists &wait3) {
        @r = wait3($options // 0);
        $unpack_mode = WU_pid_stat | WU_rusage;
    } elsif ($waitmode == WM_WAIT4 && exists &wait4) {
        @r = wait4($cpid, $options // 0);
        $unpack_mode = WU_pid_stat | WU_rusage;
    } elsif ($waitmode == WM_WAITID) {
        @r = waitid P_PID, $cpid, $options // WEXITED;
        $unpack_mode = WU_siginfo | WU_rusage;
    } elsif ($waitmode == WM_WAITID5) {
        @r = waitid5 P_PID, $cpid, $options // WEXITED;
        $unpack_mode = WU_siginfo | WU_rusage;
    } elsif ($waitmode == WM_WAITIDX) {
        @r = waitid_ P_PID, $cpid, $options // WEXITED, $with_rusage, $with_siginfo;
        $unpack_mode = WU_siginfo | WU_rusage;
    } else {
        warn "Unimplemented syscall $wm_name[$waitmode]\n";
        @r = (undef, 'syscall not implemented');
        $! = 38; #ENOSYS;
        return 1;
    }

    @r or die "Couldn't wait for $cpid using wm=$waitmode $wm_name[$waitmode]; $!\n";

    my ( $rpid, $status )
        = splice @r, 0, 2
        if $unpack_mode & WU_pid_stat;
    my ( $si_status, $si_code, $si_pid, $si_uid, $si_signo )
        = splice @r, 0, 5
        if $unpack_mode & WU_siginfo;
    my ( $ru_utime, $ru_stime, $ru_maxrss, $ru_ixrss, $ru_idrss, $ru_isrss,
         $ru_minflt, $ru_majflt, $ru_nswap, $ru_inblock, $ru_oublock,
         $ru_msgsnd, $ru_msgrcv, $ru_nsignals, $ru_nvcsw, $ru_nivcsw )
        = splice @r, 0, 16
        if $unpack_mode & WU_rusage;

    warn "Results:\n".join(', ', @r);
    if (defined $rpid) {
        warn sprintf "\trpid=%d, status=%#x\n", $rpid, $status;
    } elsif (defined $status) {
        warn sprintf "\tpid=none, errno=%s\n", $status;
    }
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

    1;
}

sub all {
    my $errors = 0;
    eval { one $_; 1 } or do { ++$errors; warn $@ } for WM_first .. WM_last;
    warn "\n$errors errors\n";
    $errors == 0;
}

if ($waitmode == WM_ALL) {
    all;
} else {
    one $waitmode;
}
