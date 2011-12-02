/*
 * codegen.h
 *
 * Authors
 *   - Matthew Low
 *   - Anthony Galati
 *   - Mike Bujold
 *   - Stevan Clement
 */

#include "codegen.h"

int do_codegen = 1;

void stop_codegen(void)
{
  do_codegen = 0;
}

void asc_assignment(struct sym_rec* var, struct expr_t* expr)
{
  if (!do_codegen)
    return;

  int expr_tc = expr->type->desc.type_attr.type_class;

  push_operand(expr);
  emit_pop(var->desc.var_attr.location.display, var->desc.var_attr.location.offset);
}

void asc_addition(struct expr_t* operand1, struct expr_t* operand2)
{
  if (!do_codegen)
    return;

  int tc1 = operand1->type->desc.type_attr.type_class,
      tc2 = operand2->type->desc.type_attr.type_class;

  int real_addition = 0;

  if (tc1 == TC_REAL || tc2 == TC_REAL)
    real_addition = 1;

  int convert_to_real[2] = {0, 0};
  if (tc1 == TC_REAL && tc2 == TC_INTEGER)
    convert_to_real[1] = 1;
  else if (tc1 == TC_INTEGER && tc2 == TC_REAL)
    convert_to_real[0] = 1;

  // Only pushes onto the stack if it isn't already there
  push_operand(operand1);
  if (convert_to_real[0])
    emit(ASC_ITOR);
  push_operand(operand2);
  if (convert_to_real[1])
    emit(ASC_ITOR);

  if (real_addition)
    emit(ASC_ADDR);
  else
    emit(ASC_ADDI);
}

void push_operand(struct expr_t* operand)
{
  if (!do_codegen)
    return;

  if (operand->location)
    emit_push(operand->location->display, operand->location->offset);
  else if (operand->is_const)
    switch(operand->type->desc.type_attr.type_class)
    {
      case TC_INTEGER:
        emit_consti(operand->value.integer);
        break;
      case TC_REAL:
        emit_constr(operand->value.real);
        break;
      case TC_CHAR:
        emit_consti((int)operand->value.character);
        break;
      case TC_BOOLEAN:
        emit_consti(operand->value.boolean);
        break;
      default:
        printf("emit_operand: Trying to push something weird onto the stack\n");
    }
}

void emit_push(int display, int offset)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tPUSH %d[%d]\n", offset, display);
}

void emit_pushi(int display)
{
  if (!do_codegen)
    return;

  if (display < 0)
    fprintf(asc_file, "\tPUSHI%d\n");
  else
    fprintf(asc_file, "\tPUSHI %d\n", display);
}

void emit_pusha(int display, int offset)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tPUSHA %d[%d]\n", offset, display);
}

void emit_pop(int display, int offset)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tPOP %d[%d]\n", offset, display);
}

void emit_popi(int display)
{
  if (!do_codegen)
    return;

  if (display < 0)
    fprintf(asc_file, "\tPOPI\n");
  else
    fprintf(asc_file, "\tPOPI %d\n", display);
}

void emit_consti(int n)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tCONSTI %d\n", n);
}

void emit_constr(float r)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tCONSTR %f\n", r);
}

void emit_adjust(int amount)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tADJUST %d\n", amount);
}

void emit_alloc(int n)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tALLOC %d\n", n);
}

void emit_ifz(char* label)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tIFZ %s\n", label);
}

void emit_ifnz(char* label)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tIFNZ %s\n", label);
}

void emit_iferr(char* label)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tIFERR %s\n", label);
}

void emit_goto(char* label)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tGOTO %s\n", label);
}

void emit_call(int display, char* label)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tCALL %d, %s\n", display, label);
}

void emit_ret(int display)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tRET %d\n", display);
}

void emit_comment(char* comment)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "# %s\n", comment);
}

void emit_trace(int n)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "!T=%d\n", n);
}

void emit_dump(void)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "!D\n");
}

void emit(char* op)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\t%s\n", op);
}
