module fpu_division(
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result
);

   // extract sign
   wire sign_a = a[31];
   wire sign_b = b[31];

   // extract exponent.
   wire [7:0] exp_a = a[30:23];
   wire [7:0] exp_b = b[30:23];
   wire [7:0] new_exp;

   // extract mantissa.
   wire [23:0] mant_a = {1'b1,a[22:0]};
   wire [23:0] mant_b = {1'b1,b[22:0]};
   wire [47:0] temp_mant;
   wire [22:0] final_mant;

   // compute sign
   wire sign_result = sign_a ^ sign_b;

   // Compute exponent.
   assign new_exp = (exp_a - exp_b) + 8'd127;

   // Divide Mantissas
   assign temp_mant = {mant_a,24'b0}/ mant_b;
   assign final_mant = temp_mant[23:1];

    // fpu value representation.
   always @* begin
      result = {sign_result, new_exp, final_mant};
   end

endmodule