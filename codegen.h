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

#define SCOPE_BEGIN 1
#define SCOPE_END   0

FILE* asc_file;

void stop_codegen(void);

void emit_addition(struct expr_t* operand1, struct expr_t* operand2);

void emit_operand(struct expr_t* operand);

void emit_pop(int display, int offset);

void emit_add(int, int);

void emit_itor(void);

void emit_iconst(int val);
void emit_rconst(float val);

void emit_addi(void);
void emit_addr(void);

void emit_push(int display, int offset);
void emit_pushi(int display);
void emit_pusha(int display, int offset);

void emit_stop(void);

void adjust_stack(int scope_action);

void emit(char* output, int a, int b);

#endif
