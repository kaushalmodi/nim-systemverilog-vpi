// The Verilog PLI Handbook - Section 2.10

#include <stdlib.h> /* ANSI C standard library */
#include <stdio.h> /* ANSI C standard input/output library */
#include <stdarg.h> /* ANSI C standard arguments library */
#include "vpi_user.h" /* IEEE 1364 PLI VPI routine library */

/* prototypes of PLI application routine names */
PLI_INT32 PLIbook_PowSizetf(PLI_BYTE8 *user_data),
    PLIbook_PowCalltf(PLI_BYTE8 *user_data),
    PLIbook_PowCompiletf(PLI_BYTE8 *user_data),
    PLIbook_PowStartOfSim(s_cb_data *callback_data);

/* $pow Registration Data */
/* (add this function name to the vlog_startup_routines array) */

void PLIbook_pow_register()
{
    s_vpi_systf_data tf_data;
    s_cb_data cb_data_s;
    vpiHandle callback_handle;

    tf_data.type = vpiSysFunc;
    tf_data.sysfunctype = vpiSysFuncSized;
    tf_data.tfname = "$pow";
    tf_data.calltf = PLIbook_PowCalltf;
    tf_data.compiletf = PLIbook_PowCompiletf;
    tf_data.sizetf = PLIbook_PowSizetf;
    tf_data.user_data = NULL;
    vpi_register_systf(&tf_data);
    cb_data_s.reason = cbStartOfSimulation;
    cb_data_s.cb_rtn = PLIbook_PowStartOfSim;
    cb_data_s.obj = NULL;
    cb_data_s.time = NULL;
    cb_data_s.value = NULL;
    cb_data_s.user_data = NULL;
    callback_handle = vpi_register_cb(&cb_data_s);
    vpi_free_object(callback_handle); /* don’t need callback handle */
}

/* Sizetf application */
PLI_INT32 PLIbook_PowSizetf(PLI_BYTE8 *user_data)
{
    return(32); /* $pow returns 32-bit values */
}

/* compiletf application to verify valid systf args. */
PLI_INT32 PLIbook_PowCompiletf(PLI_BYTE8 *user_data)
{
    vpiHandle systf_handle, arg_itr, arg_handle;
    PLI_INT32 tfarg_type;
    int err_flag = 0;
    do { /* group all tests, so can break out of group on error */
        systf_handle = vpi_handle(vpiSysTfCall, NULL);
        arg_itr = vpi_iterate(vpiArgument, systf_handle);
        if (arg_itr == NULL) {
            vpi_printf("ERROR: $pow requires 2 arguments; has none\n");
            err_flag = 1;
            break;
        }
        arg_handle = vpi_scan(arg_itr);
        tfarg_type = vpi_get(vpiType, arg_handle);
        if ( (tfarg_type != vpiReg) &&
             (tfarg_type != vpiIntegerVar) &&
             (tfarg_type != vpiConstant) ) {
            vpi_printf("ERROR: $pow arg1 must be number, variable or net\n");
            err_flag = 1;
            break;
        }

        arg_handle = vpi_scan(arg_itr);
        if (arg_handle == NULL) {
            vpi_printf("ERROR: $pow requires 2nd argument\n");
            err_flag = 1;
            break;
        }
        tfarg_type = vpi_get(vpiType, arg_handle);
        if ( (tfarg_type != vpiReg) &&
             (tfarg_type != vpiIntegerVar) &&
             (tfarg_type != vpiConstant) ) {
            vpi_printf("ERROR: $pow arg2 must be number, variable or net\n");
            err_flag = 1;
            break;
        }
        if (vpi_scan(arg_itr) != NULL) {
            vpi_printf("ERROR: $pow requires 2 arguments; has too many\n");
            vpi_free_object(arg_itr);
            err_flag = 1;
            break;
        }
    } while (0 == 1); /* end of test group; only executed once */
    if (err_flag) {
        vpi_control(vpiFinish, 1); /* abort simulation */
    }
    return(0);
}

/* calltf to calculate base to power of exponent and return result. */
#include <math.h>
PLI_INT32 PLIbook_PowCalltf(PLI_BYTE8 *user_data)
{
    s_vpi_value value_s;
    vpiHandle systf_handle, arg_itr, arg_handle;
    PLI_INT32 base, exp;
    double result;
    systf_handle = vpi_handle(vpiSysTfCall, NULL);
    arg_itr = vpi_iterate(vpiArgument, systf_handle);
    if (arg_itr == NULL) {
        vpi_printf("ERROR: $pow failed to obtain systf arg handles\n");
        return(0);
    }
    /* read base from systf arg 1 (compiletf has already verified) */
    arg_handle = vpi_scan(arg_itr);
    value_s.format = vpiIntVal;
    vpi_get_value(arg_handle, &value_s);
    base = value_s.value.integer;

    /* read exponent from systf arg 2 (compiletf has already verified) */
    arg_handle = vpi_scan(arg_itr);
    vpi_free_object(arg_itr); /* not calling scan until returns null */
    vpi_get_value(arg_handle, &value_s);
    exp = value_s.value.integer;
    /* calculate result of base to power of exponent */
    result = pow( (double)base, (double)exp );
    /* write result to simulation as return value $pow */
    value_s.value.integer = (PLI_INT32)result;
    vpi_put_value(systf_handle, &value_s, NULL, vpiNoDelay);
    return(0);
}

/* Start-of-simulation application */
PLI_INT32 PLIbook_PowStartOfSim(s_cb_data *callback_data)
{
    vpi_printf("\n$pow PLI application is being used.\n\n");
    return(0);
}

void (*vlog_startup_routines[ ] ) () = {
    PLIbook_pow_register,
    0  // last entry must be 0
};
