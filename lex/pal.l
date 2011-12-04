/* pal.l
 *
 * Defines regular expressions for recognizing tokens. Does some error handling.
 *
 * Authors
 *   - Matthew Low
 *   - Anthony Galati
 *   - Mike Bujold
 *   - Stevan Clement
 */

%{
#include <stdio.h>
#include <string.h>

#include "codegen.h"
#include "pal.h"
#include "pal_gram.tab.h"
#include "semantics.h"

#define YY_USER_ACTION {              \
  update_position(strlen(yytext));    \
  if (last_token != -1)               \
    asc_notify_last_token(last_token);\
  last_token = -1;                    \
  }

//extern YYLTYPE yylloc;

//#define YY_USER_INIT yylloc.first_line=1;

//#define DEBUG
#ifdef DEBUG
#define DB_PRINTF(format, a...) printf(format, ## a)
#else
#define DB_PRINTF(format, a...)
#endif

int last_token = -1;
%}

%option noyywrap
%x COMMENT
%%
 /* Handles { comments \n\n\n } */
^[ \t]*"{"                        DB_PRINTF("Entering COMMENT----- "); BEGIN COMMENT; /* Gotta get that comment */
^[ \t]*"{".*"}"[ \t]*\n           new_position_line(); /* One line comment */
<COMMENT>"}"[ \t]*\n              BEGIN 0; new_position_line();
<COMMENT>"}"                      BEGIN 0;
<COMMENT>\n                       DB_PRINTF("NEWLINE----- "); new_position_line();
<COMMENT>.                        ;
"{".*"}"                          DB_PRINTF("(Single line COMMENT) ");

 /* Reserved words ---------- */
and                               DB_PRINTF("AND ");  yylval.integer = AND; return AND;
or                                DB_PRINTF("OR ");   yylval.integer = OR;  return OR;
not                               DB_PRINTF("NOT ");  yylval.integer = NOT; return NOT;

div                               DB_PRINTF("DIV ");  yylval.integer = DIV; return DIV;
mod                               DB_PRINTF("MOD ");  yylval.integer = MOD; return MOD;

array                             DB_PRINTF("ARRAY "); return ARRAY;
begin                             DB_PRINTF("P_BEGIN "); last_token = P_BEGIN; return P_BEGIN;
const                             DB_PRINTF("CONST "); return CONST;
 /*true								              DB_PRINTF("BOOL - TRUE "); return BOOL;     */
 /*false								              DB_PRINTF("BOOL - FALSE "); return BOOL;  */
continue                          DB_PRINTF("CONTINUE "); return CONTINUE;
do                                DB_PRINTF("DO "); last_token = DO; return DO;
end                               DB_PRINTF("END "); return END;
exit                              DB_PRINTF("EXIT "); return EXIT;
function                          DB_PRINTF("FUNCTION "); return FUNCTION;
if                                DB_PRINTF("IF "); return IF;
then                              DB_PRINTF("THEN "); last_token = THEN; return THEN;
else                              DB_PRINTF("ELSE "); last_token = ELSE; return ELSE;
of                                DB_PRINTF("OF "); return OF;
procedure                         DB_PRINTF("PROCEDURE "); return PROCEDURE;
program                           DB_PRINTF("PROGRAM "); return PROGRAM;
record                            DB_PRINTF("RECORD "); return RECORD;
type                              DB_PRINTF("TYPE "); return TYPE;
var                               DB_PRINTF("VAR "); return VAR;
while                             DB_PRINTF("WHILE "); incrementWhileCounter(); asc_while(ASC_WHILE_BEGIN); return WHILE;

 /* Numbers and variables ---------- */
(([0-9]+"."[0-9]+(E("-"|"+")?[0-9]+)?)|([0-9]+(E("-"|"+")?[0-9]+)))  {
                                                                           DB_PRINTF("REAL ");
                                                                           sscanf(yytext, "%lf", &yylval.real_t);
                                                                           return REAL_CONST;
                                                                         }


\'(\\(n|t|'|\\)|[^\\'])*\'			  {
                                        DB_PRINTF( "%s ", yytext);
                                        yylval.name = strdup(yytext);

                                        if (schomp(yylval.name) != 0)
                                          illegal_string();                                          
                                        
                                        return STRING; /* returns properly terminate strings */
                                      }

\'(\\(n|t|'|\\)|[^\\'])*\n        {DB_PRINTF("Unterminated string "); unterminated_string(); return NSTRING; /* returns non-terminated strings */}       
                                        /* Strings may require some checking later            "'"(.*?)"'"  */
                                        /* Probably have to rip the single quotes off (yyleng) */

 /* This next one conflicts with the above VAR so... */
[A-Za-z][A-Za-z0-9]*              DB_PRINTF("ID(%s) ", yytext); yylval.name = strdup(yytext); return ID;
[0-9]+                            DB_PRINTF("INT "); yylval.integer = atoi(yytext); return INT_CONST;

 /* Operators ---------- */
":="                              DB_PRINTF("ASSIGNMENT "); return ASSIGNMENT;
"="                               DB_PRINTF("EQUALS ");       yylval.integer = EQUALS;        return EQUALS;
"<>"                              DB_PRINTF("NOT_EQUAL ");    yylval.integer = NOT_EQUAL;     return NOT_EQUAL;
"<"                               DB_PRINTF("LESS_THAN ");    yylval.integer = LESS_THAN;     return LESS_THAN;
">"                               DB_PRINTF("GREATER_THAN "); yylval.integer = GREATER_THAN;  return GREATER_THAN;
"<="                              DB_PRINTF("LESS_EQUAL");    yylval.integer = LESS_EQUAL;    return LESS_EQUAL;
">="                              DB_PRINTF("GREATER_EQUAL"); yylval.integer = GREATER_EQUAL; return GREATER_EQUAL; 
"+"                               DB_PRINTF("PLUS ");         yylval.integer = PLUS;          return PLUS;
"-"                               DB_PRINTF("MINUS ");        yylval.integer = MINUS;         return MINUS;
"*"                               DB_PRINTF("MULTIPLY ");     yylval.integer = MULTIPLY;      return MULTIPLY;
"/"                               DB_PRINTF("DIVIDE ");       yylval.integer = DIVIDE;        return DIVIDE;
 /* div and mod are under reserved words */

 /* Other lexical characters ---------- */
"("                               DB_PRINTF("O_BRACKET "); return O_BRACKET;
")"                               DB_PRINTF("C_BRACKET "); return C_BRACKET;
"."                               DB_PRINTF("PERIOD "); return PERIOD;
";"                               DB_PRINTF("S_COLON "); yylval.ch = ';'; return S_COLON;
":"                               DB_PRINTF("COLON "); return COLON;
"["                               DB_PRINTF("O_SBRACKET "); return O_SBRACKET;
"]"                               DB_PRINTF("C_SBRACKET "); return C_SBRACKET;
","                               DB_PRINTF("COMMA "); return COMMA;
".."							                DB_PRINTF("DDOT "); return DDOT;

 /* Comments, newlines, garbage ---------- */                               
\n                                DB_PRINTF("\n "); new_position_line();
[ \t]+                            /* ignore whitespace */;
\/\/.*\n                          new_position_line(); /* comment   What is EOF in PAL? */ 
[&!@#$%^{}"]                      DB_PRINTF("Garbage character "); lexerror(yytext);
.                                 DB_PRINTF("Garbage character "); lexerror(yytext);
%%
