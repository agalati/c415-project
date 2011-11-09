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

#include "semantics.h"
#include "symtab.h"

struct sym_rec* prev_fields;
int search_fields = 0;

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
%token            STRING THEN TYPE VAR WHILE 
%token  <integer> INT_CONST
%token  <real_t>  REAL_CONST

%type   <symrec>  expr 
%type   <symrec>  type 
%type   <symrec>  simple_type
%type   <symrec>  scalar_list
%type   <symrec>  scalar_type
%type   <range>   array_type
%type   <symrec>  structured_type
%type   <symrec>  field_list
%type   <symrec>  field

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
                                    sprintf(error, "'%s' is not a type.");
                                    semantic_error(error);
                                  }
                              }
                        ;

scalar_type             : O_BRACKET scalar_list C_BRACKET
                          {
                            $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                            $$->next = NULL;
                            $$->name = NULL;
                            $$->class = OC_TYPE;
                            $$->desc.type_attr.type_class = TC_SCALAR;
                            $$->desc.type_attr.type_description.scalar = (struct tc_scalar*)malloc(sizeof(struct tc_scalar));
                            $$->desc.type_attr.type_description.scalar->const_list = $2;
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
                              $$->level = get_current_level()-1;
                              $$->class = OC_CONST;
                              $$->desc.const_attr.type = builtinlookup("integer");
                            }
                            else
                            {
                              char error[1024];
                              sprintf(error, "'%s' has already been declared in this scope.", $1);
                              semantic_error(error);
                            }
                          }
                        | scalar_list COMMA ID
                          {
                            if (locallookup($3) == NULL)
                            {
                              $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              $$->next = $1;
                              $$->name = $3;
                              $$->level = get_current_level()-1;
                              $$->class = OC_CONST;
                              $$->desc.const_attr.type = builtinlookup("integer");
                            }
                            else
                            {
                              char error[1024];
                              sprintf(error, "'%s' has already been declared in this scope.", $1);
                              semantic_error(error);
                            }
                          }
                        ;

structured_type         : ARRAY O_SBRACKET array_type C_SBRACKET OF type
                          {
                            if ($3 != NULL && $6 != NULL)
                            {
                              $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              $$->next = NULL;
                              $$->name = NULL;
                              $$->class = OC_TYPE;
                              $$->desc.type_attr.type_class = TC_ARRAY;
                              $$->desc.type_attr.type_description.array = (struct tc_array*)malloc(sizeof(struct tc_array));
                              $$->desc.type_attr.type_description.array->subrange = $3;
                              $$->desc.type_attr.type_description.array->object_type = $6;
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
                          }
                        | field_list S_COLON field
                          {
                            $3->next = $1;
                            $$ = $3;
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
                                if (strcmp($1, prev->name) == 0)
                                  found = 1;
                              }
                            }
                            if (!found)
                            {
                              $$ = (struct sym_rec*)malloc(sizeof(struct sym_rec));
                              $$->next = NULL;
                              $$->name = $1;
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

var_decl                : ID COLON type     { declare_variable($1); /* $$ = $3; */}
                        | ID COMMA var_decl { declare_variable($1); /* $$ = $3; */}
                        ;

proc_decl_part          : proc_decl_list
                        |
                        ;

proc_decl_list          : proc_decl
                        | proc_decl_list proc_decl
                        ;

proc_decl               : proc_heading decls compound_stat S_COLON
                        //| error S_COLON { yyerrok; yyclearin; }
                        ;

proc_heading            : PROCEDURE ID f_parm_decl S_COLON
                        | FUNCTION ID f_parm_decl COLON ID S_COLON
                        ;

f_parm_decl             : O_BRACKET f_parm_list C_BRACKET
                        | O_BRACKET C_BRACKET
                        ;

f_parm_list             : f_parm
                        | f_parm_list S_COLON f_parm
                        | error S_COLON f_parm { yyerrok; yyclearin; }
                        ;

f_parm                  : ID COLON ID
                        | VAR ID COLON ID
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
                        | proc_invok
                        | compound_stat
                        ;

proc_invok              : plist_finvok C_BRACKET
                        | ID O_BRACKET C_BRACKET
                        ;

var                     : ID
                        | var PERIOD ID
                        | subscripted_var C_SBRACKET
                        ;

subscripted_var         : var O_SBRACKET expr
                        | subscripted_var COMMA expr
                        ;

expr                    : simple_expr
                        | simple_expr operator expr
                        ;
            
operator                : EQUALS
                        | NOT_EQUAL
                        | LESS_EQUAL
                        | LESS_THAN
                        | GREATER_EQUAL
                        | GREATER_THAN
                        | error
                        ;

simple_expr             : term
                        | PLUS term
                        | MINUS term
                        | simple_expr PLUS term
                        | simple_expr MINUS term
                        | simple_expr OR  term
                        ;

term                    : factor
                        | term MULTIPLY factor
                        | term DIVIDE factor
                        | term DIV factor
                        | term MOD factor
                        | term AND factor
                        ;

factor                  : var                       /* removed simple_type and added it's applicable atoms */
						            | unsigned_const
                        | BOOL
                        | O_BRACKET expr C_BRACKET
                        | func_invok
                        | NOT factor
                        ;

unsigned_const          : unsigned_num                    
						            | STRING                         
						            | NSTRING   			/* Non-terminated string warning here */                                        
                        ;                                

unsigned_num            : INT_CONST            
						            | REAL_CONST                           
						            ;                                

func_invok              : plist_finvok C_BRACKET
                        | ID O_BRACKET C_BRACKET
                        ;

plist_finvok            : ID O_BRACKET parm
                        | plist_finvok COMMA parm
                        ;

parm                    : expr 
                        ;

struct_stat             : IF expr THEN stat
                        | IF error THEN stat { yyerrok; yyclearin; }
                        | IF expr THEN matched_stat ELSE stat
                        | IF error THEN matched_stat ELSE stat { yyerrok; yyclearin; }
                        | IF expr THEN error ELSE stat
                        | THEN stat { yyerror("Missing 'if' required to match 'then' statement"); }
                        | THEN matched_stat ELSE stat { yyerror("Missing 'if' required to match 'then' statement"); }
                        | WHILE expr DO stat
                        | WHILE error DO { yyerrok; yyclearin; }
                        | DO stat { yyerror("Missing 'while' required to match 'do' statement"); }
                        | CONTINUE
                        | EXIT
                        ;

matched_stat            : simple_stat
                        | IF expr THEN matched_stat ELSE matched_stat
                        | IF error THEN matched_stat ELSE matched_stat { yyerrok; yyclearin; }
                        | IF expr THEN error ELSE matched_stat { yyerrok; yyclearin; }
                        | WHILE expr DO matched_stat
                        | WHILE error DO matched_stat { yyerrok; yyclearin; }
                        | CONTINUE
                        | EXIT
                        ;
%% /* End of grammer */
