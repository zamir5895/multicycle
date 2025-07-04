`timescale 1ns / 1ps

module alu(
    input  [31:0] SrcA, SrcB,
    input  [3:0]  ALUControl,
    input  wire   SMullCondition,  // NUEVA ENTRADA
    output reg [31:0] ALUResult,
    output wire [3:0] ALUFlags
);
    wire neg, zero, carry, overflow;
    wire [31:0] condinvb;
    wire [32:0] sum;
    wire [63:0] mul_result;
    wire signed [63:0] smul_result;  // NUEVA SEÑAL

    
    assign condinvb = ALUControl[0] ? ~SrcB : SrcB;
    assign sum = SrcA + condinvb + ALUControl[0];
    assign mul_result = SrcA * SrcB;
    
    // Multiplicación signed (NUEVA)
    assign smul_result = $signed(SrcA) * $signed(SrcB);

    
    always @(*) begin
        casex (ALUControl)
            4'b000?: ALUResult = sum;                    // ADD/SUB
            4'b0010: ALUResult = SrcA & SrcB;            // AND
            4'b0011: ALUResult = SrcA | SrcB;            // ORR
            4'b0100: ALUResult = SrcB;                   // MOV (A = 0, B = val)
            4'b0101: ALUResult = mul_result[31:0];       // MUL
            4'b0110: ALUResult = SMullCondition ? smul_result[31:0] : mul_result[31:0];     // MODIFICADO
            4'b0111: ALUResult = SMullCondition ? smul_result[63:32] : mul_result[63:32];  // MODIFICADO
            default: ALUResult = 32'hxxxxxxxx;
        endcase
    end
    
    assign neg = ALUResult[31];
    assign zero = (ALUResult == 32'b0);
    assign carry = (ALUControl[2:1] == 2'b00) & sum[32];
    assign overflow = (ALUControl[2:1] == 2'b00) & ~(SrcA[31] ^ SrcB[31] ^ ALUControl[0]) & (SrcA[31] ^ sum[31]);
    assign ALUFlags = {neg, zero, carry, overflow};
    
endmodule