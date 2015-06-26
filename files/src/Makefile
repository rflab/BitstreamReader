.PHONY:build rebuild clean help prof

rebuild: clean build ;

clean:
	#-rm a.out
	-rm ../bin/a.out ../bin/gmon.out ../bin/prof.out
	-make clean -C lua

build:
	mkdir -p ../bin
	make a -C lua
	g++ -std=c++14 -ldl -Wall -Wextra -I./lua streamreader.cpp lua/liblua.a -o ../bin/a.out
	#g++ -std=c++14 -ldl -Wall -Wextra -I./lua streamreader.cpp lua/liblua.a

prof:
	mkdir -p ../bin
	make a -C lua
	g++ -pg -std=c++14 -ldl -Wall -Wextra -I./lua streamreader.cpp lua/liblua.a -o ../bin/prof.out
	#./prof.out 
	#gprof prof.out gmon.out

help:
	echo 'build'
	echo 'rebuild'
	echo 'clean'
	echo 'prof -> enable -pg option'