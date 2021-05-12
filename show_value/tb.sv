// Time-stamp: <2021-05-12 09:44:33 kmodi>

`timescale 1ns/1ns

module addbit(a, b, ci, sum, co);
  input a, b, ci ;
  output sum, co;
  wire a, b, ci, sum,
       ni, n2, n3;
  xor (ni, a, b) ;
  xor #2 (sum, ni, ci) ;
  and (n2, a, b) ;
  and (n3, ni, ci) ;
  or #2 (co, n2, n3);
endmodule : addbit

module top;

  reg a, b, ci, clk;
  wire sum, co;
  addbit il (a, b, ci, sum, co);

  initial begin
    clk = 0;
    a = 0;
    b = 0;
    ci = 0;
    #10 a = 1;
    #10 b = 1;
    $show_value; // will cause compilation error
    // $show_value(); // will cause compilation error
    // $show_value(sum, 123); // will cause compilation error
    // $show_value(123); // will cause compilation error
    $show_value(sum);
    $show_value(co);
    $show_value(il.n3);
    // #10 $stop;
    $finish;
  end // initial begin

endmodule : top
