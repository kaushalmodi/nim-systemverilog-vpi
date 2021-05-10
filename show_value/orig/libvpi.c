// The Verilog PLI Handbook - Section 1.5

#include <stdlib.h>
#include "vpi_user.h"

int PLIbook_ShowVal_compiletf(char *user_data)
{
    vpiHandle systf_handle, arg_iterator, arg_handle;
    int arg_type;
    /* obtain a handle to the system task instance */
    systf_handle = vpi_handle(vpiSysTfCall, NULL);
    if (systf_handle == NULL) {
        vpi_printf("ERROR: $show_value failed to obtain systf handle\n");
        tf_dofinish(); /* abort simulation */
        return(0);
    }

    /* obtain handles to system task arguments */
    arg_iterator = vpi_iterate(vpiArgument, systf_handle);
    if (arg_iterator == NULL) {
        vpi_printf("ERROR: $show_value requires 1 argument\n");
        tf_dofinish(); /* abort simulation */
        return(0);
    }

    /* check the type of object in system task arguments */
    arg_handle = vpi_scan(arg_iterator);
    arg_type = vpi_get(vpiType, arg_handle);
    if (arg_type != vpiNet && arg_type != vpiReg) {
        vpi_printf("ERROR: $show_value arg must be a net or reg\n");
        vpi_free_object(arg_iterator); /* free iterator memory */
        tf_dofinish(); /* abort simulation */
        return (0);
    }

    /* check that there are no more system task arguments */
    arg_handle = vpi_scan(arg_iterator);
    if (arg_handle != NULL) {
        vpi_printf("ERROR: $show_value can only have 1 argument\n");
        vpi_free_object(arg_iterator); /* free iterator memory */
        tf_dofinish(); /* abort simulation */
        return(0);
    }
    return(0);
}

int PLIbook_ShowVal_calltf(char *user_data)
{
    vpiHandle systf_handle, arg_iterator, arg_handle, net_handle;
    s_vpi_value current_value;

    /* obtain a handle to the system task instance */
    systf_handle = vpi_handle(vpiSysTfCall, NULL);

    /* obtain handle to system task argument
       compiletf has already verified only 1 arg with correct type */
    arg_iterator = vpi_iterate(vpiArgument, systf_handle);
    net_handle = vpi_scan(arg_iterator);
    vpi_free_object(arg_iterator); /* free iterator memory */

    /* read current value */
    current_value. format = vpiBinStrVal; /* read value as a string */
    vpi_get_value(net_handle, &current_value);
    vpi_printf("Signal %s has the value %s\n",
               vpi_get_str(vpiFullName, net_handle),
               current_value.value.str);
    return (0) ;
}

void registerShow_ValueSystfs() {
    s_vpi_systf_data task_data_s;
    p_vpi_systf_data task_data_p = &task_data_s;
    task_data_p->type = vpiSysTask;
    task_data_p->tfname = "$show_value";
    task_data_p->compiletf = PLIbook_ShowVal_compiletf;
    task_data_p->calltf = PLIbook_ShowVal_calltf;
    task_data_p->sizetf = NULL;

    vpi_register_systf(task_data_p);
}

void (*vlog_startup_routines[ ] ) () = {
    registerShow_ValueSystfs,
    0  // last entry must be 0
};
