`timescale 1ns / 1ps

module alu(
    input  [31:0] SrcA, SrcB,        // Operandos A y B
    input  [3:0]  ALUControl,        // Control de operación
    input  wire   SMullCondition,    // Selector signed/unsigned mul
    output reg [31:0] ALUResult,     // Resultado de la operación
    output wire [3:0] ALUFlags       // Flags: N, Z, C, V
);
    wire neg, zero, carry, overflow;
    wire [31:0] condinvb;            // B complementado o no
    wire [32:0] sum;                 // Suma con carry
    wire [63:0] mul_result;          // Multiplicación unsigned
    wire signed [63:0] smul_result;  // Multiplicación signed

    // Complementar B para resta
    assign condinvb = ALUControl[0] ? ~SrcB : SrcB;
    assign sum = SrcA + condinvb + ALUControl[0];
    assign mul_result = SrcA * SrcB;
    
    // Multiplicación con signo
    assign smul_result = $signed(SrcA) * $signed(SrcB);

    
    always @(*) begin
        casex (ALUControl)
            4'b000?: ALUResult = sum;                    // ADD/SUB
            4'b0010: ALUResult = SrcA & SrcB;            // AND
            4'b0011: ALUResult = SrcA | SrcB;            // ORR
            4'b0100: ALUResult = SrcB;                   // MOV
            4'b0101: ALUResult = mul_result[31:0];       // MUL (32 bits bajos)
            4'b0110: ALUResult = SMullCondition ? smul_result[31:0] : mul_result[31:0];     // MULL parte baja
            4'b0111: ALUResult = SMullCondition ? smul_result[63:32] : mul_result[63:32];   // MULL parte alta
            4'b1000: ALUResult = (SrcB != 0) ? (SrcA / SrcB) : 32'hFFFFFFFF;               // DIV
            default: ALUResult = 32'hxxxxxxxx;
        endcase
    end
    
    // Generación de flags
    assign neg = ALUResult[31];                          // Flag negativo
    assign zero = (ALUResult == 32'b0);                  // Flag cero
    assign carry = (ALUControl[2:1] == 2'b00) & sum[32]; // Carry para ADD/SUB
    assign overflow = (ALUControl[2:1] == 2'b00) & ~(SrcA[31] ^ SrcB[31] ^ ALUControl[0]) & (SrcA[31] ^ sum[31]); // Overflow
    assign ALUFlags = {neg, zero, carry, overflow};      // Empaquetado de flags
    
endmodule