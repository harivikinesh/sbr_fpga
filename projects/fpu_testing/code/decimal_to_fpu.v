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