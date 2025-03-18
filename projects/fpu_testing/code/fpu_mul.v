module fpu_mul(
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result
);

   wire sign_a = a[31];
   wire sign_b = b[31];
   wire sign_result;

   wire [7:0] exp_a = a[30:23];
   wire [7:0] exp_b = b[30:23];
   wire [7:0] new_exp;
   reg [7:0] final_exp;

   wire [23:0] mant_a = {1'b1, a[22:0]}; // Add the implicit leading 1
   wire [23:0] mant_b = {1'b1, b[22:0]}; // Add the implicit leading 1
   wire [47:0] temp_mant;
   reg [22:0] final_mant;

   // compute sign bit
   assign sign_result = sign_a ^ sign_b;

   // Add baised exponenet
   assign new_exp = exp_a + exp_b - 8'd127;

   // Multiply the mantissa,
   assign temp_mant = mant_a * mant_b;

   // Handle 48 bit temporary mantissa
   always @* begin
          if (temp_mant[47]) begin  // overflow checking
              final_mant = temp_mant[46:24];
              final_exp = new_exp + 1;
          end else begin
              final_mant = temp_mant[45:23];
              final_exp = new_exp;
          end
      end

    // final result representation
    always @* begin
      result = {sign_result,final_exp,final_mant};
    end

endmodule