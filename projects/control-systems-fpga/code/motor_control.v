
module motor_control (
    input clk, reset,
    input [15:0] accel_y,
    input [1:0] r_enc, l_enc,
    output reg In1, In2, In3, In4,
    output reg pwm,
    // counters for encoders
    output reg [9:0] r_counter, l_counter,
    output reg [7:0] led
);

reg [19:0] cal_sum;
reg [15:0] set_point, temp;
reg [8:0] angle, pid;
reg [7:0] error, prev_val, error_sum, counter;
reg [5:0] KP = 1, KI = 0, KD = 5;
reg [3:0] cal_counter;
reg [1:0] direction;
reg calibrate;

initial begin
    cal_sum = 0; calibrate = 1; set_point = 0; temp = 0;
    direction = 0; prev_val = 0; angle = 0;
    error_sum = 0; counter = 0; pid = 255;
    In1 = 0; In2 = 0; In3 = 0; In4 = 0;
    r_counter = 0; l_counter = 0;
end

always @(posedge clk) begin
    if (!reset) begin
        set_point = 0; cal_counter = 0; led = 8'd0;
        calibrate = 1; cal_sum = 0; direction = 0;
    end
    else begin
        // calibration
        if (calibrate) begin
            if (temp != accel_y) begin
                if (cal_counter > 7) cal_sum = cal_sum + accel_y;
                if (cal_counter == 15) begin
                    set_point = cal_sum >> 3;
                    calibrate = 0; led = 8'd255;
                end
                cal_counter = cal_counter + 1'b1;
                temp = accel_y;
            end
        end
        else begin
            // direction control
            angle = (accel_y - set_point);
            // angle = ~angle = 1'b1;
            if (angle > -3 || angle < 3) direction = 0;
            else if (angle > 3 && angle < 170) direction = 2;
            else if (angle < -3) direction = 1;
        end
    end
end

// pid controller
always @(posedge clk) begin
    if (!reset) begin
        pwm = 0; pid = 0;
    end
    else begin
        if (prev_val != angle) begin
            pid = KP * angle + KI * error_sum + KD * (angle - prev_val);
            // direction control
            case (direction)
                0: begin // stop
                    In1 = 0; In2 = 0; In3 = 0; In4 = 0;
                end
                1: begin // forward
                    In1 = 1; In2 = 0; In3 = 1; In4 = 0;
                end
                2: begin // backward
                    In1 = 0; In2 = 1; In3 = 0; In4 = 1;
                end
            endcase
            prev_val = angle;
            // if (counter < 10) begin

            // end
        end
        if (pid > 255) begin
            pid = 255; pwm = 1;
        end
        else if (counter < pid) pwm = 1;
        else pwm = 0;
        counter = counter + 1'b1;
    end
end

always @(posedge r_enc[0]) begin
    if (!reset) r_counter = 0;
    if (r_enc[1]) r_counter = r_counter + 1'b1;
    else r_counter = r_counter - 1'b1;
end

always @(posedge l_enc[0]) begin
    if (!reset) l_counter = 0;
    if (l_enc[1]) l_counter = l_counter + 1'b1;
    else l_counter = l_counter - 1'b1;
end

endmodule
