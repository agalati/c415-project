/* pal.h
 *
 * Defines function names and shared variables.
 *
 * Authors
 *   - Matthew Low
 *   - Anthony Galati
 *   - Mike Bujold
 *   - Stevan Clement
 */

#ifndef LPAL_H
#define LPAL_H

#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>

FILE* prog_file;
FILE* lst_file;

off_t* line_offsets;
unsigned int num_lines;

int do_listing;
int leave_asc;
int bounds_checking;

struct error_msgs;
struct error_msgs
{
  char*               err;
  int                 line;
  struct error_msgs*  next;
};

struct error_msgs* err_buf;

int yylex (void);
void semantic_error(char const*);
void lexerror(char const*);
void unterminated_string(void);
void illegal_string(void);
void yyerror (char const *);

int ID_or_reserved(char const*);

// position tracking functions
void update_position(int distance);
void new_position_line(void);

void parse_args(int argc, char** argv);
void usage(void);

void find_line_offsets(void);
char* get_prog_line(int lineno);

void add_err_to_buf(char*);
char* pop_err_from_buf(void);

char* pretty_error(const char*);
void replace_substr(char* pretty, const char* substr, const char* replacement);

void cleanasc( char* filename);

/* String Chomp */
int schomp(char *s);

char* get_new_file_ext(char* filename, const char* new_ext);

#endif
