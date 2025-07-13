// Módulo para suma de punto flotante IEEE 754 (32 bits)
module fp_adder (
    input wire [31:0] a,
    input wire [31:0] b,
    output reg [31:0] result
);

    // Señales internas
    reg sign_a, sign_b, sign_res;
    reg [7:0] exp_a, exp_b, exp_res;
    reg [23:0] mantissa_a, mantissa_b;  // Mantisas con bit implícito
    reg [8:0] exp_diff;
    reg [24:0] mantissa_sum;
    reg [4:0] shift_count;
    integer i;

    always @(*) begin
        // Extraer campos de entrada
        sign_a = a[31];
        exp_a = a[30:23];
        mantissa_a = {1'b1, a[22:0]};  // Agregar bit implícito
        
        sign_b = b[31];
        exp_b = b[30:23];
        mantissa_b = {1'b1, b[22:0]};  // Agregar bit implícito
        
        // Casos especiales
        if (exp_a == 0) begin
            result = b;
        end else if (exp_b == 0) begin
            result = a;
        end else if (exp_a == 8'hFF || exp_b == 8'hFF) begin
            result = 32'h7FC00000; // NaN
        end else begin
            // Alinear exponentes
            if (exp_a > exp_b) begin
                exp_diff = exp_a - exp_b;
                exp_res = exp_a;
                if (exp_diff > 24) begin
                    mantissa_b = 0;
                end else begin
                    mantissa_b = mantissa_b >> exp_diff;
                end
            end else begin
                exp_diff = exp_b - exp_a;
                exp_res = exp_b;
                if (exp_diff > 24) begin
                    mantissa_a = 0;
                end else begin
                    mantissa_a = mantissa_a >> exp_diff;
                end
            end
            
            // Suma o resta según signos
            if (sign_a == sign_b) begin
                mantissa_sum = mantissa_a + mantissa_b;
                sign_res = sign_a;
            end else begin
                if (mantissa_a >= mantissa_b) begin
                    mantissa_sum = mantissa_a - mantissa_b;
                    sign_res = sign_a;
                end else begin
                    mantissa_sum = mantissa_b - mantissa_a;
                    sign_res = sign_b;
                end
            end
            
            // Normalización del resultado
            if (mantissa_sum[24]) begin
                mantissa_sum = mantissa_sum >> 1;
                exp_res = exp_res + 1;
            end else if (mantissa_sum[23] == 0) begin
                shift_count = 0;
                for (i = 22; i >= 0; i = i - 1) begin
                    if (mantissa_sum[i] && shift_count == 0) begin
                        shift_count = 23 - i;
                    end
                end
                mantissa_sum = mantissa_sum << shift_count;
                exp_res = exp_res - shift_count;
            end
            
            // Verificar overflow/underflow
            if (exp_res >= 8'hFF) begin
                result = {sign_res, 8'hFF, 23'b0}; // Infinito
            end else if (exp_res == 0) begin
                result = {sign_res, 31'b0}; // Cero
            end else begin
                result = {sign_res, exp_res, mantissa_sum[22:0]};
            end
        end
    end

endmodule
