.PHONY:build rebuild clean

rebuild: build clean ;

build:
	make a -C lua
	g++ -std=c++11 -ldl -I./lua streamreader.cpp lua/liblua.a
#-lstdc++ -lm 

clean:
	-rm a.out
	-make clean -C lua