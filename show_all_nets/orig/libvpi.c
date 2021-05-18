// The Verilog PLI Handbook - Section 3.12

// $show_all_nets
// C source to scan through a module and list the names of all nets in
// the module with the current logic value.
//
// Usage: $show_all_nets(<module_instance>);

#include <stdlib.h>    /* ANSI C standard library */
#include <stdio.h>     /* ANSI C standard input/output library */
#include <stdarg.h>    /* ANSI C standard arguments library */
#include "vpi_user.h"  /* IEEE 1364 PLI VPI routine library  */

/* prototypes of the PLI application routines */
PLI_INT32 PLIbook_ShowNets_compiletf(PLI_BYTE8 *user_data),
          PLIbook_ShowNets_calltf(PLI_BYTE8 *user_data);

/**********************************************************************
 * $show_all_nets Registration Data
 *********************************************************************/
void PLIbook_ShowNets_register()
{
  s_vpi_systf_data tf_data;

  tf_data.type        = vpiSysTask;
  tf_data.sysfunctype = 0;
  tf_data.tfname      = "$show_all_nets";
  tf_data.calltf      = PLIbook_ShowNets_calltf;
  tf_data.compiletf   = PLIbook_ShowNets_compiletf;
  tf_data.sizetf      = NULL;
  tf_data.user_data   = NULL;
  vpi_register_systf(&tf_data);
  return;
}

/**********************************************************************
 * compiletf routine
 *********************************************************************/
PLI_INT32 PLIbook_ShowNets_compiletf(PLI_BYTE8 *user_data)
{
  vpiHandle systf_handle, arg_iterator, arg_handle;
  PLI_INT32 tfarg_type;
  int       err_flag = 0;

  /* obtain a handle to the system task instance */
  systf_handle = vpi_handle(vpiSysTfCall, NULL);

  /* obtain handles to system task arguments */
  arg_iterator = vpi_iterate(vpiArgument, systf_handle);
  if (arg_iterator == NULL) {
    vpi_printf("ERROR: $show_all_nets requires 1 argument\n");
    err_flag = 1;
  }
  else {
  /* check the type of object in system task arguments */
  arg_handle = vpi_scan(arg_iterator);
  tfarg_type = vpi_get(vpiType, arg_handle);
  if (tfarg_type != vpiModule) {
    vpi_printf("ERROR: $show_all_nets arg must be module instance\n");
    vpi_free_object(arg_iterator); /* free iterator memory */
    err_flag = 1;
  }
  else {
  /* check that there is only 1 system task argument */
  arg_handle = vpi_scan(arg_iterator);
  if (arg_handle != NULL) {
    vpi_printf("ERROR: $show_all_nets can only have 1 argument\n");
    vpi_free_object(arg_iterator); /* free iterator memory */
    err_flag = 1;
  } } } /* end of if-else-if-else-if sequence */
  if (err_flag) {
    vpi_control(vpiFinish, 1);  /* abort simulation */
  }
  return(0);
}

/**********************************************************************
 * calltf routine
 *********************************************************************/
PLI_INT32 PLIbook_ShowNets_calltf(PLI_BYTE8 *user_data)
{

  vpiHandle   systf_handle, arg_iterator, module_handle,
              net_iterator, net_handle;
  s_vpi_time  current_time;
  s_vpi_value current_value;

  /* obtain a handle to the system task instance */
  systf_handle = vpi_handle(vpiSysTfCall, NULL);

  /* obtain handle to system task argument */
  /* compiletf has already verified only 1 arg with correct type */
  arg_iterator = vpi_iterate(vpiArgument, systf_handle);
  module_handle = vpi_scan(arg_iterator);
  vpi_free_object(arg_iterator);  /* free iterator memory */

  /* read current simulation time */
  current_time.type = vpiScaledRealTime;
  vpi_get_time(systf_handle, &current_time);

  vpi_printf("\nAt time %2.2f, ", current_time.real);
  vpi_printf("nets in module %s ",
              vpi_get_str(vpiFullName, module_handle));
  vpi_printf("(%s):\n", vpi_get_str(vpiDefName,  module_handle));

  /* obtain handles to nets in module and read current value */
  net_iterator = vpi_iterate(vpiNet, module_handle);
  if (net_iterator == NULL)
    vpi_printf("  no nets found in this module\n");
  else {
    current_value.format = vpiBinStrVal; /* read values as a string */
    while ( (net_handle = vpi_scan(net_iterator)) != NULL ) {
      vpi_get_value(net_handle, &current_value);
      vpi_printf("  net %-10s  value is  %s (binary)\n",
                 vpi_get_str(vpiName, net_handle),
                 current_value.value.str);
    }
  }
  return(0);
}
/*********************************************************************/

void (*vlog_startup_routines[ ] ) () = {
    PLIbook_ShowNets_register,
    0  // last entry must be 0
};
