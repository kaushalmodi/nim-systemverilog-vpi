//-----------------------------------------------------------------------------
// File:        vlab_probes.c
// Author:      Jonathan Bromley, Verilab <jonathan.bromley@verilab.com>
// Description: C code to implement Verilog signal probing by string name
// Version:     1.0beta, 24 May 2012
//-----------------------------------------------------------------------------
// This file is initimately coupled to file vlab_probes_pkg.sv which
// implements the SystemVerilog side of the signal probing functionality.
// It implements a number of SV-DPI import functions, and precisely one
// DPI export function - the DPI prototypes appear near the start of the file.
// User code should never attempt to access these functions directly.  They
// are carefully orchestrated by code in the associated SV package, and user
// access should be solely through methods provided in the SV class
// "signal_probe" found in package "vlab_probes_pkg".
//-----------------------------------------------------------------------------
// USERS SHOULD NOT ATTEMPT TO MAKE DIRECT USE OF ANYTHING IN THIS FILE.
//-----------------------------------------------------------------------------
//
// Copyright 2012 Verilab GmbH
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//-----------------------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>
#include "sv_vpi_user.h"
#include "svdpi.h"

// Everyone still supports deprecated function vpi_free_object,
// but VCS doesn't yet support vpi_release_handle, which supersedes it
//#ifdef VCS
#define vpi_release_handle vpi_free_object
//#endif

#ifdef  __cplusplus
extern "C" {
#endif

//--------------------------------------------------------------------------
// DPI import and export prototypes
//--------------------------------------------------------------------------

// DPI import ________________________________________ vlab_probes_create
//
// Create an access hook on the signal whose absolute pathname is ~name~.
// Use ~sv_key~ as the key shared between SV and C that will be used as
// the unique identifier for the created probe object.
// This function returns a pointer to a hook_record structure (see
// below), which is returned from C as void* and passed to SV as
// a "chandle".  It should be saved for use in future operations
// on this signal.  In practice the SV code will do this by maintaining
// an array of chandle indexed by their unique sv_key.
// An access hook freshly created by this function has no properties,
// i.e. it does nothing.  To make the access hook useful, it must be
// enabled by a suitable call to vlab_probes_setVcEnable (see below).
//
extern void * vlab_probes_create(char * name, int sv_key);


// DPI import ___________________________________ vlab_probes_setVcEnable
//
// Enable or disable value-changed callback on the signal referenced
// by p_hook_record ~hnd~.  If ~enable~ is true (non-zero), value-change
// monitoring is enabled for the signal.  If ~enable~ is false (zero),
// it is disabled.  If monitoring is already enabled and this function
// is called with ~enable~ true, the function has no effect.  Similarly,
// if monitoring is disabled and the function is called with ~enable~
// false, it has no effect.
//
extern void vlab_probes_setVcEnable(void * hnd, int enable);


// DPI import ___________________________________ vlab_probes_getVcEnable
//
// Find the current enabled/disabled state of value-change callback
// on the signal accessed by the hook record referenced by ~hnd~.
// Returns 0 (disabled) or 1 (enabled).
//
extern int vlab_probes_getVcEnable(void * hnd);


// DPI import ____________________________________ vlab_probes_getValue32
//
// Get the current value of the signal referenced by ~hnd~.
// The result is placed into the vector ~result~,
// which must be a 32-bit logic or equivalent type.
// ~chunk~ indicates which 32-bit slice of the signal
// is to be read: chunk=0 gets the least significant 32 bits,
// chunk=1 gets bits [63:32], and in general the function
// reads bits [32*chunk+:32].  If the specified chunk is completely
// beyond the end of the vector (i.e. the signal's size is less than
// 32*chunk bits) then the function yields an error.  If the signal
// does not completely fill the chunk (for example, a 48-bit signal
// and chunk=1) then the result is zero-extended if the signal is
// unsigned, and sign-extended in the standard Verilog 4-state way
// if the signal is signed.
// Returns 1 if success, 0 if failure (bad handle, chunk out-of-bounds).
//
extern int vlab_probes_getValue32(void * hnd, svLogicVecVal *result, int chunk);


// DPI import _______________________________________ vlab_probes_getSize
//
// Get the number of bits in the signal referenced by ~hnd~.
// Returns zero if the handle is bad.
//
extern int vlab_probes_getSize(void * hnd);


// DPI import _____________________________________ vlab_probes_getSigned
//
// Get a flag indicating whether the signal referenced by ~hnd~
// is signed (0=unsigned, 1=signed).
//
extern int vlab_probes_getSigned(void * hnd); // 1=signed, 0=unsigned


// DPI import _______________________________ vlab_probes_specifyNotifier
//
// Here's how we get the value change information back in to SV.
// First we pass the name of a single-bit signal to this function.
// That signal will be toggled by the VPI whenever it requires
// attention from SV because one of the probed signals has changed.
//
extern int vlab_probes_specifyNotifier(char * fullname);


// DPI import _____________________________ vlab_probes_processChangeList
//
// When the SV notifier signal is toggled, the SV code must immediately
// call this function.  It will service all pending value-change events,
// notifying each affected probe object in turn by calling exported
// function vlab_probes_vcNotify for that signal.
//
extern void vlab_probes_processChangeList();


// DPI export ______________________________________ vlab_probes_vcNotify
//
// vlab_probes_processChangeList() calls this DPI export function
// once for each probed signal that has a pending value-change event.
// It uses a unique int key, rather than the signal's vpi_handle
// reference, to work around a tool limitation (no associative array
// indexed by chandle).
//
extern void vlab_probes_vcNotify(int sv_key);


//-----------------------------------------------------------------------------
// Typedefs and private data used by the C functions
//-----------------------------------------------------------------------------

// The following struct is used to hold information about a
// probed signal.  Various features of the signal are cached
// here, to avoid making repeated VPI accesses to discover this
// information.  The structure sometimes appears on a linked list
// of signals that need to be serviced (the changeList), and
// struct members to support that linked list are also included.
//
typedef struct t_hook_record {
   struct t_hook_record *allHooks_link;   // linked list pointer - all records
   struct t_hook_record *changeList_link; // linked list pointer - records awaiting processing
   int on_changeList;                     // 1 if we're on the list, 0 if not
   struct t_hook_record *check;           // copy of self-pointer, for safety
   vpiHandle obj;                         // reference to the monitored signal
   int sv_key;                            // unique key to help SV find this
   vpiHandle cb;                          // VPI value-change callback object
   int size;                              // number of bits in the signal
   int isSigned;                          // is the signal signed?
   PLI_UINT32 top_mask;                   // word-mask for most significant 32 bits
   PLI_UINT32 top_msb;                    // MSB position within that word
} s_hook_record, *p_hook_record;

// A single list of hook_records that have value changes yet to be handled
static p_hook_record changeList = NULL;

// A single list of all hook_records, for use when deallocating memory
static p_hook_record allHooks = NULL;

// VPI handle to the single bit that is toggled to notify SV of pending
// value-changes that require service
static vpiHandle notifier = NULL;

// VPI handle to the simulation reset callback
static vpiHandle reset_callback = NULL;


//-----------------------------------------------------------------------------
// Static (file-local) helper functions
//-----------------------------------------------------------------------------

// Report an error in a consistent way.  This function should be used when
// control will be returned to SV with an error indication; the SV code will
// then display a more comprehensive error diagnostic.
//
static void report_error(char *message) {
   vpi_printf("*E,VLAB_PROBES: %s\n");
}


// Interrupt the simulation because of an error.
// After an error, a user can continue from the stop using
// simulator command-line functionality.  This may help with
// debugging by providing additional trace information, but
// behaviour of the signal probe package is not guaranteed
// after any error.
//
static void stop_on_error(char *message) {
   if (message != NULL) {
      report_error(message);
   }
   report_error("Stopping.  Continue the run to see further diagnostics");
   vpi_control(vpiStop, 1);
}


// Get and initialize a new s_hook_record from the heap.
// Add it to the allHooks structure to support memory
// deallocation on simulator restart.
//
static p_hook_record allocate_hook_record() {
   p_hook_record rec = (p_hook_record)malloc(sizeof(s_hook_record));
   if (rec == NULL) {
      stop_on_error("allocate_hook_record: no memory");
   } else {
      rec->on_changeList = 0;
      rec->check = rec;
      rec->obj = NULL;
      rec->allHooks_link = allHooks;
      allHooks = rec;
   }
   return rec;
}

// Deallocate a single hook_record structure.
// Destroy its internal referenced VPI objects before deallocation.
//
static void free_hook_record(p_hook_record rec) {
   if (rec == NULL) return;
   if (rec->cb != NULL) {
      (void)vpi_remove_cb(rec->cb);
   }
   if (rec->obj != NULL) {
      (void)vpi_release_handle(rec->obj);
   }
   free(rec);
}

// Deallocate all hook record structures that exist on the allHooks list.
//
static void free_all_hook_records() {
   while (allHooks != NULL) {
      p_hook_record rec = allHooks;
      allHooks = rec->allHooks_link;
      free_hook_record(rec);
   }
}

// Deallocate all memory structures owned by this VPI application.
// This will typically be done by the VPI simulation restart callback.
// NOTE that the restart callback itself is NOT deallocated here,
// because this function is probably called from within that callback.
//
static void free_everything() {
   if (notifier != NULL) {
      (void)vpi_release_handle(notifier);
   }
   free_all_hook_records();
}


// Get and remove the first (newest) entry from the
// list of signals with unserviced value changes.
// Return a reference to that entry.
//
static p_hook_record changeList_pop() {
   p_hook_record rec;
   rec = changeList;
   if (rec != NULL) {
      changeList = rec->changeList_link;
      rec->on_changeList = 0;
   }
   return rec;
}


// Add a signal to the list of unserviced value changes.
// But if the signal is already on that list, don't
// try to add it again.
//
static void changeList_pushIfNeeded(p_hook_record rec) {
   if (!rec->on_changeList) {
      rec->on_changeList = 1;
      rec->changeList_link = changeList;
      changeList = rec;
   }
}


// Check to see whether a vpiType value represents
// an appropriate Verilog type (vector, reg etc) for probing.
// Basically we are checking for an integral type, but
// there does not seem to be any VPI property for that,
// so instead we must exhaustively list all known
// integral types.
//
static int isVerilogType(PLI_INT32 vpi_type) {
   switch (vpi_type) {
      case vpiNet:
      case vpiNetBit:
      case vpiReg:
      case vpiRegBit:
      case vpiPartSelect:
      case vpiBitSelect:
      case vpiBitVar:
      case vpiEnumVar:
      case vpiIntVar:
      case vpiLongIntVar:
      case vpiShortIntVar:
      case vpiIntegerVar:
      case vpiByteVar:
         return 1;
      default:
         return 0;
   }
}

// Given a handle value obtained from an untrusted source,
// cast it to a p_hook_record and do some sanity checks.
//
static p_hook_record chandle_to_hook(void * hnd) {
   p_hook_record hook = (p_hook_record) hnd;
   if  ((hook != NULL) && (hook->check == hook)) {
      return hook;
   } else {
      stop_on_error("Bad chandle argument is not a valid created hook");
      return NULL;
   }
}


//-----------------------------------------------------------------------------
// Static (file-local) helper functions related to simulator action callbacks
//-----------------------------------------------------------------------------

// The callback function used to deal with simulator actions.
// Currently it handles only cbStartOfReset, which is caused by
// an interactive restart of the simulation back to time zero.
static PLI_INT32 action_callback(p_cb_data cb_data_p) {
   switch (cb_data_p->reason) {
      case cbStartOfReset :
         vpi_printf("\n\n*I,VLAB_PROBE: cbStartOfReset, deallocate all internal data\n\n");
         free_everything();
         break;
   }
   return 1;
}

// Set up reset/restart callbacks, removing any old callback if necessary
static void setup_reset_callback() {
   s_cb_data   cb_data;
   // Time and value structs should not be needed, but IUS requires them
   s_vpi_time  time_s;
   s_vpi_value value_s;

   // Remove any existing callback
   if (reset_callback != NULL) {
      (void)vpi_remove_cb(reset_callback);
   }
   // Set up the new callback
   cb_data.cb_rtn = &action_callback;
   cb_data.obj = NULL;
   cb_data.user_data = NULL;
   cb_data.time = &time_s;
   time_s.type = vpiSuppressTime;
   cb_data.value = &value_s;
   value_s.format = vpiSuppressVal;
   cb_data.reason = cbStartOfReset;
   reset_callback = vpi_register_cb(&cb_data);
}

//-----------------------------------------------------------------------------
// Static (file-local) helper functions related to value-change callbacks
//-----------------------------------------------------------------------------

// Toggle the notifier signal
static PLI_INT32 toggle_notifier() {
   if (notifier == NULL) {
      // Throw an error and return FALSE if there's no notifier set up.
      stop_on_error("Value-change callback but no active notifier bit");
      return 0;
   } else {
      s_vpi_value value_s;
      value_s.format = vpiScalarVal;
      vpi_get_value(notifier, &value_s);
      value_s.value.scalar = (value_s.value.scalar == vpi1)? vpi0: vpi1;
      vpi_put_value(notifier, &value_s, NULL, vpiNoDelay);
      return 1;
   }
}

// This is the function that is provided to the VPI as a value-change callback
// handler.  There is only one entry point.  Each callback's user_data field
// holds a pointer to the corrresponding signal's hook_record structure.
//
static PLI_INT32 vc_callback(p_cb_data cb_data) {
   p_hook_record hook = chandle_to_hook(cb_data->user_data);
   if (hook == NULL) return 0;
   // At any given time, the first signal that suffers a
   // value-change callback will cause the notifier signal
   // to be toggled.  Subsequent callbacks don't toggle the
   // notifier again, as that might prevent it from being
   // detected by SV "@notifier".  Instead, they are just
   // added to the changeList.  When SV eventually responds
   // to the notifier change, it causes the changeList to be
   // scanned, servicing each signal in turn and emptying
   // the changeList.  The next value change will then
   // give rise to another notification.  This mechanism
   // avoids any risk of races whereby a notification might
   // be missed.
   // We detect "first signal" by noting whether
   // the changeList is currently empty.
   int require_notification = (changeList == NULL);
   // Put this object on the changeList, if it isn't already.
   changeList_pushIfNeeded(hook);
   if (require_notification) {
      // Toggle the notifier bit.
      int ok = toggle_notifier();
      return ok;
   } else {
      return 1;
   }
}

// Sensitise to a signal by placing a value-change callback on it.
// Set up the callback so that it does not collect the signal's
// value or the callback time (reduces overhead).  Keep a copy
// of the callback handle in the signal's hook record, to simplify
// later removal of the callback.
//
static void enable_cb(p_hook_record hook) {
   if (hook->cb == NULL) {
      s_cb_data   cb_data;
      s_vpi_time  time_s;
      s_vpi_value value_s;

      cb_data.reason = cbValueChange;
      cb_data.cb_rtn = &vc_callback;
      cb_data.obj = hook->obj;
      cb_data.time = &time_s;
      time_s.type = vpiSuppressTime;
      cb_data.value = &value_s;
      value_s.format = vpiSuppressVal;
      cb_data.user_data = (PLI_BYTE8*)hook;

      hook->cb = vpi_register_cb(&cb_data);
   }
}

// Disable value-change callbacks on a signal by removing
// its value-change callback completely.
//
static void disable_cb(p_hook_record hook) {
   if (hook->cb != NULL) {
      (void) vpi_remove_cb(hook->cb);
      hook->cb = NULL;
   }
}


//-----------------------------------------------------------------------------
// SV DPI import implementations
//----------------------------------------------------------------------------


void * vlab_probes_create(char *name, int sv_key) {
   vpiHandle obj;
   p_hook_record rec;
   int objType;
   // Locate the chosen object
   obj = vpi_handle_by_name(name, NULL);
   // If there was a problem, return NULL to report it.
   if (obj == NULL) {
      vpi_printf("*W,VLAB_PROBES: create(\"%s\") could not locate requested signal\n", name);
      return NULL;
   }
   // Check the object is indeed a vector variable or net; error if not.
   objType = vpi_get(vpiType, obj);
   if (!isVerilogType(objType)) {
      vpi_printf("Unable to create probe on '%s' with key %d, type=%d\n",
                                            name, sv_key, objType);
      vpi_printf("*W,VLAB_PROBES: create(\"%s\"): object is not a variable or net of integral type\n", name);
      return NULL;
   }
   // Obtain a clean object record from free memory
   rec = allocate_hook_record();
   // Populate it
   rec->obj      = obj;
   rec->isSigned = vpi_get(vpiSigned, obj);
   rec->size     = vpi_get(vpiSize, obj);
   rec->sv_key   = sv_key;
   rec->cb       = NULL;
   rec->top_msb  = 1U << ((rec->size-1) % 32);
   rec->top_mask = 2U * rec->top_msb - 1U;

   return (void *)rec;
}


// Enable or disable value-change callback on the chosen signal.
//
void vlab_probes_setVcEnable(void * hnd, int enable) {
   p_hook_record hook = chandle_to_hook(hnd);
   if (hook == NULL) return;
   if (enable) {
      enable_cb(hook);
   } else {
      disable_cb(hook);
   }
}

// Enquiry: is value-change callback enabled on the chosen signal?
//
int vlab_probes_getVcEnable(void * hnd) {
   p_hook_record hook = chandle_to_hook(hnd);
   if (hook == NULL) return 0;
   return (hook->cb != NULL);
}

// Get up to 32 bits of the signal's value.
//
int vlab_probes_getValue32(void * hnd, svLogicVecVal *result, int chunk) {
   p_hook_record hook;
   s_vpi_value value_s;
   p_vpi_vecval vec_p;
   int chunk_lsb = chunk*32;

   hook = chandle_to_hook(hnd);

   if (hook == NULL) {
      stop_on_error("vlab_probes_getValue32: bad handle");
      return 0;
   }
   if (chunk<0) {
      report_error("vlab_probes_getValue32: negative chunk index");
      return 0;
   }
   if (chunk_lsb >= hook->size) {
      chunk = (hook->size-1)/32;
   }

   // Get the whole vector value from VPI
   value_s.format = vpiVectorVal;
   vpi_get_value(hook->obj, &value_s);

   // Copy the relevant aval/bval bits into the output argument.
   vec_p = value_s.value.vector;
   *result = vec_p[chunk];
   // Perform sign extension if appropriate.
   if ((chunk_lsb + 32) > hook->size) {
      // We're working on the most significant word, and it is not full.
      result->aval &= hook->top_mask;
      result->bval &= hook->top_mask;
      if (hook->isSigned) {
         if (result->bval & hook->top_msb) {
            result->bval |= ~(hook->top_mask);
         }
         if (result->aval & hook->top_msb) {
            result->aval |= ~(hook->top_mask);
         }
      }
   }
   return 1;
}

int vlab_probes_getSize(void * hnd) {
   p_hook_record hook = chandle_to_hook(hnd);
   if (hook == NULL) return 0;
   return hook->size;
}

int vlab_probes_getSigned(void * hnd) {
   p_hook_record hook = chandle_to_hook(hnd);
   if (hook == NULL) return 0;
   return hook->isSigned;
}

// This function must be called exactly once when the very first probe is created.
int vlab_probes_specifyNotifier(char * fullname) {
   vpiHandle obj;

   // Locate the chosen notifier signal
   obj = vpi_handle_by_name(fullname, NULL);
   // If there was a problem, return NULL to report it.
   if (obj == NULL) {
      report_error("vlab_probes_specifyNotifier() could not locate requested signal");
      return 0;
   }
   // Check the object is indeed a variable of type bit; error if not.
   if (vpi_get(vpiType, obj) != vpiBitVar) {
      report_error("vlab_probes_specifyNotifier(): object is not a bit variable");
      return 0;
   }
   notifier = obj;
   setup_reset_callback();
   return 1;
}

// Walk the changeList, calling back to SV to handle each item in turn
// as they are popped off the list. When done, the list will be empty.
void vlab_probes_processChangeList() {
   while (changeList != NULL) {
      p_hook_record rec = changeList_pop();
      vlab_probes_vcNotify(rec->sv_key);
   }
}

#ifdef  __cplusplus
}
#endif
