#ifndef SEMANTICS_H
#define SEMANTICS_H

#include "symtab.h"

// set counter to the number of parameters in the parm list 
// of the func / proc (which we can find after parsing ID)
struct plist_t
{
  struct sym_rec* parmlist;
  struct sym_rec* return_type;
  char* name;
  int level;
  int counter;
  int max;
};

struct temp_array_var
{
  struct sym_rec*        var;
  struct temp_array_var* next;
};

int isPREDFunc(struct plist_t* p);
int isSUCCFunc(struct plist_t* p);
int isORDFunc(struct plist_t* p);
int isIOFunc(struct plist_t* p);

int isORDType(struct sym_rec* parm);
int checkIOArg(struct sym_rec* parm);

int isSimpleType(struct sym_rec* type);
int assignment_compatible(struct sym_rec* left, struct sym_rec* right);
int compare_types(struct sym_rec* s, struct sym_rec* t);

void declare_const(char* name, struct sym_rec*);
void declare_type(char* name, struct sym_rec*);
void declare_variable(char* name, struct sym_rec*);

#endif
