`timescale 1ns / 1ps

// Controlador principal del procesador ARM multiciclo
// Coordina el decoder y la lógica condicional
module controller (
    clk,
    reset,
    Instr,
    ALUFlags,
    PCWrite,
    MemWrite,
    RegWrite,
    IRWrite,
    AdrSrc,
    RegSrc,
    ALUSrcA,
    ALUSrcB,
    ResultSrc,
    ImmSrc,
    ALUControl,
    UMullState,
    SMullCondition  // Selector signed/unsigned
);
    // Entradas
    input wire clk;                  // Reloj del sistema
    input wire reset;                // Reset del sistema
    input wire [31:0] Instr;         // Instrucción actual
    input wire [3:0] ALUFlags;       // Flags del ALU (N,Z,C,V)
    
    // Salidas de control
    output wire PCWrite;             // Habilitación escritura PC
    output wire MemWrite;            // Habilitación escritura memoria
    output wire RegWrite;            // Habilitación escritura registros
    output wire IRWrite;             // Habilitación escritura registro instrucción
    output wire AdrSrc;              // Selector fuente dirección
    output wire [1:0] RegSrc;        // Selector registros fuente
    output wire [1:0] ALUSrcA;       // Selector operando A del ALU
    output wire [1:0] ALUSrcB;       // Selector operando B del ALU
    output wire [1:0] ResultSrc;     // Selector resultado final
    output wire [1:0] ImmSrc;        // Selector extensión inmediato
    output wire [3:0] ALUControl;    // Control operación ALU
    output wire UMullState;          // Estado para multiplicaciones largas
    output wire SMullCondition;      // Selector signed/unsigned para MULL
    
    // Señales internas
    wire [1:0] FlagW;                // Control actualización flags
    wire PCS;                        // Escritura PC con condición
    wire NextPC;                     // Incremento PC
    wire RegW;                       // Escritura registro sin condición
    wire MemW;                       // Escritura memoria sin condición

    // Instancia del decodificador
    decode dec(
        .clk(clk),
        .reset(reset),
        .Op(Instr[27:26]),           // Tipo de operación
        .Funct(Instr[25:20]),        // Función específica
        .Rd(Instr[15:12]),           // Registro destino
        .InstrLow(Instr[7:4]),       // Bits bajos de instrucción
        .UMullState(UMullState),     // Estado multiplicación larga
        .FlagW(FlagW),               // Control actualización flags
        .PCS(PCS),                   // PC con condición
        .NextPC(NextPC),             // Incremento PC
        .RegW(RegW),                 // Escritura registro
        .MemW(MemW),                 // Escritura memoria
        .IRWrite(IRWrite),           // Control registro instrucción
        .AdrSrc(AdrSrc),             // Selector dirección
        .ResultSrc(ResultSrc),       // Selector resultado
        .ALUSrcA(ALUSrcA),           // Selector operando A
        .ALUSrcB(ALUSrcB),           // Selector operando B
        .ImmSrc(ImmSrc),             // Selector inmediato
        .RegSrc(RegSrc),             // Selector registros
        .ALUControl(ALUControl),     // Control ALU
        .UMullCondition(),           // No se usa externamente
        .SMullCondition(SMullCondition) // Condición signed/unsigned
    );
    
    // Instancia de lógica condicional
    condlogic cl(
        .clk(clk),
        .reset(reset),
        .Cond(Instr[31:28]),         // Condición de la instrucción
        .ALUFlags(ALUFlags),         // Flags del ALU
        .FlagW(FlagW),               // Control actualización flags
        .PCS(PCS),                   // PC con condición
        .NextPC(NextPC),             // Incremento PC
        .RegW(RegW),                 // Escritura registro sin condición
        .MemW(MemW),                 // Escritura memoria sin condición
        .PCWrite(PCWrite),           // Salida PC final
        .RegWrite(RegWrite),         // Salida registro final
        .MemWrite(MemWrite)          // Salida memoria final
    );
endmodule