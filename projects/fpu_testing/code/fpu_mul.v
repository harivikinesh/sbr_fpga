module fpu_mul(
    input [31:0] a,
    output reg [31:0] result
);

//  ieee value for 0.07s
parameter b = 32'h3d8f5c29;

reg a_sign;
reg [7:0] a_exponent;
reg [23:0] a_mantissa;
reg b_sign=0;
reg [7:0] b_exponent;
reg [23:0] b_mantissa;
reg [7:0] new_exponent;
reg [7:0] new_exponent2;
reg [22:0] product;
reg [47:0] temp_mantissa;
always @* begin
	b_sign = b[31];
   b_exponent = b[30:23];
	b_mantissa = {1'b1, b[22:0]};
  	a_sign = a[31];
   a_exponent = a[30:23];
   a_mantissa = {1'b1, a[22:0]};
   new_exponent = a_exponent + b_exponent - 127;	// Bias for single-precision
	////new_exponent2 = dividend_exponent - divisor_exponent + 126;
end
always @* begin
   temp_mantissa = a_mantissa * b_mantissa;
   product = temp_mantissa[46:23]; // Extract quotient
end

    // Check for overflow or underflow
always @* begin
   result = {a_sign, new_exponent, product};
end

endmodule