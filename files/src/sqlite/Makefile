.PHONY:clean a help

rebuild: clean a ;

clean:
	-rm libsqlite3.a sqlite3.o
	
a: libsqlite3.a

libsqlite3.a: sqlite3.c
	gcc -std=gnu99 -O2 -DSQLITE_THREADSAFE=0 sqlite3.c -ldl -c -o sqlite3.o
	ar r libsqlite3.a sqlite3.o

help:
	echo 'build'
	echo 'rebuild'
	echo 'clean'

