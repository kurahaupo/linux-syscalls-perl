# vim: set ts=8 :

CFLAGS += -g

all: linux-exit-status-test-c show_dirent_struct show_stat_struct show_statvfs_struct show_timex_struct show_waitid

test_one::
	$$PWD/show_stat_struct.bash -1 show_timex_struct show_stat_struct

test::
	$$PWD/show_stat_struct.bash    show_timex_struct show_stat_struct

clean::
	rm -fv *.o linux-exit-status-test-c show_*_struct show_waitid

linux-exit-status-test-c: linux-exit-status-test-c.o
	$(CC) $(CFLAGS) linux-exit-status-test-c.o $(LDFLAGS) -o $@

show_dirent_struct:     show_dirent_struct.o
	$(CC) $(CFLAGS) show_dirent_struct.o $(LDFLAGS) -o $@

show_stat_struct:       show_stat_struct.o getlink.o log2ceil.o show_struct.o sxbuf.o die.o
	$(CC) $(CFLAGS) show_stat_struct.o getlink.o log2ceil.o show_struct.o sxbuf.o die.o $(LDFLAGS) -o $@

show_statvfs_struct:    show_statvfs_struct.o
	$(CC) $(CFLAGS) show_statvfs_struct.o $(LDFLAGS) -o $@

show_struct:            show_struct.o
	$(CC) $(CFLAGS) show_struct.o $(LDFLAGS) -o $@

show_timex_struct:      show_timex_struct.o log2ceil.o show_struct.o sxbuf.o die.o
	$(CC) $(CFLAGS) show_timex_struct.o log2ceil.o show_struct.o sxbuf.o die.o $(LDFLAGS) -o $@

show_waitid:            show_waitid.o
	$(CC) $(CFLAGS) show_waitid.o -lm $(LDFLAGS) -o $@

die.o: die.c
die.o: die.h
getlink.o: die.h
getlink.o: getlink.c
getlink.o: getlink.h
linux-exit-status-test-c.o: linux-exit-status-test-c.c
log2ceil.o: log2ceil.c
log2ceil.o: log2ceil.h
show_dirent_struct.o: show_dirent_struct.c
show_stat_struct.o: die.h
show_stat_struct.o: getlink.h
show_stat_struct.o: log2ceil.h
show_stat_struct.o: show_stat_struct.c
show_stat_struct.o: show_struct.h
show_stat_struct.o: sxbuf.h
show_statvfs_struct.o: show_statvfs_struct.c
show_struct.o: die.h
show_struct.o: log2ceil.h
show_struct.o: show_struct.c
show_struct.o: show_struct.h
show_struct.o: sxbuf.h
show_timex_struct.o: die.h
show_timex_struct.o: log2ceil.h
show_timex_struct.o: show_struct.h
show_timex_struct.o: show_timex_struct.c
show_timex_struct.o: sxbuf.h
show_waitid.o: show_waitid.c
sxbuf.o: die.h
sxbuf.o: log2ceil.h
sxbuf.o: sxbuf.c
sxbuf.o: sxbuf.h
