// Time-stamp: <2021-05-19 10:53:51 kmodi>

module top(I1);
  input I1;

  reg a;
  integer some_int;
  real r1;
  time t1 [31:0];

  initial begin
    $count_args(a, some_int, r1, t1);
    $count_args();
    $count_args;
    $count_args(a);
  end

endmodule : top
