/**********************************************************************
 * $get_arg_handle_test example -- Verilog HDL test bench.
 *
 * Verilog test bench to test the VPI get_arg_handle application.
 *********************************************************************/

`timescale 1ns / 1ns

module test;
  reg  a, b, ci;
  wire sum, co;

  initial begin
    a = 0; b = 1; ci = 1;

    #10 $get_arg_handle_test(a, b, sum);
    #10 $finish;
  end
endmodule : test
