#! /module/for/perl

use strict;
use warnings;

package Linux::Syscalls::mips;

# Constants for the MIPS o32 architecture, from https://syscalls.w3challs.com/?arch=mips_n64

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

# The sequence for MIPS n64 start out the same as x86_64, offset by 5000, but
# omits the the rt_sigreturn at 15, and then more calls further on, so that it
# slowly gets further out of sync. (Its sequence is identical to MIPS n32 until
# rt_sigreturn at 5211/6211; see Linux::Syscalls::mips_n32 for more details.)

# As with the other OS-dependent files, numeric suffices are added or removed
# so that the bare names have the nearest semantics to x86_64 (32-bit UID, GID,
# & PID, and 64-bit everything else).


our %syscall_map = (

        # FROM https://syscalls.w3challs.com/?arch=mips_n64

        read                    => 5000,  # unsigned int fd,char *buf,size_t count        # fs/read_write.c:460
        write                   => 5001,  # unsigned int fd,const char *buf,size_t count        # fs/read_write.c:477
        open                    => 5002,  # const char *filename,int flags,umode_t mode        # fs/open.c:1046
        close                   => 5003,  # unsigned int fd        # fs/open.c:1117
        stat                    => 5004,  # const char *filename,struct __old_kernel_stat *statbuf        # fs/stat.c:155
        fstat                   => 5005,  # unsigned int fd,struct __old_kernel_stat *statbuf        # fs/stat.c:181
        lstat                   => 5006,  # const char *filename,struct __old_kernel_stat *statbuf        # fs/stat.c:168
        poll                    => 5007,  # struct pollfd *ufds,unsigned int nfds,int timeout_msecs        # fs/select.c:908
        lseek                   => 5008,  # unsigned int fd,off_t offset,unsigned int origin        # fs/read_write.c:230
        mmap                    => 5009,  # struct mmap_arg_struct *arg        # mm/mmap.c:1153
        mprotect                => 5010,  # unsigned long start,size_t len,unsigned long prot        # mm/mprotect.c:232
        munmap                  => 5011,  # unsigned long addr,size_t len        # mm/mmap.c:2141
        brk                     => 5012,  # unsigned long brk        # mm/mmap.c:246
        rt_sigaction            => 5013,  # int sig,const struct sigaction *act,struct sigaction *oact,size_t sigsetsize        # kernel/signal.c:3174
        rt_sigprocmask          => 5014,  # int how,sigset_t *nset,sigset_t *oset,size_t sigsetsize        # kernel/signal.c:2591
        ioctl                   => 5015,  # unsigned int fd,unsigned int cmd,unsigned long arg        # fs/ioctl.c:604
        pread                   => 5016,    pread64                 => 5016,  # char *buf,size_t count,loff_t pos        # fs/read_write.c:495
        pwrite                  => 5017,    pwrite64                => 5017,  # const char *buf size_t count,loff_t pos        # fs/read_write.c:524
        readv                   => 5018,  # unsigned long fd,const struct iovec *vec,unsigned long vlen        # fs/read_write.c:787
        writev                  => 5019,  # unsigned long fd,const struct iovec *vec,unsigned long vlen        # fs/read_write.c:808
        access                  => 5020,  # const char *filename,int mode        # fs/open.c:370
        pipe                    => 5021,  # int *fildes        # fs/pipe.c:1149
        _newselect              => 5022,  # int n,fd_set *inp,fd_set *outp,fd_set *exp,struct timeval *tvp        # fs/select.c:593
        sched_yield             => 5023,  # -        # kernel/sched/core.c:4711
        mremap                  => 5024,  # unsigned long addr,unsigned long old_len,unsigned long new_len,unsigned long flags,unsigned long new_addr        # mm/mremap.c:431
        msync                   => 5025,  # unsigned long start,size_t len,int flags        # mm/msync.c:31
        mincore                 => 5026,  # unsigned long start,size_t len,unsigned char *vec        # mm/mincore.c:266
        madvise                 => 5027,  # unsigned long start,size_t len_in,int behavior        # mm/madvise.c:362
        shmget                  => 5028,  # key_t key,size_t size,int shmflg        # ipc/shm.c:574
        shmat                   => 5029,  # int shmid,char *shmaddr,int shmflg        # ipc/shm.c:1105
        shmctl                  => 5030,  # int shmid,int cmd,struct shmid_ds *buf        # ipc/shm.c:774
        dup                     => 5031,  # unsigned int fildes        # fs/fcntl.c:131
        dup2                    => 5032,  # unsigned int oldfd,unsigned int newfd        # fs/fcntl.c:116
        pause                   => 5033,  # -        # kernel/signal.c:3245
        nanosleep               => 5034,  # struct timespec *rqtp,struct timespec *rmtp        # kernel/hrtimer.c:1621
        getitimer               => 5035,  # int which,struct itimerval *value        # kernel/itimer.c:103
        setitimer               => 5036,  # int which,struct itimerval *value,struct itimerval *ovalue        # kernel/itimer.c:278
        alarm                   => 5037,  # unsigned int seconds        # kernel/timer.c:1390
        getpid                  => 5038,  # -        # kernel/timer.c:1413
        sendfile                => 5039,  # int out_fd,int in_fd,off_t *offset,size_t count        # fs/read_write.c:973
        socket                  => 5040,  # int family,int type,int protocol        # net/socket.c:1324
        connect                 => 5041,  # int fd,struct sockaddr *uservaddr,int addrlen        # net/socket.c:1600
        accept                  => 5042,  # int fd,struct sockaddr *upeer_sockaddr,int *upeer_addrlen        # net/socket.c:1582
        sendto                  => 5043,  # int fd,void *buff,size_t len,unsigned int flags,struct sockaddr *addr,int addr_len        # net/socket.c:1695
        recvfrom                => 5044,  # int fd,void *ubuf,size_t size,unsigned int flags,struct sockaddr *addr,int *addr_len        # net/socket.c:1754
        sendmsg                 => 5045,  # int fd,struct msghdr *msg,unsigned int flags        # net/socket.c:2016
        recvmsg                 => 5046,  # int fd,struct msghdr *msg,unsigned int flags        # net/socket.c:2189
        shutdown                => 5047,  # int fd,int how        # net/socket.c:1874
        bind                    => 5048,  # int fd,struct sockaddr *umyaddr,int addrlen        # net/socket.c:1446
        listen                  => 5049,  # int fd,int backlog        # net/socket.c:1475
        getsockname             => 5050,  # int fd,struct sockaddr *usockaddr,int *usockaddr_len        # net/socket.c:1632
        getpeername             => 5051,  # int fd,struct sockaddr *usockaddr,int *usockaddr_len        # net/socket.c:1663
        socketpair              => 5052,  # int family,int type,int protocol,int *usockvec        # net/socket.c:1365
        setsockopt              => 5053,  # int fd,int level,int optname,char *optval,int optlen        # net/socket.c:1810
        getsockopt              => 5054,  # int fd,int level,int optname,char *optval,int *optlen        # net/socket.c:1844
        clone                   => 5055,  # -        # arch/mips/kernel/syscall.c:100
        fork                    => 5056,  # -        # arch/mips/kernel/syscall.c:93
        execve                  => 5057,  # -        # arch/mips/kernel/syscall.c:133
        exit                    => 5058,  # int error_code        # kernel/exit.c:1095
        wait4                   => 5059,  # pid_t upid,int *stat_addr,int options,struct rusage *ru        # kernel/exit.c:1834
        kill                    => 5060,  # pid_t pid,int sig        # kernel/signal.c:2841
        uname                   => 5061,  # struct old_utsname *name        # kernel/sys.c:1311
        semget                  => 5062,  # key_t key,int nsems,int semflg        # ipc/sem.c:367
        semop                   => 5063,  # int semid,struct sembuf *tsops,unsigned nsops        # ipc/sem.c:1548
        semctl                  => 5064,  # int semnum int cmd,union semun arg        # ipc/sem.c:1121
        shmdt                   => 5065,  # char *shmaddr        # ipc/shm.c:1121
        msgget                  => 5066,  # key_t key,int msgflg        # ipc/msg.c:312
        msgsnd                  => 5067,  # int msqid,struct msgbuf *msgp,size_t msgsz,int msgflg        # ipc/msg.c:726
        msgrcv                  => 5068,  # int msqid,struct msgbuf *msgp,size_t msgsz,long msgtyp,int msgflg        # ipc/msg.c:907
        msgctl                  => 5069,  # int msqid,int cmd,struct msqid_ds *buf        # ipc/msg.c:469
        fcntl                   => 5070,  # unsigned int fd,unsigned int cmd,unsigned long arg        # fs/fcntl.c:442
        flock                   => 5071,  # unsigned int fd,unsigned int cmd        # fs/locks.c:1636
        fsync                   => 5072,  # unsigned int fd        # fs/sync.c:201
        fdatasync               => 5073,  # unsigned int fd        # fs/sync.c:206
        truncate                => 5074,  # const char *path,long length        # fs/open.c:128
        ftruncate               => 5075,  # unsigned int fd,unsigned long length        # fs/open.c:178
        getdents                => 5076,  # unsigned int fd,struct linux_dirent *dirent,unsigned int count        # fs/readdir.c:191
        getcwd                  => 5077,  # char *buf,unsigned long size        # fs/dcache.c:2885
        chdir                   => 5078,  # const char *filename        # fs/open.c:375
        fchdir                  => 5079,  # unsigned int fd        # fs/open.c:396
        rename                  => 5080,  # const char *oldname,const char *newname        # fs/namei.c:3403
        mkdir                   => 5081,  # const char *pathname,umode_t mode        # fs/namei.c:2751
        rmdir                   => 5082,  # const char *pathname        # fs/namei.c:2870
        creat                   => 5083,  # const char *pathname,umode_t mode        # fs/open.c:1079
        link                    => 5084,  # const char *oldname,const char *newname        # fs/namei.c:3152
        unlink                  => 5085,  # const char *pathname        # fs/namei.c:2979
        symlink                 => 5086,  # const char *oldname,const char *newname        # fs/namei.c:3039
        readlink                => 5087,  # const char *path,char *buf,int bufsiz        # fs/stat.c:321
        chmod                   => 5088,  # const char *filename,umode_t mode        # fs/open.c:499
        fchmod                  => 5089,  # unsigned int fd,umode_t mode        # fs/open.c:472
        chown                   => 5090,  # const char *filename,uid_t user,gid_t group        # fs/open.c:540
        fchown                  => 5091,  # unsigned int fd,uid_t user,gid_t group        # fs/open.c:605
        lchown                  => 5092,  # const char *filename,uid_t user,gid_t group        # fs/open.c:586
        umask                   => 5093,  # int mask        # kernel/sys.c:1782
        gettimeofday            => 5094,  # struct timeval *tv,struct timezone *tz        # kernel/time.c:101
        getrlimit               => 5095,  # unsigned int resource,struct rlimit *rlim        # kernel/sys.c:1440
        getrusage               => 5096,  # int who,struct rusage *ru        # kernel/sys.c:1774
        sysinfo                 => 5097,  # struct sysinfo *info        # kernel/timer.c:1641
        times                   => 5098,  # struct tms *tbuf        # kernel/sys.c:1058
        ptrace                  => 5099,  # long request,long pid,unsigned long addr,unsigned long data        # kernel/ptrace.c:857
        getuid                  => 5100,  # -        # kernel/timer.c:1435
        syslog                  => 5101,  # int type,char *buf,int len        # kernel/printk.c:1195
        getgid                  => 5102,  # -        # kernel/timer.c:1447
        setuid                  => 5103,  # uid_t uid        # kernel/sys.c:761
        setgid                  => 5104,  # gid_t gid        # kernel/sys.c:614
        geteuid                 => 5105,  # -        # kernel/timer.c:1441
        getegid                 => 5106,  # -        # kernel/timer.c:1453
        setpgid                 => 5107,  # pid_t pid,pid_t pgid        # kernel/sys.c:1083
        getppid                 => 5108,  # -        # kernel/timer.c:1424
        getpgrp                 => 5109,  # -        # kernel/sys.c:1184
        setsid                  => 5110,  # -        # kernel/sys.c:1219
        setreuid                => 5111,  # uid_t ruid,uid_t euid        # kernel/sys.c:690
        setregid                => 5112,  # gid_t rgid,gid_t egid        # kernel/sys.c:557
        getgroups               => 5113,  # int gidsetsize,gid_t *grouplist        # kernel/groups.c:202
        setgroups               => 5114,  # int gidsetsize,gid_t *grouplist        # kernel/groups.c:231
        setresuid               => 5115,  # uid_t ruid,uid_t euid,uid_t suid        # kernel/sys.c:808
        getresuid               => 5116,  # uid_t *ruidp,uid_t *euidp,uid_t *suidp        # kernel/sys.c:873
        setresgid               => 5117,  # gid_t rgid,gid_t egid,gid_t sgid        # kernel/sys.c:893
        getresgid               => 5118,  # gid_t *rgidp,gid_t *egidp,gid_t *sgidp        # kernel/sys.c:945
        getpgid                 => 5119,  # pid_t pid        # kernel/sys.c:1154
        setfsuid                => 5120,  # uid_t uid        # kernel/sys.c:969
        setfsgid                => 5121,  # gid_t gid        # kernel/sys.c:1008
        getsid                  => 5122,  # pid_t pid        # kernel/sys.c:1191
        capget                  => 5123,  # cap_user_header_t header,cap_user_data_t dataptr        # kernel/capability.c:158
        capset                  => 5124,  # cap_user_header_t header,const cap_user_data_t data        # kernel/capability.c:232
        rt_sigpending           => 5125,  # sigset_t *set,size_t sigsetsize        # kernel/signal.c:2651
        rt_sigtimedwait         => 5126,  # const sigset_t *uthese,siginfo_t *uinfo,const struct timespec *uts,size_t sigsetsize        # kernel/signal.c:2805
        rt_sigqueueinfo         => 5127,  # pid_t pid,int sig,siginfo_t *uinfo        # kernel/signal.c:2938
        rt_sigsuspend           => 5128,  # sigset_t *unewset,size_t sigsetsize        # kernel/signal.c:3274
        sigaltstack             => 5129,  # -        # arch/mips/kernel/signal.c:320
        utime                   => 5130,  # char *filename,struct utimbuf *times        # fs/utimes.c:27
        mknod                   => 5131,  # const char *filename,umode_t mode,unsigned dev        # fs/namei.c:2693
        personality             => 5132,  # unsigned int personality        # kernel/exec_domain.c:182
        ustat                   => 5133,  # unsigned dev,struct ustat *ubuf        # fs/statfs.c:222
        statfs                  => 5134,  # const char *pathname,struct statfs *buf        # fs/statfs.c:166
        fstatfs                 => 5135,  # unsigned int fd,struct statfs *buf        # fs/statfs.c:187
        sysfs                   => 5136,  # int option,unsigned long arg1,unsigned long arg2        # fs/filesystems.c:183
        getpriority             => 5137,  # int which,int who        # kernel/sys.c:241
        setpriority             => 5138,  # int which,int who,int niceval        # kernel/sys.c:172
        sched_setparam          => 5139,  # pid_t pid,struct sched_param *param        # kernel/sched/core.c:4477
        sched_getparam          => 5140,  # pid_t pid,struct sched_param *param        # kernel/sched/core.c:4512
        sched_setscheduler      => 5141,  # pid_t pid,int policy,struct sched_param *param        # kernel/sched/core.c:4462
        sched_getscheduler      => 5142,  # pid_t pid        # kernel/sched/core.c:4486
        sched_get_priority_max  => 5143,  # int policy        # kernel/sched/core.c:4935
        sched_get_priority_min  => 5144,  # int policy        # kernel/sched/core.c:4960
        sched_rr_get_interval   => 5145,  # pid_t pid,struct timespec *interval        # kernel/sched/core.c:4985
        mlock                   => 5146,  # unsigned long start,size_t len        # mm/mlock.c:482
        munlock                 => 5147,  # unsigned long start,size_t len        # mm/mlock.c:512
        mlockall                => 5148,  # int flags        # mm/mlock.c:549
        munlockall              => 5149,  # -        # mm/mlock.c:582
        vhangup                 => 5150,  # -        # fs/open.c:1156
        pivot_root              => 5151,  # const char *new_root,const char *put_old        # fs/namespace.c:2453
        _sysctl                 => 5152,  # struct __sysctl_args *args        # kernel/sysctl_binary.c:1444
        prctl                   => 5153,  # int option,unsigned long arg2,unsigned long arg3,unsigned long arg4,unsigned long arg5        # kernel/sys.c:1999
        adjtimex                => 5154,  # struct timex *txc_p        # kernel/time.c:200
        setrlimit               => 5155,  # unsigned int resource,struct rlimit *rlim        # kernel/sys.c:1641
        chroot                  => 5156,  # const char *filename        # fs/open.c:422
        sync                    => 5157,  # -        # fs/sync.c:98
        acct                    => 5158,  # const char *name        # kernel/acct.c:255
        settimeofday            => 5159,  # struct timeval *tv,struct timezone *tz        # kernel/time.c:179
        mount                   => 5160,  # char *dev_name,char *dir_name,char *type,unsigned long flags,void *data        # fs/namespace.c:2362
        umount2                 => 5161,  # char *name,int flags        # fs/namespace.c:1190
        swapon                  => 5162,  # const char *specialfile,int swap_flags        # mm/swapfile.c:1996
        swapoff                 => 5163,  # const char *specialfile        # mm/swapfile.c:1539
        reboot                  => 5164,  # int magic1,int magic2,unsigned int cmd,void *arg        # kernel/sys.c:432
        sethostname             => 5165,  # char *name,int len        # kernel/sys.c:1365
        setdomainname           => 5166,  # char *name,int len        # kernel/sys.c:1416
        create_module           => 5167,  # -        # Not implemented
        init_module             => 5168,  # void *umod,unsigned long len,const char *uargs        # kernel/module.c:3010
        delete_module           => 5169,  # const char *name_user,unsigned int flags        # kernel/module.c:768
        get_kernel_syms         => 5170,  # -        # Not implemented
        query_module            => 5171,  # -        # Not implemented
        quotactl                => 5172,  # unsigned int cmd,const char *special,qid_t id,void *addr        # fs/quota/quota.c:346
        nfsservctl              => 5173,  # -        # Not implemented
        getpmsg                 => 5174,  # -        # Not implemented
        putpmsg                 => 5175,  # -        # Not implemented
        afs_syscall             => 5176,  # -        # Not implemented
        reserved177             => 5177,  # -        # Not implemented
        gettid                  => 5178,  # -        # kernel/timer.c:1569
        readahead               => 5179,  # loff_t offset size_t count        # mm/readahead.c:579
        setxattr                => 5180,  # const char *pathname,const char *name,const void *value,size_t size,int flags        # fs/xattr.c:361
        lsetxattr               => 5181,  # const char *pathname,const char *name,const void *value,size_t size,int flags        # fs/xattr.c:380
        fsetxattr               => 5182,  # int fd,const char *name,const void *value,size_t size,int flags        # fs/xattr.c:399
        getxattr                => 5183,  # const char *pathname,const char *name,void *value,size_t size        # fs/xattr.c:459
        lgetxattr               => 5184,  # const char *pathname,const char *name,void *value,size_t size        # fs/xattr.c:473
        fgetxattr               => 5185,  # int fd,const char *name,void *value,size_t size        # fs/xattr.c:487
        listxattr               => 5186,  # const char *pathname,char *list,size_t size        # fs/xattr.c:541
        llistxattr              => 5187,  # const char *pathname,char *list,size_t size        # fs/xattr.c:555
        flistxattr              => 5188,  # int fd,char *list,size_t size        # fs/xattr.c:569
        removexattr             => 5189,  # const char *pathname,const char *name        # fs/xattr.c:602
        lremovexattr            => 5190,  # const char *pathname,const char *name        # fs/xattr.c:620
        fremovexattr            => 5191,  # int fd,const char *name        # fs/xattr.c:638
        tkill                   => 5192,  # pid_t pid,int sig        # kernel/signal.c:2923
        reserved193             => 5193,  # -        # Not implemented
        futex                   => 5194,  # u32 *uaddr,int op,u32 val,struct timespec *utime,u32 *uaddr2,u32 val3        # kernel/futex.c:2680
        sched_setaffinity       => 5195,  # pid_t pid,unsigned int len,unsigned long *user_mask_ptr        # kernel/sched/core.c:4626
        sched_getaffinity       => 5196,  # pid_t pid,unsigned int len,unsigned long *user_mask_ptr        # kernel/sched/core.c:4677
        cacheflush              => 5197,  # unsigned long addr,unsigned long bytes,unsigned int cache        # arch/mips/mm/cache.c:67
        cachectl                => 5198,  # char *addr,int nbytes,int op        # arch/mips/kernel/syscall.c:303
        sysmips                 => 5199,  # -        # arch/mips/kernel/syscall.c:265
        io_setup                => 5200,  # unsigned nr_events,aio_context_t *ctxp        # fs/aio.c:1298
        io_destroy              => 5201,  # aio_context_t ctx        # fs/aio.c:1334
        io_getevents            => 5202,  # aio_context_t ctx_id,long min_nr,long nr,struct io_event *events,struct timespec *timeout        # fs/aio.c:1844
        io_submit               => 5203,  # aio_context_t ctx_id,long nr,struct iocb * *iocbpp        # fs/aio.c:1746
        io_cancel               => 5204,  # aio_context_t ctx_id,struct iocb *iocb,struct io_event *result        # fs/aio.c:1781
        exit_group              => 5205,  # int error_code        # kernel/exit.c:1136
        lookup_dcookie          => 5206,  # char *buf size_t len        # fs/dcookies.c:148
        epoll_create            => 5207,  # int size        # fs/eventpoll.c:1668
        epoll_ctl               => 5208,  # int epfd,int op,int fd,struct epoll_event *event        # fs/eventpoll.c:1681
        epoll_wait              => 5209,  # int epfd,struct epoll_event *events,int maxevents,int timeout        # fs/eventpoll.c:1809
        remap_file_pages        => 5210,  # unsigned long start,unsigned long size,unsigned long prot,unsigned long pgoff,unsigned long flags        # mm/fremap.c:122
        rt_sigreturn            => 5211,  # -        # arch/mips/kernel/signal.c:365
        set_tid_address         => 5212,  # int *tidptr        # kernel/fork.c:1109
        restart_syscall         => 5213,  # -        # kernel/signal.c:2501
        semtimedop              => 5214,  # int semid,struct sembuf *tsops,unsigned nsops,const struct timespec *timeout        # ipc/sem.c:1330
        fadvise                 => 5215,    fadvise64               => 5215,  # loff_t offset size_t len,int advice        # mm/fadvise.c:148
        timer_create            => 5216,  # const clockid_t which_clock,struct sigevent *timer_event_spec,timer_t *created_timer_id        # kernel/posix-timers.c:535
        timer_settime           => 5217,  # timer_t timer_id,int flags,const struct itimerspec *new_setting,struct itimerspec *old_setting        # kernel/posix-timers.c:819
        timer_gettime           => 5218,  # timer_t timer_id,struct itimerspec *setting        # kernel/posix-timers.c:715
        timer_getoverrun        => 5219,  # timer_t timer_id        # kernel/posix-timers.c:751
        timer_delete            => 5220,  # timer_t timer_id        # kernel/posix-timers.c:882
        clock_settime           => 5221,  # const clockid_t which_clock,const struct timespec *tp        # kernel/posix-timers.c:950
        clock_gettime           => 5222,  # const clockid_t which_clock,struct timespec *tp        # kernel/posix-timers.c:965
        clock_getres            => 5223,  # const clockid_t which_clock,struct timespec *tp        # kernel/posix-timers.c:1006
        clock_nanosleep         => 5224,  # const clockid_t which_clock,int flags,const struct timespec *rqtp,struct timespec *rmtp        # kernel/posix-timers.c:1035
        tgkill                  => 5225,  # pid_t tgid,pid_t pid,int sig        # kernel/signal.c:2907
        utimes                  => 5226,  # char *filename,struct timeval *utimes        # fs/utimes.c:221
        mbind                   => 5227,  # unsigned long start,unsigned long len,unsigned long mode,unsigned long *nmask,unsigned long maxnode,unsigned flags        # mm/mempolicy.c:1263
        get_mempolicy           => 5228,  # int *policy,unsigned long *nmask,unsigned long maxnode,unsigned long addr,unsigned long flags        # mm/mempolicy.c:1400
        set_mempolicy           => 5229,  # int mode,unsigned long *nmask,unsigned long maxnode        # mm/mempolicy.c:1285
        mq_open                 => 5230,  # const char *u_name,int oflag,umode_t mode,struct mq_attr *u_attr        # ipc/mqueue.c:803
        mq_unlink               => 5231,  # const char *u_name        # ipc/mqueue.c:876
        mq_timedsend            => 5232,  # mqd_t mqdes,const char *u_msg_ptr,size_t msg_len,unsigned int msg_prio,const struct timespec *u_abs_timeout        # ipc/mqueue.c:971
        mq_timedreceive         => 5233,  # mqd_t mqdes,char *u_msg_ptr,size_t msg_len,unsigned int *u_msg_prio,const struct timespec *u_abs_timeout        # ipc/mqueue.c:1092
        mq_notify               => 5234,  # mqd_t mqdes,const struct sigevent *u_notification        # ipc/mqueue.c:1201
        mq_getsetattr           => 5235,  # mqd_t mqdes,const struct mq_attr *u_mqstat,struct mq_attr *u_omqstat        # ipc/mqueue.c:1333
        vserver                 => 5236,  # -        # Not implemented
        waitid                  => 5237,  # int which,pid_t upid,struct siginfo *infop,int options,struct rusage *ru        # kernel/exit.c:1763
        add_key                 => 5239,  # const char *_type,const char *_description,const void *_payload,size_t plen,key_serial_t ringid        # security/keys/keyctl.c:54
        request_key             => 5240,  # const char *_type,const char *_description,const char *_callout_info,key_serial_t destringid        # security/keys/keyctl.c:147
        keyctl                  => 5241,  # int option,unsigned long arg2,unsigned long arg3,unsigned long arg4,unsigned long arg5        # security/keys/keyctl.c:1556
        set_thread_area         => 5242,  # unsigned long addr        # arch/mips/kernel/syscall.c:152
        inotify_init            => 5243,  # -        # fs/notify/inotify/inotify_user.c:749
        inotify_add_watch       => 5244,  # int fd,const char *pathname,u32 mask        # fs/notify/inotify/inotify_user.c:754
        inotify_rm_watch        => 5245,  # int fd,__s32 wd        # fs/notify/inotify/inotify_user.c:795
        migrate_pages           => 5246,  # pid_t pid,unsigned long maxnode,const unsigned long *old_nodes,const unsigned long *new_nodes        # mm/mempolicy.c:1304
        openat                  => 5247,  # int dfd,const char *filename,int flags,umode_t mode        # fs/open.c:1059
        mkdirat                 => 5248,  # int dfd,const char *pathname,umode_t mode        # fs/namei.c:2723
        mknodat                 => 5249,  # int dfd,const char *filename,umode_t mode,unsigned dev        # fs/namei.c:2646
        fchownat                => 5250,  # int dfd,const char *filename,uid_t user,gid_t group,int flag        # fs/open.c:559
        futimesat               => 5251,  # int dfd,const char *filename,struct timeval *utimes        # fs/utimes.c:193
        fstatat                 => 5252,    fstatat64               => 5252,    newfstatat              => 5252,  # int dfd,const char *filename,struct stat *statbuf,int flag        # fs/stat.c:269
        unlinkat                => 5253,  # int dfd,const char *pathname,int flag        # fs/namei.c:2968
        renameat                => 5254,  # int olddfd,const char *oldname,int newdfd,const char *newname        # fs/namei.c:3309
        linkat                  => 5255,  # int olddfd,const char *oldname,int newdfd,const char *newname,int flags        # fs/namei.c:3097
        symlinkat               => 5256,  # const char *oldname,int newdfd,const char *newname        # fs/namei.c:3004
        readlinkat              => 5257,  # int dfd,const char *pathname,char *buf,int bufsiz        # fs/stat.c:293
        fchmodat                => 5258,  # int dfd,const char *filename,umode_t mode        # fs/open.c:486
        faccessat               => 5259,  # int dfd,const char *filename,int mode        # fs/open.c:299
        pselect6                => 5260,  # int n,fd_set *inp,fd_set *outp,fd_set *exp,struct timespec *tsp,void *sig        # fs/select.c:671
        ppoll                   => 5261,  # struct pollfd *ufds,unsigned int nfds,struct timespec *tsp,const sigset_t *sigmask,size_t sigsetsize        # fs/select.c:942
        unshare                 => 5262,  # unsigned long unshare_flags        # kernel/fork.c:1778
        splice                  => 5263,  # int fd_in,loff_t *off_in,int fd_out,loff_t *off_out,size_t len,unsigned int flags        # fs/splice.c:1689
        sync_file_range         => 5264,  # loff_t offset loff_t nbytes,unsigned int flags        # fs/sync.c:275
        tee                     => 5265,  # int fdin,int fdout,size_t len,unsigned int flags        # fs/splice.c:2025
        vmsplice                => 5266,  # int fd,const struct iovec *iov,unsigned long nr_segs,unsigned int flags        # fs/splice.c:1663
        move_pages              => 5267,  # pid_t pid,unsigned long nr_pages,const void * *pages,const int *nodes,int *status,int flags        # mm/migrate.c:1343
        set_robust_list         => 5268,  # struct robust_list_head *head,size_t len        # kernel/futex.c:2422
        get_robust_list         => 5269,  # int pid,struct robust_list_head * *head_ptr,size_t *len_ptr        # kernel/futex.c:2444
        kexec_load              => 5270,  # unsigned long entry,unsigned long nr_segments,struct kexec_segment *segments,unsigned long flags        # kernel/kexec.c:940
        getcpu                  => 5271,  # unsigned *cpup,unsigned *nodep,struct getcpu_cache *unused        # kernel/sys.c:2179
        epoll_pwait             => 5272,  # int epfd,struct epoll_event *events,int maxevents,int timeout,const sigset_t *sigmask,size_t sigsetsize        # fs/eventpoll.c:1860
        ioprio_set              => 5273,  # int which,int who,int ioprio        # fs/ioprio.c:61
        ioprio_get              => 5274,  # int which,int who        # fs/ioprio.c:176
        utimensat               => 5275,  # int dfd,const char *filename,struct timespec *utimes,int flags        # fs/utimes.c:175
        signalfd                => 5276,  # int ufd,sigset_t *user_mask,size_t sizemask        # fs/signalfd.c:292
        timerfd                 => 5277,  # -        # Not implemented
        eventfd                 => 5278,  # unsigned int count        # fs/eventfd.c:431
        fallocate               => 5279,  # int mode loff_t offset,loff_t len        # fs/open.c:272
        timerfd_create          => 5280,  # int clockid,int flags        # fs/timerfd.c:252
        timerfd_gettime         => 5281,  # int ufd,struct itimerspec *otmr        # fs/timerfd.c:344
        timerfd_settime         => 5282,  # int ufd,int flags,const struct itimerspec *utmr,struct itimerspec *otmr        # fs/timerfd.c:283
        signalfd4               => 5283,  # int ufd,sigset_t *user_mask,size_t sizemask,int flags        # fs/signalfd.c:237
        eventfd2                => 5284,  # unsigned int count,int flags        # fs/eventfd.c:406
        epoll_create1           => 5285,  # int flags        # fs/eventpoll.c:1625
        dup3                    => 5286,  # unsigned int oldfd,unsigned int newfd,int flags        # fs/fcntl.c:53
        pipe2                   => 5287,  # int *fildes,int flags        # fs/pipe.c:1133
        inotify_init1           => 5288,  # int flags        # fs/notify/inotify/inotify_user.c:724
        preadv                  => 5289,  # unsigned long fd,const struct iovec *vec,unsigned long vlen,unsigned long pos_l,unsigned long pos_h        # fs/read_write.c:835
        pwritev                 => 5290,  # unsigned long fd,const struct iovec *vec,unsigned long vlen,unsigned long pos_l,unsigned long pos_h        # fs/read_write.c:860
        rt_tgsigqueueinfo       => 5291,  # pid_t tgid,pid_t pid,int sig,siginfo_t *uinfo        # kernel/signal.c:2979
        perf_event_open         => 5292,  # struct perf_event_attr *attr_uptr,pid_t pid,int cpu,int group_fd,unsigned long flags        # kernel/events/core.c:6186
        accept4                 => 5293,  # int fd,struct sockaddr *upeer_sockaddr,int *upeer_addrlen,int flags        # net/socket.c:1508
        recvmmsg                => 5294,  # int fd,struct mmsghdr *mmsg,unsigned int vlen,unsigned int flags,struct timespec *timeout        # net/socket.c:2313
        fanotify_init           => 5295,  # unsigned int flags,unsigned int event_f_flags        # fs/notify/fanotify/fanotify_user.c:679
        fanotify_mark           => 5296,  # unsigned int flags __u64 mask,int dfd const char *pathname        # fs/notify/fanotify/fanotify_user.c:767
        prlimit                 => 5297,    prlimit64               => 5297,  # pid_t pid,unsigned int resource,const struct rlimit64 *new_rlim,struct rlimit64 *old_rlim        # kernel/sys.c:1599
        name_to_handle_at       => 5298,  # int dfd,const char *name,struct file_handle *handle,int *mnt_id,int flag        # fs/fhandle.c:92
        open_by_handle_at       => 5299,  # int mountdirfd,struct file_handle *handle,int flags        # fs/fhandle.c:257
        clock_adjtime           => 5300,  # const clockid_t which_clock,struct timex *utx        # kernel/posix-timers.c:983
        syncfs                  => 5301,  # int fd        # fs/sync.c:134
        sendmmsg                => 5302,  # int fd,struct mmsghdr *mmsg,unsigned int vlen,unsigned int flags        # net/socket.c:2091
        setns                   => 5303,  # int fd,int nstype        # kernel/nsproxy.c:235
        process_vm_readv        => 5304,  # pid_t pid,const struct iovec *lvec,unsigned long liovcnt,const struct iovec *rvec,unsigned long riovcnt,unsigned long flags        # mm/process_vm_access.c:398
        process_vm_writev       => 5305,  # pid_t pid,const struct iovec *lvec,unsigned long liovcnt,const struct iovec *rvec,unsigned long riovcnt,unsigned long flags        # mm/process_vm_access.c:405

);

our %pack_map = (
    time_t   => 'q',
    timespec => 'qLx![q]',
    timeval  => 'qLx![q]',
);

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
