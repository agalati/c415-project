/* pal.c
 *
 * This file contains current C code shared between the lex
 * and grammar files. It also contains the main() function.
 *
 * Authors
 *   - Matthew Low
 *   - Anthony Galati
 *   - Mike Bujold
 *   - Stevan Clement
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "codegen.h"
#include "pal.h"
#include "pal_gram.tab.h"
#include "symtab.h"

int
main (  int     argc,
        char**  argv)
{
  err_buf = NULL;
  leave_asc = 0;
  bounds_checking = 1;

  parse_args(argc, argv);
  sym_tab_init();
  
  char* ascname = get_new_file_ext(argv[argc-1], ".asc");
  asc_file = fopen(ascname, "w");
  
  int ret =  yyparse ();
  //printsym();
  new_position_line();
  fclose(stdin);
  fclose(prog_file);
  fclose(asc_file);
  if (do_listing)
    fclose(lst_file);
  // pipe to asc interpreter before removing
  if(!leave_asc)
	  cleanasc(ascname);
  free(ascname);

  return ret;
}

void semantic_error(char const* errmsg)
{
  char* linebuf = get_prog_line(yylloc.first_line);
  fprintf(stderr, "%s", linebuf);
  free(linebuf);

  fprintf(stderr, "Semantic error on line %d: %s\n\n", yylloc.first_line, errmsg);
  if (do_listing)
  {
    char* err = (char*)malloc(1024*sizeof(char));
    sprintf(err, "##semantic:%d: %s\n", yylloc.first_line, errmsg);
    add_err_to_buf(err);
  }
}

void
lexerror(char const* invalid)
{
  char* linebuf = get_prog_line(yylloc.first_line);
  fprintf(stderr, "%s", linebuf);
  free(linebuf);

  fprintf(stderr, "Invalid token '%s' on line %d\n\n", invalid, yylloc.first_line);
  if (do_listing)
  {
    char* err = (char*)malloc(1024*sizeof(char));
    sprintf(err, "##lexer:%d: Invalid token.\n", yylloc.first_line);
    add_err_to_buf(err);
  }
}

void
unterminated_string(void)
{
  char* linebuf = get_prog_line(yylloc.first_line);
  fprintf(stderr, "%s", linebuf);
  free(linebuf);

  fprintf(stderr, "Unterminated string on line %d\n\n", yylloc.first_line);
  if (do_listing)
  {
    char* err = (char*)malloc(1024*sizeof(char));
    sprintf(err, "##lexer:%d: Unterminated string.\n", yylloc.first_line);
    add_err_to_buf(err);
  }
}

void
illegal_string(void)
{
  char* linebuf = get_prog_line(yylloc.first_line);
  fprintf(stderr, "%s", linebuf);
  free(linebuf);

  fprintf(stderr, "Illegal string on line %d\n\n", yylloc.first_line);
  if (do_listing)
  {
    char* err = (char*)malloc(1024*sizeof(char));
    sprintf(err, "##lexer:%d: Illegal string.\n", yylloc.first_line);
    add_err_to_buf(err);
  }
}

void
yyerror (char const *s)
{
  char* linebuf = get_prog_line(yylloc.first_line);
  fprintf(stderr, "%s", linebuf);
  free(linebuf);

  char* pretty = pretty_error(s);
  fprintf(stderr, "Error on line %d: %s\n\n", yylloc.first_line, pretty);
  if (do_listing)
  {
    char* err = (char*)malloc(1024*sizeof(char));
    sprintf(err, "##parser:%d: %s\n", yylloc.first_line, pretty);
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
		leave_asc = 1;
    else if (strcmp(arg, "-a") == 0){
		bounds_checking = 0;
		stop_boundscheck();
    } else if (strcmp(arg, "-n") == 0)
      do_listing = 0;
    else
    {
      printf("Unrecognized option: %s\n", arg);
      usage();
    }
  }

  if (do_listing)
  {
    char* lst_filename = get_new_file_ext(argv[argc-1], ".lst");

    lst_file = fopen(lst_filename, "w");
    if (!lst_file)
    {
      fprintf(stderr, "Cannot open file %s\n", lst_filename);
      exit(-3);
    }

    free(lst_filename);
  }
}

void
usage(void)
{
  printf("pal [options] file\n");
  printf("Options:\n");
  printf("\t-S\tLeave ASC code in file.asc instead of removing it. \n");
  printf("\t-n\tDo not produce a program listing.\n");
  printf("\t-a\tDo not generate run-time array subscript bounds checking.\n");
  exit(-1);
}

int
ID_or_reserved(char const* s)
{
  if (strcmp(s, "and") == 0)
    return AND;
  else if (strcmp(s, "array") == 0)
    return ARRAY;
  else if (strcmp(s, "begin") == 0)
    return P_BEGIN;
  else if (strcmp(s, "const") == 0)
    return CONST;
  else if (strcmp(s, "true") == 0)
    return BOOL;
  else if (strcmp(s, "false") == 0)
    return BOOL;
  else if (strcmp(s, "continue") == 0)
    return CONTINUE;
  else if (strcmp(s, "div") == 0)
  {
    fprintf(stderr, "div found!\n");
    return DIV;
  }
  else if (strcmp(s, "do") == 0)
    return DO;
  else if (strcmp(s, "else") == 0)
    return ELSE;
  else if (strcmp(s, "end") == 0)
    return END;
  else if (strcmp(s, "exit") == 0)
    return EXIT;
  else if (strcmp(s, "function") == 0)
    return FUNCTION;
  else if (strcmp(s, "if") == 0)
    return IF;
  else if (strcmp(s, "mod") == 0)
    return MOD;
  else if (strcmp(s, "not") == 0)
    return NOT;
  else if (strcmp(s, "of") == 0)
    return OF;
  else if (strcmp(s, "or") == 0)
    return OR;
  else if (strcmp(s, "procedure") == 0)
    return PROCEDURE;
  else if (strcmp(s, "program") == 0)
    return PROGRAM;
  else if (strcmp(s, "record") == 0)
    return RECORD;
  else if (strcmp(s, "then") == 0)
    return THEN;
  else if (strcmp(s, "type") == 0)
    return TYPE;
  else if (strcmp(s, "var") == 0)
    return VAR;
  else if (strcmp(s, "while") == 0)
    return WHILE;

  return ID;
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
    if (linebuf != "")
      fprintf(lst_file, "%s", linebuf);
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

  line_offsets = (off_t*)malloc((num_lines+1)*sizeof(off_t));
  fseek(prog_file, 0, SEEK_END);
  line_offsets[num_lines] = ftell(prog_file);

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
  ++lineno;
  line_offsets[lineno] = offset;
}

char* get_prog_line(int lineno)
{
  size_t linesize = line_offsets[lineno]-line_offsets[lineno-1];
  char* linebuf = (char*)malloc((linesize+1)*sizeof(char));
  fseek(prog_file, line_offsets[lineno-1], SEEK_SET);
  fread(linebuf, sizeof(char), linesize, prog_file);
  linebuf[linesize] = '\0';
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

char* get_new_file_ext(char* filename, const char* new_ext)
{
  // find the last . in the filename, remove the extension, and append .lst to it
  const char* ext = strrchr(filename, '.');
  unsigned long stripped_length = (unsigned long)ext - (unsigned long)filename;
  char* temp = (char*)malloc((stripped_length+strlen(new_ext)+1)*sizeof(char));
  strncpy(temp, filename, stripped_length);
  temp[stripped_length] = '\0';
  strcat(temp, new_ext);

  char* token  = strtok(temp, "/");
  char* new_filename = token;
  while (token != NULL)
  {
    new_filename = token;
    token = strtok(NULL, "/");
  }

  char* ret = (char*)malloc((1+strlen(new_filename))*sizeof(char));
  strcpy(ret, new_filename);

  free(temp);
  return ret;
}

void cleanasc(char* filename)
{
	if( remove( filename ) != 0 )
		printf( "Error cleaning asc file %s", filename );
}
