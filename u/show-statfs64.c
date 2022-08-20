#define _LARGEFILE64_SOURCE /* enables __USE_LARGEFILE64, which in turn enables struct statfs64; see <features.h> */

#include <sys/statfs.h>
#include <sys/types.h>

#include <stddef.h> /* offsetof */
#include <stdio.h>

#define SS statfs64

#define STRX(X) #X
#define STR(X) STRX(X)

#define pr_info(E) \
        printf(" @%-3zu   .%-13s  %4zu bytes\n", \
                offsetof(struct SS, E), \
                STR(E), \
                sizeof(((struct SS*)0)->E))

int main(int c,char**v){
  printf("\nstruct %-15s  %4zu bytes\n", STR(SS), sizeof(struct SS));

  pr_info(f_type);
  pr_info(f_bsize);
  pr_info(f_blocks);
  pr_info(f_bfree);
  pr_info(f_bavail);
  pr_info(f_files);
  pr_info(f_ffree);
  pr_info(f_fsid);
  pr_info(f_namelen);
  pr_info(f_frsize);
  pr_info(f_flags);
  pr_info(f_spare);

  return 0;
}
