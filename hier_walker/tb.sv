// Time-stamp: <2021-05-14 13:28:34 kmodi>

module top;

  reg buffer;

  test u_top_test_x(), u_top_test_y();
  test3 u_top_test3();

  initial begin
    $walk_hierarchy;
    $finish;
  end

endmodule : top

module top2;
  reg buffer;

  test u_top2_test();
  test4 u_top2_test4();
endmodule : top2

module test;
  reg buffer;

  test2 u_test_test2();
endmodule : test

module test2;
  reg buffer;
endmodule : test2

module test3;
  test u_test3_test();
  test2 u_test3_test2();
endmodule : test3

module test4;
  wire far;
  wire near;

  test u_test4_test();
endmodule : test4
