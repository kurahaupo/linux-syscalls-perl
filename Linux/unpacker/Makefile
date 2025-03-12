# vim: set ts=8 :

CFLAGS += -I../../../iproute2/include/uapi -I../../../../iproute2/include/uapi -D_DEFAULT_SOURCE=1 -I/mnt/sda6/usr/include -g

all::	linux-exit-status-test-c
all::	show_dirent_struct
all::	show_if_link
all::	show_ifinfomsg_struct
all::	show_msghdr_struct
all::	show_stat_struct
all::	show_statvfs_struct
all::	show_timex_struct
all::	show_waitid

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

show_if_link:           show_if_link.o die.o
	$(CC) $(CFLAGS) show_if_link.o die.o $(LDFLAGS) -o $@

show_ifinfomsg_struct:  show_ifinfomsg_struct.o die.o
	$(CC) $(CFLAGS) show_ifinfomsg_struct.o die.o $(LDFLAGS) -o $@

show_ip:  show_ip.o die.o
	$(CC) $(CFLAGS) show_ip.o die.o $(LDFLAGS) -o $@

show_ipv6:  show_ipv6.o die.o
	$(CC) $(CFLAGS) show_ipv6.o die.o $(LDFLAGS) -o $@

show_msghdr_struct:     show_msghdr_struct.o show_struct.o sxbuf.o die.o
	$(CC) $(CFLAGS) show_msghdr_struct.o show_struct.o sxbuf.o die.o $(LDFLAGS) -o $@

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
show_if_link.o: die.h
show_if_link.o: log2ceil.h
show_if_link.o: show_if_link.c
show_if_link.o: show_struct.h
show_if_link.o: sxbuf.h
show_ifinfomsg_struct.o: die.h
show_ifinfomsg_struct.o: log2ceil.h
show_ifinfomsg_struct.o: show_ifinfomsg_struct.c
show_ifinfomsg_struct.o: show_struct.h
show_ifinfomsg_struct.o: sxbuf.h
show_ip.o: die.h
show_ip.o: log2ceil.h
show_ip.o: show_ip.c
show_ip.o: show_struct.h
show_ip.o: sxbuf.h
show_ipv6.o: die.h
show_ipv6.o: log2ceil.h
show_ipv6.o: show_ipv6.c
show_ipv6.o: show_struct.h
show_ipv6.o: sxbuf.h
show_msghdr_struct.o: die.h
show_msghdr_struct.o: log2ceil.h
show_msghdr_struct.o: show_msghdr_struct.c
show_msghdr_struct.o: show_struct.h
show_msghdr_struct.o: sxbuf.h
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
