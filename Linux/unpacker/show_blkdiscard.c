#include <inttypes.h>
#include <linux/fs.h>
#include <stdio.h>

int main() {
    printf("discard=%#jx\n", (intmax_t) BLKDISCARD);
    printf("discardzeroes=%#jx\n", (intmax_t) BLKDISCARDZEROES);
}
