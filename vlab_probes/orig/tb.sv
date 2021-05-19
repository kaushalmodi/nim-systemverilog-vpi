//-----------------------------------------------------------------------------
// File:        test.sv
// Author:      Jonathan Bromley, Verilab
// Description: Simple demonstration/test for vlab_probes package
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

`timescale 1ns/1ps

//--------------------------
`define RUNTIME       10000
//--------------------------

//-----------------------------------------------------------------------------
module simple_wiggler #(parameter ID = 0);

   localparam DELAY = (ID%20) + 5;  // just to mix up the periodicity a bit

   logic s;
   int sig_changes;

   initial begin
      #10 s = 0;
      while ($time < `RUNTIME) begin
         #(DELAY) s = ~s;
         sig_changes++;
         if (ID%1) begin
            // odd-numbered IDs only...
            s <= ~s;  // create transition after one NBA delay
            sig_changes++;
         end
      end
   end

endmodule

//-----------------------------------------------------------------------------
module vector_wiggler #(parameter ID = 0, nBits = 2);

   localparam DELAY = (ID%20) + 2;

   logic [nBits-1:0] s;
   int sig_changes;

   initial begin
      #10 s = 0;
      // Make a Johnson counter that loops 000,100,110,111,011,001,000,...
      while ($time < `RUNTIME) begin
         #(DELAY)
         s = { ~s[0], s[nBits-1:1] };
         sig_changes++;
      end
   end

endmodule

//-----------------------------------------------------------------------------
module observe_and_compare #(parameter nBits = 1) (input [nBits-1:0] sig);

   localparam int nChunks = ((nBits+31)/32);

   vlab_probes_pkg::signal_probe p;  // set up by the test

   int detected_changes, sig_changes;
   logic [32*nChunks-1:0] result;

   // Detect and count changes on the real signal
   always @sig begin
      test.sig_changes++;
      sig_changes++;
   end

   // Respond to changes detected by the signal probe
   initial wait (p!=null) begin
      $display("module %m sensing %0d-bit signal %s", p.getSize(), p.getName());
      forever begin
         p.waitForChange();
         test.detected_changes++;
         detected_changes++;
         for (int chunk = 0; chunk < nChunks; chunk++) begin
            result[chunk*32 +: 32] = p.getValue32(chunk);
         end
      end
   end

   // Error checking
   //
   // We cannot depend on event ordering, so it's impossible to decide
   // precisely when to check for errors.  So we introduce a small
   // inertial delay in the error check logic, so an error must persist
   // for a small non-zero time before being detected.

   wire #1ps value_error = (result[nBits-1:0] !== sig);
   wire #1ps count_error = (sig_changes != detected_changes);

   initial wait (p!=null) forever @(value_error, count_error) begin
      if (value_error) begin
         $display("ERROR: %s observed %b, expected %b\n",
                       p.getName(), result[nBits-1:0], sig);
      end
      if (count_error) begin
         $display("ERROR: %s sig_changes=%0d, detected_changes=%0d\n",
                        p.getName(), sig_changes, detected_changes);
      end
   end
endmodule


//-----------------------------------------------------------------------------

module test;

   // Get the signal-probe functionality
   import vlab_probes_pkg::signal_probe;

   int sig_changes, detected_changes;

   generate
      genvar i;
      for (i=0; i<5; i=i+1) begin: testloop
         simple_wiggler #(.ID(i)) w();
         observe_and_compare #(1) obs(w.s);
         initial obs.p = signal_probe::create($sformatf("test.testloop[%0d].w.s", i));
      end
      for (i=31; i<=33; i++) begin: vecloop
         vector_wiggler #(.ID(i), .nBits(i)) w();
         observe_and_compare #(i) obs(w.s);
         initial obs.p = signal_probe::create($sformatf("test.vecloop[%0d].w.s", i));
      end
   endgenerate

   //---------------------------------------------------------------------

   initial begin
      #(`RUNTIME);
      #100 $display("sig_changes = %0d, detected_changes = %0d",
                    sig_changes, detected_changes);
      $finish;
   end

endmodule
