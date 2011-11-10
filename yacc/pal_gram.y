/* pal_gram.y
 *
 * Defines the grammar for PAL and contains some extra rules for error reporting/handling.
 *
 * Authors
 *   - Matthew Low
 *   - Anthony Galati
 *   - Mike Bujold
 *   - Stevan Clement
 */

%{
#define YYDEBUG 1

#include <stdlib.h>
#include <string.h>

#include "semantics.h"
#include "symtab.h"

int search_fields = 0;
struct sym_rec* prev_fields;

int clear_parm_list = 1;
struct sym_rec* parm_list = NULL;

%}

 //%expect 1     /* bison knows to expect 1 s/r conflict */
%locations
%error-verbose
  /* free discarded tokens */
//%destructor { printf ("free at %d %s\n",@$.first_line, $$); free($$); } <*>
//%destructor { free($$); } <*>

%union {
  int                 integer;
  double              real_t;
  char                ch;
  char*               name;
  struct sym_rec*     symrec;
  struct type_desc*   desc; 
  struct tc_subrange* range;
  struct plist_t*     plist;
  }

/* New tokens */
%token          ASSIGNMENT EQUALS NOT_EQUAL LESS_THAN
%token          GREATER_THAN LESS_EQUAL GREATER_EQUAL
%token          PLUS MINUS MULTIPLY DIVIDE O_BRACKET C_BRACKET
%token          PERIOD COLON O_SBRACKET C_SBRACKET
%token          COMMA START_COM END_COM NSTRING DDOT
%token <ch>     S_COLON 

/* Original tokens */
%token            AND ARRAY P_BEGIN BOOL CHAR CONST CONTINUE DIV
%token            DO ELSE END EXIT
%token  <name>    ID FUNCTION PROCEDURE 
%token            IF MOD
%token            NOT OF OR PROGRAM REAL RECORD
%token            THEN TYPE VAR WHILE 
%token  <name>    STRING 
%token  <integer> INT_CONST
%token  <real_t>  REAL_CONST

%type   <symrec>  type 
%type   <symrec>  simple_type
%type   <symrec>  scalar_list
%type   <symrec>  scalar_type
%type   <range>   array_type
%type   <symrec>  structured_type
%type   <symrec>  field_list
%type   <symrec>  field
%type   <symrec>  var_decl
%type   <symrec>  f_parm
%type   <symrec>  f_parm_list
%type   <symrec>  var
%type   <symrec>  unsigned_num
%type   <symrec>  unsigned_const
%type   <symrec>  factor
%type   <symrec>  term
%type   <symrec>  func_invok
%type   <symrec>  simple_expr
%type   <symrec>  expr
%type   <symrec>  parm
%type   <plist>   plist_finvok

%% /* Start of grammer */

program                 : program_head decls compound_stat PERIOD
                        ;

program_head            : PROGRAM ID O_BRACKET ID COMMA ID C_BRACKET S_COLON
                        | error { yyerrok; yyclearin; }
                        ;

decls                   : const_decl_part         
                          type_decl_part        
                          var_decl_part
                          proc_decl_part
                        ;

const_decl_part         : CONST const_decl_list S_COLON
                        |
                        ;

const_decl_list         : const_decl
                        | const_decl_list S_COLON const_decl
                        | error S_COLON const_decl { yyerrok; yyclearin; }
                        ;

const_decl              : ID EQUALS expr { declare_const($1, $3); }
                        //| ID expr //{ yyerror("Missing '='"); }
                        ;

type_decl_part          : TYPE type_decl_list S_COLON
                        |
                        ;

type_decl_list          : type_decl
                        | type_decl_list S_COLON type_decl
                        | error S_COLON type_decl { yyerrok; yyclearin; }
                        ;

type_decl               : ID EQUALS type { declare_type($1, $3); }
                        ;

type                    : simple_type     { $$ = $1; }
                        | structured_type { $$ = $1; }
                        ;

simple_type             : scalar_type
                          {
                            $$ = $1;
                          }
                        //| REAL
                        | ID  { $$ = globallookup($1);
                                if($$ == NULL)
                                {
                                  char error[1024];
                                  sprintf(error, "Type '%s' has not been declared.", $1);
                                  semantic_error(error);
                                }
                                else
                                  if ($$->class != OC_TYPE)
                                  {
                                    char error[1024];
                                    sprintf(error, "'%s' is not a type.", $1);
                                    semantic_error(error);
                                  }
                              }
                        ;

scalar_type             : O_BRACKET scalar_list C_BRACKET
                          {
                            if ($2 != NULL)
                            {
                              $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              $$->next = NULL;
                              $$->name = NULL;
                              $$->level = get_current_level();
                              $$->class = OC_TYPE;
                              $$->desc.type_attr.type_class = TC_SCALAR;
                              $$->desc.type_attr.type_description.scalar = (struct tc_scalar*)malloc(sizeof(struct tc_scalar));
                              $$->desc.type_attr.type_description.scalar->const_list = $2;

                              // THIS MAY NOT BE LEGIT
                              struct sym_rec* members = $2;
                              for (; members != NULL; members = members->next) {
                                  members->desc.const_attr.type = $$;
                                  addconst(members->name, $$);
                                }
                            }
                            else
                              $$ = NULL;
                          }

                        | O_BRACKET error C_BRACKET { yyerrok; yyclearin; }
                        //| INT
                        //| BOOL
                        //| CHAR
                        ;

scalar_list             : ID
                          {
                            if (locallookup($1) == NULL)
                            {
                              $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              $$->next = NULL;
                              $$->name = $1;
                              $$->level = get_current_level();
                              $$->class = OC_CONST;
                              $$->desc.const_attr.type = builtinlookup("integer");
                            }
                            else
                            {
                              $$ = NULL;
                              char error[1024];
                              sprintf(error, "'%s' has already been declared in this scope.", $1);
                              semantic_error(error);
                            }
                          }
                        | scalar_list COMMA ID
                          {
                            if (locallookup($3) == NULL)
                            {
                              struct sym_rec* member = $1;

                              for (; member != NULL && strcmp(member->name, $3); member = member->next);                              

                              if (member == NULL) {
                                 $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                                 $$->next = $1;
                                 $$->name = $3;
                                 $$->level = get_current_level();
                                 $$->class = OC_CONST;
                                 $$->desc.const_attr.type = builtinlookup("integer");
                              } else {
                                $$ = $1;
                                char error[1024];
                                sprintf(error, "'%s' has already been declared in this scalar list.", $3);
                                semantic_error(error);
                              }
                            }
                            else
                            {
                              $$ = $1;
                              char error[1024];
                              sprintf(error, "'%s' has already been declared in this scope.", $3);
                              semantic_error(error);
                            }
                          }
                        ;

structured_type         : ARRAY O_SBRACKET array_type C_SBRACKET OF type
                          {
                            if ($3 != NULL && $6 != NULL)
                            {
                              if ( $6->desc.type_attr.type_class == TC_CHAR
                                && (builtinlookup("char")->desc.type_attr.type_description.character == $6->desc.type_attr.type_description.character)
                                && $3->low == 1
                                )
                              {
                                $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                                $$->next = NULL;
                                $$->name = NULL;
                                $$->level = get_current_level();
                                $$->class = OC_TYPE;
                                $$->desc.type_attr.type_class = TC_STRING;
                                $$->desc.type_attr.type_description.string = (struct tc_string*)malloc(sizeof(struct tc_string));
                                $$->desc.type_attr.type_description.string->high = $3->high;
                              }
                              else
                              {
                                $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                                $$->next = NULL;
                                $$->name = NULL;
                                $$->level = get_current_level();
                                $$->class = OC_TYPE;
                                $$->desc.type_attr.type_class = TC_ARRAY;
                                $$->desc.type_attr.type_description.array = (struct tc_array*)malloc(sizeof(struct tc_array));
                                $$->desc.type_attr.type_description.array->subrange = $3;
                                $$->desc.type_attr.type_description.array->object_type = $6;
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        | ARRAY O_SBRACKET error C_SBRACKET OF type { yyerrok; yyclearin; }
                        | RECORD field_list END
                          {
                            search_fields = 0;
                            prev_fields = NULL;
                            if ($2 != NULL)
                            {
                              $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              $$->next = NULL;
                              $$->name = NULL;
                              $$->level = get_current_level();
                              $$->class = OC_TYPE;
                              $$->desc.type_attr.type_class = TC_RECORD;
                              $$->desc.type_attr.type_description.record = (struct tc_record*)malloc(sizeof(struct tc_record));
                              $$->desc.type_attr.type_description.record->field_list = $2;
                            }
                            else
                              $$ = NULL;
                          }
                        ;

array_type              : simple_type
                          {
                            if (isAlias("char", $1))
                            {
                              $$ = (struct tc_subrange*)malloc(sizeof(struct tc_subrange));
                              $$->mother_type = $1;
                              $$->low = 0;
                              $$->high = 255;
                            }
                            else if (isAlias("boolean", $1))
                            {
                              $$ = (struct tc_subrange*)malloc(sizeof(struct tc_subrange));
                              $$->mother_type = $1;
                              $$->low = 0;
                              $$->high = 1;
                            }
                            else
                            {
                              char error[1024];
                              sprintf(error, "Invalid index for array type.");
                              semantic_error(error);
                              $$ = NULL;
                            }
                          }
                        | INT_CONST DDOT INT_CONST
                          {
                            if ($1 <= $3)
                            {
                              $$ = (struct tc_subrange*)malloc(sizeof(struct tc_subrange));
                              $$->mother_type = builtinlookup("integer");
                              $$->low = $1;
                              $$->high = $3;
                            }
                            else
                            {
                              char error[1024];
                              sprintf(error, "Invalid indices for array type - start of subrange greater then end.");
                              semantic_error(error);
                              $$ = NULL;
                            }
                          }
                        | MINUS INT_CONST DDOT MINUS INT_CONST
                          {
                            if (-$2 <= -$5)
                            {
                              $$ = (struct tc_subrange*)malloc(sizeof(struct tc_subrange));
                              $$->mother_type = builtinlookup("integer");
                              $$->low = -$2;
                              $$->high = -$5;
                            }
                            else
                            {
                              char error[1024];
                              sprintf(error, "Invalid indices for array type - start of subrange greater then end.");
                              semantic_error(error);
                              $$ = NULL;
                            }
                          }
                        | MINUS INT_CONST DDOT INT_CONST
                          {
                            $$ = (struct tc_subrange*)malloc(sizeof(struct tc_subrange));
                            $$->mother_type = builtinlookup("integer");
                            $$->low = -$2;
                            $$->high = $4;
                          }
                        | ID DDOT ID
                          {
                            char error[1024];
                            sprintf(error, "Identifiers cannot be used as subrange in arrays.");
                            semantic_error(error);
                            $$ = NULL;
                          }
                        ;                     

field_list              : field
                          {
                            search_fields = 1;
                            $$ = $1;
                            prev_fields = $$;
                          }
                        | field_list S_COLON field
                          {
                            if ($3)
                            {
                              $3->next = $1;
                              $$ = $3;
                              prev_fields = $$;
                            }
                          }
                        | error S_COLON field { yyerrok; yyclearin; }
                        ;

field                   : ID COLON type
                          {
                            int found = 0;
                            if (search_fields)
                            {
                              struct sym_rec* prev = prev_fields;
                              for (; prev != NULL; prev = prev->next) {
                                if ($1 && prev->name && strcmp($1, prev->name) == 0)
                                  found = 1;
                              }
                            }
                            if (!found)
                            {
                              $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              $$->next = NULL;
                              $$->name = $1;
                              $$->level = get_current_level();
                              $$->class = OC_VAR;
                              $$->desc.var_attr.type = $3;
                            }
                            else
                            {
                              char error[1024];
                              sprintf(error, "Duplicate record member %s.", $1);
                              semantic_error(error);
                              $$ = NULL;
                            }
                          }
                        ;

var_decl_part           : VAR var_decl_list S_COLON
                        |
                        ;

var_decl_list           : var_decl
                        | var_decl_list S_COLON var_decl
                        | error S_COLON var_decl { yyerrok; yyclearin; }
                        ;

var_decl                : ID COLON type     { declare_variable($1, $3); $$ = $3; }
                        | ID COMMA var_decl { declare_variable($1, $3); $$ = $3; }
                        ;

proc_decl_part          : proc_decl_list
                        |
                        ;

proc_decl_list          : proc_decl
                        | proc_decl_list proc_decl
                        ;

proc_decl               : proc_heading decls compound_stat S_COLON
                          {
                            poplevel();
                          }
                        //| error S_COLON { yyerrok; yyclearin; }
                        ;

proc_heading            : PROCEDURE ID f_parm_decl S_COLON
                          {
                            if(globallookup($2) == NULL)
                              addproc($2, parm_list);
                            else
                            {
                              char error[1024];
                              sprintf(error, "Procedure name '%s' has already been declared.", $2);
                              semantic_error(error);
                            }
                            pushlevel();
                          }
                        | FUNCTION ID f_parm_decl COLON ID S_COLON
                          {
                            struct sym_rec* ret = globallookup($5);
                            if(ret == NULL)
                            {
                              char error[1024];
                              sprintf(error, "Return value '%s' of function '%s' is not a declared type.", $5, $2);
                              semantic_error(error);
                            }
                            else if(ret->class != OC_TYPE)
                            {
                              char error[1024];
                              sprintf(error, "Return value '%s' of function '%s' does not name a type.", $5, $2);
                              semantic_error(error);
                            }
                            else
                            {
                              if(globallookup($2) == NULL)
                                addfunc($2, parm_list, ret);
                              else
                              {
                                char error[1024];
                                sprintf(error, "Function name '%s' has already been declared.", $2);
                                semantic_error(error);
                              }
                              pushlevel();
                            }
                          }
                        ;

f_parm_decl             : O_BRACKET f_parm_list C_BRACKET
                          {
                            clear_parm_list = 1;
                          }
                        | O_BRACKET C_BRACKET
                        ;

f_parm_list             : f_parm
                          {
                            clear_parm_list = 0;
                            $$ = parm_list;
                          }
                        | f_parm_list S_COLON f_parm
                          {
                            $$ = parm_list;
                          }
                        | error S_COLON f_parm { yyerrok; yyclearin; }
                        ;

f_parm                  : ID COLON ID
                          {
                            if (clear_parm_list) parm_list = NULL;
                            int parm_error = 0;
                            if (parm_list != NULL)
                            {
                              struct sym_rec* prev_parms = parm_list;
                              for(; prev_parms != NULL; prev_parms = prev_parms->next)
                                if(strcmp(prev_parms->name, $1) == 0)
                                  {
                                    char error[1024];
                                    sprintf(error, "'%s' has already been declared as a parameter.", $1);
                                    semantic_error(error);
                                    parm_error = 1;
                                  }
                            }
                            struct sym_rec* s = globallookup($3);
                            if(s == NULL)
                            {
                              char error[1024];
                              sprintf(error, "'%s' is not a declared type.", $3);
                              semantic_error(error);
                              parm_error = 1;
                            }
                            else if(s->class != OC_TYPE)
                            {
                              char error[1024];
                              sprintf(error, "'%s' does not name a type.", $3);
                              semantic_error(error);
                              parm_error = 1;
                            }

                            if (parm_error) s = NULL;
                            parm_list = addparm($1, s, parm_list);
                            $$ = parm_list;
                          }
                        // TODO: fix later
                        | VAR ID COLON ID
                        {
                            if (clear_parm_list) parm_list = NULL;
                            int parm_error = 0;
                            if (parm_list != NULL)
                            {
                              struct sym_rec* prev_parms = parm_list;
                              for(; prev_parms != NULL; prev_parms = prev_parms->next)
                                if(strcmp(prev_parms->name, $2) == 0)
                                  {
                                    char error[1024];
                                    sprintf(error, "'%s' has already been declared as a parameter.", $2);
                                    semantic_error(error);
                                    parm_error = 1;
                                  }
                            }
                            struct sym_rec* s = globallookup($4);
                            if(s == NULL)
                            {
                              char error[1024];
                              sprintf(error, "'%s' is not a declared type.", $4);
                              semantic_error(error);
                              parm_error = 1;
                            }
                            else if(s->class != OC_TYPE)
                            {
                              char error[1024];
                              sprintf(error, "'%s' does not name a type.", $4);
                              semantic_error(error);
                              parm_error = 1;
                            }

                            if (parm_error) s = NULL;
                            parm_list = addparm($2, s, parm_list);
                            $$ = parm_list;
                          }
                        ;

compound_stat           : P_BEGIN stat_list END
                        ;       

stat_list               : stat
                        | stat_list S_COLON stat
                        | error S_COLON stat { yyerrok; yyclearin; }
                        ;

stat                    : simple_stat
                        | struct_stat
                        |
                        ;

simple_stat             : var ASSIGNMENT expr
                        {
                           /* Check for nulls */
                           if ($1 && $3)
                           {  
                              if ($1->class == OC_CONST) {
                                 char error[1024];
                                 if ($1->name) {
                                   sprintf(error, "cannot reassign constant '%s'", $1->name);
                                 } else {
                                   sprintf(error, "cannot reassign constant");
                                 }
                                 semantic_error(error);
                              } else if ($1->class == OC_VAR) {

                              if (assignment_compatible($1->desc.var_attr.type, $3) == 0) {
                                 char error[1024];
                                 sprintf(error, "assignment type is incompatible", $1);
                                 semantic_error(error);
                                 }
                              } else {
                                 char error[1024];
                                 if ($1->name) {
                                    sprintf(error, "Illegal assignment operation: %s is not a variable.", $1->name);
                                    semantic_error(error);
                                 }
                                 else {
                                    sprintf(error, "Illegal assignment operation: LHS not a variable.");
                                    semantic_error(error);
                                 
                                 }
                                 
                              }
                           }
                        }
                        | proc_invok
                        | compound_stat
                        ;

proc_invok              : plist_finvok C_BRACKET
                        | ID O_BRACKET C_BRACKET
                        {
                            char error[1024];
                            struct sym_rec* proc = globallookup($1);
                            if (proc) {
                              if (proc->class == OC_PROC)
                              {
                                if (proc->desc.proc_attr.parms != NULL)
                                {
                                  sprintf(error, "Missing arguments for procedure '%s'.", $1);
                                  semantic_error(error);
                                }
                              }
                              else
                              {
                                sprintf(error, "Attempting to call '%s' which is not a procedure.", $1);
                                semantic_error(error);
                              }
                            } else {
                              sprintf(error, "Attempting to call procedure '%s' which is has not been declared.", $1);
                              semantic_error(error);
                            }
                        }
                        ;

var                     : ID
                          {
                            $$ = globallookup($1);
                            if (!$$)
                            {
                              char error[1024];
                              sprintf(error, "variable '%s' undeclared at this level", $1);
                              semantic_error(error);
                            }
                          }
                        | var PERIOD ID
                        | subscripted_var C_SBRACKET
                        ;

subscripted_var         : var O_SBRACKET expr
                        {
                          if ($1) {
                             if ($1->class == OC_VAR) {
                                if ($1->desc.var_attr.type->desc.type_attr.type_class == TC_ARRAY) {
                                   
                                }
                                else {
                                   char error[1024];
                                   sprintf(error, "cannot subscript '%s', it is not an array", $1->name);
                                   semantic_error(error);}
                             }
                             
                          }
                        }
                        | subscripted_var COMMA expr
                        ;

expr                    : simple_expr { $$ = $1; }
                        | simple_expr operator expr
                          {
                            struct sym_rec* ret_type = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                            ret_type->name = NULL;
                            ret_type->level = get_current_level();
                            ret_type->class = OC_TYPE;
                            ret_type->desc.type_attr.type_class = TC_BOOLEAN;
                            ret_type->desc.type_attr.type_description.boolean = builtinlookup("boolean")->desc.type_attr.type_description.boolean;
                            $$ = ret_type;

                            char error[1024];
                            if ($1 && $3)
                            {
                              if  (   ($1->desc.type_attr.type_class != TC_SCALAR && $3->desc.type_attr.type_class == TC_SCALAR)
                                  ||  ($1->desc.type_attr.type_class == TC_SCALAR && $3->desc.type_attr.type_class != TC_SCALAR))
                              {
                                $$ = NULL;
                                sprintf(error, "Cannot mix scalar and non-scalar types to comparison operators.");
                                semantic_error(error);
                              }

                              else if (   ($1->desc.type_attr.type_class != TC_STRING && $3->desc.type_attr.type_class == TC_STRING)
                                      ||  ($1->desc.type_attr.type_class == TC_STRING && $3->desc.type_attr.type_class != TC_STRING))
                              {
                                $$ = NULL;
                                sprintf(error, "Cannot mix string and non-string types to comparison operators.");
                                semantic_error(error);
                              }

                              else if ($1->desc.type_attr.type_class == TC_SCALAR && $3->desc.type_attr.type_class == TC_SCALAR) {
                                   if ($1->desc.type_attr.type_description.scalar != $3->desc.type_attr.type_description.scalar)
                                   {
                                        $$ = NULL;
                                        sprintf(error, "Incompatible scalar types given to comparison operator.");
                                        semantic_error(error);
                                   }
                                }

                              else if ($1->desc.type_attr.type_class == TC_STRING && $3->desc.type_attr.type_class == TC_STRING) {
                                if ($1->desc.type_attr.type_description.string->high != $3->desc.type_attr.type_description.string->high)
                                {
                                  $$ = NULL;
                                  sprintf(error, "Incompatible string types given to comparison operator.");
                                  semantic_error(error);
                                  }
                                }

                              else if (   ($1->desc.type_attr.type_class != TC_BOOLEAN && $3->desc.type_attr.type_class == TC_BOOLEAN)
                                      ||  ($1->desc.type_attr.type_class == TC_BOOLEAN && $3->desc.type_attr.type_class != TC_BOOLEAN))
                              {
                                $$ = NULL;
                                sprintf(error, "Cannot mix boolean and non-boolean types to comparison operators.");
                                semantic_error(error);
                              }

                              else if (   ($1->desc.type_attr.type_class != TC_CHAR && $3->desc.type_attr.type_class == TC_CHAR)
                                      ||  ($1->desc.type_attr.type_class == TC_CHAR && $3->desc.type_attr.type_class != TC_CHAR))
                              {
                                $$ = NULL;
                                sprintf(error, "Cannot mix char and non-char types to comparison operators.");
                                semantic_error(error);
                              }

                              else if (   ($1->desc.type_attr.type_class == TC_INTEGER || $1->desc.type_attr.type_class == TC_REAL)
                                       && ($3->desc.type_attr.type_class != TC_INTEGER && $3->desc.type_attr.type_class != TC_REAL))
                              {
                                $$ = NULL;
                                sprintf(error, "Cannot mix real/integer and non-real/integer types to comparison operators.");
                                semantic_error(error);
                              }

                              else if (   ($3->desc.type_attr.type_class == TC_INTEGER || $3->desc.type_attr.type_class == TC_REAL)
                                       && ($1->desc.type_attr.type_class != TC_INTEGER && $1->desc.type_attr.type_class != TC_REAL))
                              {
                                $$ = NULL;
                                sprintf(error, "Cannot mix real/integer and non-real/integer types to comparison operators.");
                                semantic_error(error);
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        ;
            
operator                : EQUALS
                        | NOT_EQUAL
                        | LESS_EQUAL
                        | LESS_THAN
                        | GREATER_EQUAL
                        | GREATER_THAN
                        | error
                        ;

simple_expr             : term { $$ = $1; }
                        | PLUS term
                        {
                          if($2)
                          {
                            if ($2->desc.type_attr.type_class == TC_REAL || $2->desc.type_attr.type_class == TC_INTEGER)
                              $$ = $2;
                            else
                            {
                              char error[1024];
                              sprintf(error, "Unary '+' can only act on integers or reals.");
                              semantic_error(error);
                              $$ = NULL;
                            }
                          }
                          else
                            $$ = NULL;
                        }
                        | MINUS term
                        {
                          if($2)
                          {
                            if ($2->desc.type_attr.type_class == TC_REAL || $2->desc.type_attr.type_class == TC_INTEGER)
                              $$ = $2;
                            else
                            {
                              char error[1024];
                              sprintf(error, "Unary '-' can only act on integers or reals.");
                              semantic_error(error);
                              $$ = NULL;
                            }
                          }
                          else
                            $$ = NULL;
                        }
                        | simple_expr PLUS term
                          {
                            if ($1 && $3)
                            {
                              if (    ($1->desc.type_attr.type_class != TC_REAL && $1->desc.type_attr.type_class != TC_INTEGER)
                                  ||  ($3->desc.type_attr.type_class != TC_REAL && $3->desc.type_attr.type_class != TC_INTEGER)
                                  )
                              {
                                char error[1024];
                                sprintf(error, "operands of 'plus' must be either integers or reals.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                              else if ($1->desc.type_attr.type_class == TC_REAL)
                                $$ = $1;
                              else if ($3->desc.type_attr.type_class == TC_REAL)
                                $$ = $3;
                              // both integers
                              else
                                $$ = $1;
                            }
                            else
                              $$ = NULL;
                          }
                        | simple_expr MINUS term
                          {
                            if ($1 && $3)
                            {
                              if (    ($1->desc.type_attr.type_class != TC_REAL && $1->desc.type_attr.type_class != TC_INTEGER)
                                  ||  ($3->desc.type_attr.type_class != TC_REAL && $3->desc.type_attr.type_class != TC_INTEGER)
                                  )
                              {
                                char error[1024];
                                sprintf(error, "operands of 'minus' must be either integers or reals.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                              else if ($1->desc.type_attr.type_class == TC_REAL)
                                $$ = $1;
                              else if ($3->desc.type_attr.type_class == TC_REAL)
                                $$ = $3;
                              // both integers
                              else
                                $$ = $1;
                            }
                            else
                              $$ = NULL;
                          }
                        | simple_expr OR  term
                          { 
                            if ($1 && $3)
                            {
                              if ($1->desc.type_attr.type_class == TC_BOOLEAN && $3->desc.type_attr.type_class == TC_BOOLEAN)
                                  $$ = $1;
                              else
                              {
                                char error[1024];
                                sprintf(error, "'or' operands must be of type boolean.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        ;

term                    : factor { $$ = $1; }
                        | term MULTIPLY factor
                          {
                            if ($1 && $3)
                            {
                              if (    ($1->desc.type_attr.type_class != TC_REAL && $1->desc.type_attr.type_class != TC_INTEGER)
                                  ||  ($3->desc.type_attr.type_class != TC_REAL && $3->desc.type_attr.type_class != TC_INTEGER)
                                  )
                              {
                                char error[1024];
                                sprintf(error, "operands of 'multiply' must be either integers or reals.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                              else if ($1->desc.type_attr.type_class == TC_REAL)
                                $$ = $1;
                              else if ($3->desc.type_attr.type_class == TC_REAL)
                                $$ = $3;
                              // both integers
                              else
                                $$ = $1;
                            }
                            else
                              $$ = NULL;
                          }
                        | term DIVIDE factor
                          {
                            if ($1 && $3)
                            {
                              if (    ($1->desc.type_attr.type_class != TC_REAL && $1->desc.type_attr.type_class != TC_INTEGER)
                                  ||  ($3->desc.type_attr.type_class != TC_REAL && $3->desc.type_attr.type_class != TC_INTEGER)
                                  )
                              {
                                char error[1024];
                                sprintf(error, "operands of 'divide' must be either integers or reals.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                              else if ($1->desc.type_attr.type_class == TC_REAL)
                                $$ = $1;
                              else if ($3->desc.type_attr.type_class == TC_REAL)
                                $$ = $3;
                              // both integers
                              else
                                $$ = $1;
                            }
                            else
                              $$ = NULL;
                          }
                        | term DIV factor
                          {
                            if($1 && $3)
                            {
                              if ($1->desc.type_attr.type_class == TC_INTEGER && $3->desc.type_attr.type_class == TC_INTEGER)
                                  $$ = $1;
                              else
                              {
                                char error[1024];
                                sprintf(error, "'div' operands must be of type integer.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        | term MOD factor
                          {
                            if($1 && $3)
                            {
                              if ($1->desc.type_attr.type_class == TC_INTEGER && $3->desc.type_attr.type_class == TC_INTEGER)
                                  $$ = $1;
                              else
                              {
                                char error[1024];
                                sprintf(error, "'mod' operands must be of type integer.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        | term AND factor
                          { 
                            if ($1 && $3)
                            {
                              if ($1->desc.type_attr.type_class == TC_BOOLEAN && $3->desc.type_attr.type_class == TC_BOOLEAN)
                                  $$ = $1;
                              else
                              {
                                char error[1024];
                                sprintf(error, "'and' operands must be of type boolean.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        ;

factor                  : var
                          {
                            if($1)
                            {
                              switch($1->class)
                              {
                                case OC_TYPE:
                                  $$ = $1;
                                  break;
                                case OC_VAR:
                                  $$ = $1->desc.var_attr.type;
                                  break;
                                case OC_CONST:
                                  $$ = $1->desc.const_attr.type;
                                  break;
                                default:
                                  semantic_error("could not find type of expression");
                              }
                            }
                            else
                              $$ = $1;
                          }
						            | unsigned_const { $$ = $1; }
                        | O_BRACKET expr C_BRACKET { $$ = $2; }
                        | func_invok { $$ = $1; }
                        | NOT factor
                          {
                            if ($2)
                            {
                              if ($2->class == OC_TYPE && $2->desc.type_attr.type_class == TC_BOOLEAN)
                                $$ = $2;
                              else
                              {
                                char error[1024];
                                sprintf(error, "Invalid operand for unary operator 'not' - expected type boolean");
                                semantic_error(error);
                                $$ = NULL;
                              }
                            }
                            else
                              $$ = $2;
                          }
                        ;

unsigned_const          : unsigned_num { $$ = $1; }
						            | STRING
                          {
                            if (strlen($1) != 1)
                            {
                              $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              $$->next = NULL;
                              $$->name = NULL;
                              $$->level = get_current_level();
                              $$->class = OC_TYPE;
                              $$->desc.type_attr.type_class = TC_STRING;
                              $$->desc.type_attr.type_description.string = (struct tc_string*)malloc(sizeof(struct tc_string));
                              $$->desc.type_attr.type_description.string->high = strlen($1) - 2; /* Because of single quotes */
                            }
                            else
                              $$ = builtinlookup("char");
                          }
                          | NSTRING   			/* Non-terminated string warning here */                                        
                          {
                            $$ = NULL;
                          }
                        ;                                

unsigned_num            : INT_CONST
                          {
                            $$ = builtinlookup("integer");
                          }
						            | REAL_CONST
                          {
                            $$ = builtinlookup("real");
                          }
						            ;                                

func_invok              : plist_finvok C_BRACKET 
                        { /* Need return value */
                          if ($1) {
                             $$ = $1->return_type; 
                          } else {
                             $$ = NULL;
                          }
                        }
                        | ID O_BRACKET C_BRACKET
                          {
                            char error[1024];
                            struct sym_rec* func = globallookup($1);
                            if (func) {
                              if (func->class == OC_FUNC)
                              {
                                if (func->desc.func_attr.parms == NULL)
                                  $$ = func->desc.func_attr.return_type;
                                else
                                {
                                  sprintf(error, "Missing arguments for function '%s'.", $1);
                                  semantic_error(error);
                                }
                              }
                              else
                              {
                                sprintf(error, "Attempting to call '%s' which is not a function.", $1);
                                semantic_error(error);
                              }
                            } else {
                              sprintf(error, "Attempting to call '%s' which is has not been declared.", $1);
                              semantic_error(error);
                              $$ = NULL;
                            }
                          }
                        ;

plist_finvok            : ID O_BRACKET parm
                          {
                            struct sym_rec* func = globallookup($1);
                            if (func)
                            {
                              if (func->class == OC_FUNC)
                              {
                                $$ = (struct plist_t*)malloc(sizeof(struct plist_t));
                                $$->parmlist = func->desc.func_attr.parms;
                                $$->counter = 0;
                                $$->return_type = func->desc.func_attr.return_type;
                                $$->name = func->name;

                                struct sym_rec* last_parm = NULL;
                                for(func = $$->parmlist; func != NULL; func = func->next)
                                {
                                  printf("Parameter %s found\n", func->name);
                                  $$->counter = $$->counter + 1; 
                                  last_parm = func;
                                }
                                $$->max = $$->counter;

                                if ($3 && last_parm) {
                                
                                /* This should be an OC_VAR always */
                                  if (last_parm->class == OC_VAR) {
                                     if (!compare_types($3, last_parm->desc.var_attr.type))
                                     {
                                        char error[1024];
                                        sprintf(error, "Incompatible parameter passed to '%s' in position %d", $1, $$->max - $$->counter + 1);
                                        semantic_error(error);
                                     }
                                  }
                                }

                                $$->counter = $$->counter - 1;
                              }
                              else if (func->class == OC_PROC)
                              {
                                $$ = (struct plist_t*)malloc(sizeof(struct plist_t));
                                $$->parmlist = func->desc.proc_attr.parms;
                                $$->counter = 0;
                                $$->return_type = NULL;
                                $$->name = func->name;

                                struct sym_rec* last_parm = NULL;
                                for(func = $$->parmlist; func != NULL; func = func->next)
                                {
                                  $$->counter = $$->counter + 1;
                                  last_parm = func;
                                }
                                $$->max = $$->counter;

                                if ($3 && last_parm) {
                                
                                /* This should be an OC_VAR */
                                   if (last_parm->class == OC_VAR) {
                                      if (!compare_types($3, last_parm->desc.var_attr.type))
                                      {
                                        char error[1024];
                                        sprintf(error, "Incompatible parameter passed to '%s' in position %d", $1, $$->max - $$->counter + 1);
                                        semantic_error(error);
                                      }
                                   }
                                }

                                $$->counter = $$->counter - 1;
                              }
                            }
                            else
                            {
                              char error[1024];
                              sprintf(error, "Function or procedure '%s' not declared here.", $1);
                              semantic_error(error);
                              $$ = NULL;
                            }
                          }
                        | plist_finvok COMMA parm
                        {
                           if ($1) {
                                int i;
                                struct sym_rec* last_parm = NULL;
                                
                                for(i = 1, last_parm = $1->parmlist; last_parm != NULL && i < $1->counter; last_parm = last_parm->next, i++);
                                                                
                                if ($3 && last_parm) {

                                /* This should be an OC_VAR */
                                   if (last_parm->class == OC_VAR) {
                                      if (!compare_types($3, last_parm->desc.var_attr.type))
                                      {
                                        char error[1024];
                                        if ($1->name) {
                                           sprintf(error, "Incompatible parameter passed to '%s' in position %d", $1->name, $1->max - $1->counter + 1);
                                           semantic_error(error);
                                        } else {
                                           sprintf(error, "Incompatible parameter passed in position %d", $1->max - $1->counter + 1);
                                           semantic_error(error);
                                        }
                                        }
                                      }
                                   }
                                
                                $1->counter = $1->counter - 1;
                                $$ = $1;
                            } else {
                                 $$ = $1;
                            }
                        }
                        ;

parm                    : expr { $$ = $1; }
                        ;

struct_stat             : IF expr THEN stat
                          {
                            if ($2 && $2->desc.type_attr.type_class != TC_BOOLEAN)
                            {
                              char error[1024];
                              sprintf(error, "If statement conditionals must be of type boolean.");
                              semantic_error(error);
                            }
                          }
                        | IF error THEN stat { yyerrok; yyclearin; }
                        | IF expr THEN matched_stat ELSE stat
                          {
                            if ($2 && $2->desc.type_attr.type_class != TC_BOOLEAN)
                            {
                              char error[1024];
                              sprintf(error, "If statement conditionals must be of type boolean.");
                              semantic_error(error);
                            }
                          }
                        | IF error THEN matched_stat ELSE stat { yyerrok; yyclearin; }
                        | IF expr THEN error ELSE stat
                        | THEN stat { yyerror("Missing 'if' required to match 'then' statement"); }
                        | THEN matched_stat ELSE stat { yyerror("Missing 'if' required to match 'then' statement"); }
                        | WHILE expr DO stat
                          {
                            if ($2 && $2->desc.type_attr.type_class != TC_BOOLEAN)
                            {
                              char error[1024];
                              sprintf(error, "while statement conditionals must be of type boolean.");
                              semantic_error(error);
                            }
                          }
                        | WHILE error DO { yyerrok; yyclearin; }
                        | DO stat { yyerror("Missing 'while' required to match 'do' statement"); }
                        | CONTINUE
                        | EXIT
                        ;

matched_stat            : simple_stat
                        | IF expr THEN matched_stat ELSE matched_stat
                          {
                            if ($2 && $2->desc.type_attr.type_class != TC_BOOLEAN)
                            {
                              char error[1024];
                              sprintf(error, "If statement conditionals must be of type boolean.");
                              semantic_error(error);
                            }
                          }
                        | IF error THEN matched_stat ELSE matched_stat { yyerrok; yyclearin; }
                        | IF expr THEN error ELSE matched_stat { yyerrok; yyclearin; }
                        | WHILE expr DO matched_stat
                        | WHILE error DO matched_stat { yyerrok; yyclearin; }
                        | CONTINUE
                        | EXIT
                        ;
%% /* End of grammer */
