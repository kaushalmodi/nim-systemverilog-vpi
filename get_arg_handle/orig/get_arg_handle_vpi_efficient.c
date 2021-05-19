/**********************************************************************
 * PLIbook_count_args_vpi and PLIbook_get_arg_handle_vpi Examples
 * PLI application using VPI routines
 *
 * C source for functions to access handles of system task/function
 * arguments.
 *
 * Usage:
 *   numargs = PLIbook_count_args_vpi(<any_number_and_type_of_args>);
 *     Returns the number of system task/function arguments.
 *
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
int        PLIbook_count_args_vpi();
vpiHandle  PLIbook_get_arg_handle_vpi(int argNum);
vpiHandle *create_arg_array(vpiHandle systf_h);

/**********************************************************************
 * PLIbook_count_args_vpi() -- Efficient Version
 * Counts the number of system task/function arguments.  Similar to
 * tf_nump().
 *********************************************************************/
int PLIbook_count_args_vpi()
{
  vpiHandle systf_h, arg_itr, arg_h;
  int tfnum = 0;
  vpiHandle *arg_array;    /* array pointer to store arg handles */
  #if PLIbookDebug
    s_vpi_error_info err;  /* structure for error handling */
  #endif

  systf_h = vpi_handle(vpiSysTfCall, NULL);
  #if PLIbookDebug /* if error, generate verbose debug message */
    if (vpi_chk_error(&err)) {
      vpi_printf("ERROR: PLIbook_count_args_vpi() could not obtain handle to systf call\n");
      vpi_printf("File %s, Line %d: %s\n",
                  err.file, err.line, err.message);
    }
  #else  /* if error, generate brief error message */
    if (systf_h == NULL)
      vpi_printf("ERROR: PLIbook_count_args_vpi() could not obtain handle to systf call\n");
  #endif

  /* retrieve pointer to array with all argument handles */
  arg_array = (vpiHandle *)vpi_get_userdata(systf_h);
  if (arg_array == NULL) {
    /* array with all argument handles doesn't exist, create it */
    arg_array = create_arg_array(systf_h);
  }

  return((int)arg_array[0]);
}

/**********************************************************************
 * PLIbook_get_arg_handle_vpi() -- Efficient Version
 * Obtain a handle to a system task/function argument, using the
 * argument index number.  Similar to acc_handle_tfarg().
 *
 * ARGUMENTS ARE NUMBERED FROM LEFT TO RIGHT, BEGINNING WITH 1.
 *
 * This version is more efficient because it allocates memory and
 * stores the task arg handles so that vpi_iterate() and vpi_scan()
 * do not need to be called each time this application is called.
 *********************************************************************/
vpiHandle PLIbook_get_arg_handle_vpi(int argNum)
{
  vpiHandle  systf_h, arg_h;
  vpiHandle *arg_array;    /* array pointer to store arg handles */
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
  #if PLIbookDebug /* if error, generate verbose debug message */
    if (vpi_chk_error(&err)) {
      vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() could not obtain handle to systf call\n");
      vpi_printf("File %s, Line %d: %s\n",
                  err.file, err.line, err.message);
    }
  #else /* if error, generate brief error message */
    if (systf_h == NULL) {
      vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() could not obtain handle to systf call\n");
      return(NULL);
    }
  #endif

  /* retrieve pointer to array with all argument handles */
  arg_array = (vpiHandle *)vpi_get_userdata(systf_h);
  if (arg_array == NULL) {
    /* array with all argument handles doesn't exist, create it */
    arg_array = create_arg_array(systf_h);
  }

  if (argNum > (int)arg_array[0]) {
    #if PLIbookDebug  /* if error, generate verbose debug message */
      vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() arg index of %d is out-of-range\n",
                  argNum);
    #endif
    return(NULL);
  }

  /* get requested tfarg handle from array */
  arg_h = (vpiHandle)arg_array[argNum];
  return(arg_h);
}

/**********************************************************************
 * Subroutine to allocate an array and store the number of arguments
 * and all argument handles in the array.
 *********************************************************************/
vpiHandle *create_arg_array(vpiHandle systf_h)
{
  vpiHandle  arg_itr, arg_h;
  vpiHandle *arg_array; /* array pointer to store arg handles */
  int        i, tfnum = 0;
  #if PLIbookDebug
    s_vpi_error_info err;  /* structure for error handling */
  #endif

  /* allocate array based on the number of task/function arguments */
  arg_itr = vpi_iterate(vpiArgument, systf_h);
  if (arg_itr == NULL) {
    vpi_printf("ERROR: PLIbook_numargs_vpi() could not obtain iterator to systf args\n");
    return(NULL);
  }
  while (arg_h = vpi_scan(arg_itr) ) {  /* count number of args */
    tfnum++;
  }
  arg_array = (vpiHandle *)malloc(sizeof(vpiHandle) * (tfnum + 1));

  /* store pointer to array in simulator-allocated user_data storage
     that is unique for each task/func instance */
  vpi_put_userdata(systf_h, (void *)arg_array);

  /* store number of arguments in first address in array */
  arg_array[0] = (vpiHandle)tfnum;

  /* fill the array with handles to each task/function argument */
  arg_itr = vpi_iterate(vpiArgument, systf_h);
  #if PLIbookDebug /* if error, generate verbose debug message */
    if (vpi_chk_error(&err)) {
      vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() could not obtain iterator to systf args\n");
      vpi_printf("File %s, Line %d: %s\n",
                  err.file, err.line, err.message);
    }
  #else /* if error, generate brief error message */
    if (systf_h == NULL) {
      vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() could not obtain iterator to systf args\n");
      return(NULL);
    }
  #endif
  for (i=1; i<=tfnum; i++) {
    arg_h = vpi_scan(arg_itr);
    #if PLIbookDebug /* if error, generate verbose debug message */
      if (vpi_chk_error(&err)) {
        vpi_printf("ERROR: PLIbook_get_arg_handle_vpi() could not obtain handle to systf arg %d\n", i);
        vpi_printf("File %s, Line %d: %s\n",
                    err.file, err.line, err.message);
      }
    #endif
    arg_array[i] = arg_h;
  }
  if (arg_h != NULL)
    vpi_free_object(arg_itr); /* free iterator--didn't scan all args */

  return(arg_array);
}
/*********************************************************************/
