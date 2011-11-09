#ifndef SEMANTICS_H
#define SEMANTICS_H

#include "symtab.h"

// set counter to the number of parameters in the parm list 
// of the func / proc (which we can find after parsing ID)
struct plist_t
{
  struct sym_rec* parmlist;
  int counter;
};

void declare_const(char* name, struct sym_rec*);
void declare_type(char* name, struct sym_rec*);
void declare_variable(char* name, struct sym_rec*);

#endif
