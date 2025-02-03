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

    // Adjust sign of b for subtraction (invert the sign)
    wire actual_sign_b = 	sign_b;

    // Align the exponents by shifting the mantissas
    wire [7:0] exp_diff;
    wire [23:0] mant_a_shifted, mant_b_shifted;
    
    assign exp_diff = (exp_a > exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);
    assign mant_a_shifted = (exp_a >= exp_b) ? mant_a : (mant_a >> exp_diff);
    assign mant_b_shifted = (exp_b >= exp_a) ? mant_b : (mant_b >> exp_diff);

    // Perform subtraction on the mantissas

    
    assign {sign_result, mant_diff} = (sign_a == actual_sign_b) ? 
        ({1'b0, mant_a_shifted} + {1'b0, mant_b_shifted}) : 
        (mant_a_shifted > mant_b_shifted ? 
            ({1'b0, mant_a_shifted} - {1'b0, mant_b_shifted}) :
            ({1'b0, mant_b_shifted} - {1'b0, mant_a_shifted}));

    // Determine the result e xponent
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