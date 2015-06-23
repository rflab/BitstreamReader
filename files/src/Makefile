.PHONY:build rebuild clean

rebuild: clean build ;

build:
    mkdir ../bin
	make a -C lua
	g++ -std=c++11 -ldl -Wall -Wextra -I./lua streamreader.cpp lua/liblua.a -o ../bin/a.out

clean:
	-rm ../bin/a.out
	-make clean -C lua