#define _POSIX_C_SOURCE 200809L
#define _BSD_SOURCE
#define _SVID_SOURCE
#include <stdint.h>

#include <sys/resource.h>
#include <sys/syscall.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>

//#define __need_siginfo_t
//#define __USE_SVID
#include <signal.h>
//#include <bits/siginfo.h>
//#include <bits/waitflags.h>

#include <unistd.h>

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>

#if 0 && ! defined P_PID
#define P_PID 1
#endif

static inline double tv2f(struct timeval t) {
    return t.tv_sec + t.tv_usec * 0.000001;
}

typedef struct rusage rusage_t;

int waitid(idtype_t idtype, id_t id, siginfo_t *infop, int options);

static long waitid5(int id_type,
            int id,
            siginfo_t *sip,
            int options,
            rusage_t *rup ) {
    static const int syscall_id = SYS_waitid;
    printf(
            "Invoking waitid [syscall %d]\n"
            "\t type=%d id=%d\n"
            "\t rec_si=%p\n"
            "\t options=%#x\n"
            "\t rec_ru=%p\n",
            syscall_id,
            id_type,
            id,
            sip,
            options,
            rup);
    errno = 0;
    long res = syscall( syscall_id,
                        id_type,
                        id,
                        sip,
                        options,
                        rup);
    printf("waitid syscall returned %ld %m\n", res);
    return res;
}

static _Bool pref(char const *arg, char const *cmd) {
    int la = strlen(arg);
    int lc = strlen(cmd);
    int min_len = 4;
    if (la<min_len || la > lc) return 0;
    return memcmp(arg,cmd,la) == 0;
}

typedef enum wm {
    wm_ignore = 0,
    wm_wait,
    wm_waitpid,
    wm_wait3,
    wm_wait4,
    wm_waitid,
    wm_waitid5
} waitmode_t;

int main(int argc, char**argv) {
    char **argp, *arg;

    _Bool with_siginfo = 1;
    _Bool with_rusage = 1;
    _Bool with_ex = 1;
    waitmode_t wm = wm_wait;
    int options = 0;

    for(argp=argv+1;arg = *argp;++argp) {
        if (pref(arg, "--wait"        )) wm = wm_wait;                                                                              else
        if (pref(arg, "--wait3"       )) wm = wm_wait3;                                                                             else
        if (pref(arg, "--wait4"       )) wm = wm_wait4;                                                                             else
        if (pref(arg, "--waitid"      )) wm = wm_waitid;                                                                            else
        if (pref(arg, "--waitid5"     )) wm = wm_waitid5;                                                                           else
        if (pref(arg, "--waitpid"     )) wm = wm_waitpid;                                                                           else
        if (pref(arg, "--wignore"     )) wm = wm_ignore;                                                                            else

        if (pref(arg, "--wdefault"    )) options = 0;                                                                               else

        if (pref(arg, "--wallchildren")) options |=  __WALL;      else if (pref(arg, "--no-wallchildren")) options &=~ __WALL;      else
        if (pref(arg, "--wclone"      )) options |=  __WCLONE;    else if (pref(arg, "--no-wclone"      )) options &=~ __WCLONE;    else
        if (pref(arg, "--wcontinued"  )) options |=  WCONTINUED;  else if (pref(arg, "--no-wcontinued"  )) options &=~ WCONTINUED;  else
        if (pref(arg, "--wexited"     )) options |=  WEXITED;     else if (pref(arg, "--no-wexited"     )) options &=~ WEXITED;     else
        if (pref(arg, "--wnohang"     )) options |=  WNOHANG;     else if (pref(arg, "--no-wnohang"     )) options &=~ WNOHANG;     else
        if (pref(arg, "--wnothread"   )) options |=  __WNOTHREAD; else if (pref(arg, "--no-wnothread"   )) options &=~ __WNOTHREAD; else
        if (pref(arg, "--wnowait"     )) options |=  WNOWAIT;     else if (pref(arg, "--no-wnowait"     )) options &=~ WNOWAIT;     else
        if (pref(arg, "--wstopped"    )) options |=  WSTOPPED;    else if (pref(arg, "--no-wstopped"    )) options &=~ WSTOPPED;    else
        if (pref(arg, "--wuntraced"   )) options |=  WSTOPPED;    else if (pref(arg, "--no-wuntraced"   )) options &=~ WSTOPPED;    else

        if (pref(arg, "--with-siginfo")) with_siginfo = 1;        else if (pref(arg, "--without-siginfo")) with_siginfo = 0;        else
        if (pref(arg, "--with-rusage" )) with_rusage  = 1;        else if (pref(arg, "--without-rusage" )) with_rusage  = 0;        else
        if (pref(arg, "--with-ex"     )) with_ex      = 1;        else if (pref(arg, "--without-ex"     )) with_ex      = 0;        else

        { printf("Invalid option %s\n", arg); return EX_USAGE; }
    }

    pid_t cpid = fork();

    if (cpid<0) { printf("Can't fork; %m\n"); return EX_UNAVAILABLE; }

    if (cpid) {
        printf("parent process is %zu\n", (intmax_t) getpid());
        printf("child process is %zu\n",  (intmax_t) cpid);
        printf("wait mode %u\n",  wm);
        siginfo_t sif;
        memset(&sif, 0, sizeof sif);
        rusage_t rus;
        memset(&rus, 0, sizeof sif);
        int ex = ~0;
        pid_t rpid = ~0;
        _Bool has_rpid = 0;
        _Bool has_errno = 0;

        switch (wm) {
            case wm_ignore: {
                printf("Ignoring subprocess and just exiting\n");
                has_rpid = with_siginfo = with_rusage = 0;
            } break;
            case wm_wait: {
                int r = wait(&ex);
                if (r < 0)
                    with_ex = 0, has_errno = 1;
                else
                    rpid = r, has_rpid = 1;
                printf("wait returned %d, status %04x; %m\n", r, ex);
                with_siginfo = with_rusage = 0;
            } break;
            case wm_waitpid: {
                int r = waitpid(cpid, &ex, options);
                if (r < 0)
                    with_ex = 0, has_errno = 1;
                else
                    rpid = r, has_rpid = 1;
                printf("waitpid returned %d, status %04x; %m\n", r, ex);
                with_siginfo = with_rusage = 0;
            } break;
            case wm_wait3: {
                int r = wait3(&ex, options, with_rusage ? &rus : 0);
                if (r < 0)
                    with_ex = 0, has_errno = 1;
                else
                    rpid = r, has_rpid = 1;
                printf("wait3 returned %d, status %04x; %m\n", r, ex);
                with_siginfo = 0;
            } break;
            case wm_wait4: {
                int r = wait4(cpid, &ex, options, with_rusage ? &rus : 0);
                if (r < 0)
                    with_ex = 0, has_errno = 1;
                else
                    rpid = r, has_rpid = 1;
                printf("wait4 returned %d, status %04x; %m\n", r, ex);
                with_siginfo = 0;
            } break;
            case wm_waitid: {
                long r = waitid(P_PID, cpid, with_siginfo ? &sif : 0, options);
                if (r < 0)
                    with_ex = 0, has_errno = 1;
                printf("waitid returned %ld; %m\n", r);
                with_ex = with_rusage = 0;
            } break;
            case wm_waitid5: {
                long r = waitid5(P_PID, cpid, with_siginfo ? &sif : 0, options, with_rusage ? &rus : 0);
                if (r < 0)
                    with_ex = 0, has_errno = 1;
                printf("waitid5 returned %ld; %m\n", r);
                with_ex = 0;
            } break;
        }
        if (has_errno)
            printf("ERROR: %m\n");
        if (has_rpid)
            printf("RETURNED PID: %u\n", (unsigned int) rpid);
        if (with_ex) {
            printf("EXIT STATUS: %04x\n", ex);
            if (WIFEXITED(ex))
                printf("\texited with status %#x\n", WEXITSTATUS(ex));
            if (WIFSIGNALED(ex))
                printf("\tkilled by signal %#x\n", WTERMSIG(ex));
            if (WCOREDUMP(ex))
                printf("\tcore dumped\n");
            if (WIFSTOPPED(ex))
                printf("\tstopped by signal %#x\n", WSTOPSIG(ex));
            if (WIFCONTINUED(ex))
                printf("\tcontinued\n");
        }
        if (with_siginfo) {
            double const tick_scale = 1.0/sysconf(_SC_CLK_TCK);
            printf("SIGINFO: %p\n", &sif);
            #if 0
            psiginfo(&sif, "S");
            #else
            printf("\tsigno=%u\n",  sif.si_signo);
            printf("\terrno=%u\n",  sif.si_errno);
            printf("\tcode=%u\n",   sif.si_code);
            printf("\tpid=%u\n",    sif.si_pid);
            printf("\tuid=%u\n",    sif.si_uid);
            printf("\tstatus=0x%04x\n", sif.si_status);
            printf("\tstime=%.6f s\n", sif.si_stime * tick_scale);
            printf("\tutime=%.6f s\n", sif.si_utime * tick_scale);
            #endif
        }
        if (with_rusage) {
            printf("RUSAGE: %p\n", &rus);
            printf("\tutime=%.6f\n",     tv2f(rus.ru_utime));
            printf("\tmaxrss=%zd KiB\n", (intmax_t) rus.ru_maxrss);
            printf("\tixrss=%zd KiB  ",  (intmax_t) rus.ru_ixrss);
            printf("\tidrss=%zd KiB  ",  (intmax_t) rus.ru_idrss);
            printf("\tisrss=%zd KiB\n",  (intmax_t) rus.ru_isrss);
            printf("\tminflt=%zd  ",     (intmax_t) rus.ru_minflt);
            printf("\tmajflt=%zd\n",     (intmax_t) rus.ru_majflt);
            printf("\tnswap=%zd\n",      (intmax_t) rus.ru_nswap);
            printf("\tinblock=%zd  ",    (intmax_t) rus.ru_inblock);
            printf("\toublock=%zd\n",    (intmax_t) rus.ru_oublock);
            printf("\tmsgsnd=%zd  ",     (intmax_t) rus.ru_msgsnd);
            printf("\tmsgrcv=%zd\n",     (intmax_t) rus.ru_msgrcv);
            printf("\tnsignals=%zd\n",   (intmax_t) rus.ru_nsignals);
            printf("\tnvcsw=%zd  ",      (intmax_t) rus.ru_nvcsw);
            printf("\tnivcsw=%zd\n",     (intmax_t) rus.ru_nivcsw);
        }
    } else {
        int j = 1000;
        for (int i=0;i<100000000;++i)
            j+=i%j;
        sleep(1);
        _exit(0x1234567);
    }
}
