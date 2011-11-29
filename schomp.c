#include "pal.h"

int schomp(char *s)
{
  char *scan = s + 1;
  char *entry = s;
  
  int end = 1;
  int error = 0;
  
  while (*scan) {
    if (*scan == '\\') {
      scan++;
      switch (*scan) {
      case 'n' :
        *entry = '\n';
        break;
      case 't' :
        *entry = '\t';
        break;
      case '\'' :
        *entry = '\'';
        break;
      case '\\' :
        *entry = '\\';
        break;
      default :
        error = 1;;
      }
      scan++;
      entry++;
    } else {
      if (*scan == '\'')
        end = 0;
      else
        end = 1;
      
      *entry = *scan;
      
      scan++;
      entry++;
    }
  }
  /* Remove last '\'' */
  *(entry - 1) = '\0';
  if (error == 1)
    return error;
  return end;
}
