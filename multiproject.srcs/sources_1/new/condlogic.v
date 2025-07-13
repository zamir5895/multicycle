`timescale 1ns / 1ps

module condlogic (
	clk,
	reset,
	Cond,
	ALUFlags,
	FlagW,
	PCS,
	NextPC,
	RegW,
	MemW,
	PCWrite,
	RegWrite,
	MemWrite
);
	input wire clk;
	input wire reset;
	input wire [3:0] Cond;
	input wire [3:0] ALUFlags;
	input wire [1:0] FlagW;
	input wire PCS;
	input wire NextPC;
	input wire RegW;
	input wire MemW;
	output wire PCWrite;
	output wire RegWrite;
	output wire MemWrite;
	
	wire [1:0] FlagWrite;
	wire [3:0] Flags;
	wire CondEx;
	wire CondEx_out;
	
	assign FlagWrite = FlagW & {2 {CondEx}};
	
	flopenr #(2) flagr32(
		.clk(clk),
		.reset(reset),
		.en(FlagWrite[1]),
		.d(ALUFlags[3:2]),
		.q(Flags[3:2])
	);
	
	flopenr #(2) flagr10(
		.clk(clk),
		.reset(reset),
		.en(FlagWrite[0]),
		.d(ALUFlags[1:0]),
		.q(Flags[1:0])
	);
	
	condcheck condcheck(
		.Cond(Cond),
		.Flags(Flags),
		.CondEx(CondEx)
	);
	
	flopr #(1) condexre(
		.clk(clk),
		.reset(reset),
		.d(CondEx),
		.q(CondEx_out)
	);
	
	assign PCWrite = (PCS & CondEx_out) | NextPC;
	assign RegWrite = RegW & CondEx_out;
	assign MemWrite = MemW & CondEx_out;
	
endmodule