// Wrapper para seleccionar entre FPU original o modular
// Cambia el parámetro USE_MODULAR para seleccionar la implementación

module fpu_wrapper (
    input wire [31:0] a, b,           // Operandos
    input wire op,                    // 0: add, 1: mul
    input wire precision,             // 0: 16-bit, 1: 32-bit
    output wire [31:0] result,        // Resultado
    output wire overflowFlag          // Flag de overflow
);

    // Parámetro para seleccionar implementación
    parameter USE_MODULAR = 1;  // 1: usar FPU modular, 0: usar FPU original

    generate
        if (USE_MODULAR) begin : gen_modular
            // Usar implementación modular
            fpu_modular fpu_inst (
                .a(a),
                .b(b),
                .op(op),
                .precision(precision),
                .result(result),
                .overflowFlag(overflowFlag)
            );
        end else begin : gen_original
            // Usar implementación original
            fpu fpu_inst (
                .a(a),
                .b(b),
                .op(op),
                .precision(precision),
                .result(result),
                .overflowFlag(overflowFlag)
            );
        end
    endgenerate

endmodule
