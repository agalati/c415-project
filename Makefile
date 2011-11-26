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
FLAGS = -g

GRAMMAR = yacc/pal_gram.y
GRAMMAR_C = pal_gram.tab.c
LEXICAL = lex/pal.l
LEXICAL_C = lex.yy.c
SOURCES = pal.c symtab.c semantics.c

all: pal

pal: ${GRAMMAR} ${LEXICAL} ${SOURCES}
	flex ${LEXICAL}
	bison -d ${GRAMMAR}
	$(CC) $(FLAGS) ${GRAMMAR_C} ${LEXICAL_C} ${SOURCES} -o pal
	rm -f lex.yy.c pal_gram.tab.c pal_gram.tab.h

debug: ${GRAMMAR} ${LEXICAL} ${SOURCES}
	flex ${LEXICAL}
	bison -d ${GRAMMAR}
	$(CC) $(FLAGS) ${GRAMMAR_C} ${LEXICAL_C} ${SOURCES} -o pal -DDEBUG
	rm -f lex.yy.c pal_gram.tab.c pal_gram.tab.h

debug_sym: ${GRAMMAR} ${LEXICAL} ${SOURCES}
	flex ${LEXICAL}
	bison -d ${GRAMMAR}
	$(CC) $(FLAGS) ${GRAMMAR_C} ${LEXICAL_C} ${SOURCES} -o pal -DDEBUG_SYM
	rm -f lex.yy.c pal_gram.tab.c pal_gram.tab.h

clean:
	rm -f pal
	rm -f lex.yy.c pal_gram.tab.c pal_gram.tab.h
	rm -f *.lst
	rm -f *.asc
