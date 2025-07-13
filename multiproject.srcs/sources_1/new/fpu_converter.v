// Módulo para conversión entre FP16 y FP32
module fp_converter (
    input wire [15:0] fp16_in,
    input wire [31:0] fp32_in,
    input wire convert_to_32,      // 1: FP16→FP32, 0: FP32→FP16
    output reg [31:0] fp32_out,
    output reg [15:0] fp16_out
);

    // Conversión FP16 a FP32
    always @(*) begin
        if (convert_to_32) begin
            // Extraer campos FP16
            reg sign_bit = fp16_in[15];
            reg [4:0] exp_half = fp16_in[14:10];
            reg [9:0] mantissa_half = fp16_in[9:0];
            
            // Convertir a FP32
            reg [7:0] exp_single;
            reg [22:0] mantissa_single;
            
            if (exp_half == 0) begin
                exp_single = 0;
                mantissa_single = 0;
            end else if (exp_half == 5'b11111) begin
                exp_single = 8'hFF;
                mantissa_single = {mantissa_half, 13'b0};
            end else begin
                // Ajustar bias del exponente (15 para FP16, 127 para FP32)
                exp_single = exp_half - 5'd15 + 8'd127;
                mantissa_single = {mantissa_half, 13'b0};
            end
            
            fp32_out = {sign_bit, exp_single, mantissa_single};
            fp16_out = 16'b0;
        end else begin
            // Conversión FP32 a FP16
            reg sign_bit = fp32_in[31];
            reg [7:0] exp_single = fp32_in[30:23];
            reg [22:0] mantissa_single = fp32_in[22:0];
            
            // Convertir a FP16
            reg [4:0] exp_half;
            reg [9:0] mantissa_half;
            
            if (exp_single == 0) begin
                exp_half = 0;
                mantissa_half = 0;
            end else if (exp_single == 8'hFF) begin
                exp_half = 5'b11111;
                mantissa_half = mantissa_single[22:13];
            end else begin
                // Ajustar bias del exponente (127 para FP32, 15 para FP16)
                exp_half = exp_single - 8'd127 + 5'd15;
                mantissa_half = mantissa_single[22:13];
                
                // Saturación para evitar overflow
                if (exp_half > 5'd30) begin
                    exp_half = 5'b11111;
                    mantissa_half = 0;
                end else if (exp_half < 1) begin
                    exp_half = 0;
                    mantissa_half = 0;
                end
            end
            
            fp16_out = {sign_bit, exp_half, mantissa_half};
            fp32_out = 32'b0;
        end
    end

endmodule
