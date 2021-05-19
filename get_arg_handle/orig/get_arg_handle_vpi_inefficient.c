/**********************************************************************
 * PLIbook_get_arg_handle_vpi Example -- PLI application using VPI
 * routines
 *
 * C source for function to access handles of system task/function
 * arguments.
 *
 * NOTE: THIS ROUTINE IS PROVIDED AS A SHORT EXAMPLE ON HOW TO ACCESS
 * TASK/FUNCTION ARGUMENTS, AND HOW TO PERFORM ERROR CHECKING ON IF
 * THE DESIRED INFORMATION WAS OBTAINED.  THE EXAMPLE IS NOT
 * INTENDED TO BE A COMPLETE PLI APPLICATION IN AND OF ITSELF, AND
 * IS NOT EFFICIENT FOR SIMULATION PERFORMACE.
 *
 * Usage:
 *   arg_handle = PLIbook_get_arg_handle_vpi(arg_index_number);
 *     Returns a handke for a system task/function argument,
 *     using the index number of the argument, beginning with 1.
 *********************************************************************/

#define PLIbookDebug 1 /* set to non-zero for verbose debug messages */

#include <stdlib.h>    /* ANSI C standard library */
#include <stdio.h>     /* ANSI C standard input/output library */
#include <stdarg.h>    /* ANSI C standard arguments library */
#include "vpi_user.h"  /* IEEE 1364 PLI VPI routine library  */

/* Prototypes of the applications */
vpiHandle  PLIbook_get_arg_handle_vpi(int argNum);

/**********************************************************************
 * PLIbook_get_arg_handle_vpi()
 * Obtain a handle to a system task/function argument, using the
 * argument index number.  Similar to acc_handle_tfarg().
 *
 * ARGUMENTS ARE NUMBERED FROM LEFT TO RIGHT, BEGINNING WITH 1.
 *
 * The method used in this version is not as efficient as it could be,
 * because this example must call vpi_iterate() and vpi_scan() each
 * time this application is called.
 *********************************************************************/
vpiHandle PLIbook_get_arg_handle_vpi(int argNum)
{
  vpiHandle systf_h, arg_itr, arg_h;
  int i;
  #if PLIbookDebug
    s_vpi_error_info err;  /* structure for error handling */
  #endif

  if (argNum < 1) {
    #if PLIbookDebug  /* if error, generate verbose debug message */
      vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() arg index of %d is invalid\n",
                  argNum);
    #endif
    return(NULL);
  }

  systf_h = vpi_handle(vpiSysTfCall, NULL);
  #if PLIbookDebug  /* if error, generate verbose debug message */
    if (vpi_chk_error(&err)) {
      vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() could not obtain handle to systf call\n");
      vpi_printf("File %s, Line %d: %s\n",
                  err.file, err.line, err.message);
    }
  #else  /* if error, generate brief error message */
    if (systf_h == NULL) {
      vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() could not obtain handle to systf call\n");
      return(NULL);
    }
  #endif

  arg_itr = vpi_iterate(vpiArgument, systf_h);
  #if PLIbookDebug  /* if error, generate verbose debug message */
    if (vpi_chk_error(&err)) {
      vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() could not obtain iterator to systf args\n");
      vpi_printf("File %s, Line %d: %s\n",
                  err.file, err.line, err.message);
    }
  #else  /* if error, generate brief error message */
    if (systf_h == NULL) {
      vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() could not obtain iterator to systf args\n");
      return(NULL);
    }
  #endif

  for (i=1; i<=argNum; i++) {
    arg_h = vpi_scan(arg_itr);
    #if PLIbookDebug  /* if error, generate verbose debug message */
      if (vpi_chk_error(&err)) {
        vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() could not obtain handle to systf arg %d\n", i);
        vpi_printf("File %s, Line %d: %s\n",
                    err.file, err.line, err.message);
      }
    #endif
    if (arg_h == NULL) {
      #if PLIbookDebug  /* if error, generate verbose debug message */
        vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() arg index of %d is out-of-range\n",
                    argNum);
      #endif
      return(NULL);
    }
  }
  if (arg_h != NULL)
    vpi_free_object(arg_itr); /* free iterator--didn't scan all args */

  return(arg_h);
}
/*********************************************************************/
