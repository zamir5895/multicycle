`timescale 1ns / 1ps

// Datapath del procesador ARM multiciclo
// Contiene todos los componentes de procesamiento de datos
module datapath (
    // Señales de control
    input wire clk,
    input wire reset,
    
    // Interfaz con memoria
    output wire [31:0] Adr,          // Dirección de memoria
    output wire [31:0] WriteData,    // Datos a escribir
    input wire [31:0] ReadData,      // Datos leídos de memoria
    output wire [31:0] Instr,        // Instrucción actual
    output wire [3:0] ALUFlags,      // Flags del ALU
    
    // Señales de control del controller
    input wire PCWrite,              // Habilitación escritura PC
    input wire RegWrite,             // Habilitación escritura registros
    input wire IRWrite,              // Habilitación escritura registro instrucción
    input wire AdrSrc,               // Selector fuente dirección
    input wire [1:0] RegSrc,         // Selector registros fuente
    input wire [1:0] ALUSrcA,        // Selector operando A
    input wire [1:0] ALUSrcB,        // Selector operando B
    input wire [1:0] ResultSrc,      // Selector resultado final
    input wire [1:0] ImmSrc,         // Selector extensión inmediato
    input wire [3:0] ALUControl,     // Control operación ALU
    input wire UMullState,           // Estado segundo ciclo UMULL
    input wire SMullCondition        // Selector signed/unsigned

);

    // Señales internas del datapath
    wire [31:0] PC;                  // Program Counter
    wire [31:0] ExtImm;              // Inmediato extendido
    wire [31:0] SrcA;                // Operando A del ALU
    wire [31:0] SrcB;                // Operando B del ALU
    wire [31:0] Result;              // Resultado final a escribir
    wire [31:0] Data;                // Datos leídos de memoria
    wire [31:0] RD1;                 // Salida 1 del banco de registros
    wire [31:0] RD2;                 // Salida 2 del banco de registros
    wire [31:0] A;                   // Registro temporal A
    wire [31:0] ALUResult;           // Resultado directo del ALU
    wire [31:0] ALUOut;              // Resultado ALU registrado
    wire [3:0] RA1;                  // Dirección registro fuente 1
    wire [3:0] RA2;                  // Dirección registro fuente 2
    wire [3:0] WA3;                  // Dirección registro destino
    
    // Señales de detección de tipos de instrucción
    wire MulCondition;               // Detecta MUL
    wire UMullCondition;             // Detecta UMULL
    wire SMullCondition_internal;    // Detecta SMULL
    wire UDivCondition_internal;     // Detecta UDIV

    // Detectar tipos de multiplicación
    assign MulCondition    = (Instr[27:21] == 7'b0000000) && (Instr[7:4] == 4'b1001);
    assign UMullCondition  = (Instr[27:21] == 7'b0000100) && (Instr[7:4] == 4'b1001);
    assign SMullCondition_internal = (Instr[27:21] == 7'b0000110) && (Instr[7:4] == 4'b1001);
    assign UDivCondition_internal = (Instr[27:26] == 2'b01) && (Instr[25:21] == 5'b11000) && (Instr[7:4] == 4'b0001);

    // Combinar condiciones para multiplicaciones largas
    wire LongMullCondition = UMullCondition | SMullCondition_internal;

    
    // Registro PC con habilitación
    flopenr #(32) pcreg (
        .clk(clk),
        .reset(reset),
        .en(PCWrite),
        .d(Result),
        .q(PC)
    );

    // Selector de dirección de memoria (PC o resultado ALU)
    mux2 #(32) adrmux (
        .d0(PC),                     // PC para fetch
        .d1(Result),                 // Resultado ALU para memoria
        .s(AdrSrc),
        .y(Adr)
    );

    // Registro de instrucción con habilitación
    flopenr #(32) instreg (
        .clk(clk),
        .reset(reset),
        .en(IRWrite),
        .d(ReadData),
        .q(Instr)
    );

    // Registro de datos leídos de memoria
    flopr #(32) datareg (
        .clk(clk),
        .reset(reset),
        .d(ReadData),
        .q(Data)
    );

    
    // Selector registro fuente 1 (según tipo de instrucción)
    mux2 #(4) ra1mux (
        .d0(LongMullCondition ? Instr[3:0] :      // UMULL/SMULL: Rm
             MulCondition ? Instr[3:0] :          // MUL: Rm  
                            Instr[19:16]),        // Normal: Rn
        .d1(4'b1111),                             // R15 para algunas operaciones
        .s(RegSrc[0]),
        .y(RA1)
    );

    // Selector registro fuente 2 (según tipo de instrucción)
    mux2 #(4) ra2mux (
        .d0(LongMullCondition ? Instr[11:8] :     // UMULL/SMULL: Rs
             MulCondition ? Instr[11:8] :         // MUL: Rs
                            Instr[3:0]),          // Normal: Rm
        .d1(Instr[15:12]),                        // Rd para algunas operaciones
        .s(RegSrc[1]),
        .y(RA2)
    );

    // Selector registro destino (alterna en UMULL entre RdLo y RdHi)
    assign WA3 = LongMullCondition ?
                 (UMullState ? Instr[15:12] : Instr[19:16]) :  // UMULL: RdHi/RdLo
                 (MulCondition ? Instr[19:16] : Instr[15:12]); // MUL: Rd, Normal: Rd

    // Banco de registros
    regfile rf (
        .clk(clk),
        .we3(RegWrite),
        .ra1(RA1),
        .ra2(RA2),
        .wa3(WA3),
        .wd3(Result),
        .r15(Result),                             // R15 conectado al resultado
        .rd1(RD1),
        .rd2(RD2)
    );

    // Registros temporales para almacenar datos leídos
    floprdual #(32) regdual (
        .clk(clk),
        .reset(reset),
        .d1(RD1),
        .d2(RD2),
        .q1(A),                                   // Operando A temporal
        .q2(WriteData)                            // Datos a escribir en memoria
    );

    
    // Extensión de constantes inmediatas
    extend ext (
        .Instr(Instr[23:0]),
        .ImmSrc(ImmSrc),
        .ExtImm(ExtImm)
    );

    
    // Selector operando A del ALU (registro A o PC)
    mux2 #(32) srcamux (
        .d0(A),                                   // Dato de registro
        .d1(PC),                                  // Program Counter
        .s(ALUSrcA),
        .y(SrcA)
    );

    // Selector operando B del ALU (registro, inmediato o 4)
    mux3 #(32) srcbmux (
        .d0(WriteData),                           // Dato de registro
        .d1(ExtImm),                              // Inmediato extendido
        .d2(32'd4),                               // Constante 4 (incremento PC)
        .s(ALUSrcB),
        .y(SrcB)
    );

    // Unidad Aritmético-Lógica
    alu alu_inst (
        .SrcA(SrcA),
        .SrcB(SrcB),
        .ALUControl(ALUControl),
        .SMullCondition(SMullCondition),          // Selector signed/unsigned
        .ALUResult(ALUResult),
        .ALUFlags(ALUFlags)
    );

    // Registro de salida del ALU (para operaciones multiciclo)
    flopr #(32) aluoutreg (
        .clk(clk),
        .reset(reset),
        .d(ALUResult),
        .q(ALUOut)
    );

    
    // Selector resultado final a escribir en registro
    mux3 #(32) resultmux (
        .d0(ALUOut),                              // Resultado ALU registrado
        .d1(Data),                                // Datos de memoria
        .d2(ALUResult),                           // Resultado ALU directo
        .s(ResultSrc),
        .y(Result)
    );

endmodule