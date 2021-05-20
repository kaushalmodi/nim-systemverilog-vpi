//-----------------------------------------------------------------------------
// File:        vlab_probes_pkg.sv
// Author:      Jonathan Bromley, Verilab <jonathan.bromley@verilab.com>
// Description: SystemVerilog code to implement signal probing by string name
// Version:     1.0beta, 24 May 2012
//-----------------------------------------------------------------------------
// This file is initimately coupled to file vlab_probes.c, which
// implements the C side of the signal probing functionality.
// Users should be concerned ONLY with package vlab_probes_pkg,
// and the class signal_probe that it contains.  Code in package
// vlab_probes_pkg_private is, you guessed it, private and should
// never be touched by user code.
//
// Users should import ONLY the signal_probe class, using
//    import vlab_probes_pkg::signal_probe;
// See README and the user documentation for more details.
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

// I wish to prevent users from using signal_probe::new() directly.
// Instead I want them to be forced into using my create() method,
// which can do various sanity checks before committing to construction
// of a new object.  This is easily enough achieved by making the
// constructor "protected", but unfortunately some tools don't yet
// support that.

`ifdef XCELIUM
  `define PROTECTED_FUNCTION_NEW function new
`else
  `define PROTECTED_FUNCTION_NEW protected function new
`endif

    // The _private package includes quite a lot of implementation detail, and
    // in particular it is the only place where the DPI import/export
    // declarations should appear.  This avoids cluttering of the user's
    // namespace with a bunch of DPI functions that the user is in any case
    // not permitted to call.  Into this _private package we put as much of
    // the "secret" implementation as we are able.

    package vlab_probes_pkg_private;

  timeunit 1ns;
  timeprecision 1ns;

  import "DPI-C" context function chandle vlab_probes_create(input string name, input int sv_key);

  // Set/get value-change callback enable on the chosen signal.
  import "DPI-C" context function void vlab_probes_setVcEnable(chandle hnd, int enable);
  import "DPI-C" context function int vlab_probes_getVcEnable(chandle hnd);

  // Get the signal's value.
  import "DPI-C" context function int vlab_probes_getValue32(chandle hnd, output logic [31:0]value, input int chunk);

  // Get the signal's static properties.
  import "DPI-C" context function int vlab_probes_getSize(chandle hnd);
  import "DPI-C" context function int vlab_probes_getSigned(chandle hnd);

  import "DPI-C" context function int vlab_probes_specifyNotifier(string fullname);
  import "DPI-C" context function void vlab_probes_processChangeList();

  // This task sets up a notifier and then runs an infinite loop that
  // waits on notifier changes, and for each change calls the DPI
  // function vlab_probes_processChangeList().  By making it
  // static, we are able to declare a notifier within the task scope;
  // this makes it easier to find the notifier's string signal name
  // than it otherwise would be.
  //
  task static vlab_probes_run();
    bit running;
    bit notifier;  // this is the bit that will be tweaked by VPI
    string notifier_signal_name;
    notifier_signal_name = $sformatf("%m.notifier");
    assert (!running) else
      $error("vlab_probes_run() called multiple times");
    assert (!vlab_probes_specifyNotifier(notifier_signal_name)) else
      $error("vlab_probes_run() failed to register notifier signal %s",
             notifier_signal_name);
    running = 1;
    forever @notifier begin
      vlab_probes_processChangeList();
    end
  endtask

  // This virtual base class contains manipulations of the integer
  // key that's used to identify each probed signal.  A queue of
  // probe objects, indexed by that key, provides access to each
  // object's C access-hook structure via a chandle variable
  // stored in the object.
  virtual class signal_probe_private;
    pure virtual function void releaseWaiters();

    // ~started~ is used to determine whether a call to signal_probe::create
    // is the very first such call; if so, some initialization is needed.
    //
    protected static bit     started;

    // Unchanging properties of a probed signal.  These properties are
    // set up once and for all when a probe is created, and do not
    // change thenceforward.
    //
    //       ~signal_name~ is the signal's full string name, exactly as
    //       supplied to the create() function.
    protected        string  signal_name;
    //
    //       Properties of the signal, determined by VPI inquiries and
    //       copied once and for all to this object in order to reduce
    //       future need for DPI calls
    protected        bit     isSigned;  // 1 = signed, 0 = unsigned
    protected        int     size;      // vector width (bits)
    //
    //       ~handle~ is a pointer to the C struct representing the
    //       probed signal
    protected        chandle handle;
    //
    //       ~event~ is triggered for each value-change on the signal.
    //       This happens when C code calls DPI export function
    //       vlab_probes_vcNotify() for this signal.
    protected        event   change;

    // The most recent probe created on each signal name.
    // This array is maintained only to simplify checking for duplicates.
    // In the unlikely event that we want a list of all probes on a
    // given named signal, we would have to search exhaustively through
    // the base class's probes_by_key[] queue.
    protected static signal_probe_private probes_by_name[string];

    // All the probes that have been created.  The index into
    // this list is the probe's unique ID key.
    protected static signal_probe_private probes_by_key[$];
    protected static function int next_key();
      return probes_by_key.size();
    endfunction
    static function void notify(int sv_key);
      assert ((sv_key >= 0) && (sv_key < probes_by_key.size())) else
        $error ("DPI called signal_probe::notify on invalid sv_key %0d", sv_key);
      probes_by_key[sv_key].releaseWaiters();
    endfunction
    `PROTECTED_FUNCTION_NEW ();
    probes_by_key.push_back(this);
  endfunction
  endclass

  // This is the package-level function that is exported via DPI
  // to be called for each signal_probe object that has a value change.
  //
  export "DPI-C" function vlab_probes_vcNotify;
  //
  function automatic void vlab_probes_vcNotify(int sv_key);
    signal_probe_private::notify(sv_key);
  endfunction

endpackage : vlab_probes_pkg_private


  //-----------------------------------------------------------------------------

  // This is the package that users are expected to import or reference.
  // Note that the ONLY user-visible declaration in it is that of
  // class signal_probe.  This package imports vlab_probes_pkg_private
  // but does not re-export any of its contents.

package vlab_probes_pkg;

  timeunit 1ns;
  timeprecision 1ns;

  import vlab_probes_pkg_private::*;


  //////////////////////////////////////////////////////////////////
  //           class vlab_probes_pkg::signal_probe             //
  //////////////////////////////////////////////////////////////////

class signal_probe extends signal_probe_private;

  ///////////////////////////////////////////////////////////////
  //      The following method prototypes form the entire      //
  //         user-visible API to the class and package.        //
  ///////////////////////////////////////////////////////////////
  //
  extern static  function signal_probe create(string fullname, bit enable = 1);
  extern virtual task                  waitForChange();
  extern virtual function logic [31:0] getValue32(int chunk = 0);
  extern virtual function string       getName();
  extern virtual function int          getSize();
  extern virtual function bit          getSigned();
  extern virtual function void         setVcEnable(bit enable);
  extern virtual function bit          getVcEnable();
  extern virtual function void         releaseWaiters();
  //
  ///////////////////////////////////////////////////////////////
  //      End of user-visible API.  All else is protected      //
  ///////////////////////////////////////////////////////////////

  extern `PROTECTED_FUNCTION_NEW ();

endclass

  //////////////////////////////////////////////////////////////////
  //    Method bodies of class vlab_probes_pkg::signal_probe   //
  //////////////////////////////////////////////////////////////////

  function signal_probe signal_probe::create(string fullname, bit enable = 1);
    signal_probe p;
    int key;
    chandle handle;
    assert (!probes_by_name.exists(fullname)) else
      $info("Duplicate signal probe on signal \"%s\"", fullname);
    if (!started) begin
      started = 1;
      fork
        vlab_probes_run();
      join_none
    end
    key = next_key();
    handle = vlab_probes_create(fullname, key);
    assert (handle != null) else
      $warning("signal_probe::create(\"%s\") could not create probe", fullname, key);
    if (handle != null) begin
      p = new();
      probes_by_name[fullname] = p;
      p.signal_name = fullname;
      p.handle = handle;
      p.setVcEnable(enable);
      p.size = vlab_probes_getSize(handle);
      p.isSigned = (vlab_probes_getSigned(handle) != 0);
    end
    else begin
      p = null;
    end
    return p;
  endfunction

  function signal_probe::new();
    super.new();
  endfunction

  function void signal_probe::setVcEnable(bit enable);
    vlab_probes_setVcEnable(handle, enable);
  endfunction

  function string signal_probe::getName();
    return signal_name;
  endfunction

  function bit signal_probe::getVcEnable();
    return (vlab_probes_getVcEnable(handle) != 0);
  endfunction

  function logic [31:0] signal_probe::getValue32(int chunk = 0);
    logic [31:0] value;
    assert (!vlab_probes_getValue32(handle, value, chunk)) else
      $error("vlab_probes_getValue32(.chunk(%0d)) on %s failed", chunk, signal_name);
    return value;
  endfunction

  function int signal_probe::getSize();
    return size;
  endfunction

  function bit signal_probe::getSigned();
    return isSigned;
  endfunction

  task signal_probe::waitForChange();
    @change;
  endtask

  function void signal_probe::releaseWaiters();
    ->change;
  endfunction

endpackage : vlab_probes_pkg
