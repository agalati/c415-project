#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lpal.h"
#include "pal_gram.tab.h"

void
yyerror (char const *s)
{
  printf("\n");
  int c = 1;
  for (; c < yylloc.first_column; ++c)
    printf(" ");
  printf("^\n");
  printf("Error on line %d at column %d: %s\n", yylloc.first_line, yylloc.first_column, s);
}

void usage()
{
  printf("lpal <srcfile>\n\n");
}

void update_position(int distance)
{
  yylloc.first_column = yylloc.last_column;
  yylloc.last_column += distance;
}

void new_position_line(void)
{
  yylloc.first_column = 1;
  yylloc.last_column = 1;
  ++yylloc.first_line;
  ++yylloc.last_line;
}

int
main (  int     argc,
        char**  argv)
{
  if (argc < 2) usage();
  // for now, until we actually parse the other options
  if (argc > 2) usage();

  // assume the arg passed was the file to compile
  freopen(argv[1], "r", stdin);
  int ret =  yyparse ();
  fclose(stdin);
  return ret;
}
