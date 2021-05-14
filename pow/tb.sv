// Time-stamp: <2021-05-14 00:35:11 kmodi>

module top;

  initial begin
    integer a, b;

    // Uncommenting any of the below lines will throw $finish from compiletf.
    // void'($pow);
    // void'($pow());
    // void'($pow(1));
    // void'($pow(1, 2, 3));

    $display("$pow(2, 3) = %p", $pow(2, 3));

    a = 1;
    b = 0;
    $display("$pow(a, b) = %p", $pow(a, b));

    $finish;
  end // initial begin

endmodule : top
