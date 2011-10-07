#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "pal.h"
#include "pal_gram.tab.h"

void echo_file(void);

int
main (  int     argc,
        char**  argv)
{
  parse_args(argc, argv);
  int ret =  yyparse ();
  fclose(stdin);
  if (do_listing)
    fclose(prog_file);
  return ret;
}

void lexerror(char const* s, char const* invalid)
{
  size_t linesize = line_offsets[yylloc.first_line]-line_offsets[yylloc.first_line-1];
  char* linebuf = (char*)malloc(linesize*sizeof(char));
  fseek(prog_file, line_offsets[yylloc.first_line-1], SEEK_SET);
  fread(linebuf, sizeof(char), linesize, prog_file);
  linebuf[linesize-1] = '\0';

  fprintf(stderr, "%s\n", linebuf);
  free(linebuf);

  int c = 1;
  for (; c < yylloc.first_column; ++c)
    fprintf(stderr, " ");
  fprintf(stderr, "^\n");

  fprintf(stderr, "Invalid character '%s' on line %d at column %d: %s\n\n", yylloc.first_line, yylloc.first_column, s);
}

void
yyerror (char const *s)
{
  if (do_listing)
  {
    size_t linesize = line_offsets[yylloc.first_line]-line_offsets[yylloc.first_line-1];
    char* linebuf = (char*)malloc(linesize*sizeof(char));
    fseek(prog_file, line_offsets[yylloc.first_line-1], SEEK_SET);
    fread(linebuf, sizeof(char), linesize, prog_file);
    linebuf[linesize-1] = '\0';

    printf("%s\n", linebuf);
    free(linebuf);

    int c = 1;
    for (; c < yylloc.first_column; ++c)
      printf(" ");
    printf("^\n");
  }

  printf("Error on line %d at column %d: %s\n\n", yylloc.first_line, yylloc.first_column, s);
}

void parse_args(int argc, char** argv)
{
  if (argc < 2) usage();
  if (argc > 5) usage();

  freopen(argv[argc-1], "r", stdin);
  do_listing = 1;

  int narg;
  char* arg;
  for (narg = 1; narg < argc-1; ++narg)
  {
    arg = argv[narg];
    if (strcmp(arg, "-S") == 0)
      printf("-S option not implemented yet, ignoring...\n");
    else if (strcmp(arg, "-a") == 0)
      printf("-a option not implemented yet, ignoring...\n");
    else if (strcmp(arg, "-n") == 0)
      do_listing = 0;
    else
    {
      printf("Unrecognized option: %s\n", arg);
      usage();
    }
  }

  if (do_listing)
  {
    prog_file = fopen(argv[argc-1], "r");
    find_line_offsets();
    //echo_file();
  }
}

void
usage(void)
{
  printf("Usage:\npal [options] file\n");
  printf("Options:\n");
  printf("\t-S\tLeave ASC code in file.asc instead of removing it (not implemented)\n");
  printf("\t-n\tDo not produce a program listing.\n");
  printf("\t-a\tDo not generate run-time array subscript bounds checking.\n");
  exit(1);
}

void
update_position(int distance)
{
  yylloc.first_column = yylloc.last_column;
  yylloc.last_column += distance;
}

void
new_position_line(void)
{
  yylloc.first_column = 1;
  yylloc.last_column = 1;
  ++yylloc.first_line;
  ++yylloc.last_line;
}

// Go over the file twice, first to count the number of lines,
// and then again to store the line offsets
void
find_line_offsets(void)
{
  rewind(prog_file);
  char c = fgetc(prog_file);
  num_lines = 0;
  while (c != EOF)
  {
    if (c == '\n')
      ++num_lines;
    c = fgetc(prog_file);
  }
  ++num_lines;

  line_offsets = (off_t*)malloc(num_lines*sizeof(off_t));
  fseek(prog_file, 0, SEEK_END);
  line_offsets[num_lines-1] = ftell(prog_file);

  rewind(prog_file);
  line_offsets[0] = 0;
  off_t offset = 0;
  unsigned int lineno = 0;
  c = fgetc(prog_file);
  while(c != EOF)
  {
    ++offset;
    if (c == '\n')
    {
      ++lineno;
      line_offsets[lineno] = offset;
    }
    c = fgetc(prog_file);
  }
}

void echo_file(void)
{
  int i;
  int linesize;
  char* linebuf;
  for (i = 0; i < num_lines-1; ++i)
  {
    linesize = line_offsets[i+1]-line_offsets[i];
    linebuf = (char*)malloc(linesize*sizeof(char));
    fseek(prog_file, line_offsets[i], SEEK_SET);
    fread(linebuf, sizeof(char), linesize, prog_file);
    linebuf[linesize-1] = '\0';
    printf("%s\n", linebuf);
  }
}
