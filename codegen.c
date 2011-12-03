/*
 * codegen.h
 *
 * Authors
 *   - Matthew Low
 *   - Anthony Galati
 *   - Mike Bujold
 *   - Stevan Clement
 */

#include <stdlib.h>

#include "pal_gram.tab.h"

#include "codegen.h"

int do_codegen = 1;

void stop_codegen(void)
{
  emit_comment("Stopping code generation.");
  do_codegen = 0;
}

char* get_next_while_label()
{
  static unsigned int n = 0;
  ++n;
  // max label size is 16
  char* label = (char*)malloc(16*sizeof(char));
  sprintf(label, "wlab_%d", n);
  return label;
}

char* get_next_if_label()
{
  static unsigned int n = 0;
  ++n;
  // max label size is 16
  char* label = (char*)malloc(16*sizeof(char));
  sprintf(label, "ilab_%d", n);
  return label;
}

void asc_while(int section)
{
  if (!do_codegen)
    return;

  static char* label = NULL;
  static char* endlabel = NULL;
  switch(section)
  {
    case ASC_WHILE_BEGIN:
      label = get_next_while_label();
      endlabel = (char*)malloc(16*sizeof(char));
      sprintf(endlabel, "end_%s", label);
      fprintf(asc_file, "\n%s\n", label);
      break;
    case ASC_WHILE_DO:
      emit_ifz(endlabel);
      break;
    case ASC_WHILE_END:
      emit_goto(label);
      fprintf(asc_file, "%s\n\n", endlabel);
      free(label);
      free(endlabel);
      break;
    case ASC_WHILE_CONTINUE:
      emit_goto(label);
      break;
    case ASC_WHILE_EXIT:
      emit_goto(endlabel);
      break;
    default:
      printf("asc_while: invalid section\n");
  }
}

void asc_assignment(struct sym_rec* var, struct expr_t* expr)
{
  if (!do_codegen)
    return;

  int expr_tc = expr->type->desc.type_attr.type_class;

  push_operand(expr);
  emit_pop(var->desc.var_attr.location.display, var->desc.var_attr.location.offset);
}

void asc_math(int op, struct expr_t* operand1, struct expr_t* operand2)
{
  if (!do_codegen)
    return;

  int tc1 = operand1->type->desc.type_attr.type_class,
      tc2 = operand2->type->desc.type_attr.type_class;

  int real_math = 0;

  if (tc1 == TC_REAL || tc2 == TC_REAL)
    real_math = 1;

  int convert_to_real[2] = {0, 0};
  if (op == DIVIDE)
  {
    convert_to_real[0] = 1;
    convert_to_real[1] = 1;
  }
  else if (tc1 == TC_REAL && tc2 == TC_INTEGER)
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

  switch(op)
  {
    case PLUS:
      if (real_math)
        emit(ASC_ADDR);
      else
        emit(ASC_ADDI);
      break;
    case MINUS:
      if (real_math)
        emit(ASC_SUBR);
      else
        emit(ASC_SUBI);
      break;
    case MULTIPLY:
      if (real_math)
        emit(ASC_MULR);
      else
        emit(ASC_MULI);
      break;
    case DIVIDE:
        emit(ASC_DIVR);
      break;
    default:
      printf("asc_math: unknown operation code\n");
  }
}

void asc_integer_math(int op, struct expr_t* operand1, struct expr_t* operand2)
{
  if (!do_codegen)
    return;

  // Only pushes onto the stack if it isn't already there
  push_operand(operand1);
  push_operand(operand2);

  switch(op)
  {
    case MOD:
        emit(ASC_MOD);
        break;
    case DIV:
        emit(ASC_DIVI);
      break;
    default:
      printf("asc_integer_math: unknown operation code\n");
  }
}

void asc_comparisons(int op, struct expr_t* operand1, struct expr_t* operand2)
{
  if (!do_codegen)
    return;

  int tc1 = operand1->type->desc.type_attr.type_class,
      tc2 = operand2->type->desc.type_attr.type_class;

  int real_comparisons = 0;

  if (tc1 == TC_REAL || tc2 == TC_REAL)
    real_comparisons = 1;

  int convert_to_real[2] = {0, 0};
  if (tc1 == TC_REAL && tc2 == TC_INTEGER)
    convert_to_real[1] = 1;
  else if (tc1 == TC_INTEGER && tc2 == TC_REAL)
    convert_to_real[0] = 1;

  push_operand(operand1);
  if (convert_to_real[0])
    emit(ASC_ITOR);

  push_operand(operand2);
  if (convert_to_real[1])
    emit(ASC_ITOR);

  switch(op)
  {
    case EQUALS:
      if (real_comparisons)
        emit(ASC_EQR);
      else
        emit(ASC_EQI);
      break;
    case NOT_EQUAL:
      if (real_comparisons)
        emit(ASC_EQR);
      else
        emit(ASC_EQI);
      emit(ASC_NOT);
      break;
    case LESS_THAN:
      if (real_comparisons)
        emit(ASC_LTR);
      else
        emit(ASC_LTI);
      break;
    case GREATER_THAN:
      if(real_comparisons)
        emit(ASC_GTR);
      else
        emit(ASC_GTI);
      break;
    case LESS_EQUAL:
      if(real_comparisons)
        emit(ASC_GTR);
      else
        emit(ASC_GTI);
      emit(ASC_NOT);
      break;
    case GREATER_EQUAL:
      if (real_comparisons)
        emit(ASC_LTR);
      else
        emit(ASC_LTI);
      emit(ASC_NOT);
      break;
    default:
      printf("asc_comparisons: Unknown comparison code\n");
  }
}

void asc_logic(int op, struct expr_t* operand1, struct expr_t* operand2)
{
  if (!do_codegen)
    return;

  // Only pushes onto the stack if it isn't already there
  push_operand(operand1);
  if (operand2)
    push_operand(operand2);

  switch(op)
  {
    case AND:
      emit(ASC_AND);
      break;
    case OR:
      emit(ASC_OR);
      break;
    case NOT:
      emit(ASC_NOT);
      break;
    default:
      printf("asc_logic: unknown operation code\n");
  }
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

  if (display < 0)
    fprintf(asc_file, "\tPUSH %d\n", offset);
  else
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

  if(display < 0)
    fprintf(asc_file, "\tPOP %d\n", offset, display);
  else
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
