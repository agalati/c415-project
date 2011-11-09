/*
 * sym_tab.c
 *
 * Contains the functions for the symbol table.
 *
 * Authors
 *   - Matthew Low
 *   - Anthony Galati
 *   - Mike Bujold
 *   - Stevan Clement
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "pal.h"
#include "symtab.h"

/* Real level + 1 = current_level (so this value is initialized for level 0) */
int current_level = 1;

/* The symbol table : levels -1 through 15 are available and map to [n+1] */
struct sym_rec *sym_tab[MAX_LEVEL + 1];

/* Yes, I am actually doing the following */
/* Base level structures */

struct tc_integer   base_integer;
struct tc_real      base_real;
struct tc_char      base_character;
struct tc_boolean   base_boolean;
//  struct tc_string    string;
//  struct tc_scalar    scalar;
//  struct tc_array     array;
//  struct tc_record    record;
//  struct tc_subrange  subrange;

#define INIT_ITEMS 24

struct sym_rec init_items[] = {
  /* Predefined Types */
  [0] = { .name = "integer", .level = -1, .class = OC_TYPE, .desc.type_attr.type_class = TC_INTEGER, .desc.type_attr.type_description.integer = &base_integer },
  [1] = { .name = "char", .level = -1, .class = OC_TYPE, .desc.type_attr.type_class = TC_CHAR, .desc.type_attr.type_description.character = &base_character },
  [2] = { .name = "boolean", .level = -1, .class = OC_TYPE, .desc.type_attr.type_class = TC_BOOLEAN, .desc.type_attr.type_description.boolean = &base_boolean },
  [3] = { .name = "real", .level = -1, .class = OC_TYPE, .desc.type_attr.type_class = TC_REAL, .desc.type_attr.type_description.real = &base_real },

  /* Predefined Constants */
  [4] = { .name = "true", .level = -1, .class = OC_CONST, .desc.const_attr.type = NULL },
  [5] = { .name = "false", .level = -1, .class = OC_CONST, .desc.const_attr.type = NULL },
  [6] = { .name = "maxint", .level = -1, .class = OC_CONST, .desc.const_attr.type = NULL },
  
  /* Predefined Procedures */
  [7] = { .name = "writeln", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [8] = { .name = "write", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [9] = { .name = "readln", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [10] = { .name = "read", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [11] = { .name = "ord", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [12] = { .name = "chr", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [13] = { .name = "trunc", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [14] = { .name = "round", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [15] = { .name = "succ", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [16] = { .name = "pred", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [17] = { .name = "odd", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [18] = { .name = "abs", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [19] = { .name = "sqr", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [20] = { .name = "sqrt", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [21] = { .name = "sin", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [22] = { .name = "exp", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [23] = { .name = "ln", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
};

/*****************************************
 * Print symbol table - use it to debug
 */
void printsym() {

  int i;
  struct sym_rec *s;

  for (i = 0; i < MAX_LEVEL; i++) {
    if ( sym_tab[i] != NULL) {
      printf("LEVEL %d\n", i - 1);
      printf("--------\n");
      for (s = sym_tab[i]; s != NULL; s = s->next) {
        printf("Name: %-17s | Level: %d | Class: %d\n", s->name, s->level, s->class);
      }
      printf("--------\n");
    }
  }
}

/*****************************************
 * Print current level - use it to debug
 */
void printlevel() {
  printf("Current level = %d\n", current_level - 1);
}

int get_current_level()
{
  return current_level - 1;
}

/*****************************************
 * Symbol table initialization - sets up level -1
 */
void sym_tab_init()
{
  int i;

  for (i = 0; i < MAX_LEVEL; i++) {
    sym_tab[i] = NULL;
  }

  /* Fill table with initial items */
  for (sym_tab[0] = &init_items[0], i = 1; i < INIT_ITEMS; i++) {
    init_items[i].next = sym_tab[0];
    sym_tab[0] = &init_items[i];
  }

  #ifdef DEBUG_SYM
  printsym();
  #endif
}

/*****************************************
 * Push level - Go up a level
 */
void pushlevel()
{
  current_level++;
}

/*****************************************
 * Pop level - Go down a level
 */
void poplevel()
{
  current_level--;

  /* Free linked list and it's components */
  
}

/*****************************************
 * Local lookup - checks the level you're on
 */
struct sym_rec *locallookup(char* name)
{
  /* Currently just checks name */
  struct sym_rec *s;

  if ( sym_tab[current_level] != NULL) {
    for (s = sym_tab[current_level]; s != NULL; s = s->next) {
      if ( strcmp(name, s->name) == 0 )
	      return s;
    }
  }
  return NULL;
}

struct sym_rec *builtinlookup(char* name)
{
  /* Currently just checks name */
  struct sym_rec *s;

  if ( sym_tab[0] != NULL) {
    for (s = sym_tab[0]; s != NULL; s = s->next) {
      if ( strcmp(name, s->name) == 0 )
	      return s;
    }
  }
  return NULL;
}

/*****************************************
 * Global lookup - checks everywhere, starts with current level
 *                 and returns the first match
 */
struct sym_rec *globallookup(char* name)
{
  /* Currently just checks name */
  int i;
  struct sym_rec *s;

  for (i = current_level; i >= 0; i--) {
    if ( sym_tab[i] != NULL) {
      for (s = sym_tab[i]; s != NULL; s = s->next) {
	      if ( strcmp(name, s->name) == 0 )
	        return s;
      }
    }
  }
  return NULL;
}

int isAlias(char* builtin, struct sym_rec* s)
{
  struct sym_rec* b = builtinlookup(builtin);

  // make sure b and s are not null
  if (b && s)
    if (b->class == OC_TYPE)
      if (b->desc.type_attr.type_class == s->desc.type_attr.type_class)
        switch(b->desc.type_attr.type_class)
        {
          case TC_CHAR: 
            if (b->desc.type_attr.type_description.character == s->desc.type_attr.type_description.character)
              return 1;
            return 0;
          case TC_BOOLEAN:
            if (b->desc.type_attr.type_description.boolean == s->desc.type_attr.type_description.boolean)
              return 1;
            return 0;
          default: printf("Error - reached unreachable default case in isAlias\n"); return 0;
         }
}

struct sym_rec *addconst(char* name, struct sym_rec* type)
{
  struct sym_rec *s;

  s = malloc(sizeof(struct sym_rec));
  if (s == NULL) {
    fprintf(stderr, "Error: malloc failed in addconst()\n");
    exit(EXIT_FAILURE);
  }

  s->name = strdup(name);
  s->level = current_level - 1;
  s->class = OC_CONST;
  s->desc.const_attr.type = type;

  /* Constants currently don't have a value */
  /*
  switch (type->type_class)
    {
    case TC_INTEGER :
      s->desc.const_attr.value.integer = integer;
      break;
    case TC_REAL :
      s->desc.const_attr.value.real = real;
      break;
    case TC_STRING :
      s->desc.const_attr.value.string = strdup(string);
      break;
    default :
      fprintf(stderr, "Error: constant type failed in addconst()\n");
      exit(EXIT_FAILURE);
    }
  */
  
  s->next = sym_tab[current_level];
  sym_tab[current_level] = s;

  return s;
}

struct sym_rec *addvar(char* name, struct sym_rec* type)
{
  struct sym_rec *s;

  s = malloc(sizeof(struct sym_rec));
  if (s == NULL) {
    fprintf(stderr, "Error: malloc failed in addvar()\n");
    exit(EXIT_FAILURE);
  }

  s->name = strdup(name);
  s->level = current_level - 1;
  s->class = OC_VAR;
  s->desc.var_attr.type = type;

  s->next = sym_tab[current_level];
  sym_tab[current_level] = s;

#ifdef DEBUG_SYM
  printsym();
#endif

  return s;
}

struct sym_rec *addfunc(char* name, struct sym_rec* parm_list, struct sym_rec* return_type)
{
  struct sym_rec *s;

  s = malloc(sizeof(struct sym_rec));
  if (s == NULL) {
    fprintf(stderr, "Error: malloc failed in addfunc()\n");
    exit(EXIT_FAILURE);
  }

  s->name = strdup(name);
  s->level = current_level - 1;
  s->class = OC_FUNC;
  s->desc.func_attr.parms = parm_list;
  s->desc.func_attr.return_type = return_type;

  s->next = sym_tab[current_level];
  sym_tab[current_level] = s;

  return s;
}

struct sym_rec *addproc(char* name, struct sym_rec* parm_list)
{
  struct sym_rec *s;

  s = malloc(sizeof(struct sym_rec));
  if (s == NULL) {
    fprintf(stderr, "Error: malloc failed in addproc()\n");
    exit(EXIT_FAILURE);
  }

  s->name = strdup(name);
  s->level = current_level - 1;
  s->class = OC_PROC;
  s->desc.proc_attr.parms = parm_list;

  s->next = sym_tab[current_level];
  sym_tab[current_level] = s;

  return s;
}

struct sym_rec *addtype(char* name, struct type_desc* type)
{
  struct sym_rec *s;

  s = malloc(sizeof(struct sym_rec));
  if (s == NULL) {
    fprintf(stderr, "Error: malloc failed in addtype()\n");
    exit(EXIT_FAILURE);
  }

  s->name = strdup(name);
  s->level = current_level - 1;
  s->class = OC_TYPE;
  s->desc.type_attr.type_class = type->type_class;
  s->desc.type_attr.type_description = type->type_description;

  s->next = sym_tab[current_level];
  sym_tab[current_level] = s;

  return s;
}

/* Add parameters to the parameter list and also add the variable to the next level */
struct sym_rec *addparm(char* name, struct sym_rec* type, struct sym_rec* parm_list)
{
  struct sym_rec *s;
  struct sym_rec *t;

  s = malloc(sizeof(struct sym_rec));
  if (s == NULL) {
    fprintf(stderr, "Error: malloc failed in addparm()\n");
    exit(EXIT_FAILURE);
  }

  s->name = strdup(name);
  s->level = current_level - 1;
  s->class = OC_VAR;
  s->desc.var_attr.type = type;

  /* Add to next level of symbol table */
  s->next = sym_tab[current_level + 1];
  sym_tab[current_level + 1] = s;

  /* Adds a copy to the current parameter list (var_attr.location should be the same) */
  t = malloc(sizeof(struct sym_rec));
  if (t == NULL) {
    fprintf(stderr, "Error: malloc failed in addparm()\n");
    exit(EXIT_FAILURE);
  }

  t->name = strdup(name);
  t->level = current_level - 1;
  t->class = OC_VAR;
  t->desc.var_attr.type = type;

  t->next = parm_list;
  parm_list = t;

  /* Return the parameter list */
  return t;
}
