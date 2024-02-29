

module process_data (
    input [15:0] data,
    output reg [15:0] gyro_x
);

always @(data) begin
    gyro_x = data >> 7;
end

endmodule