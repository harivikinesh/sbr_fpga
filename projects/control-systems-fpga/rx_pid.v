
// Module Declaration
module rx_pid(
    input clk_50m, rx,
    output reg [5:0] KP, KI, KD
);

// Parameters for State Machine Declared
parameter   idle = 2'b00, start = 2'b01, rxspm = 2'b10, stop = 2'b11, cpb = 434;

// Variable Declarations
reg [8:0] counter, temp;
reg [7:0] msg;
reg [3:0] index;
reg [1:0] present, char_index;
reg multic;

initial begin
	index = 0; msg = 0; char_index = 0;
	temp = 0; present = 0; counter = 0;
	KP = 3; KI = 1; KD = 5; multic = 0;
end


always @(posedge clk_50m) begin
	  case(present)
			idle:
				 // Idle State
				 begin
					  counter = 0; 
					  if (rx == 1'b0) present = start;
				 end

			start:
				 // Reading Start Bit
				 begin
					  if(counter == 434) begin
							present = rxspm; counter = 0;
					  end
					  else counter = counter + 1'b1;
				 end

			rxspm:
				 // Reading Data Bits
				 begin
					  counter = counter + 1'b1;
					  // Serial to Parallel Conversion
					  // Using Shift Register
					  if(counter == 15) msg <= {rx, msg[7:1]};
					  if(counter == 434) begin
							index = index + 1'b1; counter = 0;
					  end
					  if(index == 8) begin
							index = 0; present = stop;
							case (char_index)
								0: KP = temp;
								1: KI = temp;
								2: KD = temp;
								default: char_index = 0;
							endcase
							if (msg == 44) begin
								char_index = char_index + 1'b1; temp = 0;
							end
							else begin
								if (multic) temp = temp * 10;
								temp = temp + (msg - 48);
								multic = ~multic;
							end
							msg <= 0;
					  end
				 end

			stop:
				 // Reading Stop Bit
				 begin
					  if(counter == 434) present = idle;
					  counter = counter + 1'b1;
				 end
	  endcase
end

endmodule