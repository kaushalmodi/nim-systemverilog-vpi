/**********************************************************************
 * $show_all_signals example 1 -- Verilog HDL test bench.
 *
 * Verilog test bench to test the $show_all_signals PLI application on
 * a 1-bit adder modeled using gate primitives.
 *********************************************************************/

`timescale 1ns / 1ns

module top;
  tri [1:0] results;
  integer test;
  real foo;
  time bar;

  addbit i1 (test[0], test[1], test[2], results[0], results[1]);

  initial
    begin
      test = 3'b000;
      foo = 3.14;
      bar = 0;
      bar[63:60] = 4'hF;
      bar[35:32] = 4'hA;
      bar[31:28] = 4'hC;
      bar[03:00] = 4'hE;

      #10 test = 3'b011;

      #10 $show_all_signals(top);
      #10 $show_all_signals(i1);

      // #10 $stop;
      #10 $finish;
    end
endmodule : top


// An RTL level 1 bit adder model
module addbit (a, b, ci, sum, co);
  input  a, b, ci;
  output sum, co;

  wire  a, b, ci;
  reg   sum, co;

  always @(a or b or ci)
    {co, sum} = a + b + ci;

endmodule : addbit
