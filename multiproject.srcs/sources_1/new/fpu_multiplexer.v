// Módulo para multiplicación de punto flotante IEEE 754 (32 bits)
module fp_multiplier (
    input wire [31:0] a,
    input wire [31:0] b,
    output reg [31:0] result
);

    // Señales internas
    reg sign_a, sign_b, sign_res;
    reg [7:0] exp_a, exp_b;
    reg [8:0] exp_res;
    reg [23:0] mantissa_a, mantissa_b;  // Mantisas con bit implícito
    reg [47:0] mantissa_product;        // Producto de mantisas
    reg [22:0] mantissa_res;

    always @(*) begin
        // Extraer campos de entrada
        sign_a = a[31];
        exp_a = a[30:23];
        mantissa_a = {1'b1, a[22:0]};  // Agregar bit implícito
        
        sign_b = b[31];
        exp_b = b[30:23];
        mantissa_b = {1'b1, b[22:0]};  // Agregar bit implícito
        
        // Calcular signo del resultado
        sign_res = sign_a ^ sign_b;
        
        // Casos especiales
        if (exp_a == 0 || exp_b == 0) begin
            result = {sign_res, 31'b0}; // Cero
        end else if (exp_a == 8'hFF || exp_b == 8'hFF) begin
            result = {sign_res, 8'hFF, 23'b0}; // Infinito
        end else begin
            // Calcular exponente del resultado
            exp_res = exp_a + exp_b - 8'd127;
            
            // Multiplicar mantisas
            mantissa_product = mantissa_a * mantissa_b;
            
            // Normalización del producto
            if (mantissa_product[47]) begin
                mantissa_res = mantissa_product[46:24];
                exp_res = exp_res + 1;
            end else begin
                mantissa_res = mantissa_product[45:23];
            end
            
            // Verificar overflow/underflow
            if (exp_res >= 9'd255) begin
                result = {sign_res, 8'hFF, 23'b0}; // Infinito
            end else if (exp_res <= 0) begin
                result = {sign_res, 31'b0}; // Cero
            end else begin
                result = {sign_res, exp_res[7:0], mantissa_res};
            end
        end
    end

endmodule
