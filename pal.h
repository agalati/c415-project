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

struct error_msgs;
struct error_msgs
{
  char*               err;
  struct error_msgs*  next;
};

struct error_msgs* err_buf;

int yylex (void);
void lexerror(char const*);
void yyerror (char const *);

// position tracking functions
void update_position(int distance);
void new_position_line(void);

void parse_args(int argc, char** argv);
void usage(void);

void find_line_offsets(void);
char* get_prog_line(int lineno);

void add_err_to_buf(char*);
char* pop_err_from_buf(void);

#endif
