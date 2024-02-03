#! /module/for/perl

use strict;
use warnings;

package Linux::Syscalls::x86_32;

use Config;
use Exporter 'import';

use Linux::Syscalls::x86_64;

#
# This file supports x86_64 in 32-bit mode.
#
# This is untested because I've yet to find a version of Perl compiled with
# '-mx32'. If you have one, please let me know.
#
# Alternative names are available for some syscalls:
#   fadvise                 ← fadvise64
#   fstatat                 ← newfstatat
#   getdents                ← getdents64
#   prlimit                 ← prlimit64
#

# On x86 platforms, the choice of architecture is given by this logic (in
# /usr/include/x86_64-linux-gnu/asm/unistd.h):
#   ifdef __i386__
#    include <asm/unistd_32.h>   /* ia32 */
#   elif defined(__ILP32__)
#    include <asm/unistd_x32.h>  /* x86_32 */
#   else
#    include <asm/unistd_64.h>   /* x86_64 */
#   endif

use constant { _X32_SYSCALL_BIT => 0x40000000 };    # 1 << 30


$pack_map{time_t}   = 'l' ;     # seconds
$pack_map{timespec} = 'lL';     # seconds, nanoseconds
$pack_map{timeval}  = 'lL';     # seconds, microseconds


# Perl compiled as 32-bit (but for x86_64 architecture)

# FROM /usr/include/x86_64-linux-gnu/asm/unistd_x32.h
use constant { _B9 => 0x200 };          # 1 << 9

$syscall_map{rt_sigaction}      =  0 | _B9; # replaces x86_64 call #13
$syscall_map{rt_sigreturn}      =  1 | _B9; # replaces x86_64 call #15
$syscall_map{ioctl}             =  2 | _B9; # replaces x86_64 call #16
$syscall_map{readv}             =  3 | _B9; # replaces x86_64 call #19
$syscall_map{writev}            =  4 | _B9; # replaces x86_64 call #20
$syscall_map{recvfrom}          =  5 | _B9; # replaces x86_64 call #45
$syscall_map{sendmsg}           =  6 | _B9; # replaces x86_64 call #46
$syscall_map{recvmsg}           =  7 | _B9; # replaces x86_64 call #47
$syscall_map{execve}            =  8 | _B9; # replaces x86_64 call #59
$syscall_map{ptrace}            =  9 | _B9; # replaces x86_64 call #101
$syscall_map{rt_sigpending}     = 10 | _B9; # replaces x86_64 call #127
$syscall_map{rt_sigtimedwait}   = 11 | _B9; # replaces x86_64 call #128
$syscall_map{rt_sigqueueinfo}   = 12 | _B9; # replaces x86_64 call #129
$syscall_map{sigaltstack}       = 13 | _B9; # replaces x86_64 call #131
$syscall_map{timer_create}      = 14 | _B9; # replaces x86_64 call #222
$syscall_map{mq_notify}         = 15 | _B9; # replaces x86_64 call #244
$syscall_map{kexec_load}        = 16 | _B9; # replaces x86_64 call #246
$syscall_map{waitid}            = 17 | _B9; # replaces x86_64 call #247
$syscall_map{set_robust_list}   = 18 | _B9; # replaces x86_64 call #273
$syscall_map{get_robust_list}   = 19 | _B9; # replaces x86_64 call #274
$syscall_map{vmsplice}          = 20 | _B9; # replaces x86_64 call #278
$syscall_map{move_pages}        = 21 | _B9; # replaces x86_64 call #279
$syscall_map{preadv}            = 22 | _B9; # replaces x86_64 call #295
$syscall_map{pwritev}           = 23 | _B9; # replaces x86_64 call #296
$syscall_map{rt_tgsigqueueinfo} = 24 | _B9; # replaces x86_64 call #297
$syscall_map{recvmmsg}          = 25 | _B9; # replaces x86_64 call #299
$syscall_map{sendmmsg}          = 26 | _B9; # replaces x86_64 call #307
$syscall_map{process_vm_readv}  = 27 | _B9; # replaces x86_64 call #310
$syscall_map{process_vm_writev} = 28 | _B9; # replaces x86_64 call #311
$syscall_map{setsockopt}        = 29 | _B9; # replaces x86_64 call #54
$syscall_map{getsockopt}        = 30 | _B9; # replaces x86_64 call #55
$syscall_map{io_setup}          = 31 | _B9; # replaces x86_64 call #206
$syscall_map{io_submit}         = 32 | _B9; # replaces x86_64 call #209
$syscall_map{execveat}          = 33 | _B9; # replaces x86_64 call #322
$syscall_map{preadv2}           = 34 | _B9; # replaces x86_64 call #327
$syscall_map{pwritev2}          = 35 | _B9; # replaces x86_64 call #328

# Only x86_64 - no _32 equivalent
delete $syscall_map{uselib};
delete $syscall_map{_sysctl};
delete $syscall_map{create_module};
delete $syscall_map{get_kernel_syms};
delete $syscall_map{query_module};
delete $syscall_map{nfsservctl};
delete $syscall_map{set_thread_area};
delete $syscall_map{get_thread_area};
delete $syscall_map{epoll_ctl_old};
delete $syscall_map{epoll_wait_old};
delete $syscall_map{vserver};

$_ |= _X32_SYSCALL_BIT for values %syscall_map;

$pack_map{time_t}   = 'l' ;     # seconds
$pack_map{timespec} = 'lL';     # seconds, nanoseconds
$pack_map{timeval}  = 'lL';     # seconds, microseconds

our @EXPORT = qw(
    %pack_map
    %syscall_map
);

our %EXPORT_TAGS;
$EXPORT_TAGS{everything} = \@EXPORT;

1;
