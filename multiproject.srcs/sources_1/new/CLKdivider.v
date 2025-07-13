// Divisor de reloj para generar señal de 480Hz desde 100MHz
module CLKdivider(
    input clk,
    input reset,
    output reg t    // Señal de salida a 480Hz
);
    reg [17:0] contador;    // Contador de 18 bits para división
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            contador <= 18'd0;
            t <= 1'b0;
        end else begin
            if (contador >= 18'd104166) begin // 100MHz / 480Hz / 2 ≈ 104166
                contador <= 18'd0;           // Reinicia contador
                t <= ~t;                     // Alterna la salida
            end else begin
                contador <= contador + 1;
            end
        end
    end
endmodule