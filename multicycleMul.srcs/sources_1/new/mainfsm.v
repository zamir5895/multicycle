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
// Description: Máquina de estados finita principal del procesador ARM multiciclo
//              Controla la secuencia de ejecución de instrucciones
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 

// Máquina de estados finita principal
// Controla el flujo de ejecución multiciclo del procesador
module mainfsm (
    clk,
    reset,
    Op,
    Funct,
    LongMullCondition,
    IRWrite,
    AdrSrc,
    ALUSrcA,
    ALUSrcB,
    ResultSrc,
    NextPC,
    RegW,
    MemW,
    Branch,
    ALUOp,
    UMullState          // Estado para multiplicaciones largas
);
    // Entradas
    input wire clk;                  // Reloj del sistema
    input wire reset;                // Reset del sistema
    input wire [1:0] Op;             // Tipo de operación (bits 27:26)
    input wire [5:0] Funct;          // Función específica (bits 25:20)
    input wire LongMullCondition;    // Detecta UMULL/SMULL
    
    // Salidas de control
    output wire IRWrite;             // Habilitación escritura registro instrucción
    output wire AdrSrc;              // Selector fuente dirección (0=PC, 1=ALU)
    output wire [1:0] ALUSrcA;       // Selector operando A del ALU
    output wire [1:0] ALUSrcB;       // Selector operando B del ALU
    output wire [1:0] ResultSrc;     // Selector resultado final
    output wire NextPC;              // Incremento PC
    output wire RegW;                // Escritura registro (sin condición)
    output wire MemW;                // Escritura memoria (sin condición)
    output wire Branch;              // Señal de branch
    output wire ALUOp;               // Operación aritmética
    output wire UMullState;          // Estado multiplicación larga
    
    // Registros internos
    reg [3:0] state;                 // Estado actual
    reg [3:0] nextstate;             // Próximo estado
    reg [12:0] controls;             // Vector de señales de control
    
    // ===== DEFINICIÓN DE ESTADOS =====
    
    localparam [3:0] FETCH = 0;      // Buscar instrucción
    localparam [3:0] DECODE = 1;     // Decodificar instrucción
    localparam [3:0] MEMADR = 2;     // Calcular dirección memoria
    localparam [3:0] MEMRD = 3;      // Leer de memoria
    localparam [3:0] MEMWB = 4;      // Escribir datos a registro
    localparam [3:0] MEMWR = 5;      // Escribir a memoria
    localparam [3:0] EXECUTER = 6;   // Ejecutar operación R-type
    localparam [3:0] EXECUTEI = 7;   // Ejecutar operación I-type
    localparam [3:0] ALUWB = 8;      // Escribir resultado ALU
    localparam [3:0] BRANCH = 9;     // Ejecutar branch
    localparam [3:0] UMULL1 = 10;    // Escribir RdLo (UMULL/SMULL)
    localparam [3:0] UMULL2 = 11;    // Escribir RdHi (UMULL/SMULL)
    localparam [3:0] UNKNOWN = 12;   // Estado desconocido
    
    // Detectar si estamos en el segundo ciclo de UMULL
    assign UMullState = (state == UMULL1);
    
    // ===== LÓGICA DE TRANSICIÓN DE ESTADOS =====
    
    // Registro de estado con reset
    always @(posedge clk or posedge reset)
        if (reset)
            state <= FETCH;              // Comenzar en FETCH
        else
            state <= nextstate;          // Transición al próximo estado
    
    // Lógica combinacional para próximo estado
    always @(*)
        casex (state)
            FETCH: nextstate = DECODE;   // Siempre ir a decodificar
            
            DECODE: begin                // Decidir según tipo de instrucción
                case (Op)
                    2'b00: begin         // Operaciones de datos
                        if (LongMullCondition)
                            nextstate = EXECUTER;    // UMULL/SMULL
                        else if (Funct[5])
                            nextstate = EXECUTEI;    // I-type
                        else
                            nextstate = EXECUTER;    // R-type
                    end
                    2'b01: nextstate = MEMADR;       // Load/Store
                    2'b10: nextstate = BRANCH;       // Branch
                    default: nextstate = UNKNOWN;
                endcase
            end
            
            EXECUTER: begin              // Decidir después de ejecutar
                if (LongMullCondition)
                    nextstate = UMULL1;  // Ir a escribir RdLo
                else
                    nextstate = ALUWB;   // Escribir resultado normal
            end
            
            EXECUTEI: nextstate = ALUWB; // Escribir resultado I-type
            UMULL1: nextstate = UMULL2;  // Escribir RdHi después de RdLo
            UMULL2: nextstate = FETCH;   // Volver a buscar después de RdHi
            
            MEMADR: begin                // Decidir load/store
                if (Funct[0])
                    nextstate = MEMRD;   // Load
                else
                    nextstate = MEMWR;   // Store
            end
            
            MEMRD: nextstate = MEMWB;    // Escribir datos leídos
            MEMWB: nextstate = FETCH;    // Volver a buscar
            MEMWR: nextstate = FETCH;    // Volver a buscar
            ALUWB: nextstate = FETCH;    // Volver a buscar
            BRANCH: nextstate = FETCH;   // Volver a buscar
            default: nextstate = FETCH;  // Estado seguro
        endcase
    
    // ===== GENERACIÓN DE SEÑALES DE CONTROL =====
    
    // Asignación de señales de control según estado actual
    always @(*)
        case (state)
            // FETCH: PC→Adr, ReadData→IR, PC=PC+4
            FETCH:    controls = 13'b1_0_0_0_1_0_10_01_10_0;
            
            // DECODE: Leer registros, extender inmediato
            DECODE:   controls = 13'b0000001001100;
            
            // EXECUTER: Calcular con ALU
            EXECUTER: controls = 13'b0000000000001;
            
            // EXECUTEI: Calcular con ALU e inmediato
            EXECUTEI: controls = 13'b0000000000011;
            
            // ALUWB: Escribir resultado ALU a registro
            ALUWB:    controls = 13'b0001000000000;
            
            // UMULL1: Escribir RdLo (parte baja multiplicación)
            UMULL1:   controls = 13'b0001010000001;
            
            // UMULL2: Escribir RdHi (parte alta multiplicación)
            UMULL2:   controls = 13'b0001010000000;
            
            // MEMADR: Calcular dirección de memoria
            MEMADR:   controls = 13'b0000000000010;
            
            // MEMWR: Escribir a memoria
            MEMWR:    controls = 13'b0010010000000;
            
            // MEMRD: Leer de memoria
            MEMRD:    controls = 13'b0000010000000;
            
            // MEMWB: Escribir datos de memoria a registro
            MEMWB:    controls = 13'b0001000100000;
            
            // BRANCH: Actualizar PC con dirección de branch
            BRANCH:   controls = 13'b0_1_0_0_0_0_10_10_01_0;
            
            // Estado por defecto
            default:  controls = 13'bxxxxxxxxxxxxx;
        endcase
        
    // Decodificación del vector de control
    // Formato: {NextPC, Branch, MemW, RegW, IRWrite, AdrSrc, ResultSrc[1:0], ALUSrcA[1:0], ALUSrcB[1:0], ALUOp}
    assign {NextPC, Branch, MemW, RegW, IRWrite, AdrSrc, ResultSrc, ALUSrcA, ALUSrcB, ALUOp} = controls;
endmodule