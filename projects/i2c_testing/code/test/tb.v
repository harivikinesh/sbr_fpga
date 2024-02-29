
module tb;

reg clk, rst;
wire scl, sda;

i2c_testing_bdf uut ( clk, rst, scl, sda);

initial begin
    clk = 0; rst = 1;
end

always begin
    clk = ~clk; #10000;
end

endmodule
