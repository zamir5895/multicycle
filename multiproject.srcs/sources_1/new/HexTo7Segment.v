`timescale 1ns / 1ps

module HexTo7Segment (
    input [3:0] digito,
    output reg [7:0] catode
);
    always @(*) begin
        case (digito)
            //                ABCDEFG.
            4'h0: catode = 8'b00000011; // 0
            4'h1: catode = 8'b11111001; // 1
            4'h2: catode = 8'b10100100; // 2
            4'h3: catode = 8'b10110000; // 3
            4'h4: catode = 8'b10011001; // 4
            4'h5: catode = 8'b10010010; // 5
            4'h6: catode = 8'b10000010; // 6
            4'h7: catode = 8'b11111000; // 7
            4'h8: catode = 8'b10000000; // 8
            4'h9: catode = 8'b10010000; // 9
            4'hA: catode = 8'b10001000; // A
            4'hB: catode = 8'b10000011; // b
            4'hC: catode = 8'b11000110; // C
            4'hD: catode = 8'b10100001; // d
            4'hE: catode = 8'b10000110; // E
            4'hF: catode = 8'b10001110; // F
            default: catode = 8'b11111111; // off
        endcase
    end
endmodule
