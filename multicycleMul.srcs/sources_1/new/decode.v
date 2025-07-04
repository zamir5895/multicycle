`timescale 1ns / 1ps

module decode (
    // Entradas principales
    input wire clk, reset,
    input wire [1:0] Op,           // Campo Opcode de la instrucción
    input wire [5:0] Funct,         // Campo Funct para operaciones extendidas
    input wire [3:0] Rd,            // Registro destino
    input wire [3:0] InstrLow,      // Bits bajos de la instrucción
    input wire UMullState,          // Control de ciclos para UMULL/SMULL (0=primer ciclo, 1=segundo)
    
    // Salidas de control
    output reg [1:0] FlagW,        // Control de flags [1:0] = [N,Z, C,V]
    output wire PCS,               // Selección de PC (1=ejecutar branch)
    output wire NextPC,            // Avanzar PC
    output wire RegW,              // Escritura en banco de registros
    output wire MemW,              // Escritura en memoria
    output wire IRWrite,           // Escritura en registro de instrucción
    output wire AdrSrc,            // Selección de dirección de memoria
    output wire [1:0] ResultSrc,   // Selección de resultado (ALU/Mem/PC)
    output wire [1:0] ALUSrcA,     // Selección de operando A para ALU
    output wire [1:0] ALUSrcB,     // Selección de operando B para ALU
    output wire [1:0] ImmSrc,      // Control de extensión de inmediato
    output wire [1:0] RegSrc,      // Selección de registros fuente
    output reg [3:0] ALUControl,   // Control de operación ALU
    output wire UMullCondition,    // Identifica instrucción UMULL
    output wire SMullCondition     // Identifica instrucción SMULL
);
    
    // Detección de tipos de instrucción
    assign MulCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00000) && (InstrLow == 4'b1001); // MUL estándar
    
    assign UMullCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00100) && (InstrLow == 4'b1001); // UMULL
    
    assign SMullCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00110) && (InstrLow == 4'b1001); // SMULL
    
    wire LongMullCondition = UMullCondition | SMullCondition; // Cualquier multiplicación larga

    // Máquina de estados principal
    mainfsm fsm(
        .clk(clk),
        .reset(reset),
        .Op(Op),
        .Funct(Funct),
        .LongMullCondition(LongMullCondition),
        // Salidas de control conectadas directamente
        .IRWrite(IRWrite),
        .AdrSrc(AdrSrc),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .ResultSrc(ResultSrc),
        .NextPC(NextPC),
        .RegW(RegW),
        .MemW(MemW),
        .Branch(Branch),
        .ALUOp(ALUOp),
        .UMullState(UMullState)
    );

    // Control de inmediatos y selección de registros
    assign ImmSrc = Op; // La extensión de inmediato depende del Opcode
    
    assign RegSrc[1] = Op == 2'b01; // Selección registro fuente 1
    assign RegSrc[0] = Op == 2'b10; // Selección registro fuente 2

    // Lógica de control ALU
    always @(*) begin
        if (ALUOp) begin
            // Prioridad para operaciones de multiplicación
            if (LongMullCondition) begin  
                ALUControl = UMullState ? 4'b0111 : 4'b0110; // 0111=parte alta, 0110=parte baja
            end
            else if (MulCondition) begin
                ALUControl = 4'b0101; // MUL estándar
            end else begin
                // Operaciones ALU básicas
                case (Funct[4:1])
                    4'b0100: ALUControl = 4'b0000; // ADD
                    4'b0010: ALUControl = 4'b0001; // SUB
                    4'b0000: ALUControl = 4'b0010; // AND
                    4'b1100: ALUControl = 4'b0011; // ORR
                    4'b1101: ALUControl = 4'b0100; // MOV
                    default: ALUControl = 4'bxxxx; // No definido
                endcase
            end
            
            // Control de flags (N,Z,C,V)
            if (LongMullCondition) begin
                FlagW[1] = Funct[0] & UMullState; // Actualizar flags solo en 2do ciclo si bit S está activo
                FlagW[0] = 1'b0;                  // Las multiplicaciones no afectan carry/overflow
            end else if (MulCondition) begin
                FlagW[1] = Funct[0]; // MUL solo actualiza N/Z si S=1
                FlagW[0] = 1'b0;     // No afecta C/V
            end else begin
                FlagW[1] = Funct[0]; // N/Z para operaciones normales
                FlagW[0] = Funct[0] & ((ALUControl == 4'b0000) | (ALUControl == 4'b0001)); // C/V solo para ADD/SUB
            end
        end
        else begin
            // Valores por defecto cuando ALU no está activa
            ALUControl = 4'b0000; // ADD
            FlagW = 2'b00;        // No actualizar flags
        end
    end
    
    // Lógica de control de flujo (branches y escritura a PC)
    assign PCS = ((Rd == 4'b1111) & RegW) | Branch; // 1 si es branch o escritura a PC (R15)
endmodule