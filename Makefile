# very basic - I'll fix it soon

CC = gcc

all: lpal

lpal: lex/pal.l yacc/pal_gram.y lpal.c
	flex lex/pal.l
	bison -d yacc/pal_gram.y
	$(CC) lpal.c lex.yy.c pal_gram.tab.c -o lpal
	rm -f lex.yy.c pal_gram.tab.c pal_gram.tab.h

clean:
	rm -f lpal
