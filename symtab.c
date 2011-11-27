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

struct pf_node
{
  struct sym_rec* func_entry; // NULL if we are in a procedure
  struct pf_node* next;
};

struct pf_node* pf_list = NULL;

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

/* The built in params aren't included here */
#define INIT_ITEMS 27

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
  [7] = { .name = "pi", .level = -1, .class = OC_CONST, .desc.const_attr.type = NULL },
  
  /* Predefined Procedures */
  [8] = { .name = "writeln", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [9] = { .name = "write", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [10] = { .name = "readln", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [11] = { .name = "read", .level = -1, .class = OC_PROC, .desc.proc_attr.parms = NULL },
  [12] = { .name = "ord", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [13] = { .name = "chr", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [14] = { .name = "trunc", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [15] = { .name = "round", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [16] = { .name = "succ", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [17] = { .name = "pred", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [18] = { .name = "odd", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [19] = { .name = "abs", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [20] = { .name = "sqr", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [21] = { .name = "sqrt", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [22] = { .name = "sin", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [23] = { .name = "exp", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [24] = { .name = "ln", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [25] = { .name = "cos", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },
  [26] = { .name = "arctan", .level = -1, .class = OC_FUNC, .desc.proc_attr.parms = NULL },

  /* Param lists for the above functions */
  [27] = { .name = "ord_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [28] = { .name = "chr_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [29] = { .name = "trunc_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [30] = { .name = "round_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [31] = { .name = "succ_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [32] = { .name = "pred_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [33] = { .name = "odd_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },

  [34] = { .name = "abs_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [35] = { .name = "sqr_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [36] = { .name = "sqrt_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [37] = { .name = "sin_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [38] = { .name = "exp_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [39] = { .name = "ln_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [40] = { .name = "cos_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  [41] = { .name = "arctan_parm", .level = 0, .class = OC_VAR, .desc.var_attr.type = NULL },
  
};

/*****************************************
 * Print symbol table - use it to debug
 */
void printrecord(struct sym_rec* s);
void printtype(struct sym_rec* s) {

  struct sym_rec* t;
  
  if (s == NULL) {
    printf("| Type is NULL ");
    return;
  }
  if (s->name != NULL)
    printf("| Type name: %s ", s->name);
  switch (s->desc.type_attr.type_class) {
  case TC_INTEGER :
    printf("| Integer at type %p ", s->desc.type_attr.type_description.integer);
    break;
  case TC_REAL :
    printf("| Real type at %p ", s->desc.type_attr.type_description.real);
    break;
  case TC_CHAR :
    printf("| Char type at %p ", s->desc.type_attr.type_description.character);
    break;
  case TC_BOOLEAN :
    printf("| Boolean type at %p ", s->desc.type_attr.type_description.boolean);
    break;
  case TC_STRING :
    printf("| String at type %p ", s->desc.type_attr.type_description.string);
    printf("| high = %d ", s->desc.type_attr.type_description.string->high);
    break;
  case TC_SCALAR :
    printf("| Scalar at type %p ", s->desc.type_attr.type_description.scalar);
    printf(" Featuring: \n");
    
    t = s->desc.type_attr.type_description.scalar->const_list;
    
    for (; t != NULL; t = t->next) {
      printf("\tName: %-17s | Level: %d | Class: %d \n", t->name, t->level, t->class);
    }
    break;
  case TC_RECORD :
    printf("| Record at type %p ", s->desc.type_attr.type_description.record);
    printf("\n\t Record List:\n");

    t = s->desc.type_attr.type_description.record->field_list;
    
    for (; t != NULL; t = t->next)
      printrecord(t);
    break;
  case TC_ARRAY :
    printf("| Array at type %p ", s->desc.type_attr.type_description.array);
    printf("| Subrange at type %p ", s->desc.type_attr.type_description.array->subrange);
    printf("| sub low = %d ", s->desc.type_attr.type_description.array->subrange->low);
    printf("| sub high =  %d ", s->desc.type_attr.type_description.array->subrange->high);
    printtype(s->desc.type_attr.type_description.array->subrange->mother_type);
    break;
  case TC_SUBRANGE :
    printf("\n## Symbol table is broken (subrange being parsed) ##\n");
    break;
  default :
    printf("\n## Symbol table is broken ##\n");
  }
}

void printrecord(struct sym_rec* s) {
  int i;
  struct sym_rec *t = s;

  printf("\tName: %-17s | Level: %d | Class: %d ", t->name, t->level, t->class);
  
  switch (t->class) {
  case OC_CONST :
    printtype(t->desc.const_attr.type);
    break;
  case OC_VAR :
    printtype(t->desc.var_attr.type);
      break;
  case OC_FUNC :
    break;
  case OC_PROC :
    break;
  case OC_PARM :
    break;
  case OC_TYPE :
    printtype(t);
    break;
  case OC_ERROR :
    printf("| ERROR TOKEN");
    break;
  }
  printf("\n");
  
}

void printsym() {

  int i;
  struct sym_rec *s;

  for (i = 0; i < MAX_LEVEL; i++) {
    if ( sym_tab[i] != NULL) {
      printf("LEVEL %d\n", i - 1);
      printf("--------\n");
      for (s = sym_tab[i]; s != NULL; s = s->next) {
        printf("Name: %-17s | Level: %d | Class: %d ", s->name, s->level, s->class);

        switch (s->class) {
        case OC_CONST :
          printtype(s->desc.const_attr.type);
          break;
        case OC_VAR :
          printtype(s->desc.var_attr.type);
          break;
        case OC_FUNC :
          break;
        case OC_PROC :
          break;
        case OC_PARM :
          break;
        case OC_TYPE :
          printtype(s);
          break;
        case OC_ERROR :
          printf("| ERROR TOKEN");
          break; 
        }
        printf("\n");
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

  /* Constant types hooked up here */
  init_items[4].desc.const_attr.type = &init_items[2];
  init_items[5].desc.const_attr.type = &init_items[2];
  init_items[6].desc.const_attr.type = &init_items[0];
  init_items[7].desc.const_attr.type = &init_items[3];

  /* Built in function parameters hooked up here */
  /* Read and write functions will stay NULL and be special cases */
  for (i = 12; i < INIT_ITEMS; i++) {
    init_items[INIT_ITEMS - 12 + i].next = NULL;
    init_items[i].desc.func_attr.parms = &init_items[INIT_ITEMS - 12 + i];
  }

  /* Set function return types */
  
  init_items[12].desc.func_attr.return_type = &init_items[0];
  init_items[13].desc.func_attr.return_type = &init_items[1];
  init_items[14].desc.func_attr.return_type = &init_items[0];
  init_items[15].desc.func_attr.return_type = &init_items[0];

  /* Hard code this somewhere succ(), pred() */
  //init_items[16].desc.func_attr.return_type = &init_items[0];

  init_items[18].desc.func_attr.return_type = &init_items[2];

  /* Special logic required for table at "http://pascal-central.com/iso7185.html#6.6.6.2%20Arithmetic%20functions"*/
  //init_items[19].desc.func_attr.return_type = &init_items[0];

  init_items[21].desc.func_attr.return_type = &init_items[3];
  init_items[22].desc.func_attr.return_type = &init_items[3];
  init_items[23].desc.func_attr.return_type = &init_items[3];
  init_items[24].desc.func_attr.return_type = &init_items[3];
  init_items[25].desc.func_attr.return_type = &init_items[3];
  init_items[26].desc.func_attr.return_type = &init_items[3];
  
  /* Set types for params */
  /* Hardcode succ(), pred(), ord() and the special logic at URL above */
  init_items[28].desc.var_attr.type = &init_items[0];
  init_items[29].desc.var_attr.type = &init_items[3];
  init_items[30].desc.var_attr.type = &init_items[3];
  init_items[33].desc.var_attr.type = &init_items[0];
  init_items[36].desc.var_attr.type = &init_items[3];
  init_items[37].desc.var_attr.type = &init_items[3];
  init_items[38].desc.var_attr.type = &init_items[3];
  init_items[39].desc.var_attr.type = &init_items[3];
  init_items[40].desc.var_attr.type = &init_items[3];
  init_items[41].desc.var_attr.type = &init_items[3];
  
  
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
 *
 * If we are calling a procedure, pass NULL to func_rec, otherwise pass the sym_rec for the func.
 */
void pushlevel(struct sym_rec* func_rec)
{
//  printsym();
  current_level++;
  if (current_level >= MAX_LEVEL)
  {
    fprintf(stderr, "Maximum nesting depth for procedures and functions exceeded (current level is %d, max is %d). Stopping parse.\n", current_level, MAX_LEVEL);
    exit(1);
  }

  struct pf_node* new_node = (struct pf_node*)malloc(sizeof(struct pf_node));
  new_node->next = pf_list;
  new_node->func_entry = func_rec;
  pf_list = new_node;
}

/*****************************************
 * Pop level - Go down a level
 */
void poplevel()
{
  /* Free linked list and it's components */
  sym_tab[current_level] = NULL;

  current_level--;

  if (pf_list)
  {
    struct pf_node* rmv_node = pf_list;
    pf_list = pf_list->next;
    free(rmv_node);
  }
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
  struct sym_rec *func_rec;

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

  func_rec = s;

  s->next = sym_tab[current_level];
  sym_tab[current_level] = s;

  s = (struct sym_rec*)malloc(sizeof(struct sym_rec));
  s->name = strdup(name);
  s->level = current_level;
  s->class = OC_RETURN;
  s->desc.var_attr.type = return_type;

  s->next = sym_tab[current_level+1];
  sym_tab[current_level+1] = s;

  return func_rec;
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

  if (type != NULL)
  {
    s->name = strdup(name);
    s->level = current_level - 1;
    s->class = OC_TYPE;
    s->desc.type_attr.type_class = type->type_class;
    s->desc.type_attr.type_description = type->type_description;

    s->next = sym_tab[current_level];
    sym_tab[current_level] = s;
  }
  else
  {
    s->name = strdup(name);
    s->level = current_level - 1;
    s->class = OC_ERROR;

    s->next = sym_tab[current_level];
    sym_tab[current_level] = s;
  }

  return s;
}

/* Add parameters to the parameter list and also add the variable to the next level */
struct sym_rec *addparm(char* name, struct sym_rec* type, struct sym_rec* parm_list)
{
  struct sym_rec *s;
  struct sym_rec *t;

  if (type)
  {
    s = malloc(sizeof(struct sym_rec));
    if (s == NULL) {
      fprintf(stderr, "Error: malloc failed in addparm()\n");
      exit(EXIT_FAILURE);
    }

    s->name = strdup(name);
    s->level = current_level;
    s->class = OC_VAR;
    s->desc.var_attr.type = type;

    /* Add to next level of symbol table */
    s->next = sym_tab[current_level + 1];
    sym_tab[current_level + 1] = s;

    // Add parameter types to the next level to prevent redefinition
    s = malloc(sizeof(struct sym_rec));
    s->name = strdup(type->name);
    s->level = current_level;
    s->class = OC_TYPE;
    s->desc.type_attr.type_class = type->desc.type_attr.type_class;
    switch(s->desc.type_attr.type_class)
    {
      case TC_INTEGER:
        s->desc.type_attr.type_description.integer = type->desc.type_attr.type_description.integer;
        break;
      case TC_REAL:
        s->desc.type_attr.type_description.real = type->desc.type_attr.type_description.real;
        break;
      case TC_CHAR:
        s->desc.type_attr.type_description.character = type->desc.type_attr.type_description.character;
        break;
      case TC_BOOLEAN:
        s->desc.type_attr.type_description.boolean = type->desc.type_attr.type_description.boolean;
        break;
      case TC_STRING:
        s->desc.type_attr.type_description.string = type->desc.type_attr.type_description.string;
        break;
      case TC_ARRAY:
        s->desc.type_attr.type_description.array = type->desc.type_attr.type_description.array;
        break;
      case TC_RECORD:
        s->desc.type_attr.type_description.record = type->desc.type_attr.type_description.record;
        break;
      case TC_SUBRANGE:
        s->desc.type_attr.type_description.subrange = type->desc.type_attr.type_description.subrange;
        break;
      case TC_SCALAR:
        s->desc.type_attr.type_description.scalar = type->desc.type_attr.type_description.scalar;
        break;
    }
    s->next = sym_tab[current_level + 1];
    sym_tab[current_level + 1] = s;
  }

  /* Adds a copy to the current parameter list (var_attr.location should be the same) */
  t = malloc(sizeof(struct sym_rec));
  if (t == NULL) {
    fprintf(stderr, "Error: malloc failed in addparm()\n");
    exit(EXIT_FAILURE);
  }

  t->name = strdup(name);
  t->level = current_level - 1;
  if(type)
    t->class = OC_VAR;
  else
    t->class = OC_ERROR;
  t->desc.var_attr.type = type;

  t->next = parm_list;
  parm_list = t;

  /* Return the parameter list */
  return t;
}

struct sym_rec* isCurrentFunction(char* name)
{
  if (!pf_list)
    return NULL;

  if (!pf_list->func_entry)
    return NULL;

  char* func_name = pf_list->func_entry->name;
  if (func_name == NULL)
  {
    fprintf(stderr, "FATAL ERROR: function name NULL.\n");
    exit(1);
  }

  if (strcmp(func_name, name) == 0)
    return pf_list->func_entry;
  return NULL;
}
