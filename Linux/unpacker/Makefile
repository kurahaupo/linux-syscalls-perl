# vim: set ts=8 :

all: show_stat_struct show_timex_struct

test_one::
	$$PWD/show_stat_struct.bash -1 show_timex_struct show_stat_struct

test::
	$$PWD/show_stat_struct.bash    show_timex_struct show_stat_struct

clean::
	rm -fv die.o getlink.o log2ceil.o perl_unpack.o show_stat_struct.o show_struct.o sxbuf.o

show_stat_struct:       show_stat_struct.o getlink.o log2ceil.o perl_unpack.o show_struct.o sxbuf.o die.o
	$(CC) $(CFLAGS) show_stat_struct.o getlink.o log2ceil.o perl_unpack.o show_struct.o sxbuf.o die.o $(LDFLAGS) -o $@

show_stat_struct.o: die.h
show_stat_struct.o: getlink.h
show_stat_struct.o: log2ceil.h
show_stat_struct.o: perl_unpack.h
show_stat_struct.o: show_struct.h
show_stat_struct.o: sxbuf.h

show_timex_struct: show_timex_struct.o getlink.o log2ceil.o perl_unpack.o show_struct.o sxbuf.o die.o
	$(CC) $(CFLAGS) show_timex_struct.o getlink.o log2ceil.o perl_unpack.o show_struct.o sxbuf.o die.o $(LDFLAGS) -o $@

show_timex_struct.o: die.h
show_timex_struct.o: getlink.h
show_timex_struct.o: log2ceil.h
show_timex_struct.o: perl_unpack.h
show_timex_struct.o: show_struct.h
show_timex_struct.o: sxbuf.h

die.o: die.c
die.o: die.h
getlink.o: getlink.c
getlink.o: getlink.h
log2ceil.o: log2ceil.c
log2ceil.o: log2ceil.h
perl_unpack.o: log2ceil.h
perl_unpack.o: perl_unpack.h
show_struct.o: die.h
show_struct.o: log2ceil.h
show_struct.o: perl_unpack.h
show_struct.o: show_struct.h
show_struct.o: sxbuf.h
sxbuf.o: die.h
sxbuf.o: log2ceil.h
sxbuf.o: sxbuf.c
sxbuf.o: sxbuf.h
