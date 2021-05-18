// Time-stamp: <2021-05-18 15:55:48 kmodi>

module top;

  initial begin
    // Uncommenting any of the below lines will throw $finish from compiletf.
    // void'($pow);
    // void'($pow());
    // void'($pow(1));
    // void'($pow("abc", "def"));
    // void'($pow(1, 2, 3));

    $display("$pow(2, 3) = %p", $pow(2, 3));

    begin
      integer a, b;
      // int a, b; // Uncommenting this line (and commenting out the above) will throw $finish from compiletf

      a = 1;
      b = 0;
      $display("$pow(a, b) = %p", $pow(a, b));
    end

    $finish;
  end // initial begin

endmodule : top
