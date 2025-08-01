/*
Function Nmae :	I2C_Core_Verilog

Logic			  :	Verilog Module to for an I2C Core. This Core can perform a 2 Byte read operation or a 1 Byte Write Operation. I2C Frequency is 100KHz
*/

//Verilog Module to for an I2C Core
//This Core can perform a 2 Byte read operation or a 1 Byte Write Operation
//I2C Frequency is 100KHz

module I2C_Core_Verilog(
	input clk, rst,data_valid,rw,    //data_valid tells whether the data on the input line is valid or not. rw tells whether it is a write operation(rw=0) or read oepration(rw=1)
	input [6:0]slave_addr,           //Address of the slave that needs to be accessed
	input [7:0]reg_addr, reg_data,   //Address of the register that need to be accessed and data that needs to be written to the register(in case of write operation)
	output [15:0]rrx_data,     //Data recieved from reading the specified register on the  slave
	output scl, 	 		        //I2C clock
	output busy,CS,            //when busy is high, it indicates that the core is busy, CS is the Chip select signal, it must be pulled high for I2C protocol
	inout sda              //I2C  data line. This is a bidirectional port
);

localparam I2C_CLOCK_PERIOD = 500;

//States of SCL State Machine
localparam IDLE1 			 = 2'b00;
localparam SDA_WENT_LOW 	 = 2'b01;
localparam SCL_TOGGLE 		 = 2'b10;

//States of SDA State Machine
localparam IDLE2 				= 5'b00000;
localparam START_BIT 			= 5'b00001;
localparam SLAVE_ADDR_WR		= 5'b00010;
localparam WAIT_ACK1 		    = 5'b00011;
localparam REG_ADDR 			= 5'b00100;
localparam WAIT_ACK2 			= 5'b00101;
localparam SLAVE_ADDR_RD 	    = 5'b00110;
localparam WAIT_ACK3			= 5'b00111;
localparam DATA_LSB 			= 5'b01000;
localparam SYNC_BACK 			= 5'b01001;
localparam SEND_ACK 			= 5'b01010;
localparam DATA_MSB 		    = 5'b01011;
localparam SYNC_BACK2 			= 5'b01100;
localparam SEND_NACK			= 5'b01101;
localparam STOP_BIT 			= 5'b01110;
localparam CLEANUP 				= 5'b01111;
localparam SLAVE_CTRL_WR        = 5'b10000;


reg send_slave_addr_rd       = 0;   //flag that is set when slave address in read mode is to sent
reg send_slave_addr_wr       = 0;	//flag that is set when slave address in write mode is to sent
reg slave_ack                = 0;   //Flag to indicate slave has acknowledged
reg r_i2c_read               = 0;   //If this is high, then it means a read operation has been requested
reg r_i2c_write              = 0;   //If this is high, then it means a write operation has been requested
reg r_busy                   = 0;

reg r_sda   		 		 = 1;   //local register to hold scl value
reg r_scl 	  		 		 = 1;   //local register to hold sda value
wire [15:0]rx_data			 = 0;
reg [15:0]r_rx_data       	 = 0;   //Local register to store value recived from slave
reg [15:0]r_rx_data_temp  	 = 0;   //local register into which data is shifted
reg [8:0]scl_counter 		 = 0;	//Counter to count clock cycles to control scl
reg [3:0]i2c_clk_counter     = 0;   //Counter that counts the number of scl clock cycles
reg [8:0]sda_counter 		 = 0;   //Counter to count clock cycles to control sda
reg [4:0]sda_state    		 = 0;
reg [1:0]scl_state 	 		 = 0;
reg [7:0]r_reg_data          = 0;   //This register is used to store the data that must be written to the slave
reg [7:0]r_slave_addr_wr  	 = 0; // 7 bit Address of the slave with a write bit at lsb
reg [7:0]r_slave_addr_rd  	 = 0;  //7 bit Address of the slave with a read bit at lsb
reg [7:0]r_reg_addr       	 = 0;  //8 bit Address of the X-axis data register on the accelerometer

reg prev_value_of_i2c_clock  = 0;     //Register used to store the previous value of i2c clock(scl)
reg posedge_of_i2c_clock 	 = 0;     //Register used as a flag to indicate when a rising edge of scl has occured

assign sda 		= !r_sda ? r_sda : 1'bz;   //Only drive the sda and scl line when a logic zero needs to be sent, in all other cases, leave it at high impedance.
                                                            //The sda/scl line is pulled up, so when high impedance value is set, the port gets pulled up to logic high
assign scl 		= r_scl;
assign rrx_data = r_rx_data;
assign busy    = r_busy;
assign CS  		= 1'b1;

reg dvalid=0;
reg [31:0] add=0;
reg [3:0] count=0;

//This always block is used to detect the rising egde of the I2C clock (scl)
always@(posedge clk)
begin
    if(prev_value_of_i2c_clock != r_scl)     //If previous value of scl is not equal to the present value,
                                                //Then a rising edge has occured
        posedge_of_i2c_clock <= 1;
    else
        posedge_of_i2c_clock <= 0;

    if(prev_value_of_i2c_clock)              //if prev_value_of_i2c_clock was 1, then the next change would be a negative edge
                                                //Hence reset the flag
        posedge_of_i2c_clock <= 0;

    prev_value_of_i2c_clock <= r_scl;
end


//This always block is used to control the I2C Clock.
//SCL frequency is 100kHz

always @ (posedge clk, negedge rst)
begin
    if( rst == 0)
    begin
        scl_state <= IDLE1;
    end
    else
    begin
        case(scl_state)
        //This state pulls up the clock and resets the clock
        IDLE1:
        begin
            r_scl 		<= 1;               //pullup scl
            scl_counter <= 0  ;              //Reset Counter
            if(sda_state == START_BIT)                  //Check if sda state is START_BIT
                scl_state  <= SDA_WENT_LOW;    //jump to next state when r_sda goes low
            else
                scl_state  <= IDLE1;
        end

        //This State waits for 2.5us so that scl phase is shifted by 45 degrees
        SDA_WENT_LOW:
        begin
            if(scl_counter<125)          //wait until counter reaches 125
            begin
                scl_counter <= scl_counter + 1;   //increment counter
                scl_state   <= SDA_WENT_LOW;      //stay in present state
            end
            else
            begin
                scl_counter <= 0;                 //reset counter
                scl_state   <= SCL_TOGGLE;        //Jump to next state
            end
        end

        //This State toggles SCL to generate a 400KHz I2C Clock
        SCL_TOGGLE:
        begin
            if((sda_state != CLEANUP) && (sda_state != STOP_BIT)) //If sda is not in cleanup state, toggle scl with 400kHz frequency
                begin
                scl_state 		 <= SCL_TOGGLE;
                if(scl_counter < (I2C_CLOCK_PERIOD/2)-1)    //if counter is less than half of i2c clock period,
                                                            //Wait and increment counter
                    scl_counter  <= scl_counter + 1;
                else
                begin
                    scl_counter  <= 0;                  //reset counter
                    r_scl 		 <= ~r_scl;             //Toggle r_scl when counter reaches 250(half of i2c clock period
                end
            end
            else
            begin
                if(scl_counter < (I2C_CLOCK_PERIOD/2)-1)
                begin
                    scl_counter  <= scl_counter + 1;
                    r_scl        <= 0;
                end
                else
                begin
                    r_scl			 <= 1;                 //Pullup r_scl when sda enters cleanup state
                    scl_state 		 <= IDLE1;              //return to IDLE state
                end
            end
        end
        default: scl_state <= IDLE1;
        endcase
    end
end

//This Always block is used to control the sda pin
always @ (posedge clk, negedge rst)
begin
    if(rst == 0)
    begin
        sda_state 		 <= IDLE2;    //Set the State to IDLE2
        r_slave_addr_rd <= 0;      //Reset all Registers
        r_slave_addr_wr <= 0;
        r_reg_addr      <= 0;
        r_i2c_read      <= 0;
        r_i2c_write     <= 0;
        r_busy          <= 0;
        r_rx_data       <= 0;
    end
    else
    begin
        if(data_valid)    			//when data_valid goes high, read the data on the input lines and set up the registers with necessary data
        begin
            r_busy             <= 1;
            if(rw == 1)                            //if rw = 1, it means that its a read operation
            begin
                r_slave_addr_rd <= {slave_addr,1'b1};  //load register with slave address followed by a read bit
                r_slave_addr_wr <= {slave_addr,1'b0};  //load register with slave address followed by a write bit
                r_reg_addr      <= reg_addr;           //load the register with register address
                r_i2c_read      <= 1;                  //set the i2c read flag
                r_i2c_write     <= 0;                  //reset the i2c write flag
            end
            else                                      //if rw = 0, then it means that its a write operation
            begin
                r_slave_addr_wr <= {slave_addr,1'b0};   //load register with slave address followed by a write bit
                r_reg_addr      <= reg_addr;           //load the register with register address
                r_reg_data      <= reg_data;            //load the register with the data that needs to be written
                r_i2c_read      <= 0;                   //reset the i2c read flag
                r_i2c_write     <= 1;                   //set the i2c write flag
            end
        end
        if(r_i2c_read)
        begin
            case(sda_state)
                //This State is used to reset the registers
                IDLE2:
                begin
                    r_rx_data_temp      <= 0;
                    sda_counter 	    <= 0;      //Reset counters
                    i2c_clk_counter     <= 0;
                    r_sda 			   	<= 1;      //release sda pin
                    //r_busy              <= 1;      //set the i2c core status as busy
                    slave_ack           <= 1;      //set slave acknowledge status to high(not acknowledged)
                    send_slave_addr_wr  <= 1;      //Set this to indicate that slave address must be sent
                    send_slave_addr_rd  <= 0;
                    sda_state   	    <= START_BIT;  //Jump to start bit state
                end

                //This State is used to send the Start Bit
                START_BIT:
                begin
                    if(sda_counter < I2C_CLOCK_PERIOD-1)
                    begin
                        r_sda 		<= 0;  						//reset sda to indicate start
                        sda_counter <= sda_counter + 1;
                    end
                    else
                    begin
                        sda_counter    <= 0;
                        if(send_slave_addr_wr)          //if send_slave_addr_wr go to to SLAVE_ADDR_WR state to send data
                            sda_state  <= SLAVE_ADDR_WR;
                        else if(send_slave_addr_rd)     //if send_slave_addr_wr go to to SLAVE_ADDR_RD state to send data
                            sda_state  <= SLAVE_ADDR_RD;
                        else
                            sda_state <= IDLE2;
                    end
                end

                //This State is used to send the slave address
                SLAVE_ADDR_WR:
                begin
                    if(i2c_clk_counter<8)                     //count how many scl clock cycles have elapsed
                    begin
                        send_slave_addr_wr <= 0;                  //reset send slave address flag
                        sda_state          <= SLAVE_ADDR_WR;         //remain in this state until all address bits are sent
                        if(sda_counter == 0)  	                   //send a bit and wait for 500 clock cycles
                        begin
                            i2c_clk_counter <= i2c_clk_counter + 1;
                            sda_counter     <= sda_counter+1;
                            r_sda 		    <= r_slave_addr_wr[7];   //Send the MSB bit on the sda line
                            r_slave_addr_wr <= r_slave_addr_wr<<1;   //left shift slave_addr  register to bring the next bit in line to MSB
                        end
                        else if(sda_counter < I2C_CLOCK_PERIOD)
                        begin
                            sda_counter    <= sda_counter + 1;      //Increment Counter
                        end
                        else
                            sda_counter    <= 0;                  //Reset Counter after 500 clock cycles
                    end
                    else
                    begin
                        if(sda_counter < I2C_CLOCK_PERIOD-1)        //Wait for 500 Clock cycles before going to next state
                        begin
                            sda_counter     <= sda_counter+1;
                        end
                        else
                        begin
                            sda_counter        <= 0;
                            i2c_clk_counter    <= 0;                 //reset counter
                            r_sda              <= 1;                 //release the sda line
                            sda_state          <= WAIT_ACK1;         //Go to next state
                        end
                    end
                end

                //This state is to wait for the ACK bit
                WAIT_ACK1:
                begin
                    if(sda_counter< (I2C_CLOCK_PERIOD/2) - 1)      //Wait for 250 clock cycles (1.25us)
                    begin
                        sda_counter <= sda_counter + 1;
                        sda_state   <= WAIT_ACK1;
                        slave_ack   <= sda;                       //scan the sda line store its value
                    end
                    else
                    begin
                        if(!slave_ack)                              //Check if sda pin is low, if its low, then the slave has acknowledged
                        begin
                            if(sda_counter< (I2C_CLOCK_PERIOD-1))  //Wait for 250 clockcycles before moving to next state
                            begin
                                sda_counter <= sda_counter + 1;
                                sda_state   <= WAIT_ACK1;
                            end
                            else
                            begin
                                slave_ack   <= 1;
                                sda_counter <= 0;
                                sda_state   <= REG_ADDR;
                            end
                        end
                        else
                        begin
                            if(sda_counter< (I2C_CLOCK_PERIOD-1))  //If acknowledgment was not recieved , move to clean UP state after 250 clock cycles
                            begin
                                sda_counter <= sda_counter + 1;
                                sda_state   <= WAIT_ACK1;
                            end
                            else
                            begin
                                sda_counter <= 0;
                                sda_state   <= CLEANUP;
                            end
                        end
                    end
                end

                //This state is used to send the register address to the slave
                REG_ADDR:
                begin
                    if(i2c_clk_counter<8)                      //count how many scl clock cycles have elapsed
                    begin
                        sda_state          <= REG_ADDR;         //remain in this state until all address bits are sent
                        if(sda_counter == 0)  	                //send a bit and wait for 500 clock cycles
                        begin
                            i2c_clk_counter <= i2c_clk_counter + 1;
                            sda_counter     <= sda_counter+1;
                            r_sda 		    <= r_reg_addr[7];        //Send the MSB bit on the sda line
                            r_reg_addr 	    <= r_reg_addr<<1;   			//left shift reg_addr  register to bring the next bit in line to MSB
                        end
                        else if(sda_counter < I2C_CLOCK_PERIOD)   //wait for 500 clock counts before sending next bit
                        begin
                            sda_counter    <= sda_counter + 1;     //Increment Counter
                        end
                        else
                            sda_counter 	<= 0;                 //Reset Counter after 500 clock cycles
                    end
                    else
                    begin
                        if(sda_counter < I2C_CLOCK_PERIOD-1)        //Wait for 500 Clock cycles before going to next state
                        begin
                            sda_counter     <= sda_counter+1;
                        end
                        else
                        begin
                            send_slave_addr_rd <= 1;                 //set this flag as its the next operation
                            sda_counter        <= 0;
                            i2c_clk_counter    <= 0;                 //reset counter
                            r_sda              <= 1;                 //release the sda line
                            sda_state          <= WAIT_ACK2;         //Go to next state
                        end
                    end
                end

                //This state waits for Acknowledgement from the Slave
                WAIT_ACK2:
                begin
                    if(sda_counter< (I2C_CLOCK_PERIOD/2)-1)      //Wait for 250 clock cycles (1.25us)
                    begin
                        sda_counter <= sda_counter + 1;
                        sda_state   <= WAIT_ACK2;
                        slave_ack   <= sda;
                    end
                    else
                    begin
                        if(!slave_ack)                              //Check if sda pin is low, if its low, then the slave has acknowledged
                        begin
                            if(sda_counter< (I2C_CLOCK_PERIOD-1))  //Wait for 250 clockcycles before moving to next state
                            begin
                                sda_counter <= sda_counter + 1;
                                sda_state   <= WAIT_ACK2;
                            end
                            else
                            begin
                                slave_ack   <= 1;
                                sda_counter <= 0;
                                sda_state   <= CLEANUP;
                            end
                        end
                        else
                        begin
                            if(sda_counter< (I2C_CLOCK_PERIOD-1))  //If acknowledgment was not recieved , move to clean UP state after 250 clock cycles
                            begin
                                sda_counter <= sda_counter + 1;
                                sda_state   <= WAIT_ACK2;
                            end
                            else
                            begin
                                send_slave_addr_rd <= 0;
                                sda_counter <= 0;
                                sda_state   <= CLEANUP;
                            end
                        end
                    end
                end
                //This State sends the Slave Address asking for a read operation on the previously specified register address
                SLAVE_ADDR_RD:
                begin
                    if(i2c_clk_counter<8)                     //count how many scl clock cycles have elapsed
                    begin
                        send_slave_addr_rd <= 0;                  //reset send slave address flag
                        sda_state          <= SLAVE_ADDR_RD;         //remain in this state until all address bits are sent
                        if(sda_counter == 0)  						//send a bit and wait for 500 clock cycles
                        begin
                            i2c_clk_counter <= i2c_clk_counter + 1;
                            sda_counter    <= sda_counter+1;
                            r_sda 		   <= r_slave_addr_rd[7];   //Send the MSB bit on the sda line
                            r_slave_addr_rd <= r_slave_addr_rd<<1;   //left shift slave_addr_rd  register to bring the next bit in line to MSB
                        end
                        else if(sda_counter < I2C_CLOCK_PERIOD)   //wait for 500 clock counts before sending next bit
                        begin
                            sda_counter    <= sda_counter + 1;    //Increment counter
                        end
                        else
                            sda_counter 	<= 0;               //Reset Counter after 500 clock cycles
                    end
                    else
                    begin
                        if(sda_counter < I2C_CLOCK_PERIOD-1)        //Wait for 500 Clock cycles before going to next state
                        begin
                            sda_counter     <= sda_counter+1;
                        end
                        else
                        begin
                            sda_counter        <= 0;
                            i2c_clk_counter    <= 0;                 //reset counter
                            r_sda              <= 1;                 //release the sda line
                            sda_state          <= WAIT_ACK3;         //Go to next state
                        end
                    end
                end

                //This state is to wait for the slave to send an Acknowledgement
                WAIT_ACK3:
                begin
                    if(sda_counter< (I2C_CLOCK_PERIOD/2))      //Wait for 250 clock cycles (1.25us)
                    begin
                        sda_counter <= sda_counter + 1;
                        sda_state   <= WAIT_ACK3;
                        slave_ack   <= sda;
                    end
                    else
                    begin
                        if(!slave_ack)                              //Check if sda pin is low, if its low, then the slave has acknowledged
                        begin
                            if(sda_counter< (I2C_CLOCK_PERIOD-1))  //Wait for 250 clockcycles before moving to next state
                            begin
                                sda_counter <= sda_counter + 1;
                                sda_state   <= WAIT_ACK3;
                            end
                            else
                            begin
                                slave_ack   <= 1;
                                sda_counter <= 0;
                                sda_state   <= DATA_LSB;
                            end
                        end
                        else
                        begin
                            if(sda_counter< (I2C_CLOCK_PERIOD-1))  //If acknowledgment was not recieved , move to clean UP state after 250 clock cycles
                            begin
                                sda_counter <= sda_counter + 1;
                                sda_state   <= WAIT_ACK3;
                            end
                            else
                            begin
                                sda_counter 	   <= 0;
                                sda_state          <= CLEANUP;
                            end
                        end
                    end
                end

                //This State is used to read the data on sda line and store it
                DATA_LSB:
                begin
                //	dvalid<=0;												/////////////////////////////////////////// made by ayush to tell when the data is valid////////////////////
                    if(i2c_clk_counter < 8)                     //Check if 8 bits have been recived
                    begin
                        sda_state            <= DATA_LSB;         //remain in this state until all address bits are sent
                        if(posedge_of_i2c_clock)  	             //wait for positive edge of I2C clock to read the data
                        begin
                            i2c_clk_counter   <= i2c_clk_counter +1;
                            r_rx_data_temp[7:0] <= {r_rx_data_temp[6:0], sda};   //load the bit on the sda line into a register and shift it left
                        end
                    end
                    else
                    begin
                        i2c_clk_counter    <= 0;
                        sda_state          <= SYNC_BACK;         //Go to next state
                    end
                end

                //this State is used to get back in sync with the scl
                SYNC_BACK:
                begin
                    if(sda_counter < 372)                      //wait for 372 clock cycles, this is about 75% of the scl clock cycle
                    begin
                        sda_counter <= sda_counter + 1;
                        sda_state   <= SYNC_BACK;
                    end
                    else
                    begin
                        sda_counter <= 0;                     //once this time has passed, the core is back in sync with the scl
                        sda_state   <= SEND_ACK;
                    end
                end

                //This state is used to send an Acknowledgement to the slave
                SEND_ACK:
                begin
                    if(sda_counter < I2C_CLOCK_PERIOD-1)     //Keep the sda line low for 500 clock cycles
                    begin
                        r_sda 			<= 0;
                        sda_counter 	<= sda_counter + 1;
                        sda_state       <= SEND_ACK;
                    end
                    else
                    begin
                        sda_counter     <= 0;
                        r_sda           <= 1;
                        sda_state       <= DATA_MSB;
                    end
                end

                //This state is used to reciever and store the MSB part of the data
                DATA_MSB:
                begin
                //	dvalid<=0; 												/////////////////////////////////////////// made by ayush to tell when the data is valid////////////////////
                    if(i2c_clk_counter < 8)                     //Check if 8 bits have been recived
                    begin
                        sda_state           	<= DATA_MSB;         //remain in this state until all address bits are sent
                        if(posedge_of_i2c_clock)  	             	//wait for positive edge of I2C clock to read the data
                        begin
                            i2c_clk_counter 	     <= i2c_clk_counter + 1;
                            r_rx_data_temp[15:8]  <= {r_rx_data_temp[14:8], sda};   //load the bit on the sda line into a register and shift it left
                        end
                    end
                    else
                    begin
                    //	dvalid<=1;											/////////////////////////////////////////// made by ayush to tell when the data is valid////////////////////
                        i2c_clk_counter         <= 0;
                        //r_rx_data            	<= r_rx_data_temp;   //Load the accelerometer reading into output register

                        count<=count+1;
                        add<=add+r_rx_data_temp;
                        if(count==15) begin
                            r_rx_data<=(add>>4);
                            add<=(add>>4);
                            count<=0;
                            end


                        sda_state          	    <= SYNC_BACK2;         //Go to next state
                    end
                end

                //This state is used to sync back with the scl after reading the data
                SYNC_BACK2:
                begin
                    if(sda_counter < 372)                      //wait for 372 clock cycles, this is about 75% of the scl clock cycle
                    begin
                        sda_counter <= sda_counter + 1;
                        sda_state   <= SYNC_BACK2;
                    end
                    else
                    begin
                        sda_counter <= 0;                     //once this time has passed, the core is back in sync with the scl
                        sda_state   <= SEND_NACK;
                    end
                end

                //This state is used to send the 'Not Acknowledged' Signal. This is required to end the current communication
                SEND_NACK:
                begin
                    if(sda_counter < I2C_CLOCK_PERIOD-1)     //Keep the sda line high for 500 clock cycles, this acts as a
                                                                //'Not Acknowledged' Signal
                    begin
                        r_sda 			<= 1;
                        sda_counter 	<= sda_counter + 1;
                        sda_state       <= SEND_NACK;
                    end
                    else
                    begin
                        sda_counter     <= 0;
                        r_sda           <= 1;
                        sda_state       <= STOP_BIT;
                    end
                end

                //This State is used to send Stop Bit
                STOP_BIT:
                begin
                    if(sda_counter< I2C_CLOCK_PERIOD-1)       //Keep the sda line low for one I2C clock cycle and
                                                                // let it become high after the scl line becomes high.
                                                                //This works like a Stop Bit
                    begin
                        sda_counter   <= sda_counter + 1;
                        r_sda         <= 0;
                    end
                    else
                    begin
                        sda_counter   <= 0;
                        sda_state     <= CLEANUP;
                    end
                end
                //This state pulls up the sda line and changes to the state to the next required operation based on the flags
                CLEANUP:
                begin
                    if(sda_counter < I2C_CLOCK_PERIOD-1)
                    begin
                        r_sda 		  <= 1;
                        sda_counter   <= sda_counter + 1;
                    end
                    else
                    begin
                        sda_counter   <= 0;
                        if((send_slave_addr_rd) || (send_slave_addr_wr))
                            sda_state <= START_BIT;
                        else
                        begin
                            r_i2c_read    <= 0;
                            r_busy        <= 0;             //when communication is done, indicate that the core is free
                            sda_state     <= IDLE2;
                        end
                    end
                end
            endcase
        end
        else if (r_i2c_write)
        begin
            case(sda_state)
                //This State is used to reset the registers
                IDLE2:
                begin
                    r_busy              <= 1;     //set this to indicate that the i2c core is busy
                    sda_counter 	    <= 0;     //Reset counter
                    i2c_clk_counter     <= 0;
                    r_sda 			   	<= 1;      //Pullup sda pin
                    slave_ack           <= 0;
                    send_slave_addr_wr  <= 1;     //Set this to indicate that slave address in write mode must be sent
                    sda_state   	    <= START_BIT;  //Jump to start bit state
                end

                //This State is used to send the Start Bit
                START_BIT:
                begin
                    if(sda_counter < I2C_CLOCK_PERIOD-1)
                    begin
                        r_sda 		<= 0;  						//reset sda to indicate start
                        sda_counter <= sda_counter + 1;
                    end
                    else
                    begin
                        sda_counter    <= 0;
                        if(send_slave_addr_wr)          //if send_slave_addr_wr go to to SLAVE_ADDR_WR state to send data
                            sda_state  <= SLAVE_ADDR_WR;
                        else
                            sda_state <= IDLE2;
                    end
                end

                //This State is used to send the slave address
                SLAVE_ADDR_WR:
                begin
                    if(i2c_clk_counter<8)                     //count how many scl clock cycles have elapsed
                    begin
                        send_slave_addr_wr <= 0;                  //reset send slave address flag
                        sda_state          <= SLAVE_ADDR_WR;         //remain in this state until all address bits are sent
                        if(sda_counter == 0)  	                   //send a bit and wait for 500 clock cycles
                        begin
                            i2c_clk_counter <= i2c_clk_counter + 1;
                            sda_counter     <= sda_counter+1;
                            r_sda 		    <= r_slave_addr_wr[7];   //Send the MSB bit on the sda line
                            r_slave_addr_wr   <= r_slave_addr_wr<<1;   //left shift r_slave_addr_wr  register to bring the next bit in line to MSB
                        end
                        else if(sda_counter < I2C_CLOCK_PERIOD)
                        begin
                            sda_counter    <= sda_counter + 1;      //Increment Counter
                        end
                        else
                            sda_counter    <= 0;                  //Reset Counter after 500 clock cycles
                    end
                    else
                    begin
                        if(sda_counter < I2C_CLOCK_PERIOD-1)        //Wait for 500 Clock cycles before going to next state
                        begin
                            sda_counter     <= sda_counter+1;
                        end
                        else
                        begin
                            sda_counter        <= 0;
                            i2c_clk_counter    <= 0;                 //reset counter
                            r_sda              <= 1;                 //release the sda line
                            sda_state          <= WAIT_ACK1;         //Go to next state
                        end
                    end
                end

                //This state is to wait for the ACK bit
                WAIT_ACK1:
                begin
                    if(sda_counter< (I2C_CLOCK_PERIOD/2) - 1)      //Wait for 250 clock cycles (1.25us)
                    begin
                        sda_counter <= sda_counter + 1;
                        sda_state   <= WAIT_ACK1;
                        slave_ack   <= sda;                       //scan the sda line store its value
                    end
                    else
                    begin
                        if(!slave_ack)                              //Check if sda pin is low, if its low, then the slave has acknowledged
                        begin
                            if(sda_counter< (I2C_CLOCK_PERIOD-1))  //Wait for 250 clockcycles before moving to next state
                            begin
                                sda_counter <= sda_counter + 1;
                                sda_state   <= WAIT_ACK1;
                            end
                            else
                            begin
                                slave_ack   <= 1;
                                sda_counter <= 0;
                                sda_state   <= REG_ADDR;
                            end
                        end
                        else
                        begin
                            if(sda_counter< (I2C_CLOCK_PERIOD-1))  //If acknowledgment was not recieved , move to clean UP state after 250 clock cycles
                            begin
                                sda_counter <= sda_counter + 1;
                                sda_state   <= WAIT_ACK1;
                            end
                            else
                            begin
                                sda_counter <= 0;
                                sda_state   <= CLEANUP;
                            end
                        end
                    end
                end

                REG_ADDR:
                begin
                    if(i2c_clk_counter<8)                      //count how many scl clock cycles have elapsed
                    begin
                        sda_state          <= REG_ADDR;         //remain in this state until all address bits are sent
                        if(sda_counter == 0)  	                //send a bit and wait for 500 clock cycles
                        begin
                            i2c_clk_counter <= i2c_clk_counter + 1;
                            sda_counter     <= sda_counter+1;
                            r_sda 		    <= r_reg_addr[7];        //Send the MSB bit on the sda line
                            r_reg_addr 	    <= r_reg_addr<<1;   	//left shift reg_addr  register to bring the next bit in line to MSB
                        end
                        else if(sda_counter < I2C_CLOCK_PERIOD)   //wait for 500 clock counts before sending next bit
                        begin
                            sda_counter    <= sda_counter + 1;     //Increment Counter
                        end
                        else
                            sda_counter 	<= 0;                 //Reset Counter after 500 clock cycles
                    end
                    else
                    begin
                        if(sda_counter < I2C_CLOCK_PERIOD-1)        //Wait for 500 Clock cycles before going to next state
                        begin
                            sda_counter     <= sda_counter+1;
                        end
                        else
                        begin
                            send_slave_addr_rd <= 1;                 //set this flag as its the next operation
                            sda_counter        <= 0;
                            i2c_clk_counter    <= 0;                 //reset counter
                            r_sda              <= 1;                 //release the sda line
                            sda_state          <= WAIT_ACK2;         //Go to next state
                        end
                    end
                end

                WAIT_ACK2:
                begin
                    if(sda_counter< (I2C_CLOCK_PERIOD/2)-1)      //Wait for 250 clock cycles (1.25us)
                    begin
                        sda_counter <= sda_counter + 1;
                        sda_state   <= WAIT_ACK2;
                        slave_ack   <= sda;
                    end
                    else
                    begin
                        if(!slave_ack)                              //Check if sda pin is low, if its low, then the slave has acknowledged
                        begin
                            if(sda_counter< (I2C_CLOCK_PERIOD-1))  //Wait for 250 clockcycles before moving to next state
                            begin
                                sda_counter <= sda_counter + 1;
                                sda_state   <= WAIT_ACK2;
                            end
                            else
                            begin
                                slave_ack   <= 1;
                                sda_counter <= 0;
                                sda_state   <= SLAVE_CTRL_WR;
                            end
                        end
                        else
                        begin
                            if(sda_counter< (I2C_CLOCK_PERIOD-1))  //If acknowledgment was not recieved , move to clean UP state after 250 clock cycles
                            begin
                                sda_counter <= sda_counter + 1;
                                sda_state   <= WAIT_ACK2;
                            end
                            else
                            begin
                                send_slave_addr_rd <= 0;
                                sda_counter <= 0;
                                sda_state   <= CLEANUP;
                            end
                        end
                    end
                end

                SLAVE_CTRL_WR:
                begin
                    if(i2c_clk_counter<8)                     //count how many scl clock cycles have elapsed
                    begin
                        sda_state          <= SLAVE_CTRL_WR;         //remain in this state until all address bits are sent
                        if(sda_counter == 0)  	                   //send a bit and wait for 500 clock cycles
                        begin
                            i2c_clk_counter <= i2c_clk_counter + 1;
                            sda_counter     <= sda_counter+1;
                            r_sda 		    <= r_reg_data[7];         //Send the MSB bit on the sda line
                            r_reg_data      <= r_reg_data<<1;   //left shift slave_addr_wr  register to bring the next bit in line to MSB
                        end
                        else if(sda_counter < I2C_CLOCK_PERIOD)
                        begin
                            sda_counter    <= sda_counter + 1;      //Increment Counter
                        end
                        else
                            sda_counter    <= 0;                  //Reset Counter after 500 clock cycles
                    end
                    else
                    begin
                        if(sda_counter < I2C_CLOCK_PERIOD-1)        //Wait for 500 Clock cycles before going to next state
                        begin
                            sda_counter     <= sda_counter+1;
                        end
                        else
                        begin
                            sda_counter        <= 0;
                            i2c_clk_counter    <= 0;                 //reset counter
                            r_sda              <= 1;                 //release the sda line
                            sda_state          <= STOP_BIT;         //Go to next state
                        end
                    end
                end

                //This State is used to send Stop Bit
                STOP_BIT:
                begin
                    if(sda_counter< I2C_CLOCK_PERIOD-1)       //Keep the sda line low for one I2C clock cycle and
                                                                // let it become high after the scl line becomes high.
                                                                //This works like a Stop Bit
                    begin
                        sda_counter   <= sda_counter + 1;
                        r_sda         <= 0;
                    end
                    else
                    begin
                        sda_counter   <= 0;
                        sda_state     <= CLEANUP;
                    end
                end

                //This state pulls up the sda line and changes to the state to the next required operation based on the flags
                CLEANUP:
                begin
                    if(sda_counter < I2C_CLOCK_PERIOD-1)
                    begin
                        r_sda 		  <= 1;
                        sda_counter   <= sda_counter + 1;
                    end
                    else
                    begin
                        sda_counter   <= 0;
                        r_i2c_write   <= 0;             //Reset the write flag,as operation is done
                        r_busy    	  <= 0;				//when communication is done, indicate that the core is free
                        sda_state 	  <= IDLE2;
                    end
                end
                default: sda_state <= IDLE2;
            endcase
        end
        else
            sda_state <= IDLE2;
    end
end
endmodule
