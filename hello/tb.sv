// Time-stamp: <2021-05-18 16:46:31 kmodi>

program top;

  initial begin
    $hello;
    $bye;
    $bye(); // Nim svvpi considers this also as 0 arguments

    // Uncommenting below line will throw $finish from compiletf.
    // $bye(1);

    $finish;
  end

endprogram : top
