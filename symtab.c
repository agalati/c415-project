/*
 * sym_tab.c
 *
 * Contains the functions for the symbol table.
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

/*****************************************
 * Print symbol table - use it to debug
 */
void printsym() {

  int i;
  struct sym_rec *s;

  for (i = 0; i < INIT_ITEMS; i++) {
    if ( sym_tab[i] != NULL) {
      for (s = sym_tab[i]; s != NULL; s = s->next) {
        printf("Name: %s | Level: %d | Class: %d\n", s->name, s->level, s->class);
      }
    }
  }
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

  struct sym_rec init_items[] = {
    /* Predefined Types */
    [0] = { .name = "integer", .level = -1, .class = OC_TYPE, .cont.type_attr.type_class = TC_INTEGER, .cont.type_attr.type_description.integer = &base_integer },
    [1] = { .name = "char", .level = -1, .class = OC_TYPE, .cont.type_attr.type_class = TC_CHAR, .cont.type_attr.type_description.character = &base_character },
    [2] = { .name = "boolean", .level = -1, .class = OC_TYPE, .cont.type_attr.type_class = TC_BOOLEAN, .cont.type_attr.type_description.boolean = &base_boolean },
    [3] = { .name = "real", .level = -1, .class = OC_TYPE, .cont.type_attr.type_class = TC_REAL, .cont.type_attr.type_description.real = &base_real },

    /* Predefined Procedures */
    [4] = { .name = "writeln", .level = -1, .class = OC_PROC, .cont.proc_attr.parms = NULL }
  };

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
      if ( strncmp(name, s->name, strlen(name)) == 0 )
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
    if ( sym_tab[current_level] != NULL) {
      for (s = sym_tab[i]; s != NULL; s = s->next) {
	if ( strncmp(name, s->name, strlen(name)) == 0 )
	  return s;
      }
    }
  }
  return NULL;
}

struct sym_rec *addconst() {}

struct sym_rec *addvar(char* name, struct type_cont* type)
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
  s->cont.var_attr.type = type;

  s->next = sym_tab[current_level];
  sym_tab[current_level] = s;
}

struct sym_rec *addfunc()
{
}

struct sym_rec *addproc()
{
}

struct sym_rec *addtype()
{
}

/* Not sure if we need this last one */
struct sym_rec *addparm()
{
}

