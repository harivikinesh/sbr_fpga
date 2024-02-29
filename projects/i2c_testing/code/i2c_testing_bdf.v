// Copyright (C) 2020  Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions
// and other software and tools, and any partner logic
// functions, and any output files from any of the foregoing
// (including device programming or simulation files), and any
// associated documentation or information are expressly subject
// to the terms and conditions of the Intel Program License
// Subscription Agreement, the Intel Quartus Prime License Agreement,
// the Intel FPGA IP License Agreement, or other applicable license
// agreement, including, without limitation, that your use is for
// the sole purpose of programming logic devices manufactured by
// Intel and sold by Intel or its authorized distributors.  Please
// refer to the applicable agreement for further details, at
// https://fpgasoftware.intel.com/eula.

// PROGRAM		"Quartus Prime"
// VERSION		"Version 20.1.1 Build 720 11/11/2020 SJ Lite Edition"
// CREATED		"Tue Feb 27 10:45:46 2024"

module i2c_testing_bdf (
	clk,
	rst,
	scl,
	sda
);


input wire	clk;
input wire	rst;
output wire	scl;
inout wire	sda;

wire	SYNTHESIZED_WIRE_0;
wire	SYNTHESIZED_WIRE_1;
wire	SYNTHESIZED_WIRE_2;
wire	[7:0] SYNTHESIZED_WIRE_3;
wire	[7:0] SYNTHESIZED_WIRE_4;
wire	[6:0] SYNTHESIZED_WIRE_5;
wire	[15:0] SYNTHESIZED_WIRE_6;





I2C_Controller	b2v_inst(
	.clk(clk),
	.rst(rst),
	.core_busy(SYNTHESIZED_WIRE_0),
	.data_valid(SYNTHESIZED_WIRE_1),
	.rw(SYNTHESIZED_WIRE_2),
	.reg_addr(SYNTHESIZED_WIRE_3),
	.reg_data(SYNTHESIZED_WIRE_4),
	.slave_addr(SYNTHESIZED_WIRE_5));



I2C_Core_Verilog	b2v_inst6(
	.clk(clk),
	.rst(rst),
	.data_valid(SYNTHESIZED_WIRE_1),
	.rw(SYNTHESIZED_WIRE_2),
	.sda(sda),
	.reg_addr(SYNTHESIZED_WIRE_3),
	.reg_data(SYNTHESIZED_WIRE_4),
	.slave_addr(SYNTHESIZED_WIRE_5),
	.scl(scl),
	.busy(SYNTHESIZED_WIRE_0),


	.rrx_data(SYNTHESIZED_WIRE_6));


process_data	b2v_inst7(
	.data(SYNTHESIZED_WIRE_6)
	);


endmodule
