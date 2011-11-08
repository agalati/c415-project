#include <stdlib.h>
#include <stdio.h>

#include "pal.h"
#include "semantics.h"
#include "symtab.h"

void declare_variable(char* name)
{ 
  if(locallookup(name) == NULL)
  {
    addvar(name, NULL);
    //$$ = $3;
  }
  else
  {
    char error[1024];
    sprintf(error, "Variable already declared: %s", name);
    semantic_error(error);
  }
}
