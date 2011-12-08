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

#include "codegen.h"
#include "pal.h"
#include "semantics.h"
#include "symtab.h"

struct sym_rec* prev_fields;

struct sym_rec* parm_list = NULL;

struct temp_array_var* temp_array_vars = NULL;

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
  struct expr_t*      exprec;
  struct var_info_t*  varinfo;
  }

/* New tokens */
%token            ASSIGNMENT
%token  <integer> GREATER_THAN LESS_EQUAL GREATER_EQUAL EQUALS NOT_EQUAL LESS_THAN
%token            O_BRACKET C_BRACKET
%token            PERIOD COLON O_SBRACKET C_SBRACKET
%token            COMMA START_COM END_COM NSTRING DDOT
%token  <ch>      S_COLON 
%token  <integer> PLUS MINUS MULTIPLY DIVIDE MOD DIV

/* Original tokens */
%token            ARRAY P_BEGIN BOOL CHAR CONST CONTINUE
%token            DO ELSE END EXIT
%token  <name>    ID FUNCTION PROCEDURE 
%token            IF 
%token            OF PROGRAM REAL RECORD
%token            THEN TYPE VAR WHILE 
%token  <name>    STRING 
%token  <integer> INT_CONST
%token  <real_t>  REAL_CONST
%token  <integer> AND OR NOT

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
%type   <varinfo> var
%type   <varinfo> subscripted_var
%type   <exprec>  unsigned_num
%type   <exprec>  unsigned_const
%type   <exprec>  factor
%type   <exprec>  term
%type   <exprec>  func_invok
%type   <exprec>  simple_expr
%type   <exprec>  expr
%type   <exprec>  parm
%type   <plist>   plist_finvok
%type   <integer> operator

%% /* Start of grammer */

program                 : program_head decls compound_stat PERIOD	 { asc_stop(); }
                        | error
                        ;

program_head            : PROGRAM ID O_BRACKET ID COMMA ID C_BRACKET S_COLON
                          { 
                            asc_function_definition(ASC_FUNCTION_BEGIN, $2, NULL, 0);
                            asc_start($2);
                          }

                        | error { yyerrok; yyclearin; }
                        ;

decls                   : const_decl_part         
                          type_decl_part        
                          var_decl_part
                          proc_decl_part
						            //| error S_COLON	{ yyerrok; yyclearin; }
                        ;

const_decl_part         : CONST const_decl_list S_COLON
                        |
                        ;

const_decl_list         : const_decl
                        | const_decl_list S_COLON const_decl
                        | error S_COLON const_decl { yyerrok; yyclearin; }
                        ;

const_decl              : ID EQUALS expr { declare_const($1, $3);}
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

                              struct sym_rec* members = $2;
                              for (; members != NULL; members = members->next) {
                                  members->desc.const_attr.type = $$;
                                  struct sym_rec* sym_entry = addconst(members->name, $$);
                                  sym_entry->desc.const_attr.value.integer = members->desc.const_attr.value.integer;
                                  //printf("Adding scalar '%s' with value %d\n", members->name, members->desc.const_attr.value.integer);
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
                              $$->desc.const_attr.value.integer = 0;
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

                              int i;
                              for (i=0; member != NULL && strcmp(member->name, $3); member = member->next, i++);

                              if (member == NULL) {
                                 $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                                 $$->next = $1;
                                 $$->name = $3;
                                 $$->level = get_current_level();
                                 $$->class = OC_CONST;
                                 $$->desc.const_attr.type = builtinlookup("integer");
                                 $$->desc.const_attr.value.integer = i;
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
                              if ( $6->class == OC_TYPE && $6->desc.type_attr.type_class == TC_CHAR
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
                        | ARRAY O_SBRACKET error C_SBRACKET OF type
                          {
                            $$ = NULL;
                            yyerrok; yyclearin; 
                          }
                        | RECORD field_list END
                          {
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
                            //if ($1)
                            //  printf("array typename: %s\n", $1->name);
                            if ($1 && isAlias("char", $1))
                            {
                              $$ = (struct tc_subrange*)malloc(sizeof(struct tc_subrange));
                              $$->mother_type = $1;
                              $$->low = 0;
                              $$->high = 255;
                            }
                            else if ($1 && isAlias("boolean", $1))
                            {
                              $$ = (struct tc_subrange*)malloc(sizeof(struct tc_subrange));
                              $$->mother_type = $1;
                              $$->low = 0;
                              $$->high = 1;
                            }
                            else if ($1) // if $1 is null, we've already printed an error
                            {
                              char error[1024];
                              sprintf(error, "Invalid index for array type.");
                              semantic_error(error);
                              $$ = NULL;
                            }
                          }
                        | expr DDOT expr
                          {
                            if ($1 && $3 && $1->type && $3->type)
                            {
                              if($1->is_const && $3->is_const)
                              {
                                if (compare_types($1->type, $3->type, 0))
                                {
                                  char error[1024];
                                  $$ = (struct tc_subrange*)malloc(sizeof(struct tc_subrange));
                                  $$->mother_type = $1->type;

                                  switch($1->type->desc.type_attr.type_class)
                                  {
                                    case TC_INTEGER:
                                      if ($1->value.integer > $3->value.integer)
                                      {
                                        sprintf(error, "Invalid indices for array type - start of subrange greater than end.");
                                        semantic_error(error);
                                        free($$);
                                        $$ = NULL;
                                      }
                                      else
                                      {
                                        $$->low = $1->value.integer;
                                        $$->high = $3->value.integer;
                                      }
                                      break;
                                    case TC_REAL:
                                      sprintf(error, "Invalid indices for array type - index type cannot be real.");
                                      semantic_error(error);
                                      free($$);
                                      $$ = NULL;
                                      break;
                                    case TC_CHAR:
                                      if ($1->value.character > $3->value.character)
                                      {
                                        sprintf(error, "Invalid indices for array type - start of subrange greater than end.");
                                        semantic_error(error);
                                        free($$);
                                        $$ = NULL;
                                      }
                                      else
                                      {
                                        $$->low = (int)($1->value.character);
                                        $$->high = (int)($3->value.character);
                                      }
                                      break;
                                    case TC_BOOLEAN:
                                      if ($1->value.boolean > $3->value.boolean)
                                      {
                                        sprintf(error, "Invalid indices for array type - start of subrange greater than end.");
                                        semantic_error(error);
                                        free($$);
                                        $$ = NULL;
                                      }
                                      else
                                      {
                                        $$->low = $1->value.boolean;
                                        $$->high = $3->value.boolean;
                                      }
                                      break;
                                    case TC_STRING:
                                      sprintf(error, "Invalid indices for array type - the index type cannot be string.");
                                      semantic_error(error);
                                      free($$);
                                      $$ = NULL;
                                      break;
                                    case TC_SCALAR:
                                      if ($1->value.integer > $3->value.integer)
                                      {
                                        sprintf(error, "Invalid indices for array type - start of subrange greater than end.");
                                        semantic_error(error);
                                        free($$);
                                        $$ = NULL;
                                      }
                                      else
                                      {
                                        $$->low = $1->value.integer;
                                        $$->high = $3->value.integer;
                                      }
                                      break;
                                    case TC_ARRAY:
                                      sprintf(error, "Invalid indices for array type - the index type cannot be an array.");
                                      semantic_error(error);
                                      free($$);
                                      $$ = NULL;
                                      break;
                                    case TC_RECORD:
                                      sprintf(error, "Invalid indices for array type - the index type cannot be a record.");
                                      semantic_error(error);
                                      free($$);
                                      $$ = NULL;
                                      break;
                                    case TC_SUBRANGE:
                                      sprintf(error, "Invalid indices for array type - the index type cannot be an subrange.");
                                      semantic_error(error);
                                      free($$);
                                      $$ = NULL;
                                      break;
                                    default:
                                      printf("This is not a TC_ enum...\n");
                                  }
                                }
                                else
                                {
                                  char error[1024];
                                  sprintf(error, "Array indices have different types.");
                                  semantic_error(error);
                                }
                              }
                              else
                              {
                                char error[1024];
                                sprintf(error, "Array indices must be constants.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                            }
                          }
                          /*
                          | STRING DDOT STRING
                          {
                            if (strlen($1) == 1 && strlen($3) == 1)
                            {
                              int low = (int)($1[1]);
                              int high = (int)($3[1]);
                              if (low <= high)
                              {
                                $$ = (struct tc_subrange*)malloc(sizeof(struct tc_subrange));
                                $$->mother_type = builtinlookup("char");
                                $$->low = low;
                                $$->high = high;
                              }
                              else
                              {
                                char error[1024];
                                sprintf(error, "Invalid indices for array type - start of subrange greater than end.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                            }
                            else
                            {
                              char error[1024];
                              sprintf(error, "Cannot use strings as indices of arrays.");
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
                              sprintf(error, "Invalid indices for array type - start of subrange greater than end.");
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
                              sprintf(error, "Invalid indices for array type - start of subrange greater than end.");
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
                        //| error { $$ = NULL; yyclearin; yyerrok; }
                        */
                        ;                     

field_list              : field
                          {
                            $$ = $1;
                            prev_fields = $$;
                            if (prev_fields)
                              prev_fields->next = NULL;
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
                        | error S_COLON field { $$ = NULL;  yyerrok; yyclearin; }
                        ;

field                   : ID COLON type
                          {
                            int found = 0;
                            
                            struct sym_rec* prev = prev_fields;
                            for (; prev != NULL; prev = prev->next) {
                              if ($1 && prev->name && strcmp($1, prev->name) == 0)
                                found = 1;
                            }

                            if (!found)
                            {
                              $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              $$->next = NULL;
                              $$->name = $1;
                              $$->level = get_current_level();
                              $$->class = OC_VAR;
                              $$->desc.var_attr.type = $3;
                              $$->desc.var_attr.reference_semantics = 0;
                              if (!prev_fields)
                                $$->desc.var_attr.location.offset = 0;
                              else
                              {
                                $$->desc.var_attr.location.offset = prev_fields->desc.var_attr.location.offset;
                                $$->desc.var_attr.location.offset += sizeof_type(prev_fields->desc.var_attr.type);
                              }
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
                            asc_function_definition(ASC_FUNCTION_END, NULL, NULL, 0);
                          }
                        //| error S_COLON { yyerrok; yyclearin; }
                        ;

proc_heading            : PROCEDURE ID f_parm_decl S_COLON
                          {
                            struct sym_rec* proc = NULL;
                            if(locallookup($2) == NULL)
                              proc = addproc($2, parm_list);
                            else
                            {
                              char error[1024];
                              sprintf(error, "Procedure name '%s' has already been declared.", $2);
                              semantic_error(error);
                            }
                            pushlevel(NULL);
                            asc_function_definition(ASC_FUNCTION_BEGIN, $2, parm_list, proc ? proc->desc.proc_attr.id : -1);
                            parm_list = NULL;
                          }
                        | PROCEDURE error f_parm_decl S_COLON { yyerrok; yyclearin; parm_list = NULL; pushlevel(NULL);}
                        | FUNCTION error f_parm_decl S_COLON { yyerrok; yyclearin; parm_list = NULL; pushlevel(NULL);}
                        | FUNCTION error f_parm_decl COLON ID S_COLON { yyerrok; yyclearin; parm_list = NULL; pushlevel(NULL);}
                        | FUNCTION ID f_parm_decl COLON ID S_COLON
                          {
                            struct sym_rec* ret = globallookup($5);
                            struct sym_rec* func_rec = NULL;
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
                              /* Add to sym_tab no matter what */
                              if(locallookup($2) == NULL)
                                func_rec = addfunc($2, parm_list, ret);
                              else
                              {
                                char error[1024];
                                sprintf(error, "Function name '%s' has already been declared.", $2);
                                semantic_error(error);
                              }
                              if (isSimpleType(ret) == 0) {
                                char error[1024];
                                sprintf(error, "Functions may only return a simple type.", $2);
                                semantic_error(error);
                              }
                            }
                            pushlevel(func_rec);
                            asc_function_definition(ASC_FUNCTION_BEGIN, $2, parm_list, func_rec ? func_rec->desc.func_attr.id : -1);
                            parm_list = NULL;
                          }
                        | FUNCTION ID f_parm_decl S_COLON
                          {
                            char error[1024];
                            sprintf(error, "Function '%s' has no return type.", $2);
                            yyerror(error);

                            struct sym_rec* func_rec = NULL;
                            if(globallookup($2) == NULL)
                              func_rec = addfunc($2, parm_list, NULL);
                            else
                            {
                              char error[1024];
                              sprintf(error, "Function name '%s' has already been declared.", $2);
                              semantic_error(error);
                            }
                            pushlevel(func_rec);
                            parm_list = NULL;
                          }
                        ;

f_parm_decl             : O_BRACKET f_parm_list C_BRACKET
                        | O_BRACKET C_BRACKET
                        ;

f_parm_list             : f_parm
                          {
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
                            else if(strcmp($1, s->name) == 0)
                            {
                              char error[1024];
                              sprintf(error, "'%s' is already in use at this scope.", $3);
                              semantic_error(error);
                              parm_error = 1;
                            }

                            if (parm_error) s = NULL;

                            int size = 1;
                            if (s && s->class == OC_TYPE)
                              size = sizeof_type(s);

                            struct location_t location;
                            asc_next_parameter_location(&location, size);
                            parm_list = addparm($1, s, parm_list, &location, 0);
                            $$ = parm_list;
                          }
                        | VAR ID COLON ID
                        {
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

                            struct location_t location;
                            asc_next_parameter_location(&location, 1);
                            parm_list = addparm($2, s, parm_list, &location, 1); // 1 because we passing by reference
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
                          if ($1 && $1->var && $3 && $3->type)
                          {  
                            if ($1->var->desc.var_attr.type != NULL)
                            {
                              if ($1->var->class == OC_CONST) {
                                 char error[1024];
                                 if ($1->var->name) {
                                   sprintf(error, "cannot reassign constant '%s'", $1->var->name);
                                 } else {
                                   sprintf(error, "cannot reassign constant");
                                 }
                                 semantic_error(error);
                              } else if ($1->var->class == OC_VAR || $1->var->class == OC_RETURN) {
                                if (assignment_compatible($1->var->desc.var_attr.type, $3->type) == 0) {
                                  char error[1024];
                                  sprintf(error, "assignment type is incompatible", $1);
                                  semantic_error(error);
                                } else {
                                  //printf("Assigning to %s, with location_on_stack %d\n", $1->var->name, $1->location_on_stack);
                                  asc_assignment($1->var, $1->location_on_stack, $3);
                                }
                              } else {
                                 char error[1024];
                                 if ($1->var->name) {
                                    sprintf(error, "Illegal assignment operation: %s is not a variable.", $1->var->name);
                                    semantic_error(error);
                                 }
                                 else {
                                    sprintf(error, "Illegal assignment operation: LHS not a variable.");
                                    semantic_error(error);
                                 
                                 }
                              }
                            }
                          }
                          // free all the temporary variables that we've kept around to access array subscripting
                          while(temp_array_vars != NULL)
                          {
                            struct temp_array_var* tmp = temp_array_vars;
                            temp_array_vars = temp_array_vars->next;
                            free(tmp);
                          }
                        }
                        | proc_invok
                        | compound_stat
                        ;

proc_invok              : plist_finvok C_BRACKET
                        {
                          if ($1)
                          {
                            if ($1->counter != 0 && !isIOFunc($1))
                            {
                              char error[1024];
                              if ($1->name)
                                sprintf(error, "Wrong number of parameters given to '%s'.", $1->name);
                              else
                               sprintf(error, "Wrong number of parameters.");
                              semantic_error(error);
                            }

                            struct sym_rec* func = isCurrentFunction($1->name);
                            if (!func)
                              func = globallookup($1->name);
                            asc_function_call(ASC_FUNCTION_CALL_END, func, 0, 0, 1);
                          }
                        }
                        | ID O_BRACKET C_BRACKET
                        {
                            char error[1024];
                            struct sym_rec* proc = isCurrentFunction($1);
                            if (!proc)
                              proc = globallookup($1);
                            if (proc) {
                              if (proc->class == OC_PROC)
                              {
                                if (proc->desc.proc_attr.parms != NULL)
                                {
                                  sprintf(error, "Missing arguments for procedure '%s'.", $1);
                                  semantic_error(error);
                                }
                                else
                                {
                                  asc_function_call(ASC_FUNCTION_CALL_BEGIN, proc, 0, 0, 1);
                                  asc_function_call(ASC_FUNCTION_CALL_END, proc, 0, 0, 1);
                                }
                              }
                              else if (proc->class == OC_FUNC)
                              {
                                if (proc->desc.func_attr.parms != NULL)
                                {
                                  sprintf(error, "Missing arguments for function '%s'.", $1);
                                  semantic_error(error);
                                }
                                else
                                {
                                  asc_function_call(ASC_FUNCTION_CALL_BEGIN, proc, 0, 0, 1);
                                  asc_function_call(ASC_FUNCTION_CALL_END, proc, 0, 0, 1);
                                }
                              }
                              else
                              {
                                sprintf(error, "Attempting to call '%s' which is not a procedure or a function.", $1);
                                semantic_error(error);
                              }
                            } else {
                              sprintf(error, "Attempting to call procedure or function '%s' which is has not been declared.", $1);
                              semantic_error(error);
                            }
                        }
                        ;

var                     : ID
                          {
                            $$ = (struct var_info_t*)malloc(sizeof(struct var_info_t));
                            $$->var = globallookup($1);
                            $$->location_on_stack = 0;
                            //printf("found var %s with reference semantics %d\n", $$->var->name, $$->var->desc.var_attr.reference_semantics);
                            if (!$$->var)
                            {
                              char error[1024];
                              sprintf(error, "variable '%s' undeclared at this level", $1);
                              semantic_error(error);
                            }
                          }
                        | var PERIOD ID
                        {
                          struct sym_rec* oldvar = $1->var;
                          $$ = $1;
                          if ($1 && $1->var)
                          {
                            if ($1->var->class == OC_VAR && $1->var->desc.var_attr.type)
                            {
                              if ($1->var->desc.var_attr.type->desc.type_attr.type_class == TC_RECORD)
                              {
                                struct sym_rec* field = $1->var->desc.var_attr.type->desc.type_attr.type_description.record->field_list;
                                for(; field != NULL; field = field->next)
                                  if (strcmp(field->name,$3)==0)
                                    break;
                                // field is either the variable ID or null, we pass back both
                                $$->var = field;
                                if (!$$->var)
                                {
                                  char error[1024];
                                  sprintf(error, "'%s' is not a member of '%s'.", $3, oldvar->name);
                                  semantic_error(error);
                                  free($$);
                                  $$ = NULL;
                                }
                                else
                                {
                                  emit_consti(field->desc.var_attr.location.offset);
                                  if (oldvar->desc.var_attr.reference_semantics)
                                    emit_push(oldvar->desc.var_attr.location.display, oldvar->desc.var_attr.location.offset);
                                  else if (!($1->location_on_stack))
                                    emit_pusha(oldvar->desc.var_attr.location.display, oldvar->desc.var_attr.location.offset);
                                  emit(ASC_ADDI);
                                  $$->location_on_stack = 1;
                                  $1->var->desc.var_attr.reference_semantics = 0;
                                }
                              }
                              else
                              {
                                char error[1024];
                                sprintf(error, "Invalid use of . operator, '%s' is not a record.", oldvar->name);
                                semantic_error(error);
                                free($$);
                                $$ = NULL;
                              }
                            }
                            else
                            {
                              free($$);
                              $$ = NULL;
                            }
                          }
                          else
                          {
                            free($$);
                            $$ = NULL;
                          }
                        }
                        | subscripted_var C_SBRACKET { $$ = $1; }
                        ;

subscripted_var         : var O_SBRACKET expr
                        {
                          int index = 0,
                              upper = 0,
                              lower = 0;

                          if ($1 && $1->var)
                          {
                          
                             struct sym_rec* oldvar = $1->var;
                             if ($1->var->class == OC_VAR && $1->var->desc.var_attr.type) 
                             {
                                if ($1->var->desc.var_attr.type->desc.type_attr.type_class == TC_ARRAY)
                                {
                                  upper = $1->var->desc.var_attr.type->desc.type_attr.type_description.array->subrange->high;
                                  lower = $1->var->desc.var_attr.type->desc.type_attr.type_description.array->subrange->low;
                                  if ($3 && $3->type)
                                  {
                                    if ($3->type->desc.type_attr.type_class != $1->var->desc.var_attr.type->desc.type_attr.type_description.array->subrange->mother_type->desc.type_attr.type_class)
                                    {
                                      char error[1024];
                                      sprintf(error, "Invalid index into array");
                                      semantic_error(error);
                                    }
                                    else if ($3->is_const)
                                    {
                                      char error[1024];
                                      switch($3->type->desc.type_attr.type_class)
                                      {
                                        case TC_INTEGER:
                                        case TC_SCALAR:
                                          if ($3->value.integer > upper || $3->value.integer < lower)
                                          {
                                            sprintf(error, "Array index outside of array bounds");
                                            semantic_error(error);
                                          }
                                          index = $3->value.integer;
                                          break;
                                        case TC_REAL:
                                          printf("Subscripting an array with a real, this should be caught by the time we get here\n");
                                          break;
                                        case TC_CHAR:
                                          if ($3->value.character > upper || $3->value.character < lower)
                                          {
                                            sprintf(error, "Array index outside of array bounds");
                                            semantic_error(error);
                                          }
                                          index = (int)($3->value.character);
                                          break;
                                        case TC_BOOLEAN:
                                          if ($3->value.boolean > upper || $3->value.boolean < lower)
                                          {
                                            sprintf(error, "Array index outside of array bounds");
                                            semantic_error(error);
                                          }
                                          index = $3->value.boolean;
                                          break;
                                        case TC_STRING:
                                          printf("Subscripting an array with a string, this should be caught by the time we get here\n");
                                          break;
                                        case TC_ARRAY:
                                          printf("Subscripting an array with an array, this should be caught by the time we get here\n");
                                          break;
                                        case TC_RECORD:
                                          printf("Subscripting an array with a record, this should be caught by the time we get here\n");
                                          break;
                                        case TC_SUBRANGE:
                                          printf("Subscripting an array with a subrange, this should be caught by the time we get here\n");
                                          break;
                                      }
                                    }
                                  }

                                  $$ = $1;
                                  struct sym_rec* oldvar_objtype = $1->var->desc.var_attr.type->desc.type_attr.type_description.array->object_type;
                                  struct location_t* old_location = &($1->var->desc.var_attr.location);
                                  $$->var = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                                  $$->var->next = NULL;
                                  $$->var->name = "array_tmp";
                                  $$->var->level = get_current_level();
                                  $$->var->class = OC_VAR;
                                  $$->var->desc.var_attr.type = oldvar_objtype;

                                  $$->var->desc.var_attr.location.display = old_location->display;
                                  $$->var->desc.var_attr.location.offset = old_location->offset;
                                  $$->var->desc.var_attr.reference_semantics = oldvar->desc.var_attr.reference_semantics;

                                  //printf("Subscripting %s with reference semantics %d\n", $1->var->name, oldvar->desc.var_attr.reference_semantics);
                                  asc_subscript_var($1, old_location, lower);
                                  $$->location_on_stack = 1;
                                  $$->var->desc.var_attr.reference_semantics = 0;
                                  //}

                                  struct temp_array_var* new_temp_var = (struct temp_array_var*)malloc(sizeof(struct temp_array_var));
                                  new_temp_var->var = $$->var;
                                  new_temp_var->next = temp_array_vars;
                                  temp_array_vars = new_temp_var;
                                }
                                else if ($1->var->desc.var_attr.type->desc.type_attr.type_class == TC_STRING)
                                {
                                  upper = $1->var->desc.var_attr.type->desc.type_attr.type_description.string->high;
                                  lower = 1;
                                  if ($3 && $3->type)
                                  {
                                    if ($3->type->desc.type_attr.type_class != builtinlookup("integer")->desc.type_attr.type_class)
                                    {
                                      char error[1024];
                                      sprintf(error, "Invalid index into string");
                                      semantic_error(error);
                                    }
                                    else if ($3->is_const)
                                    {
                                      char error[1024];
                                      switch($3->type->desc.type_attr.type_class)
                                      {
                                        case TC_INTEGER:
                                        case TC_SCALAR:
                                          if ($3->value.integer > upper)
                                          {
                                            sprintf(error, "String index outside of string bounds");
                                            semantic_error(error);
                                          }
                                          index = $3->value.integer;
                                          break;
                                        case TC_REAL:
                                          printf("Subscripting a string with a real, this should be caught by the time we get here\n");
                                          break;
                                        case TC_CHAR:
                                          if ($3->value.character > upper)
                                          {
                                            sprintf(error, "String index outside of array bounds");
                                            semantic_error(error);
                                          }
                                          index = (int)($3->value.character);
                                          break;
                                        case TC_BOOLEAN:
                                          if ($3->value.boolean > upper)
                                          {
                                            sprintf(error, "String index outside of array bounds");
                                            semantic_error(error);
                                          }
                                          index = $3->value.boolean;
                                          break;
                                        case TC_STRING:
                                          printf("Subscripting a string with a string, this should be caught by the time we get here\n");
                                          break;
                                        case TC_ARRAY:
                                          printf("Subscripting a string with an array, this should be caught by the time we get here\n");
                                          break;
                                        case TC_RECORD:
                                          printf("Subscripting a string with a record, this should be caught by the time we get here\n");
                                          break;
                                        case TC_SUBRANGE:
                                          printf("Subscripting a string with a subrange, this should be caught by the time we get here\n");
                                          break;
                                      }
                                    }
                                  }

                                  $$ = $1;
                                  struct location_t* old_location = &($1->var->desc.var_attr.location);
                                  $$->var = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                                  $$->var->next = NULL;
                                  $$->var->name = NULL;
                                  $$->var->level = get_current_level();
                                  $$->var->class = OC_VAR;
                                  $$->var->desc.var_attr.type = builtinlookup("char");

                                  $$->var->desc.var_attr.location.display = old_location->display;
                                  $$->var->desc.var_attr.location.offset = old_location->offset;
                                  $$->var->desc.var_attr.reference_semantics = oldvar->desc.var_attr.reference_semantics;

                                  asc_subscript_var($1, old_location, lower);
                                  $$->location_on_stack = 1;
                                  $$->var->desc.var_attr.reference_semantics = 0;

                                  struct temp_array_var* new_temp_var = (struct temp_array_var*)malloc(sizeof(struct temp_array_var));
                                  new_temp_var->var = $$->var;
                                  new_temp_var->next = temp_array_vars;
                                  temp_array_vars = new_temp_var;
                                }
                                else 
                                {
                                  char error[1024];
                                  if ($1->var->name)
                                    sprintf(error, "cannot subscript '%s', it is not an array or string", $1->var->name);
                                  else
                                    sprintf(error, "cannot subscript variables that are not arrays or strings");
                                   semantic_error(error);
                                   $$ = NULL;
                                }
                             }
                          }
                        }
                        | subscripted_var COMMA expr
                        {
                          int index = 0,
                              upper = 0,
                              lower = 0;

                          if ($1 && $1->var)
                          {
                             struct sym_rec* oldvar = $1->var;
                             if ($1->var->class == OC_VAR && $1->var->desc.var_attr.type) 
                             {
                                if ($1->var->desc.var_attr.type->desc.type_attr.type_class == TC_ARRAY)
                                {
                                  upper = $1->var->desc.var_attr.type->desc.type_attr.type_description.array->subrange->high;
                                  lower = $1->var->desc.var_attr.type->desc.type_attr.type_description.array->subrange->low;
                                  if ($3 && $3->type)
                                  {
                                    if ($3->type->desc.type_attr.type_class != $1->var->desc.var_attr.type->desc.type_attr.type_description.array->subrange->mother_type->desc.type_attr.type_class)
                                    {
                                      char error[1024];
                                      sprintf(error, "Invalid index into array");
                                      semantic_error(error);
                                    }
                                    else if ($3->is_const)
                                    {
                                      char error[1024];
                                      switch($3->type->desc.type_attr.type_class)
                                      {
                                        case TC_INTEGER:
                                        case TC_SCALAR:
                                          if ($3->value.integer > upper || $3->value.integer < lower)
                                          {
                                            sprintf(error, "Array index outside of array bounds");
                                            semantic_error(error);
                                          }
                                          index = $3->value.integer;
                                          break;
                                        case TC_REAL:
                                          printf("Subscripting an array with a real, this should be caught by the time we get here\n");
                                          break;
                                        case TC_CHAR:
                                          if ($3->value.character > upper || $3->value.character < lower)
                                          {
                                            sprintf(error, "Array index outside of array bounds");
                                            semantic_error(error);
                                          }
                                          index = (int)($3->value.character);
                                          break;
                                        case TC_BOOLEAN:
                                          if ($3->value.boolean > upper || $3->value.boolean < lower)
                                          {
                                            sprintf(error, "Array index outside of array bounds");
                                            semantic_error(error);
                                          }
                                          index = $3->value.integer;
                                          break;
                                        case TC_STRING:
                                          printf("Subscripting an array with a string, this should be caught by the time we get here\n");
                                          break;
                                        case TC_ARRAY:
                                          printf("Subscripting an array with an array, this should be caught by the time we get here\n");
                                          break;
                                        case TC_RECORD:
                                          printf("Subscripting an array with a record, this should be caught by the time we get here\n");
                                          break;
                                        case TC_SUBRANGE:
                                          printf("Subscripting an array with a subrange, this should be caught by the time we get here\n");
                                          break;
                                      }
                                    }
                                  }

                                  $$ = $1;
                                  struct sym_rec* oldvar_objtype = $1->var->desc.var_attr.type->desc.type_attr.type_description.array->object_type;
                                  struct location_t* old_location = &($1->var->desc.var_attr.location);
                                  $$->var = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                                  $$->var->next = NULL;
                                  $$->var->name = NULL;
                                  $$->var->level = get_current_level();
                                  $$->var->class = OC_VAR;
                                  $$->var->desc.var_attr.type = oldvar_objtype;

                                  $$->var->desc.var_attr.location.display = old_location->display;
                                  $$->var->desc.var_attr.location.offset = old_location->offset;
                                  $$->var->desc.var_attr.reference_semantics = oldvar->desc.var_attr.reference_semantics;

                                  asc_subscript_var($1, old_location, lower);
                                  $$->location_on_stack = 1;
                                  $$->var->desc.var_attr.reference_semantics = 0;

                                  struct temp_array_var* new_temp_var = (struct temp_array_var*)malloc(sizeof(struct temp_array_var));
                                  new_temp_var->var = $$->var;
                                  new_temp_var->next = temp_array_vars;
                                  temp_array_vars = new_temp_var;
                                }
                                else if ($1->var->desc.var_attr.type->desc.type_attr.type_class == TC_STRING)
                                {
                                  upper = $1->var->desc.var_attr.type->desc.type_attr.type_description.string->high;
                                  lower = 1;
                                  if ($3 && $3->type)
                                  {
                                    if ($3->type->desc.type_attr.type_class != builtinlookup("integer")->desc.type_attr.type_class)
                                    {
                                      char error[1024];
                                      sprintf(error, "Invalid index into string");
                                      semantic_error(error);
                                    }
                                    else if ($3->is_const)
                                    {
                                      char error[1024];
                                      switch($3->type->desc.type_attr.type_class)
                                      {
                                        case TC_INTEGER:
                                        case TC_SCALAR:
                                          if ($3->value.integer > upper)
                                          {
                                            sprintf(error, "String index outside of string bounds");
                                            semantic_error(error);
                                          }
                                          index = $3->value.integer;
                                          break;
                                        case TC_REAL:
                                          printf("Subscripting a string with a real, this should be caught by the time we get here\n");
                                          break;
                                        case TC_CHAR:
                                          if ($3->value.character > upper)
                                          {
                                            sprintf(error, "String index outside of array bounds");
                                            semantic_error(error);
                                          }
                                          index = (int)($3->value.character);
                                          break;
                                        case TC_BOOLEAN:
                                          if ($3->value.boolean > upper)
                                          {
                                            sprintf(error, "String index outside of array bounds");
                                            semantic_error(error);
                                          }
                                          index = $3->value.integer;
                                          break;
                                        case TC_STRING:
                                          printf("Subscripting a string with a string, this should be caught by the time we get here\n");
                                          break;
                                        case TC_ARRAY:
                                          printf("Subscripting a string with an array, this should be caught by the time we get here\n");
                                          break;
                                        case TC_RECORD:
                                          printf("Subscripting a string with a record, this should be caught by the time we get here\n");
                                          break;
                                        case TC_SUBRANGE:
                                          printf("Subscripting a string with a subrange, this should be caught by the time we get here\n");
                                          break;
                                      }
                                    }
                                  }

                                  $$ = $1;
                                  struct location_t* old_location = &($1->var->desc.var_attr.location);
                                  $$->var = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                                  $$->var->next = NULL;
                                  $$->var->name = NULL;
                                  $$->var->level = get_current_level();
                                  $$->var->class = OC_VAR;
                                  $$->var->desc.var_attr.type = builtinlookup("char");

                                  $$->var->desc.var_attr.location.display = old_location->display;
                                  $$->var->desc.var_attr.location.offset = old_location->offset;
                                  $$->var->desc.var_attr.reference_semantics = oldvar->desc.var_attr.reference_semantics;

                                  asc_subscript_var($1, old_location, lower);
                                  $$->location_on_stack = 1;
                                  $$->var->desc.var_attr.reference_semantics = 0;

                                  struct temp_array_var* new_temp_var = (struct temp_array_var*)malloc(sizeof(struct temp_array_var));
                                  new_temp_var->var = $$->var;
                                  new_temp_var->next = temp_array_vars;
                                  temp_array_vars = new_temp_var;
                                }
                                else 
                                {
                                  char error[1024];
                                  if ($1->var->name)
                                    sprintf(error, "cannot subscript '%s', it is not an array or string", $1->var->name);
                                  else
                                    sprintf(error, "cannot subscript variables that are not arrays or strings");
                                  semantic_error(error);
                                  $$ = NULL;
                                }
                             }
                          }
                          else
                            $$ = NULL;
                        }
                        ;

expr                    : simple_expr { $$ = $1; asc_store_simple_expr($$); }
                        | expr operator simple_expr 
                          {
                            char error[1024];
                            if ($1 && $3 && $1->type && $3->type)
                            {
                              struct sym_rec* ret_type = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              ret_type->name = NULL;
                              ret_type->level = get_current_level();
                              ret_type->class = OC_TYPE;
                              ret_type->desc.type_attr.type_class = TC_BOOLEAN;
                              ret_type->desc.type_attr.type_description.boolean = builtinlookup("boolean")->desc.type_attr.type_description.boolean;

                              $$ = (struct expr_t*)malloc(sizeof(struct expr_t));
                              $$->type = ret_type;
                              $$->location = NULL;
                              $$->is_const = 0;
                              $$->is_in_address_on_stack = 0;
                              $$->is_reference = 0;

                              if  (   ($1->type->desc.type_attr.type_class != TC_SCALAR && $3->type->desc.type_attr.type_class == TC_SCALAR)
                                  ||  ($1->type->desc.type_attr.type_class == TC_SCALAR && $3->type->desc.type_attr.type_class != TC_SCALAR))
                              {
                                free($$);
                                $$ = NULL;
                                sprintf(error, "Cannot mix scalar and non-scalar types to comparison operators.");
                                semantic_error(error);
                              }

                              else if (   ($1->type->desc.type_attr.type_class != TC_STRING && $3->type->desc.type_attr.type_class == TC_STRING)
                                      ||  ($1->type->desc.type_attr.type_class == TC_STRING && $3->type->desc.type_attr.type_class != TC_STRING))
                              {
                                free($$);
                                $$ = NULL;
                                sprintf(error, "Cannot mix string and non-string types to comparison operators.");
                                semantic_error(error);
                              }

                              else if ($1->type->desc.type_attr.type_class == TC_SCALAR && $3->type->desc.type_attr.type_class == TC_SCALAR) {
                                   if ($1->type->desc.type_attr.type_description.scalar != $3->type->desc.type_attr.type_description.scalar)
                                   {
                                        free($$);
                                        $$ = NULL;
                                        sprintf(error, "Incompatible scalar types given to comparison operator.");
                                        semantic_error(error);
                                   }
                                }

                              else if ($1->type->desc.type_attr.type_class == TC_STRING && $3->type->desc.type_attr.type_class == TC_STRING) {
                                if ($1->type->desc.type_attr.type_description.string->high != $3->type->desc.type_attr.type_description.string->high)
                                {
                                  free($$);
                                  $$ = NULL;
                                  sprintf(error, "Incompatible string types given to comparison operator.");
                                  semantic_error(error);
                                  }
                                }

                              else if (   ($1->type->desc.type_attr.type_class != TC_BOOLEAN && $3->type->desc.type_attr.type_class == TC_BOOLEAN)
                                      ||  ($1->type->desc.type_attr.type_class == TC_BOOLEAN && $3->type->desc.type_attr.type_class != TC_BOOLEAN))
                              {
                                free($$);
                                $$ = NULL;
                                sprintf(error, "Cannot mix boolean and non-boolean types to comparison operators.");
                                semantic_error(error);
                              }

                              else if (   ($1->type->desc.type_attr.type_class != TC_CHAR && $3->type->desc.type_attr.type_class == TC_CHAR)
                                      ||  ($1->type->desc.type_attr.type_class == TC_CHAR && $3->type->desc.type_attr.type_class != TC_CHAR))
                              {
                                free($$);
                                $$ = NULL;
                                sprintf(error, "Cannot mix char and non-char types to comparison operators.");
                                semantic_error(error);
                              }

                              else if (   ($1->type->desc.type_attr.type_class == TC_INTEGER || $1->type->desc.type_attr.type_class == TC_REAL)
                                       && ($3->type->desc.type_attr.type_class != TC_INTEGER && $3->type->desc.type_attr.type_class != TC_REAL))
                              {
                                free($$);
                                $$ = NULL;
                                sprintf(error, "Cannot mix real/integer and non-real/integer types to comparison operators.");
                                semantic_error(error);
                              }

                              else if (   ($3->type->desc.type_attr.type_class == TC_INTEGER || $3->type->desc.type_attr.type_class == TC_REAL)
                                       && ($1->type->desc.type_attr.type_class != TC_INTEGER && $1->type->desc.type_attr.type_class != TC_REAL))
                              {
                                free($$);
                                $$ = NULL;
                                sprintf(error, "Cannot mix real/integer and non-real/integer types to comparison operators.");
                                semantic_error(error);
                              }

                              if ($$ == NULL)
                                free(ret_type);
                              else
                              {
                                if ($1->is_const && $3->is_const)
                                {
                                  $$->is_const = 1;
                                  do_op($1, $3, $2, $$);
                                  asc_store_simple_expr($$);
                                }
                                else
                                {
                                  asc_comparisons($2, $1, $3);
                                  $$->is_const = 0;
                                }
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        ;
            
operator                : EQUALS          { $$ = EQUALS; }
                        | NOT_EQUAL       { $$ = NOT_EQUAL; }
                        | LESS_EQUAL      { $$ = LESS_EQUAL; }
                        | LESS_THAN       { $$ = LESS_THAN; }
                        | GREATER_EQUAL   { $$ = GREATER_EQUAL; }
                        | GREATER_THAN    { $$ = GREATER_THAN; }
                        | error           { $$ = -1; }
                        ;

simple_expr             : term { $$ = $1; }
                        | PLUS term
                        {
                          if($2 && $2->type)
                          {
                            if ($2->type->desc.type_attr.type_class == TC_REAL || $2->type->desc.type_attr.type_class == TC_INTEGER)
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
                          if($2 && $2->type)
                          {
                            if ($2->type->desc.type_attr.type_class == TC_REAL || $2->type->desc.type_attr.type_class == TC_INTEGER)
                            {
                              $$ = $2;
                              if ($2->is_const)
                              {
                                if ($2->type->desc.type_attr.type_class == TC_REAL)
                                  $$->value.real = -($2->value.real);
                                else
                                  $$->value.integer = -($2->value.integer);
                              }
                              $$->location = NULL;
                              $$->is_in_address_on_stack = 0;
                              $$->is_reference = 0;
                            }
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
                            if($1 && $3 && $1->type && $3->type)
                            {
                              if (    ($1->type->desc.type_attr.type_class != TC_REAL && $1->type->desc.type_attr.type_class != TC_INTEGER)
                                  ||  ($3->type->desc.type_attr.type_class != TC_REAL && $3->type->desc.type_attr.type_class != TC_INTEGER)
                                  )
                              {
                                char error[1024];
                                sprintf(error, "operands of 'plus' must be either integers or reals.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                              else
                              {
                                if ($1->type->desc.type_attr.type_class == TC_REAL)
                                  $$ = $1;
                                else if ($3->type->desc.type_attr.type_class == TC_REAL)
                                  $$ = $3;
                                // both integers
                                else
                                  $$ = $1;

                                if ($1->is_const && $3->is_const)
                                {
                                  if (  ($1->type->desc.type_attr.type_class == TC_REAL)
                                     && ($3->type->desc.type_attr.type_class == TC_REAL))
                                    $$->value.real = ($1->value.real) + ($3->value.real);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_INTEGER)
                                          && ($3->type->desc.type_attr.type_class == TC_REAL))
                                    $$->value.real = ($1->value.integer) + ($3->value.real);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_REAL)
                                          && ($3->type->desc.type_attr.type_class == TC_INTEGER))
                                    $$->value.real = ($1->value.real) + ($3->value.integer);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_INTEGER)
                                          && ($3->type->desc.type_attr.type_class == TC_INTEGER))
                                    $$->value.integer = ($1->value.integer) + ($3->value.integer);
                                }
                                else
                                {
                                  asc_math($2, $1, $3);
                                  $$->is_const = 0;
                                }
                                $$->location = NULL;
                                $$->is_in_address_on_stack = 0;
                                $$->is_reference = 0;
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        | simple_expr MINUS term
                          {
                            if($1 && $3 && $1->type && $3->type)
                            {
                              if (    ($1->type->desc.type_attr.type_class != TC_REAL && $1->type->desc.type_attr.type_class != TC_INTEGER)
                                  ||  ($3->type->desc.type_attr.type_class != TC_REAL && $3->type->desc.type_attr.type_class != TC_INTEGER)
                                  )
                              {
                                char error[1024];
                                sprintf(error, "operands of 'minus' must be either integers or reals.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                              else
                              {
                                if ($1->type->desc.type_attr.type_class == TC_REAL)
                                  $$ = $1;
                                else if ($3->type->desc.type_attr.type_class == TC_REAL)
                                  $$ = $3;
                                // both integers
                                else
                                  $$ = $1;

                                if ($1->is_const && $3->is_const)
                                {
                                  if (  ($1->type->desc.type_attr.type_class == TC_REAL)
                                     && ($3->type->desc.type_attr.type_class == TC_REAL))
                                    $$->value.real = ($1->value.real) - ($3->value.real);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_INTEGER)
                                          && ($3->type->desc.type_attr.type_class == TC_REAL))
                                    $$->value.real = ($1->value.integer) - ($3->value.real);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_REAL)
                                          && ($3->type->desc.type_attr.type_class == TC_INTEGER))
                                    $$->value.real = ($1->value.real) - ($3->value.integer);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_INTEGER)
                                          && ($3->type->desc.type_attr.type_class == TC_INTEGER))
                                    $$->value.integer = ($1->value.integer) - ($3->value.integer);
                                }
                                else
                                {
                                  asc_math($2, $1, $3);
                                  $$->is_const = 0;
                                }
                                $$->location = NULL;
                                $$->is_in_address_on_stack = 0;
                                $$->is_reference = 0;
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        | simple_expr OR  term
                          { 
                            if($1 && $3 && $1->type && $3->type)
                            {
                              if ($1->type->desc.type_attr.type_class == TC_BOOLEAN && $3->type->desc.type_attr.type_class == TC_BOOLEAN)
                              {
                                $$ = $1;
                                if ($1->is_const && $3->is_const)
                                {
                                  $$->value.boolean = $1->value.boolean || $3->value.boolean;
                                  $$->location = NULL;
                                  $$->is_in_address_on_stack = 0;
                                  $$->is_reference = 0;
                                }
                                else
                                {
                                  asc_logic($2, $1, $3);
                                  $$->is_const = 0;
                                  $$->location = NULL;
                                  $$->is_in_address_on_stack = 0;
                                  $$->is_reference = 0;
                                }
                              }
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
                            if($1 && $3 && $1->type && $3->type)
                            {
                              if (    ($1->type->desc.type_attr.type_class != TC_REAL && $1->type->desc.type_attr.type_class != TC_INTEGER)
                                  ||  ($3->type->desc.type_attr.type_class != TC_REAL && $3->type->desc.type_attr.type_class != TC_INTEGER)
                                  )
                              {
                                char error[1024];
                                sprintf(error, "operands of 'multiply' must be either integers or reals.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                              else
                              {
                                if ($1->type->desc.type_attr.type_class == TC_REAL)
                                  $$ = $1;
                                else if ($3->type->desc.type_attr.type_class == TC_REAL)
                                  $$ = $3;
                                // both integers
                                else
                                  $$ = $1;

                                if ($1->is_const && $3->is_const)
                                {
                                  if (  ($1->type->desc.type_attr.type_class == TC_REAL)
                                     && ($3->type->desc.type_attr.type_class == TC_REAL))
                                    $$->value.real = ($1->value.real) * ($3->value.real);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_INTEGER)
                                          && ($3->type->desc.type_attr.type_class == TC_REAL))
                                    $$->value.real = ($1->value.integer) * ($3->value.real);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_REAL)
                                          && ($3->type->desc.type_attr.type_class == TC_INTEGER))
                                    $$->value.real = ($1->value.real) * ($3->value.integer);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_INTEGER)
                                          && ($3->type->desc.type_attr.type_class == TC_INTEGER))
                                    $$->value.integer = ($1->value.integer) * ($3->value.integer);
                                }
                                else
                                {
                                  asc_math($2, $1, $3);
                                  $$->is_const = 0;
                                  $$->is_in_address_on_stack = 0;
                                  $$->is_reference = 0;
                                }
                                $$->location = NULL;
                                $$->is_in_address_on_stack = 0;
                                $$->is_reference = 0;
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        | term DIVIDE factor
                          {
                            if($1 && $3 && $1->type && $3->type)
                            {
                              if (    ($1->type->desc.type_attr.type_class != TC_REAL && $1->type->desc.type_attr.type_class != TC_INTEGER)
                                  ||  ($3->type->desc.type_attr.type_class != TC_REAL && $3->type->desc.type_attr.type_class != TC_INTEGER)
                                  )
                              {
                                char error[1024];
                                sprintf(error, "operands of 'divide' must be either integers or reals.");
                                semantic_error(error);
                                $$ = NULL;
                              }
                              else
                              {
                                if ($1->type->desc.type_attr.type_class == TC_REAL)
                                  $$ = $1;
                                else if ($3->type->desc.type_attr.type_class == TC_REAL)
                                  $$ = $3;
                                // both integers
                                else
                                {
                                  $$ = (struct expr_t*)malloc(sizeof(struct expr_t));
                                  $$->type = builtinlookup("real");
                                }

                                if ($1->is_const && $3->is_const)
                                {
                                  if (  ($1->type->desc.type_attr.type_class == TC_REAL)
                                     && ($3->type->desc.type_attr.type_class == TC_REAL))
                                    $$->value.real = ($1->value.real) / ($3->value.real);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_INTEGER)
                                          && ($3->type->desc.type_attr.type_class == TC_REAL))
                                    $$->value.real = ($1->value.integer) / ($3->value.real);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_REAL)
                                          && ($3->type->desc.type_attr.type_class == TC_INTEGER))
                                    $$->value.real = ($1->value.real) / ($3->value.integer);
                                  else if (  ($1->type->desc.type_attr.type_class == TC_INTEGER)
                                          && ($3->type->desc.type_attr.type_class == TC_INTEGER))
                                    $$->value.real = 1.0*($1->value.integer) / ($3->value.integer);

                                  $$->is_const = 1;
                                  $$->is_in_address_on_stack = 0;
                                  $$->is_reference = 0;
                                }
                                else
                                {
                                  asc_math($2, $1, $3);
                                  $$->is_const = 0;
                                  $$->is_in_address_on_stack = 0;
                                  $$->is_reference = 0;
                                }
                                $$->location = NULL;
                                $$->is_in_address_on_stack = 0;
                                $$->is_reference = 0;
                              }
                            }
                            else
                              $$ = NULL;
                          }
                        | term DIV factor
                          {
                            if($1 && $3 && $1->type && $3->type)
                            {
                              if ($1->type->desc.type_attr.type_class == TC_INTEGER && $3->type->desc.type_attr.type_class == TC_INTEGER)
                              {
                                $$ = $1;
                                if ($1->is_const && $3->is_const)
                                {
                                  $$->value.integer = ($1->value.integer) / ($3->value.integer);
                                  $$->location = NULL;
                                  $$->is_in_address_on_stack = 0;
                                  $$->is_reference = 0;
                                }
                                else
                                {
                                  asc_integer_math($2, $1, $3);
                                  $$->location = NULL;
                                  $$->is_const = 0;
                                  $$->is_in_address_on_stack = 0;
                                  $$->is_reference = 0;
                                }
                              }
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

                            free($3);
                          }
                        | term MOD factor
                          {
                            if($1 && $3 && $1->type && $3->type)
                            {
                              if ($1->type->desc.type_attr.type_class == TC_INTEGER && $3->type->desc.type_attr.type_class == TC_INTEGER)
                              {
                                $$ = $1;
                                if ($1->is_const && $3->is_const)
                                {
                                  $$->value.integer = ($1->value.integer) % ($3->value.integer);
                                  $$->location = NULL;
                                  $$->is_in_address_on_stack = 0;
                                  $$->is_reference = 0;
                                }
                                else
                                {
                                  asc_integer_math($2, $1, $3);
                                  $$->location = NULL;
                                  $$->is_const = 0;
                                  $$->is_in_address_on_stack = 0;
                                  $$->is_reference = 0;
                                }
                              }
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

                            free($3);
                          }
                        | term AND factor
                          { 
                            if ($1 && $3 && $1->type && $3->type)
                            {
                              if ($1->type->desc.type_attr.type_class == TC_BOOLEAN && $3->type->desc.type_attr.type_class == TC_BOOLEAN)
                              {
                                $$ = $1;
                                if ($1->is_const && $3->is_const)
                                {
                                  $$->value.boolean = ($1->value.boolean) && ($3->value.boolean);
                                  $$->location = NULL;
                                }
                                else
                                {  
                                  asc_logic($2, $1, $3);
                                  $$->location = NULL;
                                  $$->is_const = 0;
                                }
                                $$->is_in_address_on_stack = 0;
                                $$->is_reference = 0;
                              }
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

                            free($3);
                          }
                        ;

factor                  : var
                          {
                            if($1 && $1->var)
                            {
                              char error[1024];
                              $$ = (struct expr_t*)malloc(sizeof(struct expr_t));
                              $$->is_in_address_on_stack = $1->location_on_stack;
                              switch($1->var->class)
                              {
                                // this should be an impossible case, and we have to stop code generation if we get this case
                                case OC_TYPE:
                                  $$->type = $1->var;
                                  $$->location = NULL;
                                  $$->is_const = 0;
                                  $$->is_reference = 0;
                                  break;
                                case OC_VAR:
                                  $$->type = $1->var->desc.var_attr.type;
                                  $$->location = &($1->var->desc.var_attr.location);
                                  $$->is_const = 0;
                                  $$->is_reference = $1->var->desc.var_attr.reference_semantics;
                                  //asc_push_var($1);
                                  break;
                                case OC_CONST:
                                  $$->type = $1->var->desc.const_attr.type;
                                  $$->location = NULL;// &($1->desc.const_attr.location);
                                  $$->is_const = 1;
                                  $$->is_reference = 0;
                                  switch(get_type_class($1->var))
                                  {
                                    case TC_INTEGER:
                                      $$->value.integer = $1->var->desc.const_attr.value.integer;
                                      break;
                                    case TC_REAL:
                                      $$->value.real = $1->var->desc.const_attr.value.real;
                                      break;
                                    case TC_CHAR:
                                      $$->value.character = $1->var->desc.const_attr.value.character;
                                      break;
                                    case TC_BOOLEAN:
                                      $$->value.boolean = $1->var->desc.const_attr.value.boolean;
                                      break;
                                    case TC_STRING:
                                      $$->value.string = $1->var->desc.const_attr.value.string;
                                      break;
                                    case TC_SCALAR:
                                      //printf("Setting value of scalar '%s' to %d\n", $1->name, $1->desc.const_attr.value.integer);
                                      $$->value.integer = $1->var->desc.const_attr.value.integer;
                                      break;
                                    default:
                                      printf("factor: var - OC_CONST has some weird type_class that will probably break things\n");
                                      $$->is_const = 0;
                                      break;
                                  }
                                  break;
                                case OC_RETURN:
                                  sprintf(error, "'%s' cannot appear on the RHS of a statement, it is a return type.", $1->var->name);
                                  semantic_error(error);
                                  free($$);
                                  $$ = NULL;
                                  break;
                                default:
                                  semantic_error("could not find type of expression");
                                  free($$);
                                  $$ = NULL;
                              }
                            }
                            else
                              $$ = NULL;
                          }
						            | unsigned_const { $$ = $1; }
                        | O_BRACKET expr C_BRACKET { $$ = $2; }
                        | func_invok { $$ = $1; }
                        | NOT factor
                          {
                            if ($2 && $2->type)
                            {
                              if ($2->type->class == OC_TYPE && $2->type->desc.type_attr.type_class == TC_BOOLEAN)
                              {
                                $$ = $2;
                                if ($$->is_const)
                                  $$->value.boolean = !($$->value.boolean);
                                else
                                  asc_logic($1, $2, NULL);
                                $$->location = NULL;
                                $$->is_in_address_on_stack = 0;
                                $$->is_reference = 0;
                              }
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
                              $$ = malloc(sizeof(struct expr_t));
                              $$->type = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              $$->type->next = NULL;
                              $$->type->name = NULL;
                              $$->type->level = get_current_level();
                              $$->type->class = OC_TYPE;
                              $$->type->desc.type_attr.type_class = TC_STRING;
                              $$->type->desc.type_attr.type_description.string = (struct tc_string*)malloc(sizeof(struct tc_string));
                              $$->type->desc.type_attr.type_description.string->high = strlen($1);
                              
                              $$->location = NULL;
                              $$->is_const = 1;
                              $$->is_in_address_on_stack = 0;
                              $$->is_reference = 0;
                              $$->value.string = strdup(yylval.name);
                            }
                            else
                            {
                              $$ = (struct expr_t*)malloc(sizeof(struct expr_t));
                              $$->type = builtinlookup("char");
                              $$->location = NULL;
                              $$->is_const = 1;
                              $$->is_in_address_on_stack = 0;
                              $$->is_reference = 0;
                              $$->value.character = yylval.name[0];
                            }
                          }
                          | NSTRING   			/* Non-terminated string warning here */                                        
                          {
                            $$ = NULL;
                          }
                        ;                                

unsigned_num            : INT_CONST
                          {
                            $$ = (struct expr_t*)malloc(sizeof(struct expr_t));
                            $$->type = builtinlookup("integer");
                            $$->location = NULL;
                            $$->is_const = 1;
                            $$->is_in_address_on_stack = 0;
                            $$->is_reference = 0;
                            $$->value.integer = yylval.integer;
                          }
						            | REAL_CONST
                          {
                            $$ = (struct expr_t*)malloc(sizeof(struct expr_t));
                            $$->type = builtinlookup("real");
                            $$->location = NULL;
                            $$->is_const = 1;
                            $$->is_in_address_on_stack = 0;
                            $$->is_reference = 0;
                            $$->value.real = yylval.real_t;
                          }
						            ;                                

func_invok              : plist_finvok C_BRACKET 
                        { /* Need return value */
                          if ($1) {
                            if ($1->counter != 0 && !isIOFunc($1))
                            {
                              char error[1024];
                              if ($1->name)
                              {
                                sprintf(error, "Wrong number of parameters for function '%s'.", $1->name);
                              } else
                              {
                                sprintf(error, "Wrong number of parameters.");
                              }
                              semantic_error(error);
                            }
                            $$ = (struct expr_t*)malloc(sizeof(struct expr_t));
                            $$->type = $1->return_type; 
                            $$->location = NULL;
                            $$->is_const = 0;
                            $$->is_in_address_on_stack = 0;
                            $$->is_reference = 0;

                            struct sym_rec* func = isCurrentFunction($1->name);
                            if (!func)
                              func = globallookup($1->name);
                            asc_function_call(ASC_FUNCTION_CALL_END, func, 0, 0, 1);
                          } else {
                            $$ = NULL;
                          }
                        }
                        | ID O_BRACKET C_BRACKET
                          {
                            $$ = NULL;
                            char error[1024];
                            struct sym_rec* func = isCurrentFunction($1);
                            if (!func)
                              func = globallookup($1);
                            if (func) {
                              if (func->class == OC_FUNC)
                              {
                                if (func->desc.func_attr.parms == NULL)
                                {
                                  $$ = (struct expr_t*)malloc(sizeof(struct expr_t));
                                  $$->type = func->desc.func_attr.return_type;
                                  $$->location = NULL;
                                  $$->is_const = 0;
                                  $$->is_in_address_on_stack = 0;
                                  $$->is_reference = 0;

                                  asc_function_call(ASC_FUNCTION_CALL_BEGIN, func, 0, 0, 1);
                                  asc_function_call(ASC_FUNCTION_CALL_END, func, 0, 0, 1);
                                }
                                else
                                {
                                  sprintf(error, "Missing arguments for function '%s'.", $1);
                                  semantic_error(error);
                                  $$ = NULL;
                                }
                              }
                              else
                              {
                                sprintf(error, "Attempting to call '%s' which is not a function.", $1);
                                semantic_error(error);
                                $$ = NULL;
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
                            struct sym_rec* func = isCurrentFunction($1);
                            int convert_int_to_real = 0;
                            int do_general_function_call = 1;
                            if (!func)
                              func = globallookup($1);
                            if (func)
                            {
                              if (func->class == OC_FUNC)
                              {
                                $$ = (struct plist_t*)malloc(sizeof(struct plist_t));
                                $$->parmlist = func->desc.func_attr.parms;
                                $$->counter = 0;
                                $$->return_type = func->desc.func_attr.return_type;
                                $$->name = func->name;
                                $$->level = func->level;

                                struct sym_rec* last_parm = NULL;
                                if (isIOFunc($$))
                                {
                                  if($3 && $3->type && !checkIOArg($3->type))
                                  {
                                    char error[1024];
                                    sprintf(error, "Argmument 1 of '%s' must be of type integer, real, char, or string", $$->name);
                                    semantic_error(error);
                                  }
                                }
                                else if (isORDFunc($$))
                                {
                                  do_general_function_call = 0;
                                  if ($3 && $3->type && !isORDType($3->type))
                                  {
                                    char error[1024];
                                    sprintf(error, "Argmument of '%s' must be an ordinal type", $$->name);
                                    semantic_error(error);
                                  }
                                  // why do we need this
                                  $$->counter = 1;

                                  asc_ord_func($3);
                                }
                                else if (isCHRFunc($$))
                                {
                                  do_general_function_call = 0;
                                  if ($3 && $3->type && $3->type->desc.type_attr.type_class != TC_INTEGER)
                                  {
                                    char error[1024];
                                    sprintf(error, "Argmument of '%s' must be an integer type", $$->name);
                                    semantic_error(error);
                                  }
                                  // why do we need this
                                  $$->counter = 1;

                                  asc_chr_func($3);
                                }
                                else if (isPREDFunc($$) || isSUCCFunc($$))
                                {
                                  do_general_function_call = 0;
                                  if ($3 && $3->type && !isORDType($3->type))
                                  {
                                    char error[1024];
                                    sprintf(error, "Argmument of '%s' must be an ordinal type", $$->name);
                                    semantic_error(error);
                                  }
                                  else
                                  {
                                    $$->return_type = $3->type;
                                  }
                                  // more magic code
                                  $$->counter = 1;

                                  if (isPREDFunc($$))
                                    asc_pred_func($3);
                                  else
                                    asc_succ_func($3);
                                }
                                else if (isABSFunc($$) || isSQRFunc($$))
                                {
                                  do_general_function_call = 0;
                                  if ($3 && $3->type && !isIntOrRealType($3->type))
                                  {
                                    char error[1024];
                                    sprintf(error, "Argmument of '%s' must be an integer or real", $$->name);
                                    semantic_error(error);
                                  }
                                  else
                                  {
                                    $$->return_type = $3->type;
                                  }
                                  // more magic code
                                  $$->counter = 1;

                                  if (isABSFunc($$))
                                    asc_abs_func($3);
                                  else
                                    asc_sqr_func($3);
                                }
                                else
                                {
                                  for(func = $$->parmlist; func != NULL; func = func->next)
                                  {
                                    $$->counter = $$->counter + 1; 
                                    last_parm = func;
                                  }
                                  $$->max = $$->counter;

                                  if ($3 && $3->type && last_parm) {
                                  
                                  /* This should be an OC_VAR always */
                                    if (last_parm->class == OC_VAR || last_parm->class == OC_ERROR) {
                                      if (!compare_types($3->type, last_parm->desc.var_attr.type, 1))
                                      {
                                        char error[1024];
                                        sprintf(error, "Incompatible parameter passed to '%s' in position %d", $1, $$->max - $$->counter + 1);
                                        semantic_error(error);
                                      }
                                      else if (last_parm->desc.var_attr.reference_semantics && !($3->location) && !($3->is_in_address_on_stack))
                                      {
                                        char error[1024];
                                        sprintf(error, "Unable to find the address of the parameter passed by reference to '%s' in position %d", $1, $$->max - $$->counter + 1);
                                        semantic_error(error);
                                      }

                                      if ($3->type->desc.type_attr.type_class == TC_INTEGER &&
                                          last_parm->desc.var_attr.type->desc.type_attr.type_class == TC_REAL)
                                      {
                                        if (last_parm->desc.var_attr.reference_semantics)
                                        {
                                          char error[1024];
                                          sprintf(error, "Cannot pass an integer type by reference to a real type");
                                          semantic_error(error);
                                        }
                                        else
                                          convert_int_to_real = 1;
                                      }
                                    }
                                    //else
                                     // printf("last_parm->class == %d\n", last_parm->class);
                                  }
                                }

                                if ($3 && $3->type)
                                {
                                  func = isCurrentFunction($1);
                                  if (!func)
                                    func = globallookup($1);
                                  asc_function_call(ASC_FUNCTION_CALL_BEGIN, func, 0, 0, do_general_function_call);
                                  if (last_parm)
                                    asc_function_call(ASC_FUNCTION_CALL_ARG, $3, convert_int_to_real, last_parm->desc.var_attr.reference_semantics, do_general_function_call);
                                  else
                                    asc_function_call(ASC_FUNCTION_CALL_ARG, $3, convert_int_to_real, 0, do_general_function_call);
                                }

                                $$->counter = $$->counter - 1;
                              }
                              // TODO: do we even need this case, if all it does is set the return type differently this is rediculous
                              else if (func->class == OC_PROC)
                              {
                                $$ = (struct plist_t*)malloc(sizeof(struct plist_t));
                                $$->parmlist = func->desc.proc_attr.parms;
                                $$->counter = 0;
                                $$->return_type = NULL;
                                $$->name = func->name;
                                $$->level = func->level;

                                struct sym_rec* last_parm = NULL;
                                if (isIOFunc($$))
                                {
                                  if($3 && $3->type && !checkIOArg($3->type))
                                  {
                                    char error[1024];
                                    sprintf(error, "Argmument 1 of '%s' must be of type integer, real, char, or string", $$->name);
                                    semantic_error(error);
                                  }
                                }
                                else
                                {
                                  for(func = $$->parmlist; func != NULL; func = func->next)
                                  {
                                    $$->counter = $$->counter + 1;
                                    last_parm = func;
                                  }
                                  $$->max = $$->counter;

                                  if ($3 && $3->type && last_parm) {
                                  
                                  /* This should be an OC_VAR */
                                     if (last_parm->class == OC_VAR) {
                                      if (!compare_types($3->type, last_parm->desc.var_attr.type, 1))
                                      {
                                        char error[1024];
                                        sprintf(error, "Incompatible parameter passed to '%s' in position %d", $1, $$->max - $$->counter + 1);
                                        semantic_error(error);
                                      }
                                      else if (last_parm->desc.var_attr.reference_semantics && !($3->location) && !($3->is_in_address_on_stack))
                                      {
                                        char error[1024];
                                        sprintf(error, "Unable to find the address of the parameter passed by reference to '%s' in position %d", $1, $$->max - $$->counter + 1);
                                        semantic_error(error);
                                      }

                                      if ($3->type->desc.type_attr.type_class == TC_INTEGER &&
                                          last_parm->desc.var_attr.type->desc.type_attr.type_class == TC_REAL)
                                      {
                                        if (last_parm->desc.var_attr.reference_semantics)
                                        {
                                          char error[1024];
                                          sprintf(error, "Cannot pass an integer type by reference to a real type");
                                          semantic_error(error);
                                        }
                                        else
                                          convert_int_to_real = 1;
                                      }
                                    }
                                  }
                                }

                                if ($3 && $3->type)
                                {
                                  func = isCurrentFunction($1);
                                  if (!func)
                                    func = globallookup($1);
                                  asc_function_call(ASC_FUNCTION_CALL_BEGIN, func, 0, 0, 1);
                                  if (last_parm)
                                    asc_function_call(ASC_FUNCTION_CALL_ARG, $3, convert_int_to_real, last_parm->desc.var_attr.reference_semantics, 1);
                                  else
                                    asc_function_call(ASC_FUNCTION_CALL_ARG, $3, convert_int_to_real, 0, 1);

                                }

                                $$->counter = $$->counter - 1;
                              }
                              else
                              {
                                char error[1024];
                                sprintf(error, "'%s' isn't a procedure or function.", $1);
                                semantic_error(error);
                                $$ = NULL;
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
                          int convert_int_to_real = 0;
                          struct sym_rec* last_parm = NULL;
                          if ($1) {
                            if (isIOFunc($1))
                            {
                              if($3 && $3->type && !checkIOArg($3->type))
                              {
                                char error[1024];
                                sprintf(error, "Argmument %d of '%s' must be of type integer, real, char, or string", -($1->counter)+1, $$->name);
                                semantic_error(error);
                              }
                            }
                            else
                            {
                              int i;
                              for(i = 1, last_parm = $1->parmlist; last_parm != NULL && i < $1->counter; last_parm = last_parm->next, i++);

                              if ($1->counter <= 0)
                                last_parm = NULL;
                                                              
                              if ($3 && $3->type && last_parm) {
                                /* This should be an OC_VAR */
                                if (last_parm->class == OC_VAR) {
                                  if (!compare_types($3->type, last_parm->desc.var_attr.type, 1))
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
                                  else if (last_parm->desc.var_attr.reference_semantics && !($3->location) && !($3->is_in_address_on_stack))
                                  {
                                    char error[1024];
                                    sprintf(error, "Unable to find the address of the parameter passed by reference to '%s' in position %d", $1->name, $$->max - $$->counter + 1);
                                    semantic_error(error);
                                  }

                                  if ($3->type->desc.type_attr.type_class == TC_INTEGER &&
                                      last_parm->desc.var_attr.type->desc.type_attr.type_class == TC_REAL)
                                  {
                                    if (last_parm->desc.var_attr.reference_semantics)
                                    {
                                      char error[1024];
                                      sprintf(error, "Cannot pass an integer type by reference to a real type");
                                      semantic_error(error);
                                    }
                                    else
                                      convert_int_to_real = 1;
                                  }
                                }
                              }
                            }
                              
                            if ($3 && $3->type)
                            {
                              if (last_parm)
                                asc_function_call(ASC_FUNCTION_CALL_ARG, $3, convert_int_to_real, last_parm->desc.var_attr.reference_semantics, 1);
                              else
                                asc_function_call(ASC_FUNCTION_CALL_ARG, $3, convert_int_to_real, 0, 1);
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
                            if ($2 && $2->type && $2->type->desc.type_attr.type_class != TC_BOOLEAN)
                            {
                              char error[1024];
                              sprintf(error, "If statement conditionals must be of type boolean.");
                              semantic_error(error);
                            }
                            asc_if(ASC_IF_END_NO_ELSE);
                          }
                        | IF error THEN stat { yyerrok; yyclearin; }
                        | IF expr THEN matched_stat ELSE stat
                          {
                            if ($2 && $2->type && $2->type->desc.type_attr.type_class != TC_BOOLEAN)
                            {
                              char error[1024];
                              sprintf(error, "If statement conditionals must be of type boolean.");
                              semantic_error(error);
                            }
                            asc_if(ASC_IF_END);
                          }
                        | IF error THEN matched_stat ELSE stat { yyerrok; yyclearin; }
                        | IF expr THEN error ELSE stat
                        | THEN stat { yyerror("Missing 'if' required to match 'then' statement"); }
                        | THEN matched_stat ELSE stat { yyerror("Missing 'if' required to match 'then' statement"); }
                        | WHILE expr DO stat
                          {
                            if ($2 && $2->type && $2->type->desc.type_attr.type_class != TC_BOOLEAN)
                            {
                              char error[1024];
                              sprintf(error, "while statement conditionals must be of type boolean.");
                              semantic_error(error);
                            }
                            decrementWhileCounter();
                            asc_while(ASC_WHILE_END);
                          }
                        | WHILE error DO { decrementWhileCounter(); yyerrok; yyclearin; }
                        | DO stat { yyerror("Missing 'while' required to match 'do' statement"); }
                        | CONTINUE
                          {
                            if (getWhileCounter() == 0)
                            {
                              char error[1024];
                              sprintf(error, "continue statement used outside of a loop");
                              semantic_error(error);
                            }
                            asc_while(ASC_WHILE_CONTINUE);
                          }
                        | EXIT
                          {
                            if (getWhileCounter() == 0)
                            {
                              char error[1024];
                              sprintf(error, "exit statement used outside of a loop");
                              semantic_error(error);
                            }
                            asc_while(ASC_WHILE_EXIT);
                          }
                        ;

matched_stat            : simple_stat
                        | IF expr THEN matched_stat ELSE matched_stat
                          {
                            if ($2 && $2->type && $2->type->desc.type_attr.type_class != TC_BOOLEAN)
                            {
                              char error[1024];
                              sprintf(error, "If statement conditionals must be of type boolean.");
                              semantic_error(error);
                            }
                            asc_if(ASC_IF_END);
                          }
                        | IF error THEN matched_stat ELSE matched_stat { yyerrok; yyclearin; }
                        | IF expr THEN error ELSE matched_stat { yyerrok; yyclearin; }
                        | WHILE expr DO matched_stat { asc_while(ASC_WHILE_END); decrementWhileCounter(); }
                        | WHILE error DO matched_stat { decrementWhileCounter(); yyerrok; yyclearin; }
                        | CONTINUE
                          {
                            if (getWhileCounter() == 0)
                            {
                              char error[1024];
                              sprintf(error, "continue statement used outside of a loop");
                              semantic_error(error);
                            }
                            asc_while(ASC_WHILE_CONTINUE);
                          }
                        | EXIT
                          {
                            if (getWhileCounter() == 0)
                            {
                              char error[1024];
                              sprintf(error, "exit statement used outside of a loop");
                              semantic_error(error);
                            }
                            asc_while(ASC_WHILE_EXIT);
                          }
                        ;
