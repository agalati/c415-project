#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "pal.h"
#include "semantics.h"
#include "symtab.h"

int isABSFunc(struct plist_t* p)
{
  if (!p)
    return 0;

  if (p->level == -1 && (strcmp(p->name, "abs") == 0))
    return 1;

  return 0;
}
int isSQRFunc(struct plist_t* p)
{
  if (!p)
    return 0;

  if (p->level == -1 && (strcmp(p->name, "sqr") == 0))
    return 1;

  return 0;
}

int isPREDFunc(struct plist_t* p)
{
  if (!p)
    return 0;

  if (p->level == -1 && (strcmp(p->name, "pred") == 0))
    return 1;

  return 0;
}

int isSUCCFunc(struct plist_t* p)
{
  if (!p)
    return 0;

  if (p->level == -1 && (strcmp(p->name, "succ") == 0))
    return 1;

  return 0;
}

int isORDFunc(struct plist_t* p)
{
  if (!p)
    return 0;

  if (p->level == -1 && (strcmp(p->name, "ord") == 0))
    return 1;

  return 0;
}

int isIntOrRealType(struct sym_rec* parm)
{
  if (!parm)
    return 0;

  if (parm->class != OC_TYPE)
    return 0;

  if (  parm->desc.type_attr.type_class == TC_REAL 
    ||  parm->desc.type_attr.type_class == TC_INTEGER)
    return 1;

  return 0;
}

int isORDType(struct sym_rec* parm)
{
  if (!parm)
    return 0;

  if (parm->class != OC_TYPE)
    return 0;

  if (  parm->desc.type_attr.type_class == TC_SCALAR 
    ||  parm->desc.type_attr.type_class == TC_CHAR 
    ||  parm->desc.type_attr.type_class == TC_BOOLEAN
    ||  parm->desc.type_attr.type_class == TC_INTEGER)
    return 1;

  return 0;
}

int isIOFunc(struct plist_t* p)
{
  if (!p)
    return 0;

  if (p->level == -1)
  {
    if (strcmp(p->name, "write") == 0)
      return 1;
    if (strcmp(p->name, "writeln") == 0)
      return 1;
    if (strcmp(p->name, "read") == 0)
      return 1;
    if (strcmp(p->name, "readln") == 0)
      return 1;
  }
  
  return 0;
}

int checkIOArg(struct sym_rec* parm)
{
  if (!parm)
    return 0;

  if (parm->class == OC_TYPE)
  {
    switch(parm->desc.type_attr.type_class)
    {
      case TC_INTEGER:
        return 1;
      case TC_REAL:
        return 1;
      case TC_CHAR:
        return 1;
      case TC_STRING:
        return 1;
      case TC_BOOLEAN:
        return 1;
      default:
        return 0;
    }
  }
  else
  {
    fprintf(stderr, "Argument is not a type in checkIOArgs... you should not be reading this.\n");
  }

  return 0;
}

int isSimpleType(struct sym_rec* type)
{
  if (type) {
    if ((type->desc.type_attr.type_class == TC_INTEGER)
        || (type->desc.type_attr.type_class == TC_CHAR)
        || (type->desc.type_attr.type_class == TC_REAL)
        || (type->desc.type_attr.type_class == TC_BOOLEAN)
        || (type->desc.type_attr.type_class == TC_SCALAR)) {
      return 1;
    }
  }
  return 0;
}

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

  // allow assignment of chars to strings of length 1
  if (left->desc.type_attr.type_class == TC_STRING &&
      left->desc.type_attr.type_description.string->high == 1 &&
      right->desc.type_attr.type_class == TC_CHAR)
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

// s is the type being passed, t is the expected type
int compare_types(struct sym_rec* s, struct sym_rec* t)
{
  if (!s || !t)
    return 0;

  // check if the first type can be coerced into the second type
  if (s->desc.type_attr.type_class == TC_INTEGER && t->desc.type_attr.type_class == TC_REAL)
      return 1;

  // allow coercion of chars to strings of length 1
  if (t->desc.type_attr.type_class == TC_STRING &&
      t->desc.type_attr.type_description.string->high == 1 &&
      s->desc.type_attr.type_class == TC_CHAR)
  {
    return 1;
  }


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
  if (s && s->name)
    addtype(s->name, &s->desc.type_attr);

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
  if (s && s->name)
    addtype(s->name, &s->desc.type_attr);

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
