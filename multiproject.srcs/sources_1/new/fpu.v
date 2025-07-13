module fpu (
  input wire [31:0] a, b,
  input wire op, // 0: add, 1: mul
  input wire precision, // 0: (16-bit), 1:(32-bit)
  output reg [31:0] result,
  output reg overflowFlag
);
  reg [31:0] operand_a_fp32, operand_b_fp32, result_fp32;  // Operandos y resultado en FP32
  reg overflow;
  
  // Convierte FP16 a FP32
  function [31:0] convert_half_to_single;
    input [15:0] half_input;
    reg sign_bit;
    reg [4:0] exp_half;          // Exponente en FP16
    reg [9:0] mantissa_half;     // Mantisa en FP16
    reg [7:0] exp_single;        // Exponente en FP32
    reg [22:0] mantissa_single;  // Mantisa en FP32
    begin
      sign_bit = half_input[15];
      exp_half = half_input[14:10];
      mantissa_half = half_input[9:0];
      
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
      
      convert_half_to_single = {sign_bit, exp_single, mantissa_single};
    end
  endfunction
  
  // Convierte FP32 a FP16
  function [15:0] convert_single_to_half;
    input [31:0] single_input;
    reg sign_bit;
    reg [7:0] exp_single;        // Exponente en FP32
    reg [22:0] mantissa_single;  // Mantisa en FP32
    reg [4:0] exp_half;          // Exponente en FP16
    reg [9:0] mantissa_half;     // Mantisa en FP16
    begin
      sign_bit = single_input[31];
      exp_single = single_input[30:23];
      mantissa_single = single_input[22:0];
      
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
      
      convert_single_to_half = {sign_bit, exp_half, mantissa_half};
    end
  endfunction
  
  // Suma de punto flotante IEEE 754
  function [31:0] fp_add;
    input [31:0] a, b;
    reg sign_a, sign_b, sign_res;
    reg [7:0] exp_a, exp_b, exp_res;
    reg [23:0] mantissa_a, mantissa_b, mantissa_res;  // Mantisas con bit implícito
    reg [8:0] exp_diff;
    reg [24:0] mantissa_sum;
    reg [4:0] shift_count;
    integer i;
    begin
      sign_a = a[31];
      exp_a = a[30:23];
      mantissa_a = {1'b1, a[22:0]};
      
      sign_b = b[31];
      exp_b = b[30:23];
      mantissa_b = {1'b1, b[22:0]};
      
      if (exp_a == 0) begin
        fp_add = b;
      end else if (exp_b == 0) begin
        fp_add = a;
      end else if (exp_a == 8'hFF || exp_b == 8'hFF) begin
        fp_add = 32'h7FC00000; // NaN
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
          fp_add = {sign_res, 8'hFF, 23'b0}; // Infinito
        end else if (exp_res == 0) begin
          fp_add = {sign_res, 31'b0}; // Cero
        end else begin
          fp_add = {sign_res, exp_res, mantissa_sum[22:0]};
        end
      end
    end
  endfunction
  
  function [31:0] fp_mul;
    input [31:0] a, b;
    reg sign_a, sign_b, sign_res;
    reg [7:0] exp_a, exp_b;
    reg [8:0] exp_res;
    reg [23:0] mantissa_a, mantissa_b;  // Mantisas con bit implícito
    reg [47:0] mantissa_product;        // Producto de mantisas
    reg [22:0] mantissa_res;
    begin
      sign_a = a[31];
      exp_a = a[30:23];
      mantissa_a = {1'b1, a[22:0]};
      
      sign_b = b[31];
      exp_b = b[30:23];
      mantissa_b = {1'b1, b[22:0]};
      
      sign_res = sign_a ^ sign_b;
      
      if (exp_a == 0 || exp_b == 0) begin
        fp_mul = {sign_res, 31'b0}; // Cero
      end else if (exp_a == 8'hFF || exp_b == 8'hFF) begin
        fp_mul = {sign_res, 8'hFF, 23'b0};
      end else begin
        exp_res = exp_a + exp_b - 8'd127;
        
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
          fp_mul = {sign_res, 8'hFF, 23'b0}; 
        end else if (exp_res <= 0) begin
          fp_mul = {sign_res, 31'b0}; 
        end else begin
          fp_mul = {sign_res, exp_res[7:0], mantissa_res};
        end
      end
    end
  endfunction
  
  // Lógica principal de la FPU
  always @(*) begin
    // Convertir operandos según precisión
    if (precision) begin
      operand_a_fp32 = a;
      operand_b_fp32 = b;
    end else begin
      operand_a_fp32 = convert_half_to_single(a[15:0]);
      operand_b_fp32 = convert_half_to_single(b[15:0]);
    end
    
    // Seleccionar operación
    case (op)
      1'b0: result_fp32 = fp_add(operand_a_fp32, operand_b_fp32);
      1'b1: result_fp32 = fp_mul(operand_a_fp32, operand_b_fp32);
      default: result_fp32 = 32'bx;
    endcase
    
    // Detectar overflow
    overflow = (result_fp32[30:23] == 8'hFF);
    
    // Formatear resultado según precisión
    if (precision) begin
      result = result_fp32;
    end else begin
      result = {16'b0, convert_single_to_half(result_fp32)};
    end
    
    overflowFlag = overflow;
  end
endmodule