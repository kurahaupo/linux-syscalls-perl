#include <sys/types.h>
#include <sys/timex.h>

#include <stddef.h>     /* offsetof */
#include <stdint.h>     /* intmax_t */
#include <stdio.h>      /* printf, stdout, stderr */
#include <string.h>

#include <linux/rtnetlink.h>    /* what we're testing */

#include "die.h"
#include "show_struct.h"

////////////////////////////////////////

void Pnlmsghdr(void) {
    puts("");

   #define T struct nlmsghdr
    Begin1("nlmsg_");
    F(nlmsg_len);   /* Length of message including header */
    F(nlmsg_type);  /* Message content */
    F(nlmsg_flags); /* Additional flags */
    F(nlmsg_seq);   /* Sequence number */
    F(nlmsg_pid);   /* Sending process port ID */
    End();
   #undef T
}

void Pifinfomsg(void) {
    puts("");

   #define T struct ifinfomsg
    Begin1("ifi_");
    F(ifi_family);
  //F(__ifi_pad);
    F(ifi_type);    /* ARPHRD_* */
    F(ifi_index);   /* Link index   */
    F(ifi_flags);   /* IFF_* flags  */
    F(ifi_change);  /* IFF_* change mask */
    End();
   #undef T
}

struct link_info_request {
    struct nlmsghdr     hdr;
    struct ifinfomsg    ifm;
    char                buf[1024];
};

void Plink_info_request(void) {
    puts("");

   #define T struct link_info_request
    Begin();
    Fblob(hdr);
    Fblob(ifm);
    Fblob2(buf,"array");
    End();
   #undef T
};

////////////////////////////////////////////////////////////////////////////////

int main() {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    Pnlmsghdr();
    Pifinfomsg();
    Plink_info_request();

    return 0;
}
