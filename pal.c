#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "pal.h"
#include "pal_gram.tab.h"

int
main (  int     argc,
        char**  argv)
{
  err_buf = NULL;
  parse_args(argc, argv);
  int ret =  yyparse ();
  fclose(stdin);
  fclose(prog_file);
  if (do_listing)
    fclose(lst_file);
  return ret;
}

void
lexerror(char const* invalid)
{
  char* linebuf = get_prog_line(yylloc.first_line);
  fprintf(stderr, "%s\n", linebuf);
  free(linebuf);

  int c = 1;
  for (; c < yylloc.first_column; ++c)
    fprintf(stderr, " ");
  fprintf(stderr, "^\n");

  fprintf(stderr, "Invalid token '%s' on line %d at column %d\n\n", invalid, yylloc.first_line, yylloc.first_column);
  if (do_listing)
  {
    char* err = (char*)malloc(1024*sizeof(char));
    sprintf(err, "##lexer:%d.%d: Invalid token.\n", yylloc.first_line, yylloc.first_column);
    add_err_to_buf(err);
  }
}

void
yyerror (char const *s)
{
  char* linebuf = get_prog_line(yylloc.first_line);
  fprintf(stderr, "%s\n", linebuf);
  free(linebuf);

  int c = 1;
  for (; c < yylloc.first_column; ++c)
    fprintf(stderr, " ");
  fprintf(stderr, "^\n");

  char* pretty = pretty_error(s);
  fprintf(stderr, "Error on line %d at column %d: %s\n\n", yylloc.first_line, yylloc.first_column, pretty);
  if (do_listing)
  {
    char* err = (char*)malloc(1024*sizeof(char));
    sprintf(err, "##parser:%d.%d: %s\n", yylloc.first_line, yylloc.first_column, pretty);
    add_err_to_buf(err);
  }
  free(pretty);
}

void parse_args(int argc, char** argv)
{
  if (argc < 2) usage();
  if (argc > 5) usage();

  prog_file = fopen(argv[argc-1], "r");
  if (!prog_file)
  {
    fprintf(stderr, "Cannot find file %s\n", argv[argc-1]);
    exit(-2);
  }
  find_line_offsets();

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
    // find the last . in the filename, remove the extension, and append .lst to it
    const char* ext = strrchr(argv[argc-1], '.');
    unsigned long stripped_length = (unsigned long)ext - (unsigned long)argv[argc-1];
    char* temp = (char*)malloc((stripped_length+4+1)*sizeof(char));
    strncpy(temp, argv[argc-1], stripped_length);
    temp[stripped_length] = '\0';
    strcat(temp, ".lst");

    char* token  = strtok(temp, "/");
    char* lst_filename = token;
    while (token != NULL)
    {
      lst_filename = token;
      token = strtok(NULL, "/");
    }

    lst_file = fopen(lst_filename, "w");
    if (!lst_file)
    {
      fprintf(stderr, "Cannot open file %s\n", lst_filename);
      exit(-3);
    }

    free(temp);
  }
}

void
usage(void)
{
  printf("pal [options] file\n");
  printf("Options:\n");
  printf("\t-S\tLeave ASC code in file.asc instead of removing it (not implemented)\n");
  printf("\t-n\tDo not produce a program listing.\n");
  printf("\t-a\tDo not generate run-time array subscript bounds checking.\n");
  exit(-1);
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
  if (do_listing)
  {
    char* linebuf = get_prog_line(yylloc.first_line);
    fprintf(lst_file, "%s\n", linebuf);
    free(linebuf);
    linebuf = pop_err_from_buf();
    while (linebuf)
    {
      fprintf(lst_file, "%s", linebuf);
      free(linebuf);
      linebuf = pop_err_from_buf();
    }
  }
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

char* get_prog_line(int lineno)
{
  size_t linesize = line_offsets[lineno]-line_offsets[lineno-1];
  char* linebuf = (char*)malloc(linesize*sizeof(char));
  fseek(prog_file, line_offsets[lineno-1], SEEK_SET);
  fread(linebuf, sizeof(char), linesize, prog_file);
  linebuf[linesize-1] = '\0';
  return linebuf;
}

void add_err_to_buf(char* err)
{
  struct error_msgs* last_err = err_buf;
  if (last_err == NULL)
  {
    err_buf = (struct error_msgs*)malloc(sizeof(struct error_msgs));
    err_buf->err = err;
    err_buf->line = yylloc.first_line;
    err_buf->next = NULL;
  }
  else
  {
    while (last_err->next)
      last_err = last_err->next;
    last_err->next = (struct error_msgs*)malloc(sizeof(struct error_msgs));
    last_err = last_err->next;
    last_err->err = err;
    last_err->line = yylloc.first_line;
    last_err->next = NULL;
  }
}

char* pop_err_from_buf(void)
{
  if (!err_buf)
    return NULL;
  char* ret = err_buf->err;
  struct error_msgs* temp = err_buf->next;
  free(err_buf);
  err_buf = temp;
  return ret;
}

char* pretty_error(const char* s)
{
  char* pretty = (char*)malloc((strlen(s)+1)*sizeof(char));
  strcpy (pretty, s);
  replace_substr(pretty, "ASSIGNMENT", ":=");
  replace_substr(pretty, "EQUALS", "=");
  replace_substr(pretty, "NOT_EQUAL", "<>");
  replace_substr(pretty, "LESS_THAN", "<");
  replace_substr(pretty, "GREATER_THAN", ">");
  replace_substr(pretty, "LESS_EQUAL", "<=");
  replace_substr(pretty, "GREATER_EQUAL", ">=");
  replace_substr(pretty, "PLUS", "+");
  replace_substr(pretty, "MINUS", "-");
  replace_substr(pretty, "MULTIPLY", "*");
  replace_substr(pretty, "DIVIDE", "/");
  replace_substr(pretty, "O_BRACKET", "(");
  replace_substr(pretty, "C_BRACKET", ")");
  replace_substr(pretty, "PERIOD", ".");
  replace_substr(pretty, "S_COLON", ";");
  replace_substr(pretty, "COLON", ":");
  replace_substr(pretty, "O_SBRACKET", "[");
  replace_substr(pretty, "C_SBRACKET", "]");
  replace_substr(pretty, "COMMA", ",");
  replace_substr(pretty, "START_COM", "{");
  replace_substr(pretty, "END_COM", "}");
  replace_substr(pretty, "DDOT", "..");
  return pretty;
}

void replace_substr(char* pretty, const char* substr, const char* replacement)
{
  const char* loc = strstr(pretty, substr);
  if (loc != NULL)
  {
    unsigned long l1 = (unsigned long)loc - (unsigned long)pretty;
    pretty[l1] = '\0';
    strcat(pretty, replacement);
    loc = pretty + strlen(pretty);
    strcat(pretty, loc);
  }
}
