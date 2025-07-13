`timescale 1ns / 1ps

// Datapath del procesador ARM multiciclo
module datapath (
    input wire clk,
    input wire reset,
    output wire [31:0] Adr,        // Dirección de memoria
    output wire [31:0] WriteData,  // Datos a escribir en memoria
    input wire [31:0] ReadData,    // Datos leídos de memoria
    output wire [31:0] Instr,      // Instrucción actual
    output wire [3:0] ALUFlags,    // Flags de la ALU (NZCV)
    input wire PCWrite,            // Habilitación de escritura del PC
    input wire RegWrite,           // Habilitación de escritura en registros
    input wire IRWrite,            // Habilitación de escritura del registro de instrucciones
    input wire AdrSrc,             // Selector de dirección (PC o Result)
    input wire [1:0] RegSrc,       // Selector de registros fuente
    input wire [1:0] ALUa,         // Selector de entrada A de ALU
    input wire [1:0] ALUb,         // Selector de entrada B de ALU
    input wire [1:0] ResultSrc,    // Selector de resultado final
    input wire [1:0] ImmSrc,       // Selector de inmediato extendido
    input wire [3:0] ALUControl,   // Control de operación ALU
    input wire UMullState,
    input wire CondSMull,
    input wire CondFAdd,
    input wire CondFMull   
);

    wire [31:0] PC;
    wire [31:0] ExtImm;           // Inmediato extendido
    wire [31:0] a;                // Operando A de ALU
    wire [31:0] b;                // Operando B de ALU
    wire [31:0] Result;           // Resultado final del datapath
    wire [31:0] Data;             // Datos de memoria almacenados
    wire [31:0] RD1;              // Datos del registro 1
    wire [31:0] RD2;              // Datos del registro 2
    wire [31:0] A;                // Registro A almacenado
    wire [31:0] ALUResult;        // Resultado directo de ALU
    wire [31:0] ALUOut;           // Resultado de ALU almacenado
    wire [3:0] RA1;               // Dirección del registro fuente 1
    wire [3:0] RA2;               // Dirección del registro fuente 2
    wire [3:0] WriteRegAddr;      // Dirección del registro destino
    wire MulCond;
    wire UMulCond;
    wire SMulCondI;
    wire FPCond;  

    // Detectar MUL, UMULL, SMULL
    assign MulCond    = (Instr[27:21] == 7'b0000000) && (Instr[7:4] == 4'b1001);
    assign UMulCond  = (Instr[27:21] == 7'b0000100) && (Instr[7:4] == 4'b1001);
    assign SMulCondI = (Instr[27:21] == 7'b0000110) && (Instr[7:4] == 4'b1001);
    
    // detectar si es fp
    assign FPCond = CondFAdd | CondFMull;

    // Combinar cond de smull y umull
    wire LongMullCondition = UMulCond | SMulCondI;

    // Registro contador de programa (PC)
    flopenr #(32) pcrg (
        .clk(clk),
        .reset(reset),
        .en(PCWrite),
        .d(Result),
        .q(PC)
    );

    // Multiplexor para seleccionar dirección de memoria
    mux2 #(32) adrmux (
        .d0(PC),
        .d1(Result),
        .s(AdrSrc),
        .y(Adr)
    );

    // Registro de instrucciones
    flopenr #(32) instuctreg (
        .clk(clk),
        .reset(reset),
        .en(IRWrite),
        .d(ReadData),
        .q(Instr)
    );
    
    // Registro de datos leídos de memoria
    flopr #(32) datarg (
        .clk(clk),
        .reset(reset),
        .d(ReadData),
        .q(Data)
    );

    // Multiplexor para dirección de registro fuente 1
    mux2 #(4) a1mux (
        .d0(FPCond ? Instr[19:16] :    
             LongMullCondition ? Instr[3:0] : 
             MulCond ? Instr[3:0] :
                            Instr[19:16]),
        .d1(4'b1111),
        .s(RegSrc[0]),
        .y(RA1)
    );

    // Multiplexor para dirección de registro fuente 2
    mux2 #(4) a2mux (
        .d0(FPCond ? Instr[3:0] :      
             LongMullCondition ? Instr[11:8] : 
             MulCond ? Instr[11:8] :
                            Instr[3:0]),
        .d1(Instr[15:12]),
        .s(RegSrc[1]),
        .y(RA2)
    );

    // Selector de registro destino según tipo de instrucción
    assign WriteRegAddr = FPCond ? Instr[15:12] :          
                 LongMullCondition ?
                 (UMullState ? Instr[15:12] : Instr[19:16]) :
                 (MulCond ? Instr[19:16] : Instr[15:12]);

    // Banco de registros
    regfile rf (
        .clk(clk),
        .we3(RegWrite),
        .ra1(RA1),
        .ra2(RA2),
        .WriteRegAddr(WriteRegAddr),
        .wd3(Result),
        .r15(Result),
        .rd1(RD1),
        .rd2(RD2)
    );

    // Registros para almacenar datos leídos del banco
    floprdual #(32) regdual (
        .clk(clk),
        .reset(reset),
        .d1(RD1),
        .d2(RD2),
        .q1(A),
        .q2(WriteData)
    );

    // Extensor de inmediatos
    extend ext (
        .Instr(Instr[23:0]),
        .ImmSrc(ImmSrc),
        .ExtImm(ExtImm)
    );

    // Multiplexor para entrada A de ALU
    mux3 #(32) amux (
        .d0(A),
        .d1(PC),
        .d2(32'd0),
        .s(ALUa),
        .y(a)
    );

    // Multiplexor para entrada B de ALU
    mux3 #(32) bmux (
        .d0(WriteData),
        .d1(ExtImm),
        .d2(32'd4),
        .s(ALUb),
        .y(b)
    );

    // Unidad aritmético-lógica
    alu alu_inst (
        .a(a),
        .b(b),
        .ALUControl(ALUControl),
        .CondSMull(CondSMull),
        .CondFAdd(CondFAdd),  
        .CondFMull(CondFMull),  
        .InstrRd(Instr[15:12]),        
        .ALUResult(ALUResult),
        .ALUFlags(ALUFlags)
    );

    // Registro de salida de ALU
    flopr #(32) aluoutreg (
        .clk(clk),
        .reset(reset),
        .d(ALUResult),
        .q(ALUOut)
    );

    // Multiplexor para resultado final
    mux3 #(32) resultmux (
        .d0(ALUOut),
        .d1(Data),
        .d2(ALUResult),
        .s(ResultSrc),
        .y(Result)
    );

endmodule