#ifndef LPAL_H
#define LPAL_H

#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>

FILE* prog_file;
off_t* line_offsets;
unsigned int num_lines;

int yylex (void);
void yyerror (char const *);

// position tracking functions
void update_position(int distance);
void new_position_line(void);

void usage(void);
void find_line_offsets(void);

#endif
