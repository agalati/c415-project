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

  /* This is what you'll adjust by */
  int   size;
  
  struct function_info_t* next;
};

struct rb_t
{
  char* name;
  struct rb_t* next;
};

struct label_t
{
  char *label, *endlabel;
  struct label_t* next;
};

struct expr_t* curr_simple_expr = NULL;
int curr_simple_expr_handled = 0;

struct function_info_t* function_list = NULL;

int do_codegen = 1;
int bounds_checking = 1;
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

// pushes tring to stack and puts the address of the start of the string on top
int push_const_string_to_stack(struct expr_t* expr)
{
  if (!do_codegen)
    return;

  if (!expr->is_const)
  {
    printf("push_const_string_to_stack: Trying to push a non-const string to the stack\n");
    return;
  }

  if (expr->type->desc.type_attr.type_class != TC_STRING)
  {
    printf("push_const_string_to_stack: Trying to push a string when the expression is not actually a string\n");
    return;
  }

  int size = expr->type->desc.type_attr.type_description.string->high;
  int i;
  for (i=0; i<size; ++i)
    emit_consti((int)expr->value.string[i]);

  emit_adjust(1); // make room for stack pointer
  emit_call(0, "get_sp");
  emit_consti(-size);
  emit(ASC_ADDI);
  
  return size;
}

int push_expr(struct expr_t* expr)
{
  if (!do_codegen)
    return 0;

  if (expr == curr_simple_expr)
    curr_simple_expr_handled = 1;

  if (expr->location)
  {
    if (expr->type->desc.type_attr.type_class == TC_STRING)
    {
      emit_pusha(expr->location->display, expr->location->offset);
      emit_comment("push_expr");
    }
    else
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

  int i;              /* argc */
  for(i=function_list->size; i>0; --i)
    emit_push(function_list->level, -(i+2));

  //emit_adjust(function_list->argc);
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

  int num_builtin_files = 11;
  char* builtin_filenames[] = {
    "asc/get_sp.asc",
    "asc/swap_top.asc",
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
    case ELSE:
      asc_if(ASC_IF_ELSE);
      break;
    case P_BEGIN:
      if (function_list && function_list->level == get_current_level() && !function_list->handled)
        write_function_info();
      break;
    case THEN:
      if (!curr_simple_expr_handled)
        push_expr(curr_simple_expr);
      asc_if(ASC_IF_BEGIN);
  }
}

void asc_increment_var_count(int size)
{
  if (!do_codegen)
    return;

  function_list->varc = function_list->varc + size;
}

void asc_function_definition(int section, char* name, struct sym_rec* parm_list)
{
  if (!do_codegen)
    return;

  static int argc = -999;

  static int size = 0;
  
  switch(section)
  {
    case ASC_FUNCTION_BEGIN:
    {
      int i=0;
      ///////
      for(; parm_list; parm_list=parm_list->next, ++i)
      {
        if (parm_list->class = OC_VAR && parm_list->desc.var_attr.type->desc.type_attr.type_class == TC_STRING)
          size += parm_list->desc.var_attr.type->desc.type_attr.type_description.string->high;
        else
          size += 1;
      }
      ///////
      argc = i;
      
      struct function_info_t* info = (struct function_info_t*)malloc(sizeof(struct function_info_t));
      info->name = name;
      info->level = get_current_level();
      info->argc = argc;
      info->varc = 0;
      info->handled = 0;
      info->next = function_list;

      info->size = size;
      size = 0;
      
      function_list = info;
      argc = -999;
      current_parameter_offset = 0;
      break;
    }
    case ASC_FUNCTION_END:
    {
      struct function_info_t* curr_function = function_list;
      function_list = function_list->next;

      emit_adjust(-(curr_function->size));
      emit_adjust(-(curr_function->varc));
      emit_ret(get_current_level()+1);
      fprintf(asc_file, "\n");

      free(curr_function);
      break;
    }
  }
}

void asc_next_parameter_location(struct location_t* location, int size)
{
  location->display = get_current_level()+1;
  location->offset = current_parameter_offset;
  current_parameter_offset += size;
}

int asc_get_return_offset()
{
  if (current_parameter_offset)
    return -current_parameter_offset - 2; 
  else
    return -3;
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

      break;
    }
    case ASC_FUNCTION_CALL_ARG:
    {
      struct expr_t* arg = (struct expr_t*)info;
      int expr_tc = arg->type->desc.type_attr.type_class;
      if (expr_tc == TC_STRING)
      {
        handle_string_arg(arg);
        call_info->argc += arg->type->desc.type_attr.type_description.string->high;
      }
      else
      {
        push_expr(arg);
        if (convert_int_to_real)
          emit(ASC_ITOR);
        call_info->argc++;
      }
      break;
    }
    case ASC_FUNCTION_CALL_END:
    {
      // make room for return value if room has not been made by args
      if (call_info->argc == 0 && call_info->func->class == OC_FUNC)
        emit_adjust(1);

      emit_call(call_info->func->level+1, call_info->func->name);

      if (call_info->argc)
      {
        if (call_info->func->class == OC_FUNC)
          emit_adjust(-(call_info->argc-1));
        else
          emit_adjust(-(call_info->argc));
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

void handle_string_arg(struct expr_t* arg)
{
  int len = arg->type->desc.type_attr.type_description.string->high;
  int i;
  for (i = 0; i < len; ++i)
  {
    if (arg->is_const)
      emit_consti(arg->value.string[i]);
    else
      emit_push(arg->location->display, arg->location->offset+i);
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

  static struct label_t* label_stack = NULL;
  switch(section)
  {
    case ASC_WHILE_BEGIN:
    {
      struct label_t* labels = (struct label_t*)malloc(sizeof(struct label_t));
      labels->next = label_stack;
      label_stack = labels;
      labels->label = get_next_while_label();
      labels->endlabel = (char*)malloc(16*sizeof(char));
      sprintf(labels->endlabel, "end_%s", labels->label);
      fprintf(asc_file, "\n%s\n", labels->label);
      break;
    }
    case ASC_WHILE_DO:
      emit_ifz(label_stack->endlabel);
      break;
    case ASC_WHILE_END:
    {
      emit_goto(label_stack->label);
      fprintf(asc_file, "%s\n\n", label_stack->endlabel);
      free(label_stack->label);
      free(label_stack->endlabel);
      struct label_t* curr_label = label_stack;
      label_stack = label_stack->next;
      free(curr_label);
      break;
    }
    case ASC_WHILE_CONTINUE:
      emit_goto(label_stack->label);
      break;
    case ASC_WHILE_EXIT:
      emit_goto(label_stack->endlabel);
      break;
    default:
      printf("asc_while: invalid section\n");
  }
}


void asc_if(int section)
{
  if (!do_codegen)
    return;

  static struct label_t* label_stack = NULL;

  switch(section)
  {
    case ASC_IF_BEGIN:
    {
      struct label_t* labels = (struct label_t*)malloc(sizeof(struct label_t));
      labels->next = label_stack;
      label_stack = labels;
      labels->label = get_next_if_label();
      labels->endlabel = (char*)malloc(16*sizeof(char));
      sprintf(labels->endlabel, "end_%s", labels->label);
      emit_ifz(labels->label);
      break;
    }
    case ASC_IF_ELSE:
    {
      emit_goto(label_stack->endlabel);
      fprintf(asc_file, "\n%s\n", label_stack->label);
      break;
    }
    case ASC_IF_END:
    {
      fprintf(asc_file, "%s\n\n", label_stack->endlabel);
      free(label_stack->label);
      free(label_stack->endlabel);
      struct label_t* curr_label = label_stack;
      label_stack = label_stack->next;
      free(curr_label);
      break;
    }
    case ASC_IF_END_NO_ELSE:
    {
      fprintf(asc_file, "\n%s\n", label_stack->label);
      free(label_stack->label);
      free(label_stack->endlabel);
      struct label_t* curr_label = label_stack;
      label_stack = label_stack->next;
      free(curr_label);
      break;
    }
    default:
      printf("asc_if: invalid section\n");
  }
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

  int tc1 = var->desc.var_attr.type->desc.type_attr.type_class,
      tc2 = expr->type->desc.type_attr.type_class;

  if (tc1 == TC_STRING)
    assign_strings(var, expr);
  else
  {
    // else
    push_expr(expr);

    int convert_to_real = 0;

    if (tc1 == TC_REAL && tc2 == TC_INTEGER)
      convert_to_real = 1;

    if (convert_to_real)
      emit(ASC_ITOR);

    emit_pop(var->desc.var_attr.location.display, var->desc.var_attr.location.offset);
  }
}

void assign_strings(struct sym_rec* var, struct expr_t* expr)
{
  int len = expr->type->desc.type_attr.type_description.string->high;
  if (expr->is_const)
  {
    int i;
    for (i = 0; i < len; ++i)
    {
      emit_consti((int)expr->value.string[i]);
      emit_pop(var->desc.var_attr.location.display, var->desc.var_attr.location.offset+i);
    }
  }
  else if (expr->location)
  {
    emit_pusha(var->desc.var_attr.location.display, var->desc.var_attr.location.offset);
    emit_pusha(expr->location->display, expr->location->offset);
    emit_consti(len);
    emit_call(0, BUILTIN_STR_COPY);
    emit_adjust(-3);
  }
  else
    printf("assign_strings: String doesn't have a location and isn't constant...\n");
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

  if (tc1 == TC_STRING)
    string_comparison(op, operand1, operand2);
  else
    number_comparison(op, operand1, operand2);
}

void string_comparison(int op, struct expr_t* operand1, struct expr_t* operand2)
{
  if (operand1 == curr_simple_expr || operand2 == curr_simple_expr)
    curr_simple_expr_handled = 1;

  int excess = 0; // crap on the stack that we push in case of constant strings and addresses
  if (operand1->is_const)
    excess += push_const_string_to_stack(operand1);
  else if (operand1->location)
    emit_pusha(operand1->location->display, operand1->location->offset);

  if (operand2->is_const)
  {
    excess += push_const_string_to_stack(operand2);
    emit_adjust(1); // make room for stack pointer
    emit_call(0, "get_sp");
    emit_consti(-(operand2->type->desc.type_attr.type_description.string->high+2));
    emit(ASC_ADDI);
    emit_pushi(-1);
    emit_call(0, "swap_top");
    excess += 1;
  }
  else if (operand2->location)
    emit_pusha(operand2->location->display, operand2->location->offset);

  emit_consti(operand1->type->desc.type_attr.type_description.string->high);
  switch(op)
  {
    case EQUALS:
      emit_call(0, BUILTIN_STR_EQ);
      emit_adjust(-2);
      break;
    case NOT_EQUAL:
      emit_call(0, BUILTIN_STR_NEQ);
      emit_adjust(-2);
      break;
    case LESS_THAN:
      emit_call(0, BUILTIN_STR_LT);
      emit_adjust(-2);
      break;
    case GREATER_THAN:
      emit_call(0, BUILTIN_STR_GT);
      emit_adjust(-2);
      break;
    case LESS_EQUAL:
      emit_call(0, BUILTIN_STR_LE);
      emit_adjust(-2);
      break;
    case GREATER_EQUAL:
      emit_call(0, BUILTIN_STR_GE);
      emit_adjust(-2);
      break;
    default:
      printf("string_comparison: Unknown comparison code\n");
  }
  emit_adjust(1); // make room for stack pointer
  emit_call(0, "get_sp");
  emit_consti(-(excess+1));
  emit(ASC_ADDI);
  emit_call(0, "swap_top");
  emit_popi(-1);
  emit_adjust(-(excess-1));
}

void number_comparison(int op, struct expr_t* operand1, struct expr_t* operand2)
{
  int tc1 = operand1->type->desc.type_attr.type_class,
      tc2 = operand2->type->desc.type_attr.type_class;

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

  int real_comparisons = 0;

  if (tc1 == TC_REAL || tc2 == TC_REAL)
    real_comparisons = 1;

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
      printf("number_comparison: Unknown comparison code\n");
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
    fprintf(asc_file, "\tPUSHI\n");
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
    fprintf(asc_file, "\tPOP %d\n", offset);
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

void stop_boundscheck(void)
{
  emit_comment("No run-time bounds checking.");
  bounds_checking = 0;
}

/* emit before any call to dereference an array */
void emit_boundscheck(int index, int lowbound, int highbound)
{
	if (!do_codegen)
		return;
	if (!bounds_checking)
		return;
		
	/* check low bound */
	fprintf(asc_file, "lowbound_check\n");
	fprintf(asc_file, "\tCONSTI %d\n", index);
	fprintf(asc_file, "\tCONSTI %d\n", lowbound);
	fprintf(asc_file, "\tGTI\n");
	fprintf(asc_file, "\tIFZ out_of_bounds\n");
	fprintf(asc_file, "\tGOTO highbound_check\n");
	
	/* is out of bound, sandwich between checks */
	fprintf(asc_file, "out_of_bounds\n");
	fprintf(asc_file, "\tSTOP\n");	/* some kind of error message? */
	
	/*check high bound */
	fprintf(asc_file, "highbound_check\n");
	fprintf(asc_file, "\tCONSTI %d\n", index);
	fprintf(asc_file, "\tCONSTI %d\n", highbound);
	fprintf(asc_file, "\tLTI\n");
	fprintf(asc_file, "\tIFZ out_of_bounds\n");
}
