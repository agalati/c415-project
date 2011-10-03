#ifndef LPAL_H
#define LPAL_H

int yylex (void);
void yyerror (char const *);

// position tracking functions
void update_position(int distance);
void new_position_line(void);

#endif
