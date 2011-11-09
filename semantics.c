#include <stdlib.h>
#include <stdio.h>

#include "pal.h"
#include "semantics.h"
#include "symtab.h"

void declare_const(char* name, struct sym_rec* s)
{
  if(locallookup(name) == NULL)
    addconst(name, s);
  else
  {
    char error[1024];
    sprintf(error, "Constant already declared: %s", name);
    semantic_error(error);
  }
}

void declare_type(char* name, struct sym_rec* s)
{
  printf("%s is at %p\n", name, s);
  if(locallookup(name) == NULL)
  {
    if (s && s->class == OC_TYPE)
    {
      addtype(name, &s->desc.type_attr);
    }
  }
}

void declare_variable(char* name)
{ 
  if(locallookup(name) == NULL)
    addvar(name, NULL);
  else
  {
    char error[1024];
    sprintf(error, "Variable already declared: %s", name);
    semantic_error(error);
  }
}
