#include <stdlib.h>
#include <unistd.h>

#include "getlink.h"
#include "die.h"

#define SZ 4096 /* universal string buffer */

char const * getlink(char const* p) {
    static char linkname[SZ];

    ssize_t r = readlink(p, linkname, SZ);
    if (r>=0 && r<SZ) {
        linkname[r] = 0;
        return linkname;
    }

    return NULL;

//  if (errno == EINVAL)
//      return "(not a link)";

//  r = snprintf(linkname, SZ-1, "Error reading link %s; %m", p);
//  if (r>=0 && r<SZ) {
//      linkname[r] = 0;
//      return linkname;
//  }

    pdie(2, "snprintf");
}
