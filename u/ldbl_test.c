#include <stdio.h>
#include <math.h>
#include <time.h>

#ifndef _tx
#define _tx 2
#endif

#if _tx==1
#define DT   long double
#define DF "Lf"

#elif _tx==2
#define DT   double
#define DF "f"

#elif _tx==3
#define DT   float
#define DF "f"

#elif _tx==4
#define DT   __float128
#define DF "Qf"

#elif _tx==5
#define DT   __float80
#define DF "Lf"

#elif _tx==6
#define DT   __float64
#define DF "f"

#elif _tx==7
#define DT   __float32
#define DF "hf"

#elif _tx==8
#define DT   __float16
#define DF "hhf"

#elif _tx==9
#define DT   _Float128
#define DF "Qf"

#elif _tx==10
#define DT   _Float80
#define DF "Lf"

#elif _tx==11
#define DT   _Float64
#define DF "f"

#elif _tx==12
#define DT   _Float32
#define DF "hf"

#elif _tx==13
#define DT   _Float16
#define DF "hhf"

#elif _tx==14
#define DT   _Float128x
#define DF "Qf"

#elif _tx==15
#define DT   _Float80x
#define DF "Lf"

#elif _tx==16
#define DT   _Float64x
#define DF "f"

#elif _tx==17
#define DT   _Float32x
#define DF "hf"

#elif _tx==18
#define DT   _Float16x
#define DF "hhf"

#else
#error Unknown type parameter _tx
#endif

#define S2(X) S1(X)
#define S1(X) #X
#define DN S2(DT)

typedef DT DX;

void hexdump(void*pp, size_t n) {
    typedef unsigned char C;
    C *p = pp;
    for (int i=0;i<n;++i) {
        if (i && i%4==0) putchar(' ');
        printf(" %02x", p[i]);
    }
}

int main(int argc,char**argv) {
    for (int i=0;i<128;++i) {
        DX a = ldexpl(1.0L, i);
        DX b = a+1;
        printf("%-20s %3d  %-8s  | ", DN, i, a == b ? "same" : "distinct");
        //printf("%3d  %30."DF"  %-8s  %-30."DF"  ", i, a, a == b ? "same" : "distinct", b);
        hexdump(&a, sizeof a);
        printf("  | ");
        hexdump(&b, sizeof a);
        char buf[32];
        time_t c = -a / 1E6;
        strftime(buf, sizeof buf, "%F %T", gmtime(&c));
        printf("  | %s", buf);
        time_t d = a / 1E6;
        strftime(buf, sizeof buf, "%F %T %z", gmtime(&d));
        printf("  | %s", buf);
        putchar('\n');
        if (a==b) break;
    }
    return 0;
}
