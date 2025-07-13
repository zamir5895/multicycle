`timescale 1ns / 1ps

// Flip-flop dual con reset asíncrono - almacena dos valores independientes
module floprdual ( 
    clk, 
    reset, 
    d1,     // Entrada de datos 1
    d2,     // Entrada de datos 2
    q1,     // Salida registrada 1
    q2      // Salida registrada 2
);
    parameter WIDTH = 8;
    
    input wire clk;
    input wire reset;
    input wire [WIDTH - 1:0] d1;
    input wire [WIDTH - 1:0] d2;
    output reg [WIDTH - 1:0] q1;
    output reg [WIDTH - 1:0] q2;
    
    // Registro dual síncrono con reset asíncrono
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q1 <= 0;
            q2 <= 0;
        end else begin
            q1 <= d1;    // Almacena d1 en q1
            q2 <= d2;    // Almacena d2 en q2
        end
    end
    
endmodule