`timescale 1ns / 1ps

module hex_display(
    input clk,
    input reset,
    input [15:0] data,
    output wire [3:0] anode,
    output wire [7:0] catode
);
    wire scl_clk;
    wire [3:0] digito;
    
    CLKdivider sclk(
        .clk(clk),
        .reset(reset),
        .t(scl_clk)
    );
    
    hFSM mfsm(
        .clk(scl_clk),
        .reset(reset),
        .data(data),
        .digito(digito),
        .anode(anode)
    );
    
    HexTo7Segment dec(
        .digito(digito),
        .catode(catode)
    );
endmodule

