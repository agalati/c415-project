#include <stdlib.h>
#include <stdio.h>

#include "pal.h"
#include "semantics.h"
#include "symtab.h"

int compare_types(struct sym_rec* s, struct sym_rec* t)
{
  if (!s || !t)
  {
    printf("failed due to null pointers\n");
    return 0;
  }

  printf("names: %s, %s\n", s->name, t->name);

  if (s->desc.type_attr.type_class != t->desc.type_attr.type_class)
  {
    printf("failed due to different type classes - %d %d\n", s->desc.type_attr.type_class, t->desc.type_attr.type_class);
    return 0;
  }

  switch(s->desc.type_attr.type_class)
  {
    case TC_STRING:
      if (s->desc.type_attr.type_description.string->high == t->desc.type_attr.type_description.string->high)
        return 1;
      return 0;
    case TC_ARRAY:
      if (s->desc.type_attr.type_description.array == t->desc.type_attr.type_description.array)
        return 1;
      return 0;
    case TC_SCALAR:
      if (s->desc.type_attr.type_description.scalar == t->desc.type_attr.type_description.scalar)
        return 1;
      return 0;
    case TC_RECORD:
      if (s->desc.type_attr.type_description.record == t->desc.type_attr.type_description.record)
        return 1;
      return 0;
    default: return 1;
  }  
}

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
