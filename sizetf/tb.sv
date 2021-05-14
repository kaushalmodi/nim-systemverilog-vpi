// Time-stamp: <2021-05-14 09:14:39 kmodi>

program top;

  initial begin
    $display("val = %0d, size = %0d", $returns_1bit_val, $bits($returns_1bit_val));
    $display("val = %0d, size = %0d", $returns_2bit_val, $bits($returns_2bit_val));
    $display("val = %0d, size = %0d", $returns_8bit_val, $bits($returns_8bit_val));
    $display("val = %0d, size = %0d", $returns_8bitsigned_val, $bits($returns_8bitsigned_val));
    $display("val = %0d, size = %0d", $returns_32bit_val, $bits($returns_32bit_val));

    $finish;
  end

endprogram : top
