module tb();

reg [31:0] a, b;
wire [31:0] result;

fpu_mul uut(.a(a),.b(b),.result(result));

initial begin
    a = 32'h40600000;  // 3.5
    b = 32'h40200000;  // 2.5
    #10;
end

// 3.5 x 2.5 = 8.75
initial begin
    $monitor("a:%0h, b:%0h, result:%0h",a,b,result);
end

endmodule