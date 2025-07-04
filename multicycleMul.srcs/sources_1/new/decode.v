
module decode (
    clk,
    reset,
    Op,
    Funct,
    Rd,
    InstrLow,
    UMullState,  // Estado para multiplicaciones largas
    FlagW,
    PCS,
    NextPC,
    RegW,
    MemW,
    IRWrite,
    AdrSrc,
    ResultSrc,
    ALUSrcA,
    ALUSrcB,
    ImmSrc,
    RegSrc,
    ALUControl,
    UMullCondition,
    SMullCondition  // Detección SMULL
);
    // Entradas
    input wire clk;
    input wire reset;
    input wire [1:0] Op;             // Tipo de operación (bits 27:26)
    input wire [5:0] Funct;          // Función específica (bits 25:20)
    input wire [3:0] Rd;             // Registro destino
    input wire [3:0] InstrLow;       // Bits bajos instrucción
    input wire UMullState;           // 0=primer ciclo (RdLo), 1=segundo ciclo (RdHi)
    
    // Salidas de control
    output reg [1:0] FlagW;          // Control actualización flags
    output wire PCS;                 // PC con condición
    output wire NextPC;              // Incremento PC
    output wire RegW;                // Escritura registro
    output wire MemW;                // Escritura memoria
    output wire IRWrite;             // Escritura registro instrucción
    output wire AdrSrc;              // Selector dirección
    output wire [1:0] ResultSrc;     // Selector resultado
    output wire [1:0] ALUSrcA;       // Selector operando A
    output wire [1:0] ALUSrcB;       // Selector operando B
    output wire [1:0] ImmSrc;        // Selector inmediato
    output wire [1:0] RegSrc;        // Selector registros
    output reg [3:0] ALUControl;     // Control operación ALU
    output wire UMullCondition;      // Detección UMULL
    output wire SMullCondition;      // Detección SMULL
    
    // Señales internas
    wire Branch;                     // Señal de branch
    wire ALUOp;                      // Operación aritmética
    wire MulCondition;               // Detección MUL
    
    
    // Detectar MUL: Op=00, Funct[5:1]=00000, InstrLow=1001
    assign MulCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00000) && (InstrLow == 4'b1001);
    
    // Detectar UMULL: Op=00, Funct[5:1]=00100, InstrLow=1001
    assign UMullCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00100) && (InstrLow == 4'b1001);
    
    // Detectar SMULL: Op=00, Funct[5:1]=00110, InstrLow=1001
    assign SMullCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00110) && (InstrLow == 4'b1001);

    // Combinar condiciones de multiplicación larga
    wire LongMullCondition = UMullCondition | SMullCondition;
    
    
    mainfsm fsm(
        .clk(clk),
        .reset(reset),
        .Op(Op),                         // Tipo de operación
        .Funct(Funct),                   // Función específica
        .LongMullCondition(LongMullCondition), // Multiplicaciones largas
        .IRWrite(IRWrite),               // Control registro instrucción
        .AdrSrc(AdrSrc),                 // Selector dirección
        .ALUSrcA(ALUSrcA),               // Selector operando A
        .ALUSrcB(ALUSrcB),               // Selector operando B
        .ResultSrc(ResultSrc),           // Selector resultado
        .NextPC(NextPC),                 // Incremento PC
        .RegW(RegW),                     // Escritura registro
        .MemW(MemW),                     // Escritura memoria
        .Branch(Branch),                 // Señal de branch
        .ALUOp(ALUOp),                   // Operación aritmética
        .UMullState(UMullState)          // Estado multiplicación larga
    );
    
    
    // Selector extensión inmediato basado en Op
    assign ImmSrc = Op;
    
    // Selectores de registros fuente
    assign RegSrc[1] = Op == 2'b01; 
    assign RegSrc[0] = Op == 2'b10;
    
    
    always @(*) begin
        if (ALUOp) begin
            // Verificar multiplicaciones largas (UMULL/SMULL)
            if (LongMullCondition) begin
                ALUControl = UMullState ? 4'b0111 : 4'b0110;  // 0111=parte alta, 0110=parte baja
            end
            // Verificar multiplicación simple (MUL)
            else if (MulCondition) begin
                ALUControl = 4'b0101;  // Código para MUL
            end 
            // Operaciones aritméticas estándar
            else begin
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
            
            // ===== CONFIGURACIÓN FLAGS =====
            if (LongMullCondition) begin
                FlagW[1] = Funct[0] & UMullState;  // S bit solo en segundo ciclo
                FlagW[0] = 1'b0;                   // No afecta carry
            end else if (MulCondition) begin
                FlagW[1] = Funct[0];               // S bit para MUL
                FlagW[0] = 1'b0;                   // No afecta carry
            end else begin
                FlagW[1] = Funct[0];               // S bit general
                FlagW[0] = Funct[0] & ((ALUControl == 4'b0000) | (ALUControl == 4'b0001)); // Carry para ADD/SUB
            end
        end
        else begin
            ALUControl = 4'b0000;                  // Por defecto ADD
            FlagW = 2'b00;                         // No actualizar flags
        end
    end
    
    // Escritura PC con condición
    assign PCS = ((Rd == 4'b1111) & RegW) | Branch;
endmodule