#ifndef SEMANTICS_H
#define SEMANTICS_H

#include "symtab.h"

// set counter to the number of parameters in the parm list 
// of the func / proc (which we can find after parsing ID)
struct plist_t
{
  struct sym_rec* parmlist;
  struct sym_rec* return_type;
  char* name;
  int level;
  int counter;
  int max;
};

struct temp_array_var
{
  struct sym_rec*        var;
  struct temp_array_var* next;
};

struct expr_t
{
  struct sym_rec*     type;
  struct location_t*  location; // a NULL location means we do not have an address.
  int                 is_in_address_on_stack;
  int                 is_const; // if this is true, the value must be set appropriately
  int                 is_reference; // the location points to a stack location which has the address of this var
  union {
    int     integer;
    int     boolean;
    double  real;
    char*   string;
    char    character;
  } value;
};

void do_op(struct expr_t* loperand, struct expr_t* roperand, int opcode, struct expr_t* result);

int compare_ge(struct expr_t* l, struct expr_t* r);
int compare_le(struct expr_t* l, struct expr_t* r);
int compare_gt(struct expr_t* l, struct expr_t* r);
int compare_lt(struct expr_t* l, struct expr_t* r);
int compare_inequality(struct expr_t* l, struct expr_t* r);
int compare_equality(struct expr_t* l, struct expr_t* r);

int isABSFunc(struct plist_t* p);
int isSQRFunc(struct plist_t* p);
int isPREDFunc(struct plist_t* p);
int isSUCCFunc(struct plist_t* p);
int isORDFunc(struct plist_t* p);
int isCHRFunc(struct plist_t* p);
int isIOFunc(struct plist_t* p);

int isIntOrRealType(struct sym_rec* parm);
int isORDType(struct sym_rec* parm);
int checkIOArg(struct sym_rec* parm);

int isSimpleType(struct sym_rec* type);
int assignment_compatible(struct sym_rec* left, struct sym_rec* right);
int compare_types(struct sym_rec* s, struct sym_rec* t, int check_coercion);

void declare_const(char* name, struct expr_t*);
void declare_type(char* name, struct sym_rec*);
void declare_variable(char* name, struct sym_rec*);

void incrementWhileCounter();
void decrementWhileCounter();
int getWhileCounter();

#endif
