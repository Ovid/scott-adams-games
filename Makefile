#
#	Makefile for the thing
#
CC	=	gcc
#
#
ScottCurses:
	$(CC) src/ScottCurses.c src/Scott.h -o bin/ScottCurses -lcurses -ltermcap

all	:	ScottCurses

run: ScottCurses
	./bin/ScottCurses -y adv00
