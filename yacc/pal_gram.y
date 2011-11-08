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

#include "symtab.h"
%}

 //%expect 1     /* bison knows to expect 1 s/r conflict */
%locations
%error-verbose
  /* free discarded tokens */
%destructor { printf ("free at %d %s\n",@$.first_line, $$); free($$); } <*>

/* New tokens */
%token  ASSIGNMENT EQUALS NOT_EQUAL LESS_THAN
%token  GREATER_THAN LESS_EQUAL GREATER_EQUAL
%token  PLUS MINUS MULTIPLY DIVIDE O_BRACKET C_BRACKET
%token  PERIOD S_COLON COLON O_SBRACKET C_SBRACKET
%token  COMMA START_COM END_COM NSTRING DDOT

/* Original tokens */
%token  AND ARRAY P_BEGIN BOOL CHAR CONST CONTINUE DIV
%token  DO ELSE END EXIT FUNCTION ID IF INT MOD
%token  NOT OF OR PROCEDURE PROGRAM REAL RECORD
%token  STRING THEN TYPE VAR WHILE INT_CONST REAL_CONST

%% /* Start of grammer */

program                 : program_head decls compound_stat PERIOD
                        ;

program_head            : PROGRAM ID O_BRACKET ID COMMA ID C_BRACKET S_COLON
                        | error { yyclearin; }
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
                        | error S_COLON { yyclearin; }
                        ;

const_decl              : ID EQUALS expr
                        ;

type_decl_part          : TYPE type_decl_list S_COLON
                        |
                        ;

type_decl_list          : type_decl
                        | type_decl_list S_COLON type_decl
                        ;

type_decl               : ID EQUALS type
                        ;

type                    : simple_type
                        | structured_type
                        ;

simple_type             : scalar_type
                        | REAL
                        | ID
                        ;

scalar_type             : O_BRACKET scalar_list C_BRACKET
                        | O_BRACKET error C_BRACKET
                        | INT
                        | BOOL
                        | CHAR
                        ;

scalar_list             : ID
                        | scalar_list COMMA ID
                        ;

structured_type         : ARRAY O_SBRACKET array_type C_SBRACKET OF type
                        | ARRAY O_SBRACKET error C_SBRACKET OF type
                        | RECORD field_list END
                        ;

array_type              : simple_type
                        | INT DDOT INT
                        | ID DDOT ID
                        ;                     

field_list              : field
                        | field_list S_COLON field
                        ;

field                   : ID COLON type
                        ;

var_decl_part           : VAR var_decl_list S_COLON
                        |
                        ;

var_decl_list           : var_decl
                        | var_decl_list S_COLON var_decl
                        | error S_COLON { yyclearin; }
                        ;

var_decl                : ID COLON type
                        | ID COMMA var_decl
                        ;

proc_decl_part          : proc_decl_list
                        |
                        ;

proc_decl_list          : proc_decl
                        | proc_decl_list proc_decl
                        ;

proc_decl               : proc_heading decls compound_stat S_COLON
                        ;

proc_heading            : PROCEDURE ID f_parm_decl S_COLON
                        | FUNCTION ID f_parm_decl COLON ID S_COLON
                        ;

f_parm_decl             : O_BRACKET f_parm_list C_BRACKET
                        | O_BRACKET C_BRACKET
                        ;

f_parm_list             : f_parm
                        | f_parm_list S_COLON f_parm
                        ;

f_parm                  : ID COLON ID
                        | VAR ID COLON ID
                        ;

compound_stat           : P_BEGIN stat_list END
                        ;       

stat_list               : stat
                        | stat_list S_COLON stat
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
                        | INT                 
                        | REAL
                        | BOOL
                        | O_BRACKET expr C_BRACKET
                        | func_invok
                        | NOT factor
                        ;

unsigned_const    : unsigned_num                    
						| STRING                         
						| NSTRING   			/* Non-terminated string warning here */                                        
                         ;                                

unsigned_num     : INT_CONST            
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
                        | IF error THEN stat { yyclearin; }
                        | IF expr THEN matched_stat ELSE stat
                        | IF error THEN matched_stat ELSE stat
                        | IF expr THEN error ELSE stat { yyclearin; }
                        | WHILE expr DO stat
                        | WHILE error DO  { yyclearin; }
                        | CONTINUE
                        | EXIT
                        ;

matched_stat            : simple_stat
                        | IF expr THEN matched_stat ELSE matched_stat
                        | IF error THEN matched_stat ELSE matched_stat { yyclearin; }
                        | IF expr THEN error ELSE matched_stat { yyclearin; }
                        | WHILE expr DO matched_stat
                        | WHILE error DO matched_stat { yyclearin; }
                        | CONTINUE
                        | EXIT
                        ;
%% /* End of grammer */
