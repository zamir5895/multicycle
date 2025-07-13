module alu(
    input  [31:0] a, b,
    input  [3:0]  ALUControl,
    input  wire   CondSMull,
    input  wire   CondFAdd,
    input  wire   CondFMull,
    input  [3:0]  InstrRd,
    output reg [31:0] ALUResult,
    output wire [3:0] ALUFlags
);
    wire neg, zero, carry, overflow;
    wire [31:0] condinvb;          // b invertido condicionalmente para SUB
    wire [32:0] sum;               // Suma extendida a 33 bits para detectar carry
    wire [63:0] resultadoMul;      // Resultado completo de multiplicación unsigned
    wire signed [63:0] smullResultado;  // Resultado de multiplicación signed
    wire [31:0] fpuResultado;      // Resultado de operaciones de punto flotante
    wire fpuOverflow;
    
    // Invertir b para resta cuando ALUControl[0] = 1
    assign condinvb = ALUControl[0] ? ~b : b;
    assign sum = a + condinvb + ALUControl[0];
    assign resultadoMul = a * b;
    
    // mul signeed
    assign smullResultado = $signed(a) * $signed(b);
    
    // Detectar si es punto flotante
    wire is_fp_op = (ALUControl == 4'b1100) || (ALUControl == 4'b1001) || 
                    (ALUControl == 4'b1010) || (ALUControl == 4'b1011);
    
    // Instancia de la unidad de punto flotante modular
    fpu_m instancia_fpu (
        .a(a),
        .b(b),
        .op(ALUControl[1]),           // 0: suma flotante, 1: multiplicación flotante
        .precision(~ALUControl[0]),   // 1: operación en 32 bits, 0: operación en 16 bits
        .result(fpuResultado),        // Resultado de la operación FPU (ancho depende de 'precision')
        .overflowFlag(fpuOverflow)    // Bandera de overflow de la FPU
    );
    
    
    // Multiplexor principal de operaciones ALU
    always @(*) begin
        casex (ALUControl)
            4'b000?: ALUResult = sum;                    // ADD/SUB
            4'b0010: ALUResult = a & b;            // AND
            4'b0011: ALUResult = a | b;            // ORR
            4'b0100: ALUResult = b;                   // MOV 
            4'b0101: ALUResult = resultadoMul[31:0];       // MUL
            4'b0110: ALUResult = CondSMull ? smullResultado[31:0] : resultadoMul[31:0];    // UMULL/SMULL low
            4'b0111: ALUResult = CondSMull ? smullResultado[63:32] : resultadoMul[63:32];  // UMULL/SMULL high
            4'b1000: ALUResult = (b != 0) ? (a / b) : 32'hFFFFFFFF;  // DIV con protección div/0
            4'b1100: ALUResult = fpuResultado;             // FAdd de 32 bits
            4'b1001: ALUResult = fpuResultado;             // FAdd de 16 bits
            4'b1010: ALUResult = fpuResultado;             // FMul de 32 bits
            4'b1011: ALUResult = fpuResultado;             // FMul de 16 bits
            default: ALUResult = 32'hxxxxxxxx;
        endcase
    end
            
    // Generación de flags de estado
    assign neg = ALUResult[31];    // Flag negativo: bit más significativo
    assign zero = (ALUControl == 4'b0101) ? (resultadoMul[31:0] == 32'b0) :                                        // MUL (solo 32 bits bajos)
                  (ALUControl == 4'b0110) ? (CondSMull ? (smullResultado == 64'b0) : (resultadoMul == 64'b0)) :  // UMULL/SMULL
                  (ALUControl == 4'b0111) ? (CondSMull ? (smullResultado == 64'b0) : (resultadoMul == 64'b0)) :  // UMULL/SMULL high
                  (ALUResult == 32'b0);                                                                            // Otras operaciones
    
    assign carry = is_fp_op ? 1'b0 : ((ALUControl[2:1] == 2'b00) & sum[32]);    // Carry solo para ADD/SUB
    assign overflow = is_fp_op ? fpuOverflow : ((ALUControl[2:1] == 2'b00) &~(a[31] ^ b[31] ^ ALUControl[0]) &(a[31] ^ sum[31]));
    assign ALUFlags = {neg, zero, carry, overflow};  //flags: NZCV
    
endmodule