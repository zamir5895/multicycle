module fpu_m (
    input wire [31:0] a, b,           // Operandos
    input wire op,                    // 0: add, 1: mul
    input wire precision,             // 0: 16-bit, 1: 32-bit
    output reg [31:0] result,         // Resultado
    output reg overflowFlag           // Flag de overflow
);

    // Señales internas
    wire [31:0] operand_a_fp32, operand_b_fp32;
    wire [31:0] add_result, mul_result;
    wire [31:0] operation_result;
    wire [15:0] result_fp16;
    wire overflow;

    // Conversores de precisión para operandos
    fp_converter conv_a (
        .fp16_in(a[15:0]),
        .fp32_in(a),
        .convert_to_32(~precision),     // Si precision=0 (16-bit), convertir a 32
        .fp32_out(operand_a_fp32),
        .fp16_out()                     // No usado
    );

    fp_converter conv_b (
        .fp16_in(b[15:0]),
        .fp32_in(b),
        .convert_to_32(~precision),     // Si precision=0 (16-bit), convertir a 32
        .fp32_out(operand_b_fp32),
        .fp16_out()                     // No usado
    );

    // Módulo de suma flotante
    fp_adder adder (
        .a(operand_a_fp32),
        .b(operand_b_fp32),
        .result(add_result)
    );

    // Módulo de multiplicación flotante
    fp_multiplier multiplier (
        .a(operand_a_fp32),
        .b(operand_b_fp32),
        .result(mul_result)
    );

    // Selector de operación
    assign operation_result = op ? mul_result : add_result;

    // Conversor de salida para resultado
    fp_converter conv_result (
        .fp16_in(16'b0),                // No usado
        .fp32_in(operation_result),
        .convert_to_32(1'b0),           // Convertir FP32 a FP16
        .fp32_out(),                    // No usado
        .fp16_out(result_fp16)
    );

    // Lógica principal de control
    always @(*) begin
        // Detectar overflow
        overflow = (operation_result[30:23] == 8'hFF);
        
        // Formatear resultado según precisión
        if (precision) begin
            result = operation_result;  // 32-bit: usar resultado directo
        end else begin
            result = {16'b0, result_fp16};  // 16-bit: usar resultado convertido
        end
        
        overflowFlag = overflow;
    end

endmodule
