#include <stdlib.h>
#include <stdio.h>

#include "pal.h"
#include "semantics.h"
#include "symtab.h"

int assignment_compatible(struct sym_rec* left, struct sym_rec* right)
{
  if (!left || !right)
    return 0;

  /*
  printf("LHS name: %s\n", left->name);
  printf("RHS name: %s\n", right->name);
  printf("LHS = %d\n", left->desc.type_attr.type_class);
  printf("RHS = %d\n", right->desc.type_attr.type_class );
  */

  /* real := int || real */
  if ( left->desc.type_attr.type_class == TC_REAL &&
       (right->desc.type_attr.type_class == TC_INTEGER || right->desc.type_attr.type_class == TC_REAL) )
  {
    return 1;
  }

  if (right->desc.type_attr.type_class != left->desc.type_attr.type_class)
    return 0;

  switch(left->desc.type_attr.type_class)
  {
  case TC_INTEGER:
    if (left->desc.type_attr.type_class == right->desc.type_attr.type_class)
      return 1;
    return 0;
  case TC_CHAR:
    if (left->desc.type_attr.type_class == right->desc.type_attr.type_class)
      return 1;
    return 0;
  case TC_BOOLEAN:
    if (left->desc.type_attr.type_class == right->desc.type_attr.type_class)
      return 1;
    return 0;
  case TC_STRING:
    if (left->desc.type_attr.type_description.string->high == right->desc.type_attr.type_description.string->high)
      return 1;
    return 0;
  case TC_ARRAY:
    if (left->desc.type_attr.type_description.array == right->desc.type_attr.type_description.array)
      return 1;
    return 0;
  case TC_SCALAR:
    if (left->desc.type_attr.type_description.scalar == right->desc.type_attr.type_description.scalar)
      return 1;
    return 0;
  case TC_RECORD:
    if (left->desc.type_attr.type_description.record == right->desc.type_attr.type_description.record)
      return 1;
    return 0;
  default: return 0;
  }    

  return 0;
}

int compare_types(struct sym_rec* s, struct sym_rec* t)
{
  if (!s || !t)
    return 0;

  if (s->desc.type_attr.type_class != t->desc.type_attr.type_class)
    return 0;

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
