#define no_inline_log2ceil_h
#include "log2ceil.h"

#if 0
#define LM 67

static int log2mod67[] = {
#define L(n) , [((uintmax_t)1 << (n)) % 67] = (n)
    0
    L(0) L(1) L(2) L(3) L(4) L(5) L(6) L(7)
    L(8) L(9) L(10) L(11) L(12) L(13) L(14) L(15)
    L(16) L(17) L(18) L(19) L(20) L(21) L(22) L(23)
    L(24) L(25) L(26) L(27) L(28) L(29) L(30) L(31) L(32) L(33) L(34) L(35) L(36) L(37)
    L(38) L(39) L(40) L(41) L(42) L(43) L(44) L(45) L(46) L(47) L(48) L(49)
    L(50) L(51) L(52) L(53) L(54) L(55) L(56) L(57) L(58) L(59) L(60) L(61)
    L(62) L(63)
#undef L
};
#endif
