`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/04/2025 11:18:01 AM
// Design Name: 
// Module Name: datapath
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

module datapath (
    input wire clk,
    input wire reset,
    output wire [31:0] Adr,
    output wire [31:0] WriteData,
    input wire [31:0] ReadData,
    output wire [31:0] Instr,
    output wire [3:0] ALUFlags,
    input wire PCWrite,
    input wire RegWrite,
    input wire IRWrite,
    input wire AdrSrc,
    input wire [1:0] RegSrc,
    input wire [1:0] ALUSrcA,
    input wire [1:0] ALUSrcB,
    input wire [1:0] ResultSrc,
    input wire [1:0] ImmSrc,
    input wire [3:0] ALUControl,
    input wire UMullState,  // entrada para identificar el estado en el que estamos del umull
    input wire SMullCondition  // Condicion de smull

);

    wire [31:0] PC;
    wire [31:0] ExtImm;
    wire [31:0] SrcA;
    wire [31:0] SrcB;
    wire [31:0] Result;
    wire [31:0] Data;
    wire [31:0] RD1;
    wire [31:0] RD2;
    wire [31:0] A;
    wire [31:0] ALUResult;
    wire [31:0] ALUOut;
    wire [3:0] RA1;
    wire [3:0] RA2;
    wire [3:0] WA3;
    wire MulCondition;
    wire UMullCondition;
    wire SMullCondition_i; 


    // Detectar MUL y UMULL
    assign MulCondition    = (Instr[27:21] == 7'b0000000) && (Instr[7:4] == 4'b1001);
    assign UMullCondition  = (Instr[27:21] == 7'b0000100) && (Instr[7:4] == 4'b1001);
    assign SMullCondition_i = (Instr[27:21] == 7'b0000110) && (Instr[7:4] == 4'b1001);  // detectamos si es smull

    wire LongMullCondition = UMullCondition | SMullCondition_i;

    flopenr #(32) pcreg (
        .clk(clk),
        .reset(reset),
        .en(PCWrite),
        .d(Result),
        .q(PC)
    );

    mux2 #(32) adrmux (
        .d0(PC),
        .d1(Result),
        .s(AdrSrc),
        .y(Adr)
    );

    flopenr #(32) instreg (
        .clk(clk),
        .reset(reset),
        .en(IRWrite),
        .d(ReadData),
        .q(Instr)
    );

    flopr #(32) datareg (
        .clk(clk),
        .reset(reset),
        .d(ReadData),
        .q(Data)
    );

    mux2 #(4) ra1mux (
        .d0(LongMullCondition ? Instr[3:0] : 
             MulCondition ? Instr[3:0] :
                            Instr[19:16]),
        .d1(4'b1111),
        .s(RegSrc[0]),
        .y(RA1)
    );

    mux2 #(4) ra2mux (
        .d0(LongMullCondition ? Instr[11:8] : 
             MulCondition ? Instr[11:8] :
                            Instr[3:0]),
        .d1(Instr[15:12]),
        .s(RegSrc[1]),
        .y(RA2)
    );

    assign WA3 = LongMullCondition ?
                 (UMullState ? Instr[15:12] : Instr[19:16]) :
                 (MulCondition ? Instr[19:16] : Instr[15:12]);

    regfile rf (
        .clk(clk),
        .we3(RegWrite),
        .ra1(RA1),
        .ra2(RA2),
        .wa3(WA3),
        .wd3(Result),
        .r15(Result),
        .rd1(RD1),
        .rd2(RD2)
    );

    floprdual #(32) regdual (
        .clk(clk),
        .reset(reset),
        .d1(RD1),
        .d2(RD2),
        .q1(A),
        .q2(WriteData)
    );

    extend ext (
        .Instr(Instr[23:0]),
        .ImmSrc(ImmSrc),
        .ExtImm(ExtImm)
    );

    mux2 #(32) srcamux (
        .d0(A),
        .d1(PC),
        .s(ALUSrcA),
        .y(SrcA)
    );

    mux3 #(32) srcbmux (
        .d0(WriteData),
        .d1(ExtImm),
        .d2(32'd4),
        .s(ALUSrcB),
        .y(SrcB)
    );

    alu alu_inst (
        .SrcA(SrcA),
        .SrcB(SrcB),
        .ALUControl(ALUControl),
        .isSMULL(SMullCondition),  // condicion de smull
        .ALUResult(ALUResult),
        .ALUFlags(ALUFlags)
    );

    // Registro de salida del ALU
    flopr #(32) aluoutreg (
        .clk(clk),
        .reset(reset),
        .d(ALUResult),
        .q(ALUOut)
    );

    // Selección de resultado para escribir en registro
    mux3 #(32) resultmux (
        .d0(ALUOut),
        .d1(Data),
        .d2(ALUResult),
        .s(ResultSrc),
        .y(Result)
    );

endmodule