module fpu_division(
    input [31:0] dividend,
    output reg [31:0] fpu_value //Changle and Changle/2
);



reg dividend_sign;
reg [7:0] dividend_exponent;
reg [23:0] dividend_mantissa;
reg divisor_sign = 0;

// ieee value for 131
// sign exponent mantissa
// 0 1000011 000000110000000000000000
reg [7:0] divisor_exponent=8'b10000011;
reg [23:0] divisor_mantissa=24'b0000000110000000000000000;

reg [7:0] new_exponent;
reg [7:0] new_exponent2;
reg [22:0] quotient;
reg [47:0] temp_mantissa;

always @(dividend) begin
   dividend_mantissa = {1'b1, dividend[22:0]};
	dividend_sign = dividend[31];
   dividend_exponent = dividend[30:23];
   dividend_mantissa = {1'b1, dividend[22:0]};
   new_exponent = dividend_exponent - divisor_exponent + 127;	// Bias for single-precision
end
always @* begin
   temp_mantissa = {dividend_mantissa, 24'd0} / divisor_mantissa;
   quotient = temp_mantissa[23:1]; // Extract quotient
end

    // Check for overflow or underflow
always @* begin
   fpu_value = {dividend_sign, new_exponent, quotient};
end

endmodule