`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/04/2025 10:57:45 AM
// Design Name: 
// Module Name: arm
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module arm (
	clk,
	reset,
	MemWrite,
	Adr,
	WriteData,
	ReadData
);
	// Señales de reloj y reset
	input wire clk;
	input wire reset;
	
	// Interfaz con memoria
	output wire MemWrite;        // Habilitación de escritura a memoria
	output wire [31:0] Adr;      // Dirección de memoria
	output wire [31:0] WriteData; // Datos a escribir
	input wire [31:0] ReadData;   // Datos leídos de memoria

	// Señales internas entre controller y datapath
	wire [31:0] Instr;           // Instrucción actual
	wire [3:0] ALUFlags;         // Flags del ALU (N,Z,C,V)
	wire PCWrite;                // Habilitación escritura PC
	wire RegWrite;               // Habilitación escritura registros
	wire IRWrite;                // Habilitación escritura registro instrucción
	wire AdrSrc;                 // Selector fuente dirección
	wire [1:0] RegSrc;           // Selector registros fuente
	wire [1:0] ALUSrcA;          // Selector operando A del ALU
	wire [1:0] ALUSrcB;          // Selector operando B del ALU
	wire [1:0] ImmSrc;           // Selector extensión inmediato
	wire [1:0] ResultSrc;        // Selector resultado final
	wire [3:0] ALUControl;       // Control de operación ALU
	wire UMullState;             // Estado para multiplicaciones largas
    wire SMullCondition;         // Selector signed/unsigned para MULL

	// Instancia del controlador
	controller c(
		.clk(clk),
		.reset(reset),
		.Instr(Instr),               // Instrucción a decodificar
		.ALUFlags(ALUFlags),         // Flags del ALU para condiciones
		.PCWrite(PCWrite),           // Control escritura PC
		.MemWrite(MemWrite),         // Control escritura memoria
		.RegWrite(RegWrite),         // Control escritura registros
		.IRWrite(IRWrite),           // Control escritura registro instrucción
		.AdrSrc(AdrSrc),             // Selector dirección (PC vs ALU)
		.RegSrc(RegSrc),             // Selector registros fuente
		.ALUSrcA(ALUSrcA),           // Selector operando A
		.ALUSrcB(ALUSrcB),           // Selector operando B
		.ResultSrc(ResultSrc),       // Selector resultado final
		.ImmSrc(ImmSrc),             // Selector extensión inmediato
		.ALUControl(ALUControl),     // Control operación ALU
		.UMullState(UMullState),     // Estado multiplicación larga
        .SMullCondition(SMullCondition) // Condición signed/unsigned
	);

	// Instancia del datapath
	datapath dp(
		.clk(clk),
		.reset(reset),
		.Adr(Adr),                   // Dirección de memoria
		.WriteData(WriteData),       // Datos a escribir
		.ReadData(ReadData),         // Datos leídos
		.Instr(Instr),               // Instrucción actual
		.ALUFlags(ALUFlags),         // Flags generados por ALU
		.PCWrite(PCWrite),           // Habilitación PC
		.RegWrite(RegWrite),         // Habilitación registros
		.IRWrite(IRWrite),           // Habilitación registro instrucción
		.AdrSrc(AdrSrc),             // Selector dirección
		.RegSrc(RegSrc),             // Selector registros
		.ALUSrcA(ALUSrcA),           // Selector operando A
		.ALUSrcB(ALUSrcB),           // Selector operando B
		.ResultSrc(ResultSrc),       // Selector resultado
		.ImmSrc(ImmSrc),             // Selector inmediato
		.ALUControl(ALUControl),     // Control ALU
		.UMullState(UMullState),     // Estado UMULL/SMULL
		.SMullCondition(SMullCondition) // Condición signed
	);
endmodule