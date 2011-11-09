#ifndef SEMANTICS_H
#define SEMANTICS_H

#include "symtab.h"

void declare_const(char* name, struct sym_rec*);
void declare_type(char* name, struct sym_rec*);
void declare_variable(char* name, struct sym_rec*);

#endif
