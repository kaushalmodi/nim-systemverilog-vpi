// Time-stamp: <2021-05-13 21:21:44 kmodi>

module top;

  initial begin
    integer a, b;

    $display("$pow(2, 3) = %p", $pow(2, 3));

    a = 1;
    b = 0;
    $display("$pow(a, b) = %p", $pow(a, b));

    $finish;
  end // initial begin

endmodule : top
