/**********************************************************************
 * $show_all_signals example 3 -- Verilog HDL test bench.
 *
 * Verilog test bench to test the $show_all_signals PLI application on
 * a 1-bit adder modeled using gate primitives.
 *********************************************************************/
`timescale 1ns / 1ns

module top;
  integer test;
  tri [1:0] results;

  addbit i1 (test[0], test[1], test[2], results[0], results[1]);

  initial begin
    test = 3'b000;
    #10 test = 3'b001;

    #10 $show_all_signals(top.i1, ,top); /* second arg is null */

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

  always @(sum)
    $show_all_signals;
endmodule : addbit
