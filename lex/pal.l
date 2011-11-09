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

#include "pal.h"
#include "pal_gram.tab.h"

#define YY_USER_ACTION update_position(strlen(yytext));

//extern YYLTYPE yylloc;

//#define YY_USER_INIT yylloc.first_line=1;

//#define DEBUG
#ifdef DEBUG
#define DB_PRINTF(format, a...) printf(format, ## a)
#else
#define DB_PRINTF(format, a...)
#endif

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
and                               DB_PRINTF("AND "); return AND;
array                             DB_PRINTF("ARRAY "); return ARRAY;
begin                             DB_PRINTF("P_BEGIN "); return P_BEGIN;
const                             DB_PRINTF("CONST "); return CONST;
true								              DB_PRINTF("BOOL - TRUE "); return BOOL;
false								              DB_PRINTF("BOOL - FALSE "); return BOOL;
continue                          DB_PRINTF("CONTINUE "); return CONTINUE;
div                               DB_PRINTF("DIV "); return DIV;
do                                DB_PRINTF("DO "); return DO;
else                              DB_PRINTF("ELSE "); return ELSE;
end                               DB_PRINTF("END "); return END;
exit                              DB_PRINTF("EXIT "); return EXIT;
function                          DB_PRINTF("FUNCTION "); return FUNCTION;
if                                DB_PRINTF("IF "); return IF;
mod                               DB_PRINTF("MOD "); return MOD;
not                               DB_PRINTF("NOT "); return NOT;
of                                DB_PRINTF("OF "); return OF;
or                                DB_PRINTF("OR "); return OR;
procedure                         DB_PRINTF("PROCEDURE "); return PROCEDURE;
program                           DB_PRINTF("PROGRAM "); return PROGRAM;
record                            DB_PRINTF("RECORD "); return RECORD;
then                              DB_PRINTF("THEN "); return THEN;
type                              DB_PRINTF("TYPE "); return TYPE;
var                               DB_PRINTF("VAR "); return VAR;
while                             DB_PRINTF("WHILE "); return WHILE;

 /* Numbers and variables ---------- */
(([0-9]+"."[0-9]+(e|E("-"|"+")?[0-9]+)?)|([0-9]+(e|E("-"|"+")?[0-9]+)))  DB_PRINTF("REAL "); return REAL_CONST;


\'(\\(n|t|'|\\)|[^\\'])*\'			  DB_PRINTF( "%s ", yytext); return STRING; /* returns properly terminate strings */
\'(\\(n|t|'|\\)|[^\\'])*\n        {DB_PRINTF("Unterminated string "); return NSTRING; /* returns non-terminated strings */}       
                                        /* Strings may require some checking later            "'"(.*?)"'"  */
                                        /* Probably have to rip the single quotes off (yyleng) */

 /* This next one conflicts with the above VAR so... */
[A-Za-z][A-Za-z0-9]*              DB_PRINTF("ID(%s) ", yytext); yylval.name = strdup(yytext); return ID;
[0-9]+                            DB_PRINTF("INT "); yylval.integer = atoi(yytext); return INT_CONST;

 /* Operators ---------- */
":="                              DB_PRINTF("ASSIGNMENT "); return ASSIGNMENT;
"="                               DB_PRINTF("EQUALS "); return EQUALS;
"<>"                              DB_PRINTF("NOT_EQUAL "); return NOT_EQUAL;
"<"                               DB_PRINTF("LESS_THAN "); return LESS_THAN;
">"                               DB_PRINTF("GREATER_THAN "); return GREATER_THAN;
"<="                              DB_PRINTF("LESS_EQUAL"); return LESS_EQUAL;
">="                              DB_PRINTF("GREATER_EQUAL"); return GREATER_EQUAL; 
"+"                               DB_PRINTF("PLUS "); return PLUS;
"-"                               DB_PRINTF("MINUS "); return MINUS;
"*"                               DB_PRINTF("MULTIPLY "); return MULTIPLY;
"/"                               DB_PRINTF("DIVIDE "); return DIVIDE;
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
