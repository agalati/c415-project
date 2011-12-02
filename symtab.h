/*
 * symtab.h
 *
 * What are the different values for const? (see struct const_desc)
 * Should location be a struct { int level; int offset } to denote offset[current_level - 1] ???
 *
 * Authors
 *   - Matthew Low
 *   - Anthony Galati
 *   - Mike Bujold
 *   - Stevan Clement
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
#define OC_ERROR    6
#define OC_RETURN   7

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
  int high;
};

struct tc_scalar {
  struct sym_rec* const_list;
};

struct tc_array {
  struct tc_subrange* subrange;
  struct sym_rec* object_type;
};

struct tc_record {
  struct sym_rec* field_list;
};

struct tc_subrange {
  struct sym_rec*   mother_type;
  int               low;
  int               high;
};

/*
 * desc field declarations in sym_rec structure
 */

struct location_t {
  int display;
  int offset;
};

struct const_desc {
  struct sym_rec*     type;
  struct location_t   location;
  union {            /* Another struct, depending on which class */
    int     integer;
    int     boolean;
    double  real;
    char*   string;
    char    character;
  } value;
};

struct var_desc {
  struct sym_rec*     type;
  struct location_t   location;
};

struct func_desc {
  struct sym_rec* return_type;
  struct sym_rec* parms;
};

struct proc_desc {
  struct sym_rec* parms;    /* Points to the first parm (then check parm_next for NULL) */
};

struct parm_desc {
  struct sym_rec* type;
  int    location;
  struct sym_rec* next_parm;
};

struct type_desc {
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
    struct const_desc const_attr;
    struct var_desc   var_attr;
    struct func_desc  func_attr;
    struct proc_desc  proc_attr;
    struct parm_desc  parm_attr;
    struct type_desc  type_attr;
  } desc;
  struct sym_rec* next;
};

/* Function definitions */

#define MAX_LEVEL 17

int get_current_level(void);

void printsym(void);

void printlevel(void);

void pushlevel(struct sym_rec* func_rec);

void poplevel(void);

struct sym_rec *locallookup(char* name);

struct sym_rec *builtinlookup(char* name);

struct sym_rec *globallookup(char* name);

int isAlias(char* builtin, struct sym_rec* s);

struct sym_rec *addconst(char* name, struct sym_rec* type);

struct sym_rec *addvar(char* name, struct sym_rec* type);

struct sym_rec *addfunc(char* name, struct sym_rec* parm_list, struct sym_rec* return_type);

struct sym_rec *addproc(char* name, struct sym_rec* parm_list);

struct sym_rec *addtype(char* name, struct type_desc* type);

/* Not sure if we need this last one */
struct sym_rec *addparm(char* name, struct sym_rec* type, struct sym_rec* parm_list);

struct sym_rec *isCurrentFunction(char* name);

struct sym_rec *get_type(struct sym_rec* s);
int get_type_class(struct sym_rec* s);

int get_current_offset(void);

#endif
