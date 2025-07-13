`timescale 1ns / 1ps

// Módulo top para la placa Basys3 con display de 7 segmentos
module basys_top(
    input clk,
    input reset,
    input [1:0] display_sel,   // Selector de datos a mostrar
    output [3:0] anode,
    output [7:0] catode
);
    wire [31:0] WriteData;
    wire [31:0] Adr;
    wire MemWrite;
    
    // Instancia del procesador multiciclo
    top multicycle_top(
        .clk(clk),
        .reset(reset),
        .WriteData(WriteData),
        .Adr(Adr),
        .MemWrite(MemWrite)
    );
    
    reg [15:0] display_data;
    
    // Multiplexor para seleccionar qué datos mostrar
    always @(*) begin
        case (display_sel)
            2'b00: display_data = WriteData[15:0];  
            2'b01: display_data = WriteData[31:16]; 
            2'b10: display_data = Adr[15:0];        
            2'b11: display_data = Adr[31:16];      
        endcase
    end
    
    // Controlador del display hexadecimal de 7 segmentos
    hex_display display(
        .clk(clk),
        .reset(reset),
        .data(display_data),
        .anode(anode),
        .catode(catode)
    );
endmodule
