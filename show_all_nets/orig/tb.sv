`timescale 1ns / 1ns

module top;
  reg [2:0] test;
  tri [1:0] results;

  addbit i1 (test[0], test[1], test[2], results[0], results[1]);

  initial begin
    test = 3'b000;
    #10 test = 3'b011;

    #10 $show_all_nets(top);
    #10 $show_all_nets(i1);

    // #10 $stop;
    #10 $finish;
  end

endmodule : top

// A gate level 1 bit adder model
module addbit (a, b, ci, sum, co);
  input a, b, ci;
  output sum, co;

  wire a, b, ci, sum, co, n1, n2, n3;

  xor    (n1, a, b);
  xor #2 (sum, n1, ci);
  and    (n2, a, b);
  and    (n3, n1, ci);
  or  #2 (co, n2, n3);

endmodule : addbit
