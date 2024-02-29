
module motor_control (
    input clk, reset,
    input [1:0] direction,
    input [1:0] r_enc, l_enc,
    input [7:0] velocity,
    output reg enA, In1, In2,
    output reg enB, In3, In4,
    output reg [9:0] r_counter, l_counter
);

// counters for encoders
// reg [9:0] r_counter, l_counter;
reg [9:0] prev_rcnt, prev_lcnt;

initial begin
    enA = 0; In1 = 0; In2 = 0;
    enB = 0; In3 = 0; In4 = 0;
    r_counter = 0; l_counter = 0;
    prev_rcnt = 0; prev_lcnt = 0;
end

always @(posedge clk) begin
    if (!reset) begin
        enA = 0; enB = 0;
    end
    else begin
        case (direction)
            0: //forward
            begin
                enA = 0; enB = 0;
                In1 = 0; In2 = 0;
                In3 = 0; In4 = 0;
            end
            1: //backward
            begin
                enA = 1; enB = 1;
                In1 = 1; In2 = 0;
                In3 = 1; In4 = 0;
            end
            2: //stop
            begin
                enA = 1; enB = 1;
                In1 = 0; In2 = 1;
                In3 = 0; In4 = 1;
            end
        endcase
    end
end

always @(posedge r_enc[0]) begin
    if (r_enc[1]) r_counter = r_counter + 1'b1;
    else r_counter = r_counter - 1'b1;
end

always @(posedge l_enc[0]) begin
    if (l_enc[1]) l_counter = l_counter + 1'b1;
    else l_counter = l_counter - 1'b1;
end

endmodule
