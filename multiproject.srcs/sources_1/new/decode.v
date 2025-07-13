// Módulo de decodificación de instrucciones ARM
module decode (
    clk,
    reset,
    Op,                 // Opcode principal (bits 27:26)
    Funct,              // Campo de función (bits 25:20)
    Rd,                 // Registro destino (bits 15:12)
    InstrLow,           // Bits bajos de instrucción (bits 7:4)
    UMullState,         // Estado para multiplicación larga
    FlagW,              // Habilitación de escritura de flags
    PCS,                // Señal de escritura en PC
    NextPC,             // Señal para siguiente PC
    RegW,               // Habilitación de escritura en registros
    MemW,               // Habilitación de escritura en memoria
    IRWrite,            // Habilitación de escritura en registro de instrucciones
    AdrSrc,             // Selector de fuente de dirección
    ResultSrc,          // Selector de fuente de resultado
    ALUa,               // Selector de entrada A de ALU
    ALUb,               // Selector de entrada B de ALU
    ImmSrc,             // Selector de tipo de inmediato
    RegSrc,             // Selector de registros fuente
    ALUControl,         // Control de operación de ALU
    UMullCondition,     // Condición para UMULL
    CondSMull,          // Condición para SMULL
    CondFAdd,           // Condición para suma flotante
    CondFMull           // Condición para multiplicación flotante
);
    input wire clk;
    input wire reset;
    input wire [1:0] Op;
    input wire [5:0] Funct;
    input wire [3:0] Rd;
    input wire [3:0] InstrLow;
    input wire UMullState;
    output reg [1:0] FlagW;
    output wire PCS;
    output wire NextPC;
    output wire RegW;
    output wire MemW;
    output wire IRWrite;
    output wire AdrSrc;
    output wire [1:0] ResultSrc;
    output wire [1:0] ALUa;
    output wire [1:0] ALUb;
    output wire [1:0] ImmSrc;
    output wire [1:0] RegSrc;
    output reg [3:0] ALUControl;
    output wire UMullCondition;
    output wire CondSMull;
    output wire CondFAdd;
    output wire CondFMull;
    
    wire Branch;
    wire ALUOp;              // Señal que indica operación ALU
    wire MulCond;            // Condición para multiplicación simple
    
    // Detectar multiplicación simple: Op=00, Funct[5:1]=00000, InstrLow=1001
    assign MulCond = (Op == 2'b00) && (Funct[5:1] == 5'b00000) && (InstrLow == 4'b1001);
    
    // Detectar multiplicación larga unsigned: Op=00, Funct[5:1]=00100, InstrLow=1001
    assign UMullCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00100) && (InstrLow == 4'b1001);
    
    // Detectar multiplicación larga signed: Op=00, Funct[5:1]=00110, InstrLow=1001
    assign CondSMull = (Op == 2'b00) && (Funct[5:1] == 5'b00110) && (InstrLow == 4'b1001);

    // Detectar suma flotante: Op=11, Funct[5:4]=11, Funct[3:2]=00, InstrLow=1010
    assign CondFAdd = (Op == 2'b11) && (Funct[5:4] == 2'b11) && (Funct[3:2] == 2'b00) && (InstrLow == 4'b1010);
    
    // Detectar multiplicación flotante: Op=11, Funct[5:4]=11, Funct[3:2]=10, InstrLow=1010
    assign CondFMull = (Op == 2'b11) && (Funct[5:4] == 2'b11) && (Funct[3:2] == 2'b10) && (InstrLow == 4'b1010);

    // Combinar condiciones para tipos de instrucciones
    wire LongMullCondition = UMullCondition | CondSMull;    // Cualquier multiplicación larga
    wire floatCond = CondFAdd | CondFMull;             // Cualquier operación flotante
    
    // Instancia de la máquina de estados principal
    mainfsm fsm(
        .clk(clk),
        .reset(reset),
        .Op(Op),
        .Funct(Funct),
        .LongMullCondition(LongMullCondition),
        .floatCond(floatCond),
        .IRWrite(IRWrite),
        .AdrSrc(AdrSrc),
        .ALUa(ALUa),
        .ALUb(ALUb),
        .ResultSrc(ResultSrc),
        .NextPC(NextPC),
        .RegW(RegW),
        .MemW(MemW),
        .Branch(Branch),
        .ALUOp(ALUOp),
        .UMullState(UMullState)
    );
    
    // Selector de tipo de inmediato basado en opcode
    assign ImmSrc = Op;
    
    // Selección de registros fuente según tipo de instrucción
    assign RegSrc[1] = Op == 2'b01;  // Instrucciones de memoria
    assign RegSrc[0] = Op == 2'b10;  // Instrucciones de branch
    
    // Decodificación de control de ALU y flags
    always @(*) begin
        if (ALUOp) begin
            // Operaciones de punto flotante
            if (floatCond) begin
                if (CondFAdd) begin
                    if (Funct[1] == 1'b0)
                        ALUControl = 4'b1100;  // FADD 32-bit
                    else
                        ALUControl = 4'b1001;  // FADD 16-bit
                end
                else if (CondFMull) begin
                    if (Funct[1] == 1'b0)
                        ALUControl = 4'b1010;  // FMUL 32-bit
                    else
                        ALUControl = 4'b1011;  // FMUL 16-bit
                end
                else
                    ALUControl = 4'bxxxx;
            end
            // Multiplicaciones largas (64-bit)
            else if (LongMullCondition) begin
                ALUControl = UMullState ? 4'b0111 : 4'b0110;  // High o Low part
            end
            // Multiplicación simple (32-bit)
            else if (MulCond) begin
                ALUControl = 4'b0101;
            end else begin
                // Operaciones ALU estándar
                case (Funct[4:1])
                    4'b0100: ALUControl = 4'b0000;  // ADD
                    4'b0010: ALUControl = 4'b0001;  // SUB
                    4'b0000: ALUControl = 4'b0010;  // AND
                    4'b1100: ALUControl = 4'b0011;  // ORR
                    4'b1101: ALUControl = 4'b0100;  // MOV
                    4'b0011: ALUControl = 4'b1000;  // DIV
                    default: ALUControl = 4'bxxxx;
                endcase
            end
            
            // Control de escritura de flags según tipo de instrucción
            if (floatCond) begin
                FlagW[1] = Funct[0];  // Flag N y Z para punto flotante
                FlagW[0] = Funct[0];  // Flag C y V para punto flotante
            end
            else if (LongMullCondition) begin
                FlagW[1] = Funct[0] & UMullState;  // Solo en estado high
                FlagW[0] = 1'b0;                   // No hay carry/overflow
            end else if (MulCond) begin
                FlagW[1] = Funct[0];  // Solo flags N y Z
                FlagW[0] = 1'b0;      // No hay carry/overflow en MUL
            end else begin
                FlagW[1] = Funct[0];  // Flags N y Z
                FlagW[0] = Funct[0] & ((ALUControl == 4'b0000) | (ALUControl == 4'b0001));  // C y V solo en ADD/SUB
            end
        end
        else begin
            ALUControl = 4'b0000;  // Operación ADD por defecto
            FlagW = 2'b00;         // No escribir flags
        end
    end
    
    // Señal de escritura en PC: cuando Rd=15 y RegW=1, o en branch
    assign PCS = ((Rd == 4'b1111) & RegW) | Branch;
    
endmodule