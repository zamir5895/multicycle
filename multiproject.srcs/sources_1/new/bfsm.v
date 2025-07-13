`timescale 1ns / 1ps

// FSM para multiplexar display de 7 segmentos de 4 dígitos
module hFSM(
    input clk,
    input reset,
    input [15:0] data,
    output reg [3:0] digito,    // Dígito actual a mostrar (0-F)
    output reg [3:0] anode      // Control de ánodos (0=activo, 1=inactivo)
);
    reg [1:0] state;    // Estado actual del multiplexor (0-3)
    
    // Contador cíclico para cambiar entre dígitos
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= 2'b00;
        end else begin
            state <= state + 1;
        end
    end
    
    // Selección del dígito y ánodo según el estado
    always @(*) begin
        case (state)
            2'b00: begin 
                digito = data[3:0];     // Dígito menos significativo
                anode = 4'b1110;        // Activa primer display
            end
            2'b01: begin 
                digito = data[7:4];
                anode = 4'b1101;        // Activa segundo display
            end
            2'b10: begin 
                digito = data[11:8];
                anode = 4'b1011;        // Activa tercer display
            end
            2'b11: begin 
                digito = data[15:12];   // Dígito más significativo
                anode = 4'b0111;        // Activa cuarto display
            end
        endcase
    end
endmodule
