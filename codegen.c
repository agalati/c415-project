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
#include <string.h>

#include "pal_gram.tab.h"

#include "codegen.h"

struct function_info_t
{
  char* name;
  int   level, argc, varc;
  int   handled;

  struct function_info_t* next;
};

struct rb_t
{
  char* name;
  struct rb_t* next;
};

struct expr_t* curr_simple_expr = NULL;
int curr_simple_expr_handled = 0;

struct function_info_t* function_list = NULL;

int do_codegen = 1;
int current_parameter_offset = 0;

void stop_codegen(void)
{
  emit_comment("Stopping code generation.");
  do_codegen = 0;
}

void asc_store_simple_expr(struct expr_t* simple_expr)
{
  curr_simple_expr = simple_expr;
  curr_simple_expr_handled = 0;
}

int push_expr(struct expr_t* expr)
{
  if (!do_codegen)
    return 0;

  if (expr == curr_simple_expr)
    curr_simple_expr_handled = 1;

  if (expr->location)
  {
    emit_push(expr->location->display, expr->location->offset);
    return 1;
  }
  else if (expr->is_const)
  {
    switch(expr->type->desc.type_attr.type_class)
    {
      case TC_INTEGER:
        emit_consti(expr->value.integer);
        break;
      case TC_REAL:
        emit_constr(expr->value.real);
        break;
      case TC_CHAR:
        emit_consti((int)expr->value.character);
        break;
      case TC_BOOLEAN:
        emit_consti(expr->value.boolean);
        break;
      default:
        printf("push_expr: Trying to push something weird onto the stack\n");
    }
    return 1;
  }

  return 0;
}

void push_expr_address(struct expr_t* expr)
{
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

void write_function_info()
{
  if (!do_codegen || !function_list)
    return;

  if (function_list->level != get_current_level())
    return;

  fprintf(asc_file, "\n%s\n", function_list->name);
  emit_adjust(function_list->argc);
  emit_adjust(function_list->varc);
  function_list->handled = 1;
}

void asc_start(char* program_name)
{
  if (!do_codegen)
    return;

  emit_goto(program_name);
}

void asc_stop()
{
  if (!do_codegen)
    return;

  emit_dump();
  emit(ASC_STOP);

  int num_builtin_files = 9;
  char* builtin_filenames[] = {
    "asc/math_functions.asc",
    "asc/odd.asc",
    "asc/read_functions.asc",
    "asc/scalar_operations.asc",
    "asc/string_compare.asc",
    "asc/string_copy.asc",
    "asc/transfer_functions.asc",
    "asc/trig_functions.asc",
    "asc/write_procedures.asc"
  };



  char buf[1024];
  memset(buf, 0, 1024*sizeof(char));
  FILE* builtin_file;
  int i, j;
  fprintf(asc_file, "\n");
  for (i=0; i<num_builtin_files; ++i)
  {
    fprintf(asc_file, "\n");

    builtin_file = fopen(builtin_filenames[i], "r");
    if (!builtin_file)
    {
      fprintf(stderr, "Cannot find builtin function file %s\n", builtin_filenames[i]);
      exit(-2);
    }

    j = fread(buf, sizeof(char), 1024, builtin_file);
    while(j)
    {
      fwrite(buf, sizeof(char), j, asc_file);
      memset(buf, 0, 1024*sizeof(char));
      j = fread(buf, sizeof(char), 1024, builtin_file);
    }
  }

  /*
  char* builtin = NULL;
  char* filename;
  char buf[1024];
  while((builtin = required_builtins(NULL)) != NULL)
  {
    filename = (char*)malloc((1+4+4+strlen(builtin))*sizeof(char));
    strcpy(filename, "asc/");
    strcat(filename, builtin);
    strcat(filename, ".asc")
    FILE* builtin_file = fopen(filename, "r");
    if (!builtin_file)
    {
      fprintf(stderr, "Cannot find builtin function file %s\n", filename);
      exit(-2);
    }

    while(fread(buf, sizeof(char), 1024, builtin_file))
      fwrite(buf, sizeof(char), 1024, asc_file);

    free(filename);
    fprintf(asc_file, "requires %s\n", builtin);
  }
  */
}

void asc_notify_last_token(int token)
{
  if (!do_codegen)
    return;

  switch(token)
  {
    case DO:
      if (!curr_simple_expr_handled)
        push_expr(curr_simple_expr);
      asc_while(ASC_WHILE_DO);
      break;
    case P_BEGIN:
      if (function_list && function_list->level == get_current_level() && !function_list->handled)
        write_function_info();
      break;
  }
}

void asc_increment_var_count()
{
  if (!do_codegen)
    return;

  function_list->varc++;
}

void asc_function_definition(int section, char* name, struct sym_rec* parm_list)
{
  if (!do_codegen)
    return;

  static int argc = -1;

  switch(section)
  {
    case ASC_FUNCTION_BEGIN:
    {
      int i=0;
      for(; parm_list; parm_list=parm_list->next, ++i);
      argc = i;

      struct function_info_t* info = (struct function_info_t*)malloc(sizeof(struct function_info_t));
      info->name = name;
      info->level = get_current_level();
      info->argc = argc;
      info->varc = 0;
      info->handled = 0;
      info->next = function_list;

      function_list = info;
      argc = -999;
      current_parameter_offset = 0;
      break;
    }
    case ASC_FUNCTION_END:
    {
      struct function_info_t* curr_function = function_list;
      function_list = function_list->next;

      emit_adjust(-(curr_function->argc));
      emit_adjust(-(curr_function->varc));
      emit_ret(get_current_level()+1);
      fprintf(asc_file, "\n");

      free(curr_function);
      break;
    }
  }
}

void asc_next_parameter_location(struct location_t* location)
{
  location->display = get_current_level()+1;
  location->offset = current_parameter_offset++;
}

void asc_function_call (int section, void* info, int convert_int_to_real)
{
  if (!do_codegen)
    return;

  static struct func_call_info_t* call_info = NULL; 

  switch(section)
  {
    case ASC_FUNCTION_CALL_BEGIN:
    {
      struct sym_rec* func = (struct sym_rec*)info;

      struct func_call_info_t* info = (struct func_call_info_t*)malloc(sizeof(struct func_call_info_t));
      info->func = func;
      info->next = call_info;
      info->argc = 0;
      info->builtin = 0;
      call_info = info;

      // different calling convention for builtins
      if (func == builtinlookup(func->name))
      {
        call_info->builtin = 1;
        required_builtins(func->name);
        break;
      }

      // make room for return value
      if (func->class == OC_FUNC)
        emit_adjust(1);

      // make room for the stuff call puts on the stack
      emit_adjust(2);

      break;
    }
    case ASC_FUNCTION_CALL_ARG:
    {
      if (call_info->builtin)
      {
        builtin_function_call(call_info, ASC_FUNCTION_CALL_ARG, info, convert_int_to_real);
        break;
      }

      struct expr_t* arg = (struct expr_t*)info;
      if(!push_expr(arg));
      {
        emit_call(0, "get_sp");
        emit_consti(2);
        emit(ASC_ADDI);
        emit_call(0, "swap_top");
        emit_popi(-1);
      }
      if (convert_int_to_real)
        emit(ASC_ITOR);
      call_info->argc++;
      break;
    }
    case ASC_FUNCTION_CALL_END:
    {
      // different calling convention for builtins
      if (call_info->builtin)
        builtin_function_call(call_info, ASC_FUNCTION_CALL_END, info, convert_int_to_real);
      else
      {
        // adjust back through all the args
        emit_adjust(-(call_info->argc));

        // adjust back through the stuff call puts on the stack
        emit_adjust(-2);

        emit_call(call_info->func->level+1, call_info->func->name);
      }

      struct func_call_info_t* curr = call_info;
      call_info = call_info->next;
      free(curr);
      break;
    }
    default:
      printf("asc_function_call: unknown section\n");
    }
}

void builtin_function_call(struct func_call_info_t* call_info, int section, void* info, int convert_int_to_real)
{
  if (!do_codegen)
    return;

  switch(section)
  {
    case ASC_FUNCTION_CALL_BEGIN:
      break;
    case ASC_FUNCTION_CALL_ARG:
    {
      struct expr_t* arg = (struct expr_t*)info;
      push_expr(arg);
      if (convert_int_to_real)
        emit(ASC_ITOR);
      call_info->argc++;
      break;
    }
    case ASC_FUNCTION_CALL_END:
    {
      emit_call(call_info->func->level+1, call_info->func->name);

      // adjust back through all the args less one which is the return
      if (call_info->argc)
        emit_adjust(-(call_info->argc -1));

      break;
    }
    default:
      printf("builtin_function_call: unknown section\n");
  }
}

char* required_builtins(char* name)
{
  static struct rb_t* rb_list = NULL;

  struct rb_t* rb;
  if (name)
  {
    rb = (struct rb_t*)malloc(sizeof(struct rb_t));
    rb->name = name;
    rb->next = rb_list;
    rb_list = rb;
  }
  else
  {
    rb = rb_list;
    if (!rb)
      return NULL;

    rb_list = rb_list->next;
    char* ret = rb->name;
    free(rb);
    return ret; 
  }
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


void asc_if(int section)
{
  if (!do_codegen)
    return;

  static char* label = NULL;
  static char* endlabel = NULL;
}

void asc_push_var(struct sym_rec* var)
{
  if (!do_codegen || !var)
    return;

  emit_push(var->desc.var_attr.location.display, var->desc.var_attr.location.offset);
}

void asc_assignment(struct sym_rec* var, struct expr_t* expr)
{
  if (!do_codegen)
    return;

  int expr_tc = expr->type->desc.type_attr.type_class;

  push_expr(expr);

  int tc1 = var->desc.var_attr.type->desc.type_attr.type_class,
      tc2 = expr->type->desc.type_attr.type_class;

  int convert_to_real = 0;

  if (tc1 == TC_REAL && tc2 == TC_INTEGER)
    convert_to_real = 1;

  if (convert_to_real)
    emit(ASC_ITOR);

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
  push_expr(operand1);
  if (convert_to_real[0])
    emit(ASC_ITOR);
  push_expr(operand2);
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
  push_expr(operand1);
  push_expr(operand2);

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

  push_expr(operand1);
  if (convert_to_real[0])
    emit(ASC_ITOR);

  push_expr(operand2);
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
  push_expr(operand1);
  if (operand2)
    push_expr(operand2);

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
