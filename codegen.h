/*
 * codegen.h
 *
 * Authors
 *   - Matthew Low
 *   - Anthony Galati
 *   - Mike Bujold
 *   - Stevan Clement
 */

#ifndef CODEGEN_H
#define CODEGEN_H

#include <stdio.h>

#include "semantics.h"
#include "symtab.h"

/* Stack Operations */

//#define ASC_PUSH    "PUSH"
//#define ASC_PUSHI   "PUSHI"
//#define ASC_PUSHA   "PUSHA"

//#define ASC_POP     "POP"
//#define ASC_POPI    "POPI"

//#define ASC_CONSTI  "CONSTI"
//#define ASC_CONSTR  "CONSTR"

#define ASC_DUP     "DUP"
//#define ASC_ADJUST  "ADJUST"
//#define ASC_ALLOC   "ALLOC"
#define ASC_FREE    "FREE"
#define ASC_SALLOC  "SALLOC"

/* Arithmetic Operations */

#define ASC_ADDI    "ADDI"
#define ASC_ADDR    "ADDR"

#define ASC_SUBI    "SUBI"
#define ASC_SUBR    "SUBR"

#define ASC_MULI    "MULI"
#define ASC_MULR    "MULR"

#define ASC_DIVI    "DIVI"
#define ASC_DIVR    "DIVR"

#define ASC_MOD     "MOD"
#define ASC_ITOR    "ITOR"
#define ASC_RTOI    "RTOI"

/* Logical Operations */

#define ASC_EQI     "EQI"
#define ASC_EQR     "EQR"

#define ASC_LTI     "LTI"
#define ASC_LTR     "LTR"

#define ASC_GTI     "GTI"
#define ASC_GTR     "GTR"

#define ASC_OR      "OR"
#define ASC_AND     "AND"
#define ASC_NOT     "NOT"

/* Control Flow */

//#define ASC_IFZ     "IFZ"
//#define ASC_IFNZ    "IFNZ"
//#define ASC_IFERR   "IFERR"
//#define ASC_GOTO    "GOTO"
#define ASC_STOP    "STOP"

/* Subroutine Linkage */

//#define ASC_CALL    "CALL"
//#define ASC_RET     "RET"


/* Input and Output */

#define ASC_READI   "READI"
#define ASC_READR   "READR"
#define ASC_READC   "READC"

#define ASC_WRITEI  "WRITEI"
#define ASC_WRITER  "WRITER"
#define ASC_WRITEC  "WRITEC"

/* Debugging Aids */

//#define ASC_COMMENT "#"
//#define ASC_TRACE   "!T="
#define ASC_DUMP    "!D"

/* While loop sections */

#define ASC_WHILE_BEGIN       0
#define ASC_WHILE_DO          1
#define ASC_WHILE_END         2
#define ASC_WHILE_CONTINUE    3
#define ASC_WHILE_EXIT        4

/* If sections */

#define ASC_IF_BEGIN        0
#define ASC_IF_ELSE         1
#define ASC_IF_END          2
#define ASC_IF_END_NO_ELSE  3

/* Function sections */

#define ASC_FUNCTION_BEGIN    0
#define ASC_FUNCTION_END      1

/* Function call sections */

#define ASC_FUNCTION_CALL_BEGIN 0
#define ASC_FUNCTION_CALL_ARG   1
#define ASC_FUNCTION_CALL_END   2

/* Builtin function names */

#define BUILTIN_STR_EQ    "string_eq"
#define BUILTIN_STR_NEQ   "string_neq"
#define BUILTIN_STR_LT    "string_lt"
#define BUILTIN_STR_LE    "string_le"
#define BUILTIN_STR_GT    "string_gt"
#define BUILTIN_STR_GE    "string_ge"

#define BUILTIN_STR_COPY  "string_copy"

struct func_call_info_t
{
  struct sym_rec* func;
  int argc;
  int builtin;

  struct func_call_info_t* next;
};

FILE* asc_file;

void stop_codegen(void);
void asc_store_simple_expr(struct expr_t* simple_expr);
void asc_push_expr_if_unhandled();

// Only pushes onto the stack if it isn't already there
// returns 0 if nothing was pushed, or 1 otherwise
int push_expr(struct expr_t* expr);
int push_const_string_to_stack(struct expr_t* expr);

char* get_next_while_label();
char* get_next_if_label();

void write_function_info();

void asc_start();
void asc_stop();

void asc_notify_last_token(int token);

void asc_increment_var_count(int size);

void asc_next_parameter_location(struct location_t* location, int size);
void asc_function_definition(int section, char* name, struct sym_rec* parm_list);
void asc_function_call(int section, void* info, int convert_int_to_real);
void handle_composite_arg(struct expr_t* arg);

void builtin_function_call(struct func_call_info_t* call_info, int section, void* info, int convert_int_to_real);
char* required_builtins(char* name);

void asc_while(int section);
void asc_if(int section);

void asc_push_var(struct sym_rec* var);

void asc_assignment(struct sym_rec* var, int var_address_on_stack, struct expr_t* expr);
void asc_memcpy(struct sym_rec* var, int var_address_on_stack, struct expr_t* expr);

void asc_math(int op, struct expr_t* operand1, struct expr_t* operand2);
void asc_integer_math(int op, struct expr_t* operand1, struct expr_t* operand2);
void asc_comparisons(int op, struct expr_t* operand1, struct expr_t* operand2);
void asc_logic(int op, struct expr_t* operand1, struct expr_t* operand2);

void string_comparison(int op, struct expr_t* operand1, struct expr_t* operand2);
void number_comparison(int op, struct expr_t* operand1, struct expr_t* operand2);

/* Stack Operations */
void emit_push(int display, int offset);
void emit_pushi(int display); // if display < 0, it is ignored
void emit_pusha(int display, int offset);

void emit_pop(int display, int offset);
void emit_popi(int display); // if display < 0, it is ignored

void emit_consti(int n);
void emit_constr(float r);

void emit_adjust(int amount);
void emit_alloc(int n);

/* Control Flow */

void emit_ifz(char* label);
void emit_ifnz(char* label);
void emit_iferr(char* label);
void emit_goto(char* label);

/* Subroutine Linkage */

void emit_call(int display, char* label);
void emit_ret(int display);

/* Input and Output */

void emit_comment(char* comment);
void emit_trace(int n);
void emit_dump(void);

/* single function to take care of all ASC operations that don't have arguments */
void emit(char* op);

/* bounds checking */
void stop_boundscheck(void);
void emit_boundscheck(int index, int lowbound, int highbound);

#endif
