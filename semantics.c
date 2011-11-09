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
  if(locallookup(name) == NULL)
  {
    if (s && s->class == OC_TYPE)
    {
      addtype(name, &s->desc.type_attr);
    }
    else if (s == NULL)
    {
      addtype(name, NULL);
    }
  }
  else
  {
    char error[1024];
    sprintf(error, "Type '%s' already declared at this scope.", name);
    semantic_error(error);
  }
}

void declare_variable(char* name, struct sym_rec* s)
{ 
  if(locallookup(name) == NULL)
  {
    if (s && s->class == OC_TYPE)
      addvar(name, s);
    else if (s == NULL)
      addvar(name, NULL);
  }
  else
  {
    char error[1024];
    sprintf(error, "Variable '%s' already declared.", name);
    semantic_error(error);
  }
}
