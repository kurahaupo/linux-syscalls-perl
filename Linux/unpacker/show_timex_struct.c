#include <sys/types.h>
#include <sys/timex.h>

#include <stddef.h>     /* offsetof */
#include <stdint.h>     /* intmax_t */
#include <stdio.h>      /* printf, stdout, stderr */
#include <string.h>

#undef  PENV_WANT_STAT
#undef  PENV_WANT_LARGEFILE
#undef  PENV_WANT_STAT_VER

//#include "die.h"
//#include "log2ceil.h"
//#include "sxbuf.h"
#include "show_struct.h"

////////////////////////////////////////

void Ptimex(void) {
    puts("");
   #define T struct timex
    Begin();
    F(modes);           /* mode selector */
    F(offset);          /* time offset (usec) */
    F(freq);            /* frequency offset (scaled ppm) */
    F(maxerror);        /* maximum error (usec) */
    F(esterror);        /* estimated error (usec) */
    F(status);          /* clock command/status */
    F(constant);        /* pll time constant */
    F(precision);       /* clock precision (usec) (ro) */
    F(tolerance);       /* clock frequency tolerance (ppm) (ro) */
    Ftimeval(time, ""); /* (read only, except for ADJ_SETOFFSET) */
    F(tick);            /* (modified) usecs between clock ticks */
    F(ppsfreq);         /* pps frequency (scaled ppm) (ro) */
    F(jitter);          /* pps jitter (us) (ro) */
    F(shift);           /* interval duration (s) (shift) (ro) */
    F(stabil);          /* pps stability (scaled ppm) (ro) */
    F(jitcnt);          /* jitter limit exceeded (ro) */
    F(calcnt);          /* calibration intervals (ro) */
    F(errcnt);          /* calibration errors (ro) */
    F(stbcnt);          /* stability limit exceeded (ro) */
    F(tai);             /* TAI offset (ro) */
    End();
   #undef T
}

////////////////////////////////////////////////////////////////////////////////

int main() {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    Ptimex();

    return 0;
}
