`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/04/2025 11:33:33 AM
// Design Name: 
// Module Name: mainfsm
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

`timescale 1ns / 1ps

module mainfsm (
    // Entradas de control
    input wire clk,             
    input wire reset,           
    input wire [1:0] Op,         // Campo opcode de la instrucción
    input wire [5:0] Funct,      // Campo función para operaciones extendidas
    input wire LongMullCondition,// Indica operación UMULL/SMULL (multiplicación larga)
    
    // Señales de control de salida
    output wire IRWrite,         // Habilitación de escritura del registro de instrucción
    output wire AdrSrc,          // Selección de dirección de memoria (0=PC, 1=ALU)
    output wire [1:0] ALUSrcA,   // Selección operando A ALU (00=PC, 01=RegA, 10=RegB)
    output wire [1:0] ALUSrcB,   // Selección operando B ALU (00=RegB, 01=4, 10=Inm)
    output wire [1:0] ResultSrc, // Selección resultado (00=ALU, 01=Mem, 10=PC)
    output wire NextPC,          // Habilitación de incremento de PC
    output wire RegW,            // Habilitación escritura banco de registros
    output wire MemW,            // Habilitación escritura memoria
    output wire Branch,          // Indica operación de branch
    output wire ALUOp,           // Habilitación operación ALU
    output wire UMullState       // Estado UMULL (0=primer ciclo, 1=segundo ciclo)
);
    
    // Registros de estado
    reg [3:0] state;            // Estado actual
    reg [3:0] nextstate;        // Próximo estado
    reg [12:0] controls;        // Vector de señales de control
    
    // Definición de estados (one-hot encoding recomendado para FPGAs)
    localparam [3:0] 
        FETCH     = 4'b0000,    // Fetch de instrucción
        DECODE    = 4'b0001,    // Decodificación
        MEMADR    = 4'b0010,    // Cálculo dirección memoria
        MEMRD     = 4'b0011,    // Lectura memoria
        MEMWB     = 4'b0100,    // Escritura back a registro desde memoria
        MEMWR     = 4'b0101,    // Escritura memoria
        EXECUTER  = 4'b0110,    // Ejecución instrucción tipo R
        EXECUTEI  = 4'b0111,    // Ejecución instrucción tipo I
        ALUWB     = 4'b1000,    // Escritura back a registro desde ALU
        BRANCH    = 4'b1001,    // Ejecución branch
        UMULL1    = 4'b1010,    // Primer ciclo UMULL (RdLo)
        UMULL2    = 4'b1011,    // Segundo ciclo UMULL (RdHi)
        UNKNOWN   = 4'b1100;    // Estado desconocido
    
    // Control de ciclos para multiplicación larga
    assign UMullState = (state == UMULL1);  // Activo solo en primer ciclo
    
    // Lógica de transición de estados (sincronización)
    always @(posedge clk or posedge reset)
        if (reset) state <= FETCH;          // Reset asincrónico
        else state <= nextstate;           // Transición normal
    
    // Lógica de próximo estado (combinacional)
    always @(*) begin
        casex (state)
            FETCH: nextstate = DECODE;     // Siempre a DECODE después de FETCH
            
            DECODE: case (Op)
                2'b00: begin               // Instrucciones tipo R
                    if (LongMullCondition) // Detección UMULL/SMULL
                        nextstate = EXECUTER;
                    else if (Funct[5])     // Bit que distingue R/I
                        nextstate = EXECUTEI;
                    else
                        nextstate = EXECUTER;
                end
                2'b01: nextstate = MEMADR; // Acceso a memoria
                2'b10: nextstate = BRANCH; // Branch
                default: nextstate = UNKNOWN;
            endcase
            
            EXECUTER: nextstate = LongMullCondition ? UMULL1 : ALUWB;
            EXECUTEI: nextstate = ALUWB;
            UMULL1:   nextstate = UMULL2;  // Transición a segundo ciclo
            UMULL2:   nextstate = FETCH;   // Volver a fetch
            
            // Estados para acceso a memoria
            MEMADR: nextstate = Funct[0] ? MEMRD : MEMWR;
            MEMRD:  nextstate = MEMWB;
            MEMWB:  nextstate = FETCH;
            MEMWR:  nextstate = FETCH;
            
            // Estados finales
            ALUWB:  nextstate = FETCH;
            BRANCH: nextstate = FETCH;
            default: nextstate = FETCH;    // Manejo de errores
        endcase
    end
    
    // Generación de señales de control para cada estado
    always @(*) begin
        case (state)
            // Formato: NextPC,Branch,MemW,RegW,IRWrite,AdrSrc,ResultSrc,ALUSrcA,ALUSrcB,ALUOp
            FETCH:    controls = 13'b1_0_0_0_1_0_10_01_10_0;  // PC+4, leer memoria
            DECODE:   controls = 13'b0000001001100;           // Preparar operandos
            EXECUTER: controls = 13'b0000000000001;           // Operación ALU
            EXECUTEI: controls = 13'b0000000000011;           // Operación ALU con inmediato
            ALUWB:    controls = 13'b0001000000000;           // Escritura registro
            UMULL1:   controls = 13'b0001010000001;           // Escritura RdLo
            UMULL2:   controls = 13'b0001010000000;           // Escritura RdHi
            MEMADR:   controls = 13'b0000000000010;           // Cálculo dirección
            MEMWR:    controls = 13'b0010010000000;           // Escritura memoria
            MEMRD:    controls = 13'b0000010000000;           // Lectura memoria
            MEMWB:    controls = 13'b0001000100000;           // Escritura desde memoria
            BRANCH:   controls = 13'b0_1_0_0_0_0_10_10_01_0; // Ejecución branch
            default:  controls = 13'bxxxxxxxxxxxxx;           // Estado inválido
        endcase
    end
        
    // Asignación de señales de control individuales
    assign {NextPC, Branch, MemW, RegW, IRWrite, AdrSrc, 
            ResultSrc, ALUSrcA, ALUSrcB, ALUOp} = controls;
endmodule