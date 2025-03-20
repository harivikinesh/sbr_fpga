module controller(
    input [31:0] a,
    input [31:0] b,
    input [1:0] opcode,
    output reg [31:0] result
);
wire [31:0] add_result, mul_result, div_result;
wire [31:0] fpu_a, fpu_b;

decimal_to_fpu D_to_F1(.dec(a), .fpu(fpu_a));
decimal_to_fpu D_to_F2(.dec(b), .fpu(fpu_b));

fpu_adder ADD(.a(fpu_a),.b(fpu_b),.result(add_result));
fpu_mul MUL(.a(fpu_a),.b(fpu_b),.result(mul_result));
fpu_division DIV(.a(fpu_a),.b(fpu_b),.result(div_result));

always @* begin
    case(opcode)
    2'b01:begin result = add_result; end
    2'b10:begin result = mul_result; end
    2'b11:begin result = div_result; end
    default: result = 32'b0;
    endcase
end

endmodule

module decimal_to_fpu(
    input [31:0] dec,
    output [31:0] fpu
);
    wire sign;
    wire [31:0] abs_value;
    wire [7:0] exponent;
    wire [22:0] mantissa;
    wire [31:0] normalized_value;
    wire [4:0] leading_zeros;
    wire [7:0] biased_exponent;

    // Sign bit
    assign sign = dec[31];

    // Absolute value
    assign abs_value = sign ? -dec : dec;

    // Normalize the absolute value
    Normalize normalize_inst(
        .value(abs_value),
        .normalized_value(normalized_value),
        .leading_zeros(leading_zeros)
    );

    // Calculate the biased exponent
    assign biased_exponent = 8'd127 + 8'd31 - {3'b0, leading_zeros};

    // Extract the mantissa
    assign mantissa = normalized_value[30:8];

    // Assemble the IEEE 754 format
    assign fpu = {sign, biased_exponent, mantissa};

endmodule

module Normalize(
    input [31:0] value,
    output reg [31:0] normalized_value,
    output reg [4:0] leading_zeros
);
    always @* begin
        // Determine the number of leading zeros
        if (value[31]) begin
            leading_zeros = 5'd0;
            normalized_value = value;
        end else if (value[30]) begin
            leading_zeros = 5'd1;
            normalized_value = value << 1;
        end else if (value[29]) begin
            leading_zeros = 5'd2;
            normalized_value = value << 2;
        end else if (value[28]) begin
            leading_zeros = 5'd3;
            normalized_value = value << 3;
        end else if (value[27]) begin
            leading_zeros = 5'd4;
            normalized_value = value << 4;
        end else if (value[26]) begin
            leading_zeros = 5'd5;
            normalized_value = value << 5;
        end else if (value[25]) begin
            leading_zeros = 5'd6;
            normalized_value = value << 6;
        end else if (value[24]) begin
            leading_zeros = 5'd7;
            normalized_value = value << 7;
        end else if (value[23]) begin
            leading_zeros = 5'd8;
            normalized_value = value << 8;
        end else if (value[22]) begin
            leading_zeros = 5'd9;
            normalized_value = value << 9;
        end else if (value[21]) begin
            leading_zeros = 5'd10;
            normalized_value = value << 10;
        end else if (value[20]) begin
            leading_zeros = 5'd11;
            normalized_value = value << 11;
        end else if (value[19]) begin
            leading_zeros = 5'd12;
            normalized_value = value << 12;
        end else if (value[18]) begin
            leading_zeros = 5'd13;
            normalized_value = value << 13;
        end else if (value[17]) begin
            leading_zeros = 5'd14;
            normalized_value = value << 14;
        end else if (value[16]) begin
            leading_zeros = 5'd15;
            normalized_value = value << 15;
        end else if (value[15]) begin
            leading_zeros = 5'd16;
            normalized_value = value << 16;
        end else if (value[14]) begin
            leading_zeros = 5'd17;
            normalized_value = value << 17;
        end else if (value[13]) begin
            leading_zeros = 5'd18;
            normalized_value = value << 18;
        end else if (value[12]) begin
            leading_zeros = 5'd19;
            normalized_value = value << 19;
        end else if (value[11]) begin
            leading_zeros = 5'd20;
            normalized_value = value << 20;
        end else if (value[10]) begin
            leading_zeros = 5'd21;
            normalized_value = value << 21;
        end else if (value[9]) begin
            leading_zeros = 5'd22;
            normalized_value = value << 22;
        end else if (value[8]) begin
            leading_zeros = 5'd23;
            normalized_value = value << 23;
        end else if (value[7]) begin
            leading_zeros = 5'd24;
            normalized_value = value << 24;
        end else if (value[6]) begin
            leading_zeros = 5'd25;
            normalized_value = value << 25;
        end else if (value[5]) begin
            leading_zeros = 5'd26;
            normalized_value = value << 26;
        end else if (value[4]) begin
            leading_zeros = 5'd27;
            normalized_value = value << 27;
        end else if (value[3]) begin
            leading_zeros = 5'd28;
            normalized_value = value << 28;
        end else if (value[2]) begin
            leading_zeros = 5'd29;
            normalized_value = value << 29;
        end else if (value[1]) begin
            leading_zeros = 5'd30;
            normalized_value = value << 30;
        end else begin
            leading_zeros = 5'd31;
            normalized_value = value << 31;
        end
    end
endmodule

module fpu_adder(
    input [31:0] a,      // First IEEE 754 number
    input [31:0] b,      // Second IEEE 754 number
    output [31:0] result // Result of the subtraction
);
    // Split the inputs into sign, exponent, and mantissa
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [23:0] mant_a = {1'b1, a[22:0]}; // Add the implicit leading 1
    wire [23:0] mant_b = {1'b1, b[22:0]}; // Add the implicit leading 1
    wire [24:0] mant_diff;
    wire sign_result;

    wire _subtract = (sign_a ^ sign_b);

    // Align the exponents by shifting the mantissas
    wire [7:0] exp_diff;
    wire [23:0] mant_a_shifted, mant_b_shifted;

    // compare exponent.
    assign exp_diff = (exp_a > exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);

    // shift mantissa by the exp_diff
    assign mant_a_shifted = (exp_a >= exp_b) ? mant_a : (mant_a >> exp_diff);
    assign mant_b_shifted = (exp_b >= exp_a) ? mant_b : (mant_b >> exp_diff);

    // Perform addition and subtraction on the mantissas
//     assign {sign_result, mant_diff} = (_subtract) ? ({1'b0, mant_a_shifted} + {1'b0, mant_b_shifted}) : (mant_a_shifted > mant_b_shifted ? ({1'b0, mant_a_shifted} - {1'b0, mant_b_shifted}) : ({1'b0, mant_b_shifted} - {1'b0, mant_a_shifted}));
// sign_result

    assign {sign_result, mant_diff} = _subtract ? (mant_a_shifted > mant_b_shifted ? ({1'b0, mant_a_shifted} - {1'b0,mant_b_shifted}) : ({1'b0, mant_b_shifted} - {1'b0,mant_a_shifted})) : ({1'b0,mant_a_shifted} + {1'b0,mant_b_shifted});

    // Determine the result exponent
    wire [7:0] exp_result;
    assign exp_result =(exp_a >= exp_b) ? exp_a : exp_b;

    // Normalize the result without a for loop
    wire [23:0] mant_norm;
    wire [7:0] final_exp_result;
    wire [4:0] leading_zeroes;

    // Leading zero detector for the 24-bit mantissa
    assign leading_zeroes = (mant_diff[23] ? 5'd0 :
                            mant_diff[22] ? 5'd1 :
                            mant_diff[21] ? 5'd2 :
                            mant_diff[20] ? 5'd3 :
                            mant_diff[19] ? 5'd4 :
                            mant_diff[18] ? 5'd5 :
                            mant_diff[17] ? 5'd6 :
                            mant_diff[16] ? 5'd7 :
                            mant_diff[15] ? 5'd8 :
                            mant_diff[14] ? 5'd9 :
                            mant_diff[13] ? 5'd10 :
                            mant_diff[12] ? 5'd11 :
                            mant_diff[11] ? 5'd12 :
                            mant_diff[10] ? 5'd13 :
                            mant_diff[9]  ? 5'd14 :
                            mant_diff[8]  ? 5'd15 :
                            mant_diff[7]  ? 5'd16 :
                            mant_diff[6]  ? 5'd17 :
                            mant_diff[5]  ? 5'd18 :
                            mant_diff[4]  ? 5'd19 :
                            mant_diff[3]  ? 5'd20 :
                            mant_diff[2]  ? 5'd21 :
                            mant_diff[1]  ? 5'd22 : 5'd23);

    // Adjust mantissa and exponent based on leading zeroes
    assign mant_norm = mant_diff << leading_zeroes;
    assign final_exp_result = exp_result - leading_zeroes;

    // Combine the result sign, exponent, and mantissa
    assign result = {sign_result, final_exp_result, mant_norm[22:0]};

endmodule

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