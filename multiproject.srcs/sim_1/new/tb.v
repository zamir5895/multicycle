`timescale 1ns / 1ps

module testbench;
    reg clk;
    reg reset;
    reg [1:0] display_sel;
    wire [3:0] anode;
    wire [7:0] catode;
    
    // Instantiate the top_top module
    basys_top dut(
        .clk(clk),
        .reset(reset),
        .display_sel(display_sel),
        .anode(anode),
        .catode(catode)
    );
    
    // Reset generation
    initial begin
        reset <= 1;
        #(22);
        reset <= 0;
    end
    
    // Clock generation (100MHz - 10ns period)
    always begin
        clk <= 1;
        #(5);
        clk <= 0;
        #(5);
    end
    
    // Test display selection
    initial begin
        display_sel <= 2'b00; // Start showing WriteData[15:0]
        #1000;
        display_sel <= 2'b01; // Show WriteData[31:16]
        #1000;
        display_sel <= 2'b10; // Show Adr[15:0]
        #1000;
        display_sel <= 2'b11; // Show Adr[31:16]
        #1000;
        display_sel <= 2'b00; // Back to WriteData[15:0]
    end
    
    // Monitor display outputs
    always @(posedge clk) begin
        if (!reset) begin
            $display("Time: %0t | display_sel: %b | anode: %b | catode: %b", 
                     $time, display_sel, anode, catode);
        end
    end
    
endmodule