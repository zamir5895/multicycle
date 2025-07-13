module extend (
    Instr,
    ImmSrc,
    ExtImm
);
    input wire [23:0] Instr;
    input wire [1:0] ImmSrc;        // Selector de tipo de inmediato
    output reg [31:0] ExtImm;       // Inmediato extendido a 32 bits
    
    wire [7:0] imm8;
    wire [3:0] rotate;
    wire [31:0] valor_rotado;
    wire [4:0] cantidad_rotacion;
    
    // Extraer inmediato de 8 bits y campo de rotación
    assign imm8 = Instr[7:0];
    assign rotate = Instr[11:8];
    assign cantidad_rotacion = rotate * 2;  // La rotación se hace en pasos de 2 bits
    
    // Rotación circular a la derecha del inmediato de 8 bits
    assign valor_rotado = ({24'b0, imm8} >> cantidad_rotacion) | 
                        ({24'b0, imm8} << (32 - cantidad_rotacion));
    
    // Selección del tipo de extensión según ImmSrc
    always @(*)
        case (ImmSrc)
            2'b00: ExtImm = valor_rotado;                                    // Inmediato rotado (instrucciones DP)
            2'b01: ExtImm = {20'b00000000000000000000, Instr[11:0]};        // Inmediato de 12 bits (LDR/STR)
            2'b10: ExtImm = {{6 {Instr[23]}}, Instr[23:0], 2'b00};         // Inmediato de 24 bits con extensión de signo (BRANCH)
            default: ExtImm = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
        endcase
endmodule