# very basic - I'll fix it soon

CC = gcc

all: palc

pal: lex/pal.l yacc/pal_gram.y pal.c
	flex lex/pal.l
	bison -d yacc/pal_gram.y
	$(CC) pal.c lex.yy.c pal_gram.tab.c -o pal
	rm -f lex.yy.c pal_gram.tab.c pal_gram.tab.h

clean:
	rm -f pal
