/*
 * Filename
 * Here's the grammer, I just hooked it up so that I can use " return TOKEN; " in lex.
 */

%{
%}

%locations
%error-verbose

/* New tokens */
%token  ASSIGNMENT EQUALS NOT_EQUAL LESS_THAN
%token  GREATER_THAN LESS_EQUAL GREATER_EQUAL
%token  PLUS MINUS MULTIPLY DIVIDE O_BRACKET C_BRACKET
%token  PERIOD S_COLON COLON O_SBRACKET C_SBRACKET
%token  COMMA START_COM END_COM ARRAY_DOTS

/* Original tokens */
%token  AND ARRAY BEGIN BOOL CHAR CONST CONTINUE DIV
%token  DO ELSE END EXIT FUNCTION ID IF INT MOD
%token  NOT OF OR PROCEDURE PROGRAM REAL RECORD
%token  STRING THEN TYPE VAR WHILE INT_CONST REAL_CONST

%% /* Start of grammer */

program                 : program_head decls compound_stat '.'
                        ;

program_head            : PROGRAM ID '(' ID ',' ID ')' ';'
                        ;

decls                   : const_decl_part
                          type_decl_part        
                          var_decl_part
                          proc_decl_part
                        ;

const_decl_part         : CONST const_decl_list ';'
                        |
                        ;

const_decl_list         : const_decl
                        | const_decl_list ';' const_decl
                        ;

const_decl              : ID '=' expr
                        ;

type_decl_part          : TYPE type_decl_list ';'
                        |
                        ;

type_decl_list          : type_decl
                        | type_decl_list ';' type_decl
                        ;

type_decl               : ID '=' type
                        ;

type                    : simple_type
                        | structured_type
                        ;

simple_type             : scalar_type
                        : REAL
                        | ID
                        ;

scalar_type             : '(' scalar_list ')'
                        | INT
                        | BOOL
                        | CHAR
                        ;

scalar_list             : ID
                        | scalar_list ',' ID
                        ;

structured_type         : ARRAY '[' array_type ']' OF type
                        | RECORD field_list END
                        ;

array_type              : simple_type
                        | expr '..' expr
                        ;

field_list              : field
                        | field_list ';' field
                        ;

field                   : ID ':' type
                        ;

var_decl_part           : VAR var_decl_list ';'
                        |
                        ;

var_decl_list           : var_decl
                        | var_decl_list ';' var_decl
                        ;

var_decl                : ID ':' type
                        | ID ',' var_decl
                        ;

proc_decl_part          : proc_decl_list
                        |
                        ;

proc_decl_list          : proc_decl
                        | proc_decl_list proc_decl
                        ;

proc_decl               : proc_heading decls compound_stat ';'
                        ;

proc_heading            : PROCEDURE ID f_parm_decl ';'
                        | FUNCTION ID f_parm_decl ':' ID ';'
                        ;

f_parm_decl             : '(' f_parm_list ')'
                        | '(' ')'
                        ;

f_parm_list             : f_parm
                        | f_parm_list ';' f_parm
                        ;

f_parm                  : ID ':' ID
                        | VAR ID ':' ID
                        ;

compound_stat           : BEGIN stat_list END
                        ;       

stat_list               : stat
                        | stat_list ';' stat
                        ;

stat                    : simple_stat
                        | struct_stat
                        |
                        ;

simple_stat             : var ':=' expr
                        | proc_invok
                        | compound_stat
                        ;

proc_invok              : plist_finvok ')'
                        | ID '(' ')'
                        ;

var                     : ID
                        | var '.' ID
                        | subscripted_var ']'
                        ;

subscripted_var         : var '[' expr
                        | subscripted_var ',' expr
                        ;

expr                    : simple_expr
                        | expr '='     simple_expr
                        | expr '<' '>' simple_expr
                        | expr '<' '=' simple_expr
                        | expr '<'     simple_expr
                        | expr '>' '=' simple_expr
                        | expr '>'     simple_expr
                        ;

simple_expr             : term
                        | '+' term
                        | '-' term
                        | simple_expr '+' term
                        | simple_expr '-' term
                        | simple_expr OR  term
                        ;

term                    : factor
                        | term '*' factor
                        | term '/' factor
                        | term DIV factor
                        | term MOD factor
                        | term AND factor
                        ;

factor                  : var
                        | unsigned_const
                        | '(' expr ')'
                        | func_invok
                        | NOT factor
                        ;

unsigned_const          : unsigned_num
                        | ID
                        | STRING
                        ;

unsigned_num            : INT_CONST
                        | REAL_CONST
                        ;

func_invok              : plist_finvok ')'
                        | ID '(' ')'
                        ;

plist_finvok            : ID '(' parm
                        | plist_finvok ',' parm
                        ;

parm                    : expr

struct_stat             : IF expr THEN matched_stat ELSE stat
                        | IF expr THEN stat
                        | WHILE expr DO stat
                        | CONTINUE
                        | EXIT
                        ;

matched_stat            : simple_stat
                        | IF expr THEN matched_stat ELSE matched_stat
                        | WHILE expr DO matched_stat
                        | CONTINUE
                        | EXIT
                        ;
%% /* End of grammer */
