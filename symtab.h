/*
 * symtab.h
 *
 * What are the different values for const? (see struct const_cont)
 * Should location be a struct { int level; int offset } to denote offset[level] ???
 *
 */

#ifndef SYMTAB_H
#define SYMTAB_H

/*
 * Basic type class declarations - everything is
 * just an expansion of these.
 */

/* The purpose of the following definitions is to allow
 * one to know which field of the union to use
 */

#define TC_INTEGER  0
#define TC_REAL     1
#define TC_CHAR     2
#define TC_BOOLEAN  3
#define TC_STRING   4
#define TC_SCALAR   5
#define TC_ARRAY    6
#define TC_RECORD   7
#define TC_SUBRANGE 8

#define OC_CONST    0
#define OC_VAR      1
#define OC_FUNC     2
#define OC_PROC     3
#define OC_PARM     4
#define OC_TYPE     5

struct tc_integer {
  int length;
};

struct tc_real {
  int length;
};

struct tc_char {
  int length;
};

struct tc_boolean {
  int length;
};

struct tc_string {
  int length;
};

struct tc_scalar {
  struct sym_rec* const_list;
};

struct tc_array {
  struct type_cont* index_type;
  struct type_cont* object_type;
};

struct tc_record {
  struct sym_rec* field_list;
};

struct tc_subrange {
  struct type_cont* mother_type;
  int               low;
  int               high;
};

/*
 * cont field declarations in sym_rec structure
 */
struct const_cont {
  struct sym_rec* type;
  double          value;
};

struct var_cont {
  struct type_cont* type;
  int               location;
};

struct func_cont {
  struct sym_rec* type;
  struct sym_rec* parms;
};

struct proc_cont {
  struct sym_rec* parms;    /* Points to the first parm (then check parm_next for NULL) */
};

struct parm_cont {
  struct sym_rec* type;
  int      location;
  struct sym_rec* next_parm;
};

struct type_cont {
  int    type_class;        /* eg. TC_INTEGER as declared above */
  union {
    struct tc_integer*  integer;
    struct tc_real*     real;
    struct tc_char*     character;
    struct tc_boolean*  boolean;
    struct tc_string*   string;
    struct tc_scalar*   scalar;
    struct tc_array*    array;
    struct tc_record*   record;
    struct tc_subrange* subrange;
  } type_description;
};

/*
 * sym_rec structure declaration
 */

struct sym_rec {
  char *name;        /* Name of symbol */
  int  level;        /* Level of symbol */
  int  class;        /* eg. OC_CONST as declared above */
  union {            /* Another struct, depending on which class */
    struct const_cont const_attr;
    struct var_cont   var_attr;
    struct func_cont  func_attr;
    struct proc_cont  proc_attr;
    struct parm_cont  parm_attr;
    struct type_cont  type_attr;
  } cont;
  struct sym_rec* next;
};

/* Function definitions */

#define MAX_LEVEL 17
#define INIT_ITEMS 5

extern int current_level;
extern struct sym_rec *sym_tab[MAX_LEVEL + 1];

void proof(void);

void pushlevel(void);

void poplevel(void);

struct sym_rec *locallookup(char* name);

struct sym_rec *globallookup(char* name);

struct sym_rec *addconst(void);

struct sym_rec *addvar(char* name, struct type_cont* type);

struct sym_rec *addfunc(void);

struct sym_rec *addproc(void);

struct sym_rec *addtype(void);

/* Not sure if we need this last one */
struct sym_rec *addparm(void);

#endif
