#! /module/for/perl

use strict;
use warnings;

package Linux::Syscalls::mips;

# Constants for the MIPS o32 architecture.

use Exporter 'import';

use Config;

our $have_MMU = 1;
our $m32 = ! $Config{use64bitint};
our $use_32bit_off_t = 0;
our $use_arch_want_sync_file_range2 = 0;
our $use_arch_want_syscall_deprecated = 0;
our $use_arch_want_syscall_no_at = 0;
our $use_arch_want_syscall_no_flags = 0;
our $use_arch_want_time32_syscalls = 0;
our $use_syscall_compat = 0;

# The numbers for MIPS o32 start out the same as ia32, offset by 4000, but the insertion
# of 4 calls at 4147 [cacheflush (4147), cachectl (4148), sysmips (4149), and
# 4150 (unused)], so that from getsid onwards the offset becomes 4004
# (147→4151).

# As with the other OS-dependent files, numeric suffices are added or removed
# so that the bare names have the nearest semantics to x86_64 (32-bit UID, GID,
# & PID, and 64-bit everything else).

our %syscall_map = (

        # FROM https://syscalls.w3challs.com/?arch=mips_o32

        exit                    => 4001,  #   int error_code        # kernel/exit.c:1095
        fork                    => 4002,  #   -        # arch/mips/kernel/syscall.c:93
        read                    => 4003,  #   uint fd,void *buf,size_t bytecount        # fs/read_write.c:460
        write                   => 4004,  #   uint fd,void *buf,size_t bytecount        # fs/read_write.c:477
        open                    => 4005,  #   char const *filename,int flags,umode_t umode        # fs/open.c:1046
        close                   => 4006,  #   int fd        # fs/open.c:1117
        waitpid                 => 4007,  #   pid_t pid,int *stat_addr,int options        # kernel/exit.c:1879
        creat                   => 4008,  #   const char *pathname,umode_t mode        # fs/open.c:1079
        link                    => 4009,  #   const char *oldname,const char *newname        # fs/namei.c:3152
        unlink                  => 4010,  #   const char *pathname        # fs/namei.c:2979
        execve                  => 4011,  #   prog,argc,envp        # arch/mips/kernel/syscall.c:133
        chdir                   => 4012,  #   const char *filename        # fs/open.c:375
        time                    => 4013,  #   time_t *tloc        # kernel/time.c:62
        mknod                   => 4014,  #  const char *filename,umode_t mode,unsigned dev        # fs/namei.c:2693
        chmod                   => 4015,  #  const char *filename,umode_t mode        # fs/open.c:499
        lchown                  => 4016,  #  const char *filename,uid_t user,gid_t group        # fs/open.c:586
        break                   => 4017,  #  -        # Not implemented
#       unused18                => 4018,  #  -        # Not implemented
        lseek                   => 4019,  #  unsigned int fd,off_t offset,unsigned int origin        # fs/read_write.c:230
        getpid                  => 4020,  #  -        # kernel/timer.c:1413
        mount                   => 4021,  #  char *dev_name,char *dir_name,char *type,unsigned long flags,void *data        # fs/namespace.c:2362
        umount                  => 4022,  #  char *name,int flags        # fs/namespace.c:1190
        setuid                  => 4023,  #  uid_t uid        # kernel/sys.c:761
        getuid                  => 4024,  #  -        # kernel/timer.c:1435
        stime                   => 4025,  #  time_t *tptr        # kernel/time.c:81
        ptrace                  => 4026,  #  long request,long pid,unsigned long addr,unsigned long data        # kernel/ptrace.c:857
        alarm                   => 4027,  #  unsigned int seconds        # kernel/timer.c:1390
#       unused28                => 4028,  #  -        # Not implemented
        pause                   => 4029,  #  -        # kernel/signal.c:3245
        utime                   => 4030,  #  char *filename,struct utimbuf *times        # fs/utimes.c:27
        stty                    => 4031,  #  -        # Not implemented
        gtty                    => 4032,  #  -        # Not implemented
        access                  => 4033,  #  const char *filename,int mode        # fs/open.c:370
        nice                    => 4034,  #  int increment        # kernel/sched/core.c:4119
        ftime                   => 4035,  #  -        # Not implemented
        sync                    => 4036,  #  -        # fs/sync.c:98
        kill                    => 4037,  #  pid_t pid,int sig        # kernel/signal.c:2841
        rename                  => 4038,  #  const char *oldname,const char *newname        # fs/namei.c:3403
        mkdir                   => 4039,  #  const char *pathname,umode_t mode        # fs/namei.c:2751
        rmdir                   => 4040,  #  const char *pathname        # fs/namei.c:2870
        dup                     => 4041,  #  unsigned int fildes        # fs/fcntl.c:131
        pipe                    => 4042,  #  int *fildes        # fs/pipe.c:1149
        times                   => 4043,  #  struct tms *tbuf        # kernel/sys.c:1058
        prof                    => 4044,  #  -        # Not implemented
        brk                     => 4045,  #  unsigned long brk        # mm/mmap.c:246
        setgid                  => 4046,  #  gid_t gid        # kernel/sys.c:614
        getgid                  => 4047,  #  -        # kernel/timer.c:1447
        signal                  => 4048,  #  int sig,__sighandler_t handler        # kernel/signal.c:3228
        geteuid                 => 4049,  #  -        # kernel/timer.c:1441
        getegid                 => 4050,  #  -        # kernel/timer.c:1453
        acct                    => 4051,  #  const char *name        # kernel/acct.c:255
        umount2                 => 4052,  #  char *name,int flags        # fs/namespace.c:1190
        lock                    => 4053,  #  -        # Not implemented
        ioctl                   => 4054,  #  unsigned int fd,unsigned int cmd,unsigned long arg        # fs/ioctl.c:604
        fcntl32                 => 4055,  #  unsigned int fd,unsigned int cmd,unsigned long arg        # fs/fcntl.c:442
        mpx                     => 4056,  #  -        # Not implemented
        setpgid                 => 4057,  #  pid_t pid,pid_t pgid        # kernel/sys.c:1083
        ulimit                  => 4058,  #  -        # Not implemented
#       unused59                => 4059,  #  -        # Not implemented
        umask                   => 4060,  #  int mask        # kernel/sys.c:1782
        chroot                  => 4061,  #  const char *filename        # fs/open.c:422
        ustat                   => 4062,  #  unsigned dev,struct ustat *ubuf        # fs/statfs.c:222
        dup2                    => 4063,  #  unsigned int oldfd,unsigned int newfd        # fs/fcntl.c:116
        getppid                 => 4064,  #  -        # kernel/timer.c:1424
        getpgrp                 => 4065,  #  -        # kernel/sys.c:1184
        setsid                  => 4066,  #  -        # kernel/sys.c:1219
        sigaction               => 4067,  #  int sig,const struct sigaction *act,struct sigaction *oact        # arch/mips/kernel/signal.c:280
        sgetmask                => 4068,  #  -        # kernel/signal.c:3207
        ssetmask                => 4069,  #  int newmask        # kernel/signal.c:3213
        setreuid                => 4070,  #  uid_t ruid,uid_t euid        # kernel/sys.c:690
        setregid                => 4071,  #  gid_t rgid,gid_t egid        # kernel/sys.c:557
        sigsuspend              => 4072,  #  -        # arch/mips/kernel/signal.c:250
        sigpending              => 4073,  #  old_sigset_t *set        # kernel/signal.c:3107
        sethostname             => 4074,  #  char *name,int len        # kernel/sys.c:1365
        setrlimit               => 4075,  #  unsigned int resource,struct rlimit *rlim        # kernel/sys.c:1641
        getrlimit               => 4076,  #  unsigned int resource,struct rlimit *rlim        # kernel/sys.c:1440
        getrusage               => 4077,  #  int who,struct rusage *ru        # kernel/sys.c:1774
        gettimeofday            => 4078,  #  struct timeval *tv,struct timezone *tz        # kernel/time.c:101
        settimeofday            => 4079,  #  struct timeval *tv,struct timezone *tz        # kernel/time.c:179
        getgroups               => 4080,  #  int gidsetsize,gid_t *grouplist        # kernel/groups.c:202
        setgroups               => 4081,  #  int gidsetsize,gid_t *grouplist        # kernel/groups.c:231
        reserved82              => 4082,  #  -        # Not implemented
        symlink                 => 4083,  #  const char *oldname,const char *newname        # fs/namei.c:3039
#       unused84                => 4084,  #  -        # Not implemented
        readlink                => 4085,  #  const char *path,char *buf,int bufsiz        # fs/stat.c:321
        uselib                  => 4086,  #  const char *library        # fs/exec.c:116
        swapon                  => 4087,  #  const char *specialfile,int swap_flags        # mm/swapfile.c:1996
        reboot                  => 4088,  #  int magic1,int magic2,unsigned int cmd,void *arg        # kernel/sys.c:432
        readdir                 => 4089,  #  unsigned int fd,struct old_linux_dirent *dirent,unsigned int count        # fs/readdir.c:105
        mmap                    => 4090,  #  struct mmap_arg_struct *arg        # mm/mmap.c:1153
        munmap                  => 4091,  #  unsigned long addr,size_t len        # mm/mmap.c:2141
        truncate32              => 4092,  #  const char *path,long length        # fs/open.c:128
        ftruncate32             => 4093,  #  unsigned int fd,unsigned long length        # fs/open.c:178
        fchmod                  => 4094,  #  unsigned int fd,umode_t mode        # fs/open.c:472
        fchown                  => 4095,  #  unsigned int fd,uid_t user,gid_t group        # fs/open.c:605
        getpriority             => 4096,  #  int which,int who        # kernel/sys.c:241
        setpriority             => 4097,  #  int which,int who,int niceval        # kernel/sys.c:172
        profil                  => 4098,  #  -        # Not implemented
        statfs32                => 4099,  #  const char *pathname,struct statfs *buf        # fs/statfs.c:166
        fstatfs                 => 4100,  #  unsigned int fd,struct statfs *buf        # fs/statfs.c:187
        ioperm                  => 4101,  #  -        # Not implemented
        socketcall              => 4102,  #  int call,unsigned long *args        # net/socket.c:2355
        syslog                  => 4103,  #  int type,char *buf,int len        # kernel/printk.c:1195
        setitimer               => 4104,  #  int which,struct itimerval *value,struct itimerval *ovalue        # kernel/itimer.c:278
        getitimer               => 4105,  #  int which,struct itimerval *value        # kernel/itimer.c:103
        stat32                  => 4106,  #  const char *filename,struct __old_kernel_stat *statbuf        # fs/stat.c:155
        lstat32                 => 4107,  #  const char *filename,struct __old_kernel_stat *statbuf        # fs/stat.c:168
        fstat32                 => 4108,  #  unsigned int fd,struct __old_kernel_stat *statbuf        # fs/stat.c:181
#       unused109               => 4109,  #  -        # Not implemented
        iopl                    => 4110,  #  -        # Not implemented
        vhangup                 => 4111,  #  -        # fs/open.c:1156
        idle                    => 4112,  #  -        # Not implemented
        vm86                    => 4113,  #  -        # Not implemented
        wait4                   => 4114,  #  pid_t upid,int *stat_addr,int options,struct rusage *ru        # kernel/exit.c:1834
        swapoff                 => 4115,  #  const char *specialfile        # mm/swapfile.c:1539
        sysinfo                 => 4116,  #  struct sysinfo *info        # kernel/timer.c:1641
        ipc                     => 4117,  #  unsigned int call,int first,unsigned long second,unsigned long third,void *ptr,long fifth        # ipc/syscall.c:16
        fsync                   => 4118,  #  unsigned int fd        # fs/sync.c:201
        sigreturn               => 4119,  #  -        # arch/mips/kernel/signal.c:330
        clone                   => 4120,  #  -        # arch/mips/kernel/syscall.c:100
        setdomainname           => 4121,  #  char *name,int len        # kernel/sys.c:1416
        uname                   => 4122,  #  struct old_utsname *name        # kernel/sys.c:1311
        modify_ldt              => 4123,  #  -        # Not implemented
        adjtimex                => 4124,  #  struct timex *txc_p        # kernel/time.c:200
        mprotect                => 4125,  #  unsigned long start,size_t len,unsigned long prot        # mm/mprotect.c:232
        sigprocmask             => 4126,  #  int how,old_sigset_t *nset,old_sigset_t *oset        # kernel/signal.c:3125
        create_module           => 4127,  #  -        # Not implemented
        init_module             => 4128,  #  void *umod,unsigned long len,const char *uargs        # kernel/module.c:3010
        delete_module           => 4129,  #  const char *name_user,unsigned int flags        # kernel/module.c:768
        get_kernel_syms         => 4130,  #  -        # Not implemented
        quotactl                => 4131,  #  unsigned int cmd,const char *special,qid_t id,void *addr        # fs/quota/quota.c:346
        getpgid                 => 4132,  #  pid_t pid        # kernel/sys.c:1154
        fchdir                  => 4133,  #  unsigned int fd        # fs/open.c:396
        bdflush                 => 4134,  #  int func,long data        # fs/buffer.c:3130
        sysfs                   => 4135,  #  int option,unsigned long arg1,unsigned long arg2        # fs/filesystems.c:183
        personality             => 4136,  #  unsigned int personality        # kernel/exec_domain.c:182
        afs_syscall             => 4137,  #  -        # Not implemented
        setfsuid                => 4138,  #  uid_t uid        # kernel/sys.c:969
        setfsgid                => 4139,  #  gid_t gid        # kernel/sys.c:1008
        _llseek                 => 4140,  #  unsigned int fd,unsigned long offset_high,unsigned long offset_low,loff_t *result,unsigned int origin        # fs/read_write.c:254
        getdents32              => 4141,  #  unsigned int fd,struct linux_dirent *dirent,unsigned int count        # fs/readdir.c:191
        _newselect              => 4142,  #  int n,fd_set *inp,fd_set *outp,fd_set *exp,struct timeval *tvp        # fs/select.c:593
        flock                   => 4143,  #  unsigned int fd,unsigned int cmd        # fs/locks.c:1636
        msync                   => 4144,  #  unsigned long start,size_t len,int flags        # mm/msync.c:31
        readv                   => 4145,  #  unsigned long fd,const struct iovec *vec,unsigned long vlen        # fs/read_write.c:787
        writev                  => 4146,  #  unsigned long fd,const struct iovec *vec,unsigned long vlen        # fs/read_write.c:808
        cacheflush              => 4147,  #  unsigned long addr,unsigned long bytes,unsigned int cache        # arch/mips/mm/cache.c:67
        cachectl                => 4148,  #  char *addr,int nbytes,int op        # arch/mips/kernel/syscall.c:303
        sysmips                 => 4149,  #  -        # arch/mips/kernel/syscall.c:265
#       unused150               => 4150,  #  -        # Not implemented
        getsid                  => 4151,  #  pid_t pid        # kernel/sys.c:1191
        fdatasync               => 4152,  #  unsigned int fd        # fs/sync.c:206
        _sysctl                 => 4153,  #  struct __sysctl_args *args        # kernel/sysctl_binary.c:1444
        mlock                   => 4154,  #  unsigned long start,size_t len        # mm/mlock.c:482
        munlock                 => 4155,  #  unsigned long start,size_t len        # mm/mlock.c:512
        mlockall                => 4156,  #  int flags        # mm/mlock.c:549
        munlockall              => 4157,  #  -        # mm/mlock.c:582
        sched_setparam          => 4158,  #  pid_t pid,struct sched_param *param        # kernel/sched/core.c:4477
        sched_getparam          => 4159,  #  pid_t pid,struct sched_param *param        # kernel/sched/core.c:4512
        sched_setscheduler      => 4160,  #  pid_t pid,int policy,struct sched_param *param        # kernel/sched/core.c:4462
        sched_getscheduler      => 4161,  #  pid_t pid        # kernel/sched/core.c:4486
        sched_yield             => 4162,  #  -        # kernel/sched/core.c:4711
        sched_get_priority_max  => 4163,  #  int policy        # kernel/sched/core.c:4935
        sched_get_priority_min  => 4164,  #  int policy        # kernel/sched/core.c:4960
        sched_rr_get_interval   => 4165,  #  pid_t pid,struct timespec *interval        # kernel/sched/core.c:4985
        nanosleep               => 4166,  #  struct timespec *rqtp,struct timespec *rmtp        # kernel/hrtimer.c:1621
        mremap                  => 4167,  #  unsigned long addr,unsigned long old_len,unsigned long new_len,unsigned long flags,unsigned long new_addr        # mm/mremap.c:431
        accept                  => 4168,  #  int fd,struct sockaddr *upeer_sockaddr,int *upeer_addrlen        # net/socket.c:1582
        bind                    => 4169,  #  int fd,struct sockaddr *umyaddr,int addrlen        # net/socket.c:1446
        connect                 => 4170,  #  int fd,struct sockaddr *uservaddr,int addrlen        # net/socket.c:1600
        getpeername             => 4171,  #  int fd,struct sockaddr *usockaddr,int *usockaddr_len        # net/socket.c:1663
        getsockname             => 4172,  #  int fd,struct sockaddr *usockaddr,int *usockaddr_len        # net/socket.c:1632
        getsockopt              => 4173,  #  int fd,int level,int optname,char *optval,int *optlen        # net/socket.c:1844
        listen                  => 4174,  #  int fd,int backlog        # net/socket.c:1475
        recv                    => 4175,  #  int fd,void *ubuf,size_t size,unsigned int flags        # net/socket.c:1799
        recvfrom                => 4176,  #  int fd,void *ubuf,size_t size,unsigned int flags,struct sockaddr *addr,int *addr_len        # net/socket.c:1754
        recvmsg                 => 4177,  #  int fd,struct msghdr *msg,unsigned int flags        # net/socket.c:2189
        send                    => 4178,  #  int fd,void *buff,size_t len,unsigned int flags        # net/socket.c:1742
        sendmsg                 => 4179,  #  int fd,struct msghdr *msg,unsigned int flags        # net/socket.c:2016
        sendto                  => 4180,  #  int fd,void *buff,size_t len,unsigned int flags,struct sockaddr *addr,int addr_len        # net/socket.c:1695
        setsockopt              => 4181,  #  int fd,int level,int optname,char *optval,int optlen        # net/socket.c:1810
        shutdown                => 4182,  #  int fd,int how        # net/socket.c:1874
        socket                  => 4183,  #  int family,int type,int protocol        # net/socket.c:1324
        socketpair              => 4184,  #  int family,int type,int protocol,int *usockvec        # net/socket.c:1365
        setresuid               => 4185,  #  uid_t ruid,uid_t euid,uid_t suid        # kernel/sys.c:808
        getresuid               => 4186,  #  uid_t *ruidp,uid_t *euidp,uid_t *suidp        # kernel/sys.c:873
        query_module            => 4187,  #  -        # Not implemented
        poll                    => 4188,  #  struct pollfd *ufds,unsigned int nfds,int timeout_msecs        # fs/select.c:908
        nfsservctl              => 4189,  #  -        # Not implemented
        setresgid               => 4190,  #  gid_t rgid,gid_t egid,gid_t sgid        # kernel/sys.c:893
        getresgid               => 4191,  #  gid_t *rgidp,gid_t *egidp,gid_t *sgidp        # kernel/sys.c:945
        prctl                   => 4192,  #  int option,unsigned long arg2,unsigned long arg3,unsigned long arg4,unsigned long arg5        # kernel/sys.c:1999
        rt_sigreturn            => 4193,  #  -        # arch/mips/kernel/signal.c:365
        rt_sigaction            => 4194,  #  int sig,const struct sigaction *act,struct sigaction *oact,size_t sigsetsize        # kernel/signal.c:3174
        rt_sigprocmask          => 4195,  #  int how,sigset_t *nset,sigset_t *oset,size_t sigsetsize        # kernel/signal.c:2591
        rt_sigpending           => 4196,  #  sigset_t *set,size_t sigsetsize        # kernel/signal.c:2651
        rt_sigtimedwait         => 4197,  #  const sigset_t *uthese,siginfo_t *uinfo,const struct timespec *uts,size_t sigsetsize        # kernel/signal.c:2805
        rt_sigqueueinfo         => 4198,  #  pid_t pid,int sig,siginfo_t *uinfo        # kernel/signal.c:2938
        rt_sigsuspend           => 4199,  #  sigset_t *unewset,size_t sigsetsize        # kernel/signal.c:3274
        pread                   => 4200,    pread64                 => 4200,  #  char *buf size_t count,loff_t pos        # fs/read_write.c:495
        pwrite                  => 4201,    pwrite64                => 4201,  #  const char *buf size_t count,loff_t pos        # fs/read_write.c:524
        chown                   => 4202,  #  const char *filename,uid_t user,gid_t group        # fs/open.c:540
        getcwd                  => 4203,  #  char *buf,unsigned long size        # fs/dcache.c:2885
        capget                  => 4204,  #  cap_user_header_t header,cap_user_data_t dataptr        # kernel/capability.c:158
        capset                  => 4205,  #  cap_user_header_t header,const cap_user_data_t data        # kernel/capability.c:232
        sigaltstack             => 4206,  #  -        # arch/mips/kernel/signal.c:320
        sendfile32              => 4207,  #  int out_fd,int in_fd,off_t *offset,size_t count        # fs/read_write.c:973
        getpmsg                 => 4208,  #  -        # Not implemented
        putpmsg                 => 4209,  #  -        # Not implemented
        mmap2                   => 4210,  #  unsigned long addr,unsigned long len,unsigned long prot,unsigned long flags,unsigned long fd,unsigned long pgoff        # mm/mmap.c:1105
        truncate                => 4211,    truncate64              => 4211,  #  loff_t length        # fs/open.c:188
        ftruncate               => 4212,    ftruncate64             => 4212,  #  loff_t length        # fs/open.c:200
        stat                    => 4213,    stat64                  => 4213,  #  const char *filename,struct stat64 *statbuf        # fs/stat.c:372
        lstat                   => 4214,    lstat64                 => 4214,  #  const char *filename,struct stat64 *statbuf        # fs/stat.c:384
        fstat                   => 4215,    fstat64                 => 4215,  #  unsigned long fd,struct stat64 *statbuf        # fs/stat.c:396
        pivot_root              => 4216,  #  const char *new_root,const char *put_old        # fs/namespace.c:2453
        mincore                 => 4217,  #  unsigned long start,size_t len,unsigned char *vec        # mm/mincore.c:266
        madvise                 => 4218,  #  unsigned long start,size_t len_in,int behavior        # mm/madvise.c:362
        getdents                => 4219,    getdents64              => 4219,  #  unsigned int fd,struct linux_dirent64 *dirent,unsigned int count        # fs/readdir.c:272
        fcntl                   => 4220,    fcntl64                 => 4220,  #  unsigned int fd,unsigned int cmd,unsigned long arg        # fs/fcntl.c:468
        reserved221             => 4221,  #  -        # Not implemented
        gettid                  => 4222,  #  -        # kernel/timer.c:1569
        readahead               => 4223,  #  loff_t offset size_t count        # mm/readahead.c:579
        setxattr                => 4224,  #  const char *pathname,const char *name,const void *value,size_t size,int flags        # fs/xattr.c:361
        lsetxattr               => 4225,  #  const char *pathname,const char *name,const void *value,size_t size,int flags        # fs/xattr.c:380
        fsetxattr               => 4226,  #  int fd,const char *name,const void *value,size_t size,int flags        # fs/xattr.c:399
        getxattr                => 4227,  #  const char *pathname,const char *name,void *value,size_t size        # fs/xattr.c:459
        lgetxattr               => 4228,  #  const char *pathname,const char *name,void *value,size_t size        # fs/xattr.c:473
        fgetxattr               => 4229,  #  int fd,const char *name,void *value,size_t size        # fs/xattr.c:487
        listxattr               => 4230,  #  const char *pathname,char *list,size_t size        # fs/xattr.c:541
        llistxattr              => 4231,  #  const char *pathname,char *list,size_t size        # fs/xattr.c:555
        flistxattr              => 4232,  #  int fd,char *list,size_t size        # fs/xattr.c:569
        removexattr             => 4233,  #  const char *pathname,const char *name        # fs/xattr.c:602
        lremovexattr            => 4234,  #  const char *pathname,const char *name        # fs/xattr.c:620
        fremovexattr            => 4235,  #  int fd,const char *name        # fs/xattr.c:638
        tkill                   => 4236,  #  pid_t pid,int sig        # kernel/signal.c:2923
        sendfile                => 4237,    sendfile64              => 4237,  #  int out_fd,int in_fd,loff_t *offset,size_t count        # fs/read_write.c:992
        futex                   => 4238,  #  u32 *uaddr,int op,u32 val,struct timespec *utime,u32 *uaddr2,u32 val3        # kernel/futex.c:2680
        sched_setaffinity       => 4239,  #  pid_t pid,unsigned int len,unsigned long *user_mask_ptr        # kernel/sched/core.c:4626
        sched_getaffinity       => 4240,  #  pid_t pid,unsigned int len,unsigned long *user_mask_ptr        # kernel/sched/core.c:4677
        io_setup                => 4241,  #  unsigned nr_events,aio_context_t *ctxp        # fs/aio.c:1298
        io_destroy              => 4242,  #  aio_context_t ctx        # fs/aio.c:1334
        io_getevents            => 4243,  #  aio_context_t ctx_id,long min_nr,long nr,struct io_event *events,struct timespec *timeout        # fs/aio.c:1844
        io_submit               => 4244,  #  aio_context_t ctx_id,long nr,struct iocb * *iocbpp        # fs/aio.c:1746
        io_cancel               => 4245,  #  aio_context_t ctx_id,struct iocb *iocb,struct io_event *result        # fs/aio.c:1781
        exit_group              => 4246,  #  int error_code        # kernel/exit.c:1136
        lookup_dcookie          => 4247,  #  char *buf size_t len        # fs/dcookies.c:148
        epoll_create            => 4248,  #  int size        # fs/eventpoll.c:1668
        epoll_ctl               => 4249,  #  int epfd,int op,int fd,struct epoll_event *event        # fs/eventpoll.c:1681
        epoll_wait              => 4250,  #  int epfd,struct epoll_event *events,int maxevents,int timeout        # fs/eventpoll.c:1809
        remap_file_pages        => 4251,  #  unsigned long start,unsigned long size,unsigned long prot,unsigned long pgoff,unsigned long flags        # mm/fremap.c:122
        set_tid_address         => 4252,  #  int *tidptr        # kernel/fork.c:1109
        restart_syscall         => 4253,  #  -        # kernel/signal.c:2501
        fadvise                 => 4254,    fadvise64               => 4254,  #  loff_t offset size_t len,int advice        # mm/fadvise.c:148
        statfs                  => 4255,    statfs64                => 4255,  #  const char *pathname,size_t sz,struct statfs64 *buf        # fs/statfs.c:175
        fstatfs64               => 4256,  #  unsigned int fd,size_t sz,struct statfs64 *buf        # fs/statfs.c:196
        timer_create            => 4257,  #  const clockid_t which_clock,struct sigevent *timer_event_spec,timer_t *created_timer_id        # kernel/posix-timers.c:535
        timer_settime           => 4258,  #  timer_t timer_id,int flags,const struct itimerspec *new_setting,struct itimerspec *old_setting        # kernel/posix-timers.c:819
        timer_gettime           => 4259,  #  timer_t timer_id,struct itimerspec *setting        # kernel/posix-timers.c:715
        timer_getoverrun        => 4260,  #  timer_t timer_id        # kernel/posix-timers.c:751
        timer_delete            => 4261,  #  timer_t timer_id        # kernel/posix-timers.c:882
        clock_settime           => 4262,  #  const clockid_t which_clock,const struct timespec *tp        # kernel/posix-timers.c:950
        clock_gettime           => 4263,  #  const clockid_t which_clock,struct timespec *tp        # kernel/posix-timers.c:965
        clock_getres            => 4264,  #  const clockid_t which_clock,struct timespec *tp        # kernel/posix-timers.c:1006
        clock_nanosleep         => 4265,  #  const clockid_t which_clock,int flags,const struct timespec *rqtp,struct timespec *rmtp        # kernel/posix-timers.c:1035
        tgkill                  => 4266,  #  pid_t tgid,pid_t pid,int sig        # kernel/signal.c:2907
        utimes                  => 4267,  #  char *filename,struct timeval *utimes        # fs/utimes.c:221
        mbind                   => 4268,  #  unsigned long start,unsigned long len,unsigned long mode,unsigned long *nmask,unsigned long maxnode,unsigned flags        # mm/mempolicy.c:1263
        get_mempolicy           => 4269,  #  int *policy,unsigned long *nmask,unsigned long maxnode,unsigned long addr,unsigned long flags        # mm/mempolicy.c:1400
        set_mempolicy           => 4270,  #  int mode,unsigned long *nmask,unsigned long maxnode        # mm/mempolicy.c:1285
        mq_open                 => 4271,  #  const char *u_name,int oflag,umode_t mode,struct mq_attr *u_attr        # ipc/mqueue.c:803
        mq_unlink               => 4272,  #  const char *u_name        # ipc/mqueue.c:876
        mq_timedsend            => 4273,  #  mqd_t mqdes,const char *u_msg_ptr,size_t msg_len,unsigned int msg_prio,const struct timespec *u_abs_timeout        # ipc/mqueue.c:971
        mq_timedreceive         => 4274,  #  mqd_t mqdes,char *u_msg_ptr,size_t msg_len,unsigned int *u_msg_prio,const struct timespec *u_abs_timeout        # ipc/mqueue.c:1092
        mq_notify               => 4275,  #  mqd_t mqdes,const struct sigevent *u_notification        # ipc/mqueue.c:1201
        mq_getsetattr           => 4276,  #  mqd_t mqdes,const struct mq_attr *u_mqstat,struct mq_attr *u_omqstat        # ipc/mqueue.c:1333
        vserver                 => 4277,  #  -        # Not implemented
        waitid                  => 4278,  #  int which,pid_t upid,struct siginfo *infop,int options,struct rusage *ru        # kernel/exit.c:1763
        add_key                 => 4280,  #  const char *_type,const char *_description,const void *_payload,size_t plen,key_serial_t ringid        # security/keys/keyctl.c:54
        request_key             => 4281,  #  const char *_type,const char *_description,const char *_callout_info,key_serial_t destringid        # security/keys/keyctl.c:147
        keyctl                  => 4282,  #  int option,unsigned long arg2,unsigned long arg3,unsigned long arg4,unsigned long arg5        # security/keys/keyctl.c:1556
        set_thread_area         => 4283,  #  unsigned long addr        # arch/mips/kernel/syscall.c:152
        inotify_init            => 4284,  #  -        # fs/notify/inotify/inotify_user.c:749
        inotify_add_watch       => 4285,  #  int fd,const char *pathname,u32 mask        # fs/notify/inotify/inotify_user.c:754
        inotify_rm_watch        => 4286,  #  int fd,__s32 wd        # fs/notify/inotify/inotify_user.c:795
        migrate_pages           => 4287,  #  pid_t pid,unsigned long maxnode,const unsigned long *old_nodes,const unsigned long *new_nodes        # mm/mempolicy.c:1304
        openat                  => 4288,  #  int dfd,const char *filename,int flags,umode_t mode        # fs/open.c:1059
        mkdirat                 => 4289,  #  int dfd,const char *pathname,umode_t mode        # fs/namei.c:2723
        mknodat                 => 4290,  #  int dfd,const char *filename,umode_t mode,unsigned dev        # fs/namei.c:2646
        fchownat                => 4291,  #  int dfd,const char *filename,uid_t user,gid_t group,int flag        # fs/open.c:559
        futimesat               => 4292,  #  int dfd,const char *filename,struct timeval *utimes        # fs/utimes.c:193
        fstatat                 => 4293,    fstatat64               => 4293,  #  int dfd,const char *filename,struct stat64 *statbuf,int flag        # fs/stat.c:407
        unlinkat                => 4294,  #  int dfd,const char *pathname,int flag        # fs/namei.c:2968
        renameat                => 4295,  #  int olddfd,const char *oldname,int newdfd,const char *newname        # fs/namei.c:3309
        linkat                  => 4296,  #  int olddfd,const char *oldname,int newdfd,const char *newname,int flags        # fs/namei.c:3097
        symlinkat               => 4297,  #  const char *oldname,int newdfd,const char *newname        # fs/namei.c:3004
        readlinkat              => 4298,  #  int dfd,const char *pathname,char *buf,int bufsiz        # fs/stat.c:293
        fchmodat                => 4299,  #  int dfd,const char *filename,umode_t mode        # fs/open.c:486
        faccessat               => 4300,  #  int dfd,const char *filename,int mode        # fs/open.c:299
        pselect6                => 4301,  #  int n,fd_set *inp,fd_set *outp,fd_set *exp,struct timespec *tsp,void *sig        # fs/select.c:671
        ppoll                   => 4302,  #  struct pollfd *ufds,unsigned int nfds,struct timespec *tsp,const sigset_t *sigmask,size_t sigsetsize        # fs/select.c:942
        unshare                 => 4303,  #  unsigned long unshare_flags        # kernel/fork.c:1778
        splice                  => 4304,  #  int fd_in,loff_t *off_in,int fd_out,loff_t *off_out,size_t len,unsigned int flags        # fs/splice.c:1689
        sync_file_range         => 4305,  #  loff_t offset loff_t nbytes,unsigned int flags        # fs/sync.c:275
        tee                     => 4306,  #  int fdin,int fdout,size_t len,unsigned int flags        # fs/splice.c:2025
        vmsplice                => 4307,  #  int fd,const struct iovec *iov,unsigned long nr_segs,unsigned int flags        # fs/splice.c:1663
        move_pages              => 4308,  #  pid_t pid,unsigned long nr_pages,const void * *pages,const int *nodes,int *status,int flags        # mm/migrate.c:1343
        set_robust_list         => 4309,  #  struct robust_list_head *head,size_t len        # kernel/futex.c:2422
        get_robust_list         => 4310,  #  int pid,struct robust_list_head * *head_ptr,size_t *len_ptr        # kernel/futex.c:2444
        kexec_load              => 4311,  #  unsigned long entry,unsigned long nr_segments,struct kexec_segment *segments,unsigned long flags        # kernel/kexec.c:940
        getcpu                  => 4312,  #  unsigned *cpup,unsigned *nodep,struct getcpu_cache *unused        # kernel/sys.c:2179
        epoll_pwait             => 4313,  #  int epfd,struct epoll_event *events,int maxevents,int timeout,const sigset_t *sigmask,size_t sigsetsize        # fs/eventpoll.c:1860
        ioprio_set              => 4314,  #  int which,int who,int ioprio        # fs/ioprio.c:61
        ioprio_get              => 4315,  #  int which,int who        # fs/ioprio.c:176
        utimensat               => 4316,  #  int dfd,const char *filename,struct timespec *utimes,int flags        # fs/utimes.c:175
        signalfd                => 4317,  #  int ufd,sigset_t *user_mask,size_t sizemask        # fs/signalfd.c:292
        timerfd                 => 4318,  #  -        # Not implemented
        eventfd                 => 4319,  #  unsigned int count        # fs/eventfd.c:431
        fallocate               => 4320,  #  int mode loff_t offset,loff_t len        # fs/open.c:272
        timerfd_create          => 4321,  #  int clockid,int flags        # fs/timerfd.c:252
        timerfd_gettime         => 4322,  #  int ufd,struct itimerspec *otmr        # fs/timerfd.c:344
        timerfd_settime         => 4323,  #  int ufd,int flags,const struct itimerspec *utmr,struct itimerspec *otmr        # fs/timerfd.c:283
        signalfd4               => 4324,  #  int ufd,sigset_t *user_mask,size_t sizemask,int flags        # fs/signalfd.c:237
        eventfd2                => 4325,  #  unsigned int count,int flags        # fs/eventfd.c:406
        epoll_create1           => 4326,  #  int flags        # fs/eventpoll.c:1625
        dup3                    => 4327,  #  unsigned int oldfd,unsigned int newfd,int flags        # fs/fcntl.c:53
        pipe2                   => 4328,  #  int *fildes,int flags        # fs/pipe.c:1133
        inotify_init1           => 4329,  #  int flags        # fs/notify/inotify/inotify_user.c:724
        preadv                  => 4330,  #  unsigned long fd,const struct iovec *vec,unsigned long vlen,unsigned long pos_l,unsigned long pos_h        # fs/read_write.c:835
        pwritev                 => 4331,  #  unsigned long fd,const struct iovec *vec,unsigned long vlen,unsigned long pos_l,unsigned long pos_h        # fs/read_write.c:860
        rt_tgsigqueueinfo       => 4332,  #  pid_t tgid,pid_t pid,int sig,siginfo_t *uinfo        # kernel/signal.c:2979
        perf_event_open         => 4333,  #  struct perf_event_attr *attr_uptr,pid_t pid,int cpu,int group_fd,unsigned long flags        # kernel/events/core.c:6186
        accept4                 => 4334,  #  int fd,struct sockaddr *upeer_sockaddr,int *upeer_addrlen,int flags        # net/socket.c:1508
        recvmmsg                => 4335,  #  int fd,struct mmsghdr *mmsg,unsigned int vlen,unsigned int flags,struct timespec *timeout        # net/socket.c:2313
        fanotify_init           => 4336,  #  unsigned int flags,unsigned int event_f_flags        # fs/notify/fanotify/fanotify_user.c:679
        fanotify_mark           => 4337,  #  unsigned int flags __u64 mask,int dfd const char *pathname        # fs/notify/fanotify/fanotify_user.c:767
        prlimit                 => 4338,    prlimit64               => 4338,  #  pid_t pid,unsigned int resource,const struct rlimit64 *new_rlim,struct rlimit64 *old_rlim        # kernel/sys.c:1599
        name_to_handle_at       => 4339,  #  int dfd,const char *name,struct file_handle *handle,int *mnt_id,int flag        # fs/fhandle.c:92
        open_by_handle_at       => 4340,  #  int mountdirfd,struct file_handle *handle,int flags        # fs/fhandle.c:257
        clock_adjtime           => 4341,  #  const clockid_t which_clock,struct timex *utx        # kernel/posix-timers.c:983
        syncfs                  => 4342,  #  int fd        # fs/sync.c:134
        sendmmsg                => 4343,  #  int fd,struct mmsghdr *mmsg,unsigned int vlen,unsigned int flags        # net/socket.c:2091
        setns                   => 4344,  #  int fd,int nstype        # kernel/nsproxy.c:235
        process_vm_readv        => 4345,  #  pid_t pid,const struct iovec *lvec,unsigned long liovcnt,const struct iovec *rvec,unsigned long riovcnt,unsigned long flags        # mm/process_vm_access.c:398
        process_vm_writev       => 4346,  #  pid_t pid,const struct iovec *lvec,unsigned long liovcnt,const struct iovec *rvec,unsigned long riovcnt,unsigned long flags        # mm/process_vm_access.c:405

);

our %pack_map = (
    time_t   => 'q',
    timespec => 'qLx![q]',
    timeval  => 'qLx![q]',
);

# for statfs see https://git.kernel.org/pub/scm/linux/kernel/git/mips/linux.git/tree/arch/mips/include/asm/statfs.h?id=365b18189789bfa1acd9939e6312b8a4b4577b28

our @EXPORT = qw(

    $have_MMU
    $m32
    $use_32bit_off_t
    $use_arch_want_sync_file_range2
    $use_arch_want_syscall_deprecated
    $use_arch_want_syscall_no_at
    $use_arch_want_syscall_no_flags

    %syscall_map
    %pack_map

);

our %EXPORT_TAGS;
$EXPORT_TAGS{everything} = \@EXPORT;

1;
