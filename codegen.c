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

void emit_assignment(struct sym_rec* var, struct expr_t* expr)
{
  if (!do_codegen)
    return;

  int expr_tc = expr->type->desc.type_attr.type_class;

  emit_operand(expr);
  emit_pop(var->desc.var_attr.location.display, var->desc.var_attr.location.offset);
}

void emit_addition(struct expr_t* operand1, struct expr_t* operand2)
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
  emit_operand(operand1);
  if (convert_to_real[0])
    emit_itor();
  emit_operand(operand2);
  if (convert_to_real[1])
    emit_itor();

  if (real_addition)
    emit_addr();
  else
    emit_addi();
}

void emit_operand(struct expr_t* operand)
{
  if (!do_codegen)
    return;

  if (operand->location)
    emit_push(operand->location->display, operand->location->offset);
  else if (operand->is_const)
    switch(operand->type->desc.type_attr.type_class)
    {
      case TC_INTEGER:
        emit_iconst(operand->value.integer);
        break;
      case TC_REAL:
        emit_rconst(operand->value.real);
        break;
      case TC_CHAR:
        emit_iconst((int)operand->value.character);
        break;
      case TC_BOOLEAN:
        emit_iconst(operand->value.boolean);
        break;
      default:
        printf("emit_operand: Trying to push something weird onto the stack\n");
    }
}

void emit_pop(int display, int offset)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tPOP %d[%d]\n", offset, display);
}

void emit_itor(void)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tITOR\n");
}

void emit_iconst(int val)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tCONSTI %d\n", val);
}

void emit_rconst(float val)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tCONSTR %f\n", val);
}

void emit_addi(void)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tADDI\n");
}

void emit_addr(void)
{
  if(!do_codegen)
    return;

  fprintf(asc_file, "\tADDR\n");
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

  fprintf(asc_file, "\tPUSHI %d\n", display);
}

void emit_pusha(int display, int offset)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tPUSHA %d[%d]\n", offset, display);
}

void emit_stop(void)
{
  if (!do_codegen)
    return;

  fprintf(asc_file, "\tSTOP\n");
}

void adjust_stack(int scope_action)
{
  if (!do_codegen)
    return;

  if (scope_action == SCOPE_BEGIN)
    fprintf(asc_file, "\tADJUST %d\n", get_current_offset());
  else if (scope_action == SCOPE_END)
    fprintf(asc_file, "\tADJUST %d\n", -get_current_offset());
  else
    printf("adjust_stack: Invalid scope_action\n");
}
