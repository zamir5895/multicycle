module arm (
    clk,
    reset,
    MemWrite,
    Adr,
    WriteData,
    ReadData
);
    input wire clk;
    input wire reset;
    output wire MemWrite;
    output wire [31:0] Adr;
    output wire [31:0] WriteData;
    input wire [31:0] ReadData;

    wire [31:0] Instr;
    wire [3:0] ALUFlags;
    wire PCWrite;
    wire RegWrite;
    wire IRWrite;
    wire AdrSrc;
    wire [1:0] RegSrc;
    wire [1:0] ALUa;
    wire [1:0] ALUb;
    wire [1:0] ImmSrc;
    wire [1:0] ResultSrc;
    wire [3:0] ALUControl;
    wire UMullState;
    wire CondSMull;
    wire CondFAdd;  // selar de fp add
    wire CondFMull;  // señal de fp mull

    controller c(
        .clk(clk),
        .reset(reset),
        .Instr(Instr),
        .ALUFlags(ALUFlags),
        .PCWrite(PCWrite),
        .MemWrite(MemWrite),
        .RegWrite(RegWrite),
        .IRWrite(IRWrite),
        .AdrSrc(AdrSrc),
        .RegSrc(RegSrc),
        .ALUa(ALUa),
        .ALUb(ALUb),
        .ResultSrc(ResultSrc),
        .ImmSrc(ImmSrc),
        .ALUControl(ALUControl),
        .UMullState(UMullState),
        .CondSMull(CondSMull),
        .CondFAdd(CondFAdd),  
        .CondFMull(CondFMull)   
    );

    datapath dp(
        .clk(clk),
        .reset(reset),
        .Adr(Adr),
        .WriteData(WriteData),
        .ReadData(ReadData),
        .Instr(Instr),
        .ALUFlags(ALUFlags),
        .PCWrite(PCWrite),
        .RegWrite(RegWrite),
        .IRWrite(IRWrite),
        .AdrSrc(AdrSrc),
        .RegSrc(RegSrc),
        .ALUa(ALUa),
        .ALUb(ALUb),
        .ResultSrc(ResultSrc),
        .ImmSrc(ImmSrc),
        .ALUControl(ALUControl),
        .UMullState(UMullState),
        .CondSMull(CondSMull),
        .CondFAdd(CondFAdd),  
        .CondFMull(CondFMull)   
    );
endmodule
