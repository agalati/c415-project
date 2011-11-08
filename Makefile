# Authors
#   Matthew Low
#   Anthony Galati 
#   Mike Bujold
#   Stevan Clement
#
# Makefile for pal executable
#
# Compile with: 
#    make
#

CC = gcc
FLAGS =

all: pal

pal: lex/pal.l yacc/pal_gram.y pal.c symtab.c
	flex lex/pal.l
	bison -d yacc/pal_gram.y
	$(CC) $(FLAGS) symtab.c pal.c lex.yy.c pal_gram.tab.c -o pal
	rm -f lex.yy.c pal_gram.tab.c pal_gram.tab.h

debug: lex/pal.l yacc/pal_gram.y pal.c symtab.c
	flex lex/pal.l
	bison -d yacc/pal_gram.y
	$(CC) $(FLAGS) symtab.c pal.c lex.yy.c pal_gram.tab.c -o pal -DDEBUG
	rm -f lex.yy.c pal_gram.tab.c pal_gram.tab.h

debug_sym: lex/pal.l yacc/pal_gram.y pal.c symtab.c
	flex lex/pal.l
	bison -d yacc/pal_gram.y
	$(CC) $(FLAGS) symtab.c pal.c lex.yy.c pal_gram.tab.c -o pal -DDEBUG_SYM
	rm -f lex.yy.c pal_gram.tab.c pal_gram.tab.h


clean:
	rm -f pal
	rm -f lex.yy.c pal_gram.tab.c pal_gram.tab.h
	rm -f *.lst
