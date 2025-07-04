`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/04/2025 11:32:10 AM
// Design Name: 
// Module Name: floprdual
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module floprdual ( 
    clk, 
    reset, 
    d1, 
    d2, 
    q1, 
    q2 
);
    parameter WIDTH = 8;
    
    input wire clk;
    input wire reset;
    input wire [WIDTH - 1:0] d1;
    input wire [WIDTH - 1:0] d2;
    output reg [WIDTH - 1:0] q1;
    output reg [WIDTH - 1:0] q2;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q1 <= 0;
            q2 <= 0;
        end else begin
            q1 <= d1;
            q2 <= d2;
        end
    end
    
endmodule