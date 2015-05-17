.PHONY:build rebuild clean

rebuild: clean build ;

build:
	make a -C lua
	g++ -std=c++11 -ldl -Wall -Wextra -I./lua streamreader.cpp lua/liblua.a 

clean:
	-rm a.out
	-make clean -C lua