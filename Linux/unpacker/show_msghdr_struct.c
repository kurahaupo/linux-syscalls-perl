#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/socket.h>

#include <math.h>   /* sin(A) */
#include <stddef.h> /* offsetof(T,F) */
#include <stdio.h>
#include <string.h> /* strlen(S) */

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

void show_iovec(const struct iovec *v) {
    printf("iovec\n"
            "\t%zu\t%zu\tbase=%p\n"
            "\t%zu\t%zu\tlen=%zu\n"
            "\t(%zu total size)\n"
            , offsetof(typeof(*v), iov_base),  sizeof(v->iov_base),  v->iov_base
            , offsetof(typeof(*v), iov_len),   sizeof(v->iov_len),   v->iov_len
            , sizeof(*v));
    hexdump(v, sizeof *v);
        putchar('\n');
}

void show_msghdr(const struct msghdr *m) {
    printf("msghdr\n"
            "\t%zu\t%zu\tmsg_name=%p\n"
            "\t%zu\t%zu\tmsg_namelen=%u\n"
            "\t%zu\t%zu\tmsg_iov=%p\n"
            "\t%zu\t%zu\tmsg_iovlen=%zu\n"
            "\t%zu\t%zu\tmsg_control=%p\n"
            "\t%zu\t%zu\tmsg_controllen=%zu\n"
            "\t%zu\t%zu\tmsg_flags=%#x\n"
            "\t(%zu total size)\n"
            , offsetof(typeof(*m), msg_name),          sizeof(m->msg_name),        m->msg_name
            , offsetof(typeof(*m), msg_namelen),       sizeof(m->msg_namelen),     m->msg_namelen
            , offsetof(typeof(*m), msg_iov),           sizeof(m->msg_iov),         m->msg_iov
            , offsetof(typeof(*m), msg_iovlen),        sizeof(m->msg_iovlen),      m->msg_iovlen
            , offsetof(typeof(*m), msg_control),       sizeof(m->msg_control),     m->msg_control
            , offsetof(typeof(*m), msg_controllen),    sizeof(m->msg_controllen),  m->msg_controllen
            , offsetof(typeof(*m), msg_flags),         sizeof(m->msg_flags),       m->msg_flags
            , sizeof(*m));

    hexdump(m, sizeof *m);
        putchar('\n');
}

int main() {

{
    struct iovec iv = {0};
    show_iovec(&iv);

    iv.iov_base = "Hello world";
    iv.iov_len = strlen(iv.iov_base);
    show_iovec(&iv);
}


{
    struct msghdr msghdr = {0};
    show_msghdr(&msghdr);
}
    return 0;
}
