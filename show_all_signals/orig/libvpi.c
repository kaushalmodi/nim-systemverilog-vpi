// The Verilog PLI Handbook - Section 3.13.1

/**********************************************************************
 * $show_all_signals example 1 -- PLI application using VPI routines
 *
 * C source to scan through a module and list the names of all nets,
 * reg and variables in the module, with their current logic value.
 *
 * Usage: $show_all_signals(<module_instance>);
 *********************************************************************/

#include <stdlib.h>    /* ANSI C standard library */
#include <stdio.h>     /* ANSI C standard input/output library */
#include <stdarg.h>    /* ANSI C standard arguments library */
#include "vpi_user.h"  /* IEEE 1364 PLI VPI routine library  */

/* prototypes of the PLI application routines */
PLI_INT32 PLIbook_ShowSignals_compiletf(PLI_BYTE8 *user_data),
    PLIbook_ShowSignals_calltf(PLI_BYTE8 *user_data);
void PLIbook_PrintSignalValues(vpiHandle signal_iterator);

/**********************************************************************
 * $show_all_signals Registration Data
 *********************************************************************/
void PLIbook_ShowSignals_register()
{
    s_vpi_systf_data tf_data;

    tf_data.type        = vpiSysTask;
    tf_data.sysfunctype = 0;
    tf_data.tfname      = "$show_all_signals";
    tf_data.calltf      = PLIbook_ShowSignals_calltf;
    tf_data.compiletf   = PLIbook_ShowSignals_compiletf;
    tf_data.sizetf      = NULL;
    tf_data.user_data   = NULL;
    vpi_register_systf(&tf_data);
    return;
}

/**********************************************************************
 * compiletf routine
 *********************************************************************/
PLI_INT32 PLIbook_ShowSignals_compiletf(PLI_BYTE8 *user_data)
{
    vpiHandle systf_handle, arg_iterator, arg_handle;
    PLI_INT32 tfarg_type;
    int       err_flag = 0;

    /* obtain a handle to the system task instance */
    systf_handle = vpi_handle(vpiSysTfCall, NULL);

    /* obtain handles to system task arguments */
    arg_iterator = vpi_iterate(vpiArgument, systf_handle);
    if (arg_iterator == NULL) {
        vpi_printf("ERROR: $show_all_signals requires 1 argument\n");
        err_flag = 1;
    }
    else {
        /* check the type of object in system task arguments */
        arg_handle = vpi_scan(arg_iterator);
        tfarg_type = vpi_get(vpiType, arg_handle);
        if (tfarg_type != vpiModule) {
            vpi_printf("ERROR: $show_all_signals arg 1");
            vpi_printf(" must be a module instance\n");
            vpi_free_object(arg_iterator); /* free iterator memory */
            err_flag = 1;
        }
        else {
            /* check that there is only 1 system task argument */
            arg_handle = vpi_scan(arg_iterator);
            if (arg_handle != NULL) {
                vpi_printf("ERROR: $show_all_signals can only have 1 argument\n");
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
PLI_INT32 PLIbook_ShowSignals_calltf(PLI_BYTE8 *user_data)
{

    vpiHandle   systf_handle, arg_iterator, module_handle,
        signal_iterator;
    PLI_INT32   format;
    s_vpi_time  current_time;

    /* obtain a handle to the system task instance */
    systf_handle = vpi_handle(vpiSysTfCall, NULL);

    /* obtain handle to system task argument
       compiletf has already verified only 1 arg with correct type */
    arg_iterator = vpi_iterate(vpiArgument, systf_handle);
    module_handle = vpi_scan(arg_iterator);
    vpi_free_object(arg_iterator);  /* free iterator memory */

    /* read current simulation time */
    current_time.type = vpiScaledRealTime;
    vpi_get_time(systf_handle, &current_time);

    vpi_printf("\nAt time %2.2f, ", current_time.real);
    vpi_printf("signals in module %s ",
               vpi_get_str(vpiFullName, module_handle));
    vpi_printf("(%s):\n", vpi_get_str(vpiDefName, module_handle));

    /* obtain handles to nets in module and read current value */
    signal_iterator = vpi_iterate(vpiNet, module_handle);
    if (signal_iterator != NULL)
        PLIbook_PrintSignalValues(signal_iterator);

    /* obtain handles to regs in module and read current value */
    signal_iterator = vpi_iterate(vpiReg, module_handle);
    if (signal_iterator != NULL)
        PLIbook_PrintSignalValues(signal_iterator);

    /* obtain handles to variables in module and read current value */
    signal_iterator = vpi_iterate(vpiVariables, module_handle);
    if (signal_iterator != NULL)
        PLIbook_PrintSignalValues(signal_iterator);

    vpi_printf("\n"); /* add some white space to output */
    return(0);
}

void PLIbook_PrintSignalValues(vpiHandle signal_iterator)
{
    vpiHandle   signal_handle;
    PLI_INT32   signal_type;
    s_vpi_value current_value;

    while ( (signal_handle = vpi_scan(signal_iterator)) != NULL ) {
        signal_type = vpi_get(vpiType, signal_handle);
        switch (signal_type) {
        case vpiNet:
            current_value.format = vpiBinStrVal;
            vpi_get_value(signal_handle, &current_value);
            vpi_printf("  net     %-10s  value is  %s (binary)\n",
                       vpi_get_str(vpiName, signal_handle),
                       current_value.value.str);
            break;

        case vpiReg:
            current_value.format = vpiBinStrVal;
            vpi_get_value(signal_handle, &current_value);
            vpi_printf("  reg     %-10s  value is  %s (binary)\n",
                       vpi_get_str(vpiName, signal_handle),
                       current_value.value.str);
            break;

        case vpiIntegerVar:
            current_value.format = vpiIntVal;
            vpi_get_value(signal_handle, &current_value);
            vpi_printf("  integer %-10s  value is  %d (decimal)\n",
                       vpi_get_str(vpiName, signal_handle),
                       current_value.value.integer);
            break;

        case vpiRealVar:
            current_value.format = vpiRealVal;
            vpi_get_value(signal_handle, &current_value);
            vpi_printf("  real    %-10s  value is  %0.2f\n",
                       vpi_get_str(vpiName, signal_handle),
                       current_value.value.real);
            break;

        case vpiTimeVar:
            current_value.format = vpiTimeVal;
            vpi_get_value(signal_handle, &current_value);
            vpi_printf("  time    %-10s  value is  %x%x\n",
                       vpi_get_str(vpiName, signal_handle),
                       current_value.value.time->high,
                       current_value.value.time->low);
            break;
        }
    }
    return;
}
/*********************************************************************/

void (*vlog_startup_routines[ ] ) () = {
    PLIbook_ShowSignals_register,
    0  // last entry must be 0
};
