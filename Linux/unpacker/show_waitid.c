#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/wait.h>

#include <stddef.h> /* offsetof(T,F) */

#include <stdio.h>
#include <math.h>   /* sin(A) */

#define use_waitid
#define use_wait4

void hexdump(const void *p_, size_t l) {
    const char *p = p_;
    size_t i;
    for (i=0;i<l;++i) {
        if (i%8 == 0) {
            if (i > 0)
                putchar('\n');
            printf("\t%zu\t", i);
            //putchar('\t'), putchar('\t');
        }
        else
            putchar(' ');
        printf("%02hhx", p[i]);
    }
    if (l>0)
        putchar('\n');
    printf("\t%zu\n", l);
}

void show_siginfo(const siginfo_t *s) {
    printf("\tsiginfo\n"
            "\t%zu\t%zu\tsigno=%d\n"
            "\t%zu\t%zu\tcode=%d\n"
            "\t%zu\t%zu\tpid=%d\n"
            "\t%zu\t%zu\tuid=%d\n"
            "\t%zu\t%zu\tstatus=%d\n"
            , offsetof(typeof(*s), si_signo),  sizeof(s->si_signo),  s->si_signo
            , offsetof(typeof(*s), si_code),   sizeof(s->si_code),   s->si_code
            , offsetof(typeof(*s), si_pid),    sizeof(s->si_pid),    s->si_pid
            , offsetof(typeof(*s), si_uid),    sizeof(s->si_uid),    s->si_uid
            , offsetof(typeof(*s), si_status), sizeof(s->si_status), s->si_status
            );
    hexdump(s, sizeof *s);
}

void show_rusage(const struct rusage *r) {
    printf("\trusage\n"
            "\t%zu\t%zu\tru_utime=%.6f\n"
            "\t\t%zu\t%zu\tru_utime.s=%ld\n"
            "\t\t%zu\t%zu\tru_utime.u=%ld\n"

            "\t%zu\t%zu\tru_stime=%.6f\n"
            "\t\t%zu\t%zu\tru_stime.s=%ld\n"
            "\t\t%zu\t%zu\tru_stime.u=%ld\n"

            "\t%zu\t%zu\tru_maxrss=%ld\n"
            "\t%zu\t%zu\tru_ixrss=%ld\n"
            "\t%zu\t%zu\tru_idrss=%ld\n"
            "\t%zu\t%zu\tru_isrss=%ld\n"
            "\t%zu\t%zu\tru_minflt=%ld\n"
            "\t%zu\t%zu\tru_majflt=%ld\n"
            "\t%zu\t%zu\tru_nswap=%ld\n"
            "\t%zu\t%zu\tru_inblock=%ld\n"
            "\t%zu\t%zu\tru_oublock=%ld\n"
            "\t%zu\t%zu\tru_msgsnd=%ld\n"
            "\t%zu\t%zu\tru_msgrcv=%ld\n"
            "\t%zu\t%zu\tru_nsignals=%ld\n"
            "\t%zu\t%zu\tru_nvcsw=%ld\n"
            "\t%zu\t%zu\tru_nivcsw=%ld\n"
            ,

            offsetof(struct rusage, ru_utime),    sizeof(r->ru_utime),    r->ru_utime.tv_sec + 0.000001 * r->ru_utime.tv_usec, /* user CPU time used */
            offsetof(struct rusage, ru_utime.tv_sec),  sizeof(r->ru_utime.tv_sec),  r->ru_utime.tv_sec,
            offsetof(struct rusage, ru_utime.tv_usec), sizeof(r->ru_utime.tv_usec), r->ru_utime.tv_usec,

            offsetof(struct rusage, ru_stime),    sizeof(r->ru_stime),    r->ru_stime.tv_sec + 0.000001 * r->ru_stime.tv_usec, /* system CPU time used */
            offsetof(struct rusage, ru_stime.tv_sec),  sizeof(r->ru_stime.tv_sec),  r->ru_stime.tv_sec,
            offsetof(struct rusage, ru_stime.tv_usec), sizeof(r->ru_stime.tv_usec), r->ru_stime.tv_usec,

            offsetof(struct rusage, ru_maxrss),   sizeof(r->ru_maxrss),   r->ru_maxrss,        /* maximum resident set size */
            offsetof(struct rusage, ru_ixrss),    sizeof(r->ru_ixrss),    r->ru_ixrss,         /* integral shared memory size */
            offsetof(struct rusage, ru_idrss),    sizeof(r->ru_idrss),    r->ru_idrss,         /* integral unshared data size */
            offsetof(struct rusage, ru_isrss),    sizeof(r->ru_isrss),    r->ru_isrss,         /* integral unshared stack size */
            offsetof(struct rusage, ru_minflt),   sizeof(r->ru_minflt),   r->ru_minflt,        /* page reclaims (soft page faults) */
            offsetof(struct rusage, ru_majflt),   sizeof(r->ru_majflt),   r->ru_majflt,        /* page faults (hard page faults) */
            offsetof(struct rusage, ru_nswap),    sizeof(r->ru_nswap),    r->ru_nswap,         /* swaps */
            offsetof(struct rusage, ru_inblock),  sizeof(r->ru_inblock),  r->ru_inblock,       /* block input operations */
            offsetof(struct rusage, ru_oublock),  sizeof(r->ru_oublock),  r->ru_oublock,       /* block output operations */
            offsetof(struct rusage, ru_msgsnd),   sizeof(r->ru_msgsnd),   r->ru_msgsnd,        /* IPC messages sent */
            offsetof(struct rusage, ru_msgrcv),   sizeof(r->ru_msgrcv),   r->ru_msgrcv,        /* IPC messages received */
            offsetof(struct rusage, ru_nsignals), sizeof(r->ru_nsignals), r->ru_nsignals,      /* signals received */
            offsetof(struct rusage, ru_nvcsw),    sizeof(r->ru_nvcsw),    r->ru_nvcsw,         /* voluntary context switches */
            offsetof(struct rusage, ru_nivcsw),   sizeof(r->ru_nivcsw),   r->ru_nivcsw);       /* involuntary context switches */

    hexdump(r, sizeof *r);
}

int main() {
    pid_t pid = fork();
    if (pid<0) return 2;
    if (pid) {
        printf("Fork returned pid=%u\n", pid);
#if defined use_waitid
{
        siginfo_t info = {0};
        int opts = WEXITED
#if defined use_wait4
        | WNOWAIT
#endif
        ;
        int r = waitid(P_PID, pid, &info, opts);
        printf("Invoked waitid\n"
               "\targs     type=%d, id=%d, si=%p, opts=%#x\n",
               P_PID, pid, &info, opts);
        printf("\treturned r=%d errno=%m\n", r);
        show_siginfo(&info);
}
#endif
#if defined use_wait4
{
        int status;
        int opts = 0;
        struct rusage rusage = {0};
        int r = wait4(pid, &status, opts, &rusage);
        printf("Invoked wait4\n"
               "\targs     pid=%d, status=%p, opts=%#x, rusage=%p\n",
               pid, &status, opts, &rusage);
        printf("\treturned r=%d, status=%#x, errno=%m\n", r, status);
        show_rusage(&rusage);
}
#else
#error
#endif
    } else {
        float y = 0;
        int i;
        for (i=0;i<100000;++i)
            y += sin((float)(i % 355));
        sleep(1);
        return 43;
    }
    return 0;
}
