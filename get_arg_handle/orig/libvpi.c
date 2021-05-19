// The Verilog PLI Handbook - Section 4.6.4

/**********************************************************************
 * $get_arg_handle_test example -- PLI application using VPI routines
 *
 * C code to test the VPI "PLIbook_get_arg_handle_vpi() application.
 *
 * Usage: initial
 *          $get_arg_handle_test(arg1, arg2, arg3);
 *
 *   The arguments can be any Verilog data type.
 *********************************************************************/

#include <stdlib.h>    /* ANSI C standard library */
#include <stdio.h>     /* ANSI C standard input/output library */
#include <stdarg.h>    /* ANSI C standard arguments library */
#include "vpi_user.h"  /* IEEE 1364 PLI VPI routine library  */

/* prototypes of the PLI application routines */
PLI_INT32 PLIbook_GetArgTestCall(PLI_BYTE8 *user_data);


/* #include "get_arg_handle_vpi_inefficient.c"   /* include VPI app. */
#include "get_arg_handle_vpi_efficient.c"   /* include VPI app. */


/**********************************************************************
 * VPI Registration Data
 *********************************************************************/
void PLIbook_GetArgTest_register()
{
  s_vpi_systf_data tf_data;
  tf_data.type        = vpiSysTask;
  tf_data.sysfunctype = 0;
  tf_data.tfname      = "$get_arg_handle_test";
  tf_data.calltf      = PLIbook_GetArgTestCall;
  tf_data.compiletf   = NULL;
  tf_data.sizetf      = NULL;
  tf_data.user_data   = NULL;
  vpi_register_systf(&tf_data);
}
/**********************************************************************/

/**********************************************************************
 * calltf routine to exercise various utility functions.
 *********************************************************************/
PLI_INT32 PLIbook_GetArgTestCall(PLI_BYTE8 *user_data)
{
  vpiHandle arg0_h, arg1_h, arg2_h, arg3_h, arg4_h, arg5_h, arg6_h;

  vpi_printf("\nTesting PLIbook_get_arg_handle_vpi() With Good Values...\n\n");

  arg1_h = PLIbook_get_arg_handle_vpi(1);
  vpi_printf("  Handle to arg 1 is %s:  EXPECTED a\n",
             vpi_get_str(vpiName, arg1_h));

  arg3_h = PLIbook_get_arg_handle_vpi(3);
  vpi_printf("  Handle to arg 3 is %s:  EXPECTED sum\n",
             vpi_get_str(vpiName, arg3_h));


  vpi_printf("\nTesting PLIbook_get_arg_handle_vpi_vpi() with invalid index numbers...\n\n");
  arg0_h = PLIbook_get_arg_handle_vpi(0);
  vpi_printf("  Handle to arg 0 is %d:  EXPECTED 0 (NULL)\n",
             arg0_h);

  arg6_h = PLIbook_get_arg_handle_vpi(6);
  vpi_printf("  Handle to arg 6 is %d:  EXPECTED 0 (NULL)\n",
             arg6_h);

  vpi_printf("\n*** All Tests Completed ***\n\n");
  return(0);
}
/*********************************************************************/


void (*vlog_startup_routines[ ] ) () = {
    PLIbook_GetArgTest_register,
    0  // last entry must be 0
};
