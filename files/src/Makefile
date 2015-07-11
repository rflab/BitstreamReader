.PHONY:build rebuild clean help prof

rebuild: clean build ;

clean:
	-rm ../bin/streamreader.out ../bin/gmon.out ../bin/prof.out
	-make clean -C lua
	-make clean -C sqlite

build: ../bin/streamreader.out

../bin/streamreader.out: streamreader.cpp
	mkdir -p ../bin
	make a -C lua
	make a -C sqlite
	g++ -std=c++14 -O2 -Wall -Wextra -I./lua -I./sqlite \
	streamreader.cpp lua/liblua.a sqlite/libsqlite3.a \
	-ldl -o ../bin/streamreader.out
	
prof:
	mkdir -p ../bin
	make a -C lua
	g++ -pg -std=c++14 -ldl -Wall -Wextra -I./lua streamreader.cpp lua/liblua.a -o ../bin/prof.out

help:
	@echo '  build'
	@echo '  rebuild'
	@echo '  clean'
	@echo '  prof'
	@echo '    $$ ./prof.out '
	@echo '    $$ gprof prof.out gmon.out'

