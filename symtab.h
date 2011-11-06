/*
 * symtab.h
 *
 * What are the different values for const? (see struct const_cont)
 * Should location be a struct { int level; int offset } to denote offset[level] ???
 *
 */

#ifndef SYMTAB_H
#define SYMTAB_H

struct const_cont {
  sym_rec* type;
  double   value;
};

struct var_cont {
  sym_rec* type;
  int      location;
};

struct func_cont {
  sym_rec* type;
  sym_rec* parms;
};

struct proc_cont {
  sym_rec* parms;    /* Points to the first parm (then check parm_next for NULL)*/
};

struct parm_cont {
  sym_rec* type;
  int      location;
  sym_rec* next_parm;
};

struct type_cont {
  sym_rec* type_description;
};

struct sym_rec {
  char *name;        /* Name of symbol */
  int  class;        /* Options: const, type, var, proc, func */
  union {            /* Depending on which class, a pointer to another struct. */
    const_cont 
  } cont;
};

#endif
