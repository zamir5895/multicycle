`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/04/2025 10:36:59 AM
// Design Name: 
// Module Name: alu
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
`timescale 1ns / 1ps

module alu(
    input  [31:0] SrcA,   // Operando A
    input  [31:0] SrcB,   // Operando B
    input  [3:0]  ALUControl, // Control de operación (4 bits)
    input  wire   isSMULL,    // 1=Multiplicación con signo, 0=sin signo
    // Salidas
    output reg [31:0] ALUResult, // Resultado de 32 bits
    output wire [3:0] ALUFlags  // Banderas [N, Z, C, V]
);

    // Banderas internas
    wire neg;       
    wire zero;    
    wire carry;     
    wire overflow;  
    
    // Señales internas
    wire [31:0] condinvb;     
    wire [32:0] sum;          
    wire [63:0] mul_result;   
    wire signed [63:0] extendido_mul;  

    // Lógica para preparar SrcB (complemento a 1 si es resta)
    assign condinvb = ALUControl[0] ? ~SrcB : SrcB;
    
    // Sumador/Restador completo (complemento a 2 para resta)
    assign sum = SrcA + condinvb + ALUControl[0];
    
    // Multiplicación sin signo (32x32=64 bits)
    assign mul_result = SrcA * SrcB;
    
    // Multiplicación con signo (32x32=64 bits)
    assign extendido_mul = $signed(SrcA) * $signed(SrcB);

    // Unidad de control - selección de operación
    always @(*) begin
        casex (ALUControl)
            4'b000?: ALUResult = sum;                   
            4'b0010: ALUResult = SrcA & SrcB;           
            4'b0011: ALUResult = SrcA | SrcB;          
            4'b0100: ALUResult = SrcB;                 
            4'b0101: ALUResult = mul_result[31:0];     
            // MUL/UMULL/SMULL parte baja 
            4'b0110: ALUResult = isSMULL ? extendido_mul[31:0] : mul_result[31:0];
            // MUL/UMULL/SMULL parte alta
            4'b0111: ALUResult = isSMULL ? extendido_mul[63:32] : mul_result[63:32];
            default: ALUResult = 32'hxxxxxxxx;         
        endcase
    end
    
    assign neg = ALUResult[31];  
    assign zero = (ALUResult == 32'b0); 
    
    assign carry = (ALUControl[2:1] == 2'b00) & sum[32];
  
    assign overflow = (ALUControl[2:1] == 2'b00) & 
                    ~(SrcA[31] ^ SrcB[31] ^ ALUControl[0]) & 
                    (SrcA[31] ^ sum[31]);
    
    // Concatenación de banderas en orden [N, Z, C, V]
    assign ALUFlags = {neg, zero, carry, overflow};
    
endmodule