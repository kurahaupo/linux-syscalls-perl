#include <sys/statvfs.h>
#include <sys/types.h>

#include <stddef.h> /* offsetof */
#include <stdio.h>

#define SS statvfs

#define STRX(X) #X
#define STR(X) STRX(X)

#define pr_info(E) \
        printf(" @%-3zu   .%-13s  %4zu bytes\n", \
                offsetof(struct SS, E), \
                STR(E), \
                sizeof(((struct SS*)0)->E))

int main(int c,char**v){
  printf("\nstruct %-15s  %4zu bytes\n", STR(SS), sizeof(struct SS));
  pr_info(f_bsize);    /* Filesystem block size */
  pr_info(f_frsize);   /* Fragment size */
  pr_info(f_blocks);   /* Size of fs in f_frsize units */
  pr_info(f_bfree);    /* Number of free blocks */
  pr_info(f_bavail);   /* Number of free blocks for unprivileged users */
  pr_info(f_files);    /* Number of inodes */
  pr_info(f_ffree);    /* Number of free inodes */
  pr_info(f_favail);   /* Number of free inodes for unprivileged users */
  pr_info(f_fsid);     /* Filesystem ID */
  pr_info(f_flag);     /* Mount flags */
  pr_info(f_namemax);  /* Maximum filename length */
  pr_info(__f_spare);  /* padding */


  return 0;
}
