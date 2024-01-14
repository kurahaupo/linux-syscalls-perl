#include <sys/types.h>
#include <sys/timex.h>

#include <stddef.h>         /* offsetof */
#include <stdint.h>         /* intmax_t */
#include <stdio.h>          /* printf, stdout, stderr */
#include <string.h>

#include <linux/stddef.h>   /* required by <linux/ip.h> */
#include <linux/ip.h>       /* what we're testing */

#include "die.h"
#include "show_struct.h"

void Piphdr(void) {
    puts("");
   #define T struct iphdr
    Begin();
    Field(&tracker, 0, 1, 1, FM_unsigned, "ihl:4, version:4",
          "/* unpack into ihl with \"C\", then decode as version = ihl>>4, ihl&=15 */");
    /*    __u8  ihl:4,
     *          version:4; */
    F(tos);
    F(tot_len);
    F(id);
    F(frag_off);
    F(ttl);
    F(protocol);
    F(check);
    F(saddr);
    F(daddr);
    End();
   #undef T
}

void Pip_auth_hdr(void) {
    puts("");
   #define T struct ip_auth_hdr
    Begin();
    F(nexthdr);
    F(hdrlen);           /* This one is measured in 32 bit units! */
 // F(reserved);
    F(spi);
    F(seq_no);          /* Sequence number */
    FA(auth_data);     /* Variable len but >=4. Mind the 64 bit alignment! */
    End();
   #undef T
}

void Pip_esp_hdr(void) {
    puts("");
   #define T struct ip_esp_hdr
    Begin();


    F(spi);
    F(seq_no);          /* Sequence number */
    FA(enc_data);      /* Variable len but >=8. Mind the 64 bit alignment! */

    End();
   #undef T
}


void Pip_comp_hdr(void) {
    puts("");
   #define T struct ip_comp_hdr
    Begin();
    F(nexthdr);
    F(flags);
    F(cpi);
    End();
   #undef T
}


void Pip_beet_phdr(void) {
    puts("");
   #define T struct ip_beet_phdr
    Begin();
    F(nexthdr);
    F(hdrlen);
    F(padlen);
 // F(reserved);
    End();
   #undef T
}
int main() {
    Piphdr();
    Pip_auth_hdr();
    Pip_esp_hdr();
    Pip_comp_hdr();
    Pip_beet_phdr();

}

/*

void P(void) {
    puts("");
   #define T
    Begin();

    End();
   #undef T
}


*/
