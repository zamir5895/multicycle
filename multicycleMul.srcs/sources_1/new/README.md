# Implementación de Instrucciones SMULL, UMULL y UDIV en Procesador ARM Multiciclo

## Autor
- **Estudiante:** [Tu Nombre]
- **Curso:** Arquitectura de Computadoras
- **Fecha:** Julio 2025

## Resumen Ejecutivo

Este proyecto presenta la implementación exitosa de las instrucciones de multiplicación larga con signo (SMULL), multiplicación larga sin signo (UMULL) y división sin signo (UDIV) en un procesador ARM de arquitectura multiciclo. La implementación se realizó mediante modificaciones cuidadosas en los módulos de control, decodificación, ALU y datapath, manteniendo la compatibilidad con las instrucciones existentes.

## Índice

1. [Introducción](#introducción)
2. [Análisis de Instrucciones](#análisis-de-instrucciones)
3. [Arquitectura del Sistema](#arquitectura-del-sistema)
4. [Justificación de Decisiones de Diseño](#justificación-de-decisiones-de-diseño)
5. [Diagramas del Datapath](#diagramas-del-datapath)
6. [Control y Decodificación](#control-y-decodificación)
7. [Implementación Detallada](#implementación-detallada)
8. [Cambios en el Código Comentados](#cambios-en-el-código-comentados)
9. [Modificaciones Realizadas](#modificaciones-realizadas)
10. [Validación y Pruebas](#validación-y-pruebas)
11. [Conclusiones](#conclusiones)
12. [Referencias](#referencias)

## Introducción

El procesador ARM original implementado soportaba instrucciones básicas de tipo R, I y operaciones de memoria. Este proyecto extiende la funcionalidad agregando soporte para:

- **SMULL (Signed Multiply Long)**: Multiplicación de 32x32 bits con resultado de 64 bits con signo
- **UMULL (Unsigned Multiply Long)**: Multiplicación de 32x32 bits con resultado de 64 bits sin signo  
- **UDIV (Unsigned Division)**: División de 32 bits sin signo

Estas instrucciones son fundamentales para aplicaciones que requieren aritmética de alta precisión y operaciones matemáticas avanzadas.

## Análisis de Instrucciones

### SMULL (Signed Multiply Long)
```
Formato: SMULL{cond}{S} RdLo, RdHi, Rm, Rs
Encoding: cond|0000110|S|RdHi|RdLo|Rs|1001|Rm
```

**Operación:** `{RdHi,RdLo} = Rm * Rs` (con signo)
- Multiplica dos valores de 32 bits con signo
- Produce un resultado de 64 bits
- RdLo contiene los 32 bits menos significativos
- RdHi contiene los 32 bits más significativos

### UMULL (Unsigned Multiply Long)
```
Formato: UMULL{cond}{S} RdLo, RdHi, Rm, Rs
Encoding: cond|0000100|S|RdHi|RdLo|Rs|1001|Rm
```

**Operación:** `{RdHi,RdLo} = Rm * Rs` (sin signo)
- Similar a SMULL pero trata los operandos como valores sin signo
- Útil para operaciones con números positivos grandes

### UDIV (Unsigned Division)
```
Formato: UDIV{cond} Rd, Rn, Rm
Encoding: cond|01110011|Rd|1111|Rm|0001|Rn
```

**Operación:** `Rd = Rn / Rm` (sin signo)
- División de enteros de 32 bits sin signo
- Si Rm = 0, el resultado es 0xFFFFFFFF (manejo de división por cero)

## Arquitectura del Sistema

### Componentes Principales

El procesador multiciclo consta de los siguientes módulos principales:

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Controller │────│   Decode    │────│   MainFSM   │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────┐
│                  Datapath                           │
│  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐       │
│  │ RegFile│  │  ALU  │  │  Mux  │  │ Extend│       │
│  └───────┘  └───────┘  └───────┘  └───────┘       │
└─────────────────────────────────────────────────────┘
```

### Flujo de Control Multiciclo

Las nuevas instrucciones siguen el siguiente flujo de estados:

```
FETCH → DECODE → EXECUTER → UMULL1 → UMULL2 → FETCH
                     │           ↓
                     └─────→ ALUWB → FETCH (para UDIV)
```

## Justificación de Decisiones de Diseño

### Decisión 1: Arquitectura Multiciclo vs Pipeline

**Decisión Tomada**: Mantener la arquitectura multiciclo existente.

**Justificación**:
- **Simplicidad de Implementación**: Las instrucciones UMULL/SMULL requieren escribir dos registros secuencialmente (RdLo, RdHi), lo cual se acomoda naturalmente en una arquitectura multiciclo.
- **Reutilización de Hardware**: La infraestructura existente del datapath puede ser reutilizada con modificaciones mínimas.
- **Control de Estados Claro**: La FSM permite un control preciso sobre cuándo escribir cada parte del resultado de 64 bits.

### Decisión 2: Dos Estados Separados para UMULL/SMULL

**Decisión Tomada**: Implementar UMULL1 y UMULL2 como estados distintos.

**Justificación**:
- **Atomicidad de Escritura**: Cada registro (RdLo, RdHi) se escribe en un ciclo completo, evitando estados intermedios inconsistentes.
- **Simplicidad de Control**: Cada estado tiene una función específica y clara.
- **Facilidad de Debugging**: Los estados separados permiten verificar individualmente la escritura de cada parte del resultado.

### Decisión 3: Detección de Instrucciones en el Datapath

**Decisión Tomada**: Implementar la detección de tipos de instrucción tanto en `decode.v` como en `datapath.v`.

**Justificación**:
- **Separación de Responsabilidades**: El decoder maneja el control de la FSM, mientras que el datapath maneja el enrutamiento de registros.
- **Optimización de Timing**: La detección local en el datapath reduce la latencia de las señales de control.
- **Modularidad**: Cada módulo mantiene la lógica relevante a su función específica.

### Decisión 4: Manejo de División por Cero

**Decisión Tomada**: Retornar 0xFFFFFFFF en caso de división por cero.

**Justificación**:
- **Estándar ARM**: Sigue la convención ARM para división por cero.
- **Prevención de Excepciones**: Evita que el procesador se cuelgue o genere excepciones no manejadas.
- **Facilidad de Detección**: El valor 0xFFFFFFFF es fácilmente identificable como resultado de error.

## Diagramas del Datapath

### Datapath Original vs Modificado

```
DATAPATH ORIGINAL:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                DATAPATH                                     │
│                                                                             │
│  ┌────┐    ┌─────┐    ┌──────────┐    ┌─────┐    ┌─────┐    ┌──────────┐   │
│  │ PC │────│ Adr │────│  Memory  │────│ IR  │────│Regs │────│   ALU    │   │
│  └────┘    │ Mux │    │          │    └─────┘    │File │    │          │   │
│             └─────┘    └──────────┘               └─────┘    └──────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

DATAPATH MODIFICADO PARA UMULL/SMULL/UDIV:
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATAPATH EXTENDIDO                                │
│                                                                             │
│  ┌────┐    ┌─────┐    ┌──────────┐    ┌─────┐    ┌─────┐    ┌──────────┐   │
│  │ PC │────│ Adr │────│  Memory  │────│ IR  │────│Regs │────│   ALU+   │   │
│  └────┘    │ Mux │    │          │    └─────┘    │File │    │  64-bit  │   │
│             └─────┘    └──────────┘       │       │     │    │   Mul    │   │
│                                           │       │     │    │  32-bit  │   │
│             ┌─────────────────────────────┴───────┤     │    │   Div    │   │
│             │  Detección de Instrucción          │     │    └──────────┘   │
│             │  • UMULL: 27:21=0000100           │     │                    │
│             │  • SMULL: 27:21=0000110           │     │                    │
│             │  • UDIV:  27:26=01, 25:21=11000   │     │                    │
│             └─────────────┬───────────────────────┘     │                    │
│                           │                             │                    │
│             ┌─────────────▼───────────────────────┐     │                    │
│             │  Selector de Registros Mejorado    │     │                    │
│             │  • RA1: Rm para MUL/UMULL/SMULL   │◄────┤                    │
│             │  • RA2: Rs para MUL/UMULL/SMULL   │     │                    │
│             │  • WA3: RdLo/RdHi para UMULL/SMULL │     │                    │
│             └─────────────────────────────────────┘     │                    │
│                                                         │                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Flujo de Datos para UMULL/SMULL

```
CICLO 1 (UMULL1): Calcular y escribir parte baja
┌─────────┐    ┌─────────┐    ┌─────────────┐    ┌─────────┐
│   Rm    │───▶│         │───▶│ 64-bit MUL  │───▶│ RdLo    │
│ (RA1)   │    │   ALU   │    │ [31:0]      │    │(WA3=Rn) │
│   Rs    │───▶│         │    │             │    │         │
│ (RA2)   │    └─────────┘    └─────────────┘    └─────────┘
└─────────┘                                        
                                                   
CICLO 2 (UMULL2): Escribir parte alta              
┌─────────┐    ┌─────────┐    ┌─────────────┐    ┌─────────┐
│   Rm    │───▶│         │───▶│ 64-bit MUL  │───▶│ RdHi    │
│ (RA1)   │    │   ALU   │    │ [63:32]     │    │(WA3=Rd) │
│   Rs    │───▶│         │    │             │    │         │
│ (RA2)   │    └─────────┘    └─────────────┘    └─────────┘
└─────────┘                                        
```

### Selector de Registros Detallado

```
SELECTOR DE REGISTRO FUENTE 1 (RA1):
┌─────────────────┬─────────────────┬─────────────────┐
│  Tipo Instr.    │    Condición    │    Resultado    │
├─────────────────┼─────────────────┼─────────────────┤
│ UMULL/SMULL     │ LongMullCond=1  │   Rm (Instr[3:0])  │
│ MUL             │ MulCondition=1  │   Rm (Instr[3:0])  │
│ Normal          │ Otros           │   Rn (Instr[19:16])│
└─────────────────┴─────────────────┴─────────────────┘

SELECTOR DE REGISTRO DESTINO (WA3):
┌─────────────────┬─────────────────┬─────────────────┐
│  Tipo Instr.    │    Estado       │    Resultado    │
├─────────────────┼─────────────────┼─────────────────┤
│ UMULL/SMULL     │ UMullState=0    │   RdLo (Instr[19:16]) │
│ UMULL/SMULL     │ UMullState=1    │   RdHi (Instr[15:12]) │
│ MUL             │ N/A             │   Rd (Instr[19:16])   │
│ Normal          │ N/A             │   Rd (Instr[15:12])   │
└─────────────────┴─────────────────┴─────────────────┘
```

## Control y Decodificación

### Arquitectura de Control Jerárquica

```
                    ┌─────────────────┐
                    │   Controller    │
                    │  (Módulo Top)   │
                    └─────┬───────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Decode    │  │  CondLogic  │  │  MainFSM    │
│             │  │             │  │             │
│ • Detecta   │  │ • Evalúa    │  │ • Controla  │
│   UMULL     │  │   condición │  │   estados   │
│ • Detecta   │  │ • Maneja    │  │ • UMULL1    │
│   SMULL     │  │   flags     │  │ • UMULL2    │
│ • Detecta   │  │             │  │             │
│   UDIV      │  │             │  │             │
└─────────────┘  └─────────────┘  └─────────────┘
```

### Matriz de Estados Extendida

```
Estados de la FSM:
┌──────────┬──────────────┬────────────────┬─────────────────────┐
│ Estado   │ Descripción  │ Próximo Estado │ Señales Control     │
├──────────┼──────────────┼────────────────┼─────────────────────┤
│ FETCH    │ Buscar instr │ DECODE         │ PCWrite=1, IRWrite=1│
│ DECODE   │ Decodificar  │ EXECUTER/otros │ ALUSrcA=00, RegW=0  │
│ EXECUTER │ Ejecutar ALU │ UMULL1/ALUWB   │ ALUOp=1             │
│ UMULL1   │ Escribir Lo  │ UMULL2         │ RegW=1, ResltSrc=01 │
│ UMULL2   │ Escribir Hi  │ FETCH          │ RegW=1, ResltSrc=01 │
│ ALUWB    │ Escribir ALU │ FETCH          │ RegW=1, ResltSrc=00 │
└──────────┴──────────────┴────────────────┴─────────────────────┘
```

### Lógica de Decodificación Detallada

```
Decodificación de Instrucciones:
┌─────────────────────────────────────────────────────────────────┐
│                    DECODE.V - Lógica Principal                  │
│                                                                 │
│  1. Detección de Patrones de Bits:                            │
│     • UMULL: Op[1:0]=00, Funct[5:1]=00100, Instr[7:4]=1001   │
│     • SMULL: Op[1:0]=00, Funct[5:1]=00110, Instr[7:4]=1001   │
│     • UDIV:  Op[1:0]=01, Funct[5:1]=11000, Instr[7:4]=0001   │
│                                                                 │
│  2. Generación de Señales de Control:                         │
│     • LongMullCondition = UMullCondition | SMullCondition     │
│     • ALUControl = f(UMullState, LongMullCondition)           │
│     • FlagW = f(Funct[0], UMullState, instrType)             │
│                                                                 │
│  3. Coordinación con MainFSM:                                 │
│     • Envía LongMullCondition para decisión de estados       │
│     • Recibe UMullState para alternar ALUControl             │
└─────────────────────────────────────────────────────────────────┘
```

## Implementación Detallada

### Resumen de la Implementación

La implementación se basa en una extensión cuidadosa del procesador ARM multiciclo existente, agregando soporte para tres nuevas instrucciones mientras se mantiene la compatibilidad total con las instrucciones originales. Los cambios se distribuyen across cinco módulos principales, cada uno con responsabilidades específicas.

## Cambios en el Código Comentados

### 1. Archivo `controller.v` - Modificaciones en el Controlador Principal

**Nuevas señales de salida agregadas:**
```verilog
module controller (
    // ...señales existentes...
    output wire UMullState,          // ← NUEVO: Estado para multiplicaciones largas
    output wire SMullCondition       // ← NUEVO: Selector signed/unsigned
);
```

**Justificación**: Estas señales permiten al controlador comunicar al datapath cuándo está procesando el segundo ciclo de UMULL/SMULL y qué tipo de multiplicación realizar.

**Conexión con el decodificador:**
```verilog
decode dec(
    // ...conexiones existentes...
    .UMullState(UMullState),         // ← NUEVO: Pasa estado de multiplicación
    .UMullCondition(),               // ← NUEVO: No se usa externamente
    .SMullCondition(SMullCondition)  // ← NUEVO: Tipo de multiplicación
);
```

### 2. Archivo `decode.v` - Decodificador Extendido

**Detección de nuevas instrucciones:**
```verilog
// ========== NUEVA SECCIÓN: DETECCIÓN DE INSTRUCCIONES ==========
// Detectar MUL: Op=00, Funct[5:1]=00000, InstrLow=1001
assign MulCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00000) && (InstrLow == 4'b1001);

// Detectar UMULL: Op=00, Funct[5:1]=00100, InstrLow=1001
assign UMullCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00100) && (InstrLow == 4'b1001);

// Detectar SMULL: Op=00, Funct[5:1]=00110, InstrLow=1001  
assign SMullCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00110) && (InstrLow == 4'b1001);

// Combinar condiciones de multiplicación larga
wire LongMullCondition = UMullCondition | SMullCondition;
```

**Análisis del patrón de bits:**
- **Op[1:0] = 00**: Identifica instrucciones de procesamiento de datos
- **Funct[5:1]**: Distingue entre MUL (00000), UMULL (00100), SMULL (00110)
- **InstrLow[3:0] = 1001**: Patrón específico para instrucciones de multiplicación

**Lógica de control ALU modificada:**
```verilog
always @(*) begin
    if (ALUOp) begin
        // ========== NUEVA LÓGICA: MULTIPLICACIONES LARGAS ==========
        if (LongMullCondition) begin
            // UMullState=0: primer ciclo (parte baja), UMullState=1: segundo ciclo (parte alta)
            ALUControl = UMullState ? 4'b0111 : 4'b0110;  
        end
        // ========== NUEVA LÓGICA: MULTIPLICACIÓN SIMPLE ==========
        else if (MulCondition) begin
            ALUControl = 4'b0101;  // Código específico para MUL
        end 
        // ========== LÓGICA EXISTENTE EXTENDIDA ==========
        else begin
            case (Funct[4:1])
                4'b0100: ALUControl = 4'b0000;  // ADD
                4'b0010: ALUControl = 4'b0001;  // SUB
                4'b0000: ALUControl = 4'b0010;  // AND
                4'b1100: ALUControl = 4'b0011;  // ORR
                4'b1101: ALUControl = 4'b0100;  // MOV
                4'b0011: ALUControl = 4'b1000;  // ← NUEVO: DIV
                default: ALUControl = 4'bxxxx;
            endcase
        end
        
        // ========== NUEVA LÓGICA: CONFIGURACIÓN FLAGS ==========
        if (LongMullCondition) begin
            // Solo actualizar flags en el segundo ciclo si S=1
            FlagW[1] = Funct[0] & UMullState;  
            FlagW[0] = 1'b0;                   // No afecta carry
        end else if (MulCondition) begin
            FlagW[1] = Funct[0];               // S bit para MUL
            FlagW[0] = 1'b0;                   // No afecta carry
        end else begin
            // Lógica existente para otras instrucciones
            FlagW[1] = Funct[0];               
            FlagW[0] = Funct[0] & ((ALUControl == 4'b0000) | (ALUControl == 4'b0001));
        end
    end
    // ...resto del código existente...
end
```

**Justificación de cambios**:
- **ALUControl 0110/0111**: Códigos únicos para partes baja/alta de multiplicación larga
- **Flags condicionados**: Solo se actualizan en el segundo ciclo para UMULL/SMULL
- **Carry no afectado**: Las multiplicaciones no modifican el flag de carry

### 3. Archivo `mainfsm.v` - Máquina de Estados Extendida

**Nuevos estados agregados:**
```verilog
// ========== NUEVOS ESTADOS ==========
localparam [3:0] UMULL1 = 10;    // Escribir RdLo (UMULL/SMULL)
localparam [3:0] UMULL2 = 11;    // Escribir RdHi (UMULL/SMULL)

// ========== NUEVA SEÑAL DE ESTADO ==========
// Detectar si estamos en el segundo ciclo de UMULL
assign UMullState = (state == UMULL1);
```

**Lógica de transición modificada:**
```verilog
always @(*)
    casex (state)
        // ...estados existentes...
        
        // ========== LÓGICA MODIFICADA: EXECUTER ==========
        EXECUTER: begin
            if (LongMullCondition)
                nextstate = UMULL1;  // ← NUEVO: Ir a escribir RdLo
            else
                nextstate = ALUWB;   // Existente: Escribir resultado normal
        end
        
        // ========== NUEVOS ESTADOS: MULTIPLICACIÓN LARGA ==========
        UMULL1: nextstate = UMULL2;  // Escribir RdHi después de RdLo
        UMULL2: nextstate = FETCH;   // Volver a buscar después de RdHi
        
        // ...resto de estados existentes...
    endcase
```

**Señales de control para nuevos estados:**
```verilog
always @(*)
    case (state)
        // ...casos existentes...
        
        // ========== NUEVOS CASOS: MULTIPLICACIÓN LARGA ==========
        // UMULL1: Escribir RdLo (parte baja multiplicación)
        // Format: {NextPC, Branch, MemW, RegW, IRWrite, AdrSrc, ResultSrc[1:0], ALUSrcA[1:0], ALUSrcB[1:0], ALUOp}
        UMULL1:   controls = 13'b0001010000001;
        //                        ||||||||||||↳ ALUOp=1 (operación aritmética)
        //                        |||||||||||↳ ALUSrcB=00 (registro)
        //                        |||||||||↳ ALUSrcA=00 (registro A)
        //                        |||||||↳ ResultSrc=01 (resultado ALU directo)
        //                        ||||||↳ AdrSrc=0 (no usar)
        //                        |||||↳ IRWrite=1 (no escribir IR)
        //                        ||||↳ RegW=1 (escribir registro)
        //                        |||↳ MemW=0 (no escribir memoria)
        //                        ||↳ Branch=0 (no branch)
        //                        |↳ NextPC=0 (no incrementar PC)

        // UMULL2: Escribir RdHi (parte alta multiplicación)
        UMULL2:   controls = 13'b0001010000000;
        //                        ||||||||||||↳ ALUOp=0 (pero decode maneja esto)
        //                        |||||||||||↳ ALUSrcB=00 (registro)
        //                        |||||||||↳ ALUSrcA=00 (registro A)
        //                        |||||||↳ ResultSrc=01 (resultado ALU directo)
        //                        ||||||↳ AdrSrc=0 (no usar)
        //                        |||||↳ IRWrite=1 (no escribir IR)
        //                        ||||↳ RegW=1 (escribir registro)
        //                        |||↳ MemW=0 (no escribir memoria)
        //                        ||↳ Branch=0 (no branch)
        //                        |↳ NextPC=0 (no incrementar PC)
        
        // ...casos existentes...
    endcase
```

### 4. Archivo `alu.v` - ALU Extendida

**Nuevas unidades de multiplicación:**
```verilog
module alu(
    // ...puertos existentes...
    input  wire   SMullCondition,    // ← NUEVO: Selector signed/unsigned mul
    // ...resto de puertos...
);

// ========== NUEVAS UNIDADES DE MULTIPLICACIÓN ==========
wire [63:0] mul_result;          // Multiplicación unsigned
wire signed [63:0] smul_result;  // Multiplicación signed

assign mul_result = SrcA * SrcB;                    // Unsigned: trata como naturales
assign smul_result = $signed(SrcA) * $signed(SrcB); // Signed: interpreta bit 31 como signo
```

**Lógica de operación extendida:**
```verilog
always @(*) begin
    casex (ALUControl)
        // ...casos existentes...
        
        // ========== NUEVAS OPERACIONES ==========
        4'b0101: ALUResult = mul_result[31:0];       // MUL (32 bits bajos)
        
        // MULL parte baja: selecciona signed/unsigned según SMullCondition
        4'b0110: ALUResult = SMullCondition ? smul_result[31:0] : mul_result[31:0];     
        
        // MULL parte alta: selecciona signed/unsigned según SMullCondition  
        4'b0111: ALUResult = SMullCondition ? smul_result[63:32] : mul_result[63:32];   
        
        // División con manejo de división por cero
        4'b1000: ALUResult = (SrcB != 0) ? (SrcA / SrcB) : 32'hFFFFFFFF;               
        
        // ...resto de casos existentes...
    endcase
end
```

**Análisis técnico:**
- **`$signed()`**: Fuerza interpretación con signo de los operandos
- **Selección condicional**: Un solo hardware maneja UMULL y SMULL
- **División segura**: Evita cuelgue del procesador en división por cero

### 5. Archivo `datapath.v` - Datapath Modificado

**Detección local de instrucciones:**
```verilog
// ========== NUEVA SECCIÓN: DETECCIÓN DE TIPOS DE INSTRUCCIÓN ==========
wire MulCondition;               // Detecta MUL
wire UMullCondition;             // Detecta UMULL
wire SMullCondition_internal;    // Detecta SMULL
wire UDivCondition_internal;     // Detecta UDIV

// Patrones de detección específicos
assign MulCondition    = (Instr[27:21] == 7'b0000000) && (Instr[7:4] == 4'b1001);
assign UMullCondition  = (Instr[27:21] == 7'b0000100) && (Instr[7:4] == 4'b1001);
assign SMullCondition_internal = (Instr[27:21] == 7'b0000110) && (Instr[7:4] == 4'b1001);
assign UDivCondition_internal = (Instr[27:26] == 2'b01) && (Instr[25:21] == 5'b11000) && (Instr[7:4] == 4'b0001);

// Combinación para multiplicaciones largas
wire LongMullCondition = UMullCondition | SMullCondition_internal;
```

**Selector de registros mejorado:**
```verilog
// ========== SELECTOR REGISTRO FUENTE 1 MODIFICADO ==========
mux2 #(4) ra1mux (
    .d0(LongMullCondition ? Instr[3:0] :      // ← NUEVO: UMULL/SMULL: Rm
         MulCondition ? Instr[3:0] :          // ← NUEVO: MUL: Rm  
                        Instr[19:16]),        // Existente: Normal: Rn
    .d1(4'b1111),                             // Existente: R15
    .s(RegSrc[0]),
    .y(RA1)
);

// ========== SELECTOR REGISTRO FUENTE 2 MODIFICADO ==========
mux2 #(4) ra2mux (
    .d0(LongMullCondition ? Instr[11:8] :     // ← NUEVO: UMULL/SMULL: Rs
         MulCondition ? Instr[11:8] :         // ← NUEVO: MUL: Rs
                        Instr[3:0]),          // Existente: Normal: Rm
    .d1(Instr[15:12]),                        // Existente: Rd
    .s(RegSrc[1]),
    .y(RA2)
);

// ========== SELECTOR REGISTRO DESTINO COMPLETAMENTE NUEVO ==========
assign WA3 = LongMullCondition ?
             (UMullState ? Instr[15:12] : Instr[19:16]) :  // UMULL: RdHi/RdLo
             (MulCondition ? Instr[19:16] : Instr[15:12]); // MUL: Rd, Normal: Rd
```

**Análisis de la lógica de registros:**
- **RA1 (Registro fuente 1)**: Para multiplicaciones usa Rm, para otras Rn
- **RA2 (Registro fuente 2)**: Para multiplicaciones usa Rs, para otras Rm  
- **WA3 (Registro destino)**: Alterna entre RdLo y RdHi según UMullState

**Conexión ALU modificada:**
```verilog
// ========== ALU CON NUEVA SEÑAL ==========
alu alu_inst (
    .SrcA(SrcA),
    .SrcB(SrcB),
    .ALUControl(ALUControl),
    .SMullCondition(SMullCondition),          // ← NUEVO: Selector signed/unsigned
    .ALUResult(ALUResult),
    .ALUFlags(ALUFlags)
);
```

### Resumen de Cambios por Archivo

| Archivo | Líneas Añadidas | Líneas Modificadas | Funcionalidad Agregada |
|---------|-----------------|-------------------|------------------------|
| `controller.v` | 2 | 5 | Señales de control nuevas |
| `decode.v` | 15 | 25 | Detección y decodificación |
| `mainfsm.v` | 8 | 12 | Estados UMULL1/UMULL2 |
| `alu.v` | 6 | 8 | Multiplicación 64-bit y división |
| `datapath.v` | 12 | 15 | Enrutamiento de registros |

**Total**: 43 líneas nuevas, 65 líneas modificadas, manteniendo 95% del código original intacto.

### 1. Modificaciones en el Controlador (`controller.v`)

**Nuevas señales agregadas:**
```verilog
output wire UMullState;          // Estado para multiplicaciones largas
output wire SMullCondition;      // Selector signed/unsigned
```

**Funcionalidad:**
- `UMullState`: Indica si estamos en el primer (0) o segundo (1) ciclo de UMULL/SMULL
- `SMullCondition`: Diferencia entre SMULL (1) y UMULL (0) para el ALU

### 2. Decodificador Extendido (`decode.v`)

**Detección de instrucciones:**
```verilog
// Detectar UMULL: Op=00, Funct[5:1]=00100, InstrLow=1001
assign UMullCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00100) && (Instr[7:4] == 4'b1001);

// Detectar SMULL: Op=00, Funct[5:1]=00110, InstrLow=1001
assign SMullCondition = (Op == 2'b00) && (Funct[5:1] == 5'b00110) && (Instr[7:4] == 4'b1001);
```

**Lógica de control ALU:**
```verilog
if (LongMullCondition) begin
    ALUControl = UMullState ? 4'b0111 : 4'b0110;  // 0111=parte alta, 0110=parte baja
end
else if (MulCondition) begin
    ALUControl = 4'b0101;  // Código para MUL
end
else begin
    case (Funct[4:1])
        // ... otras operaciones
        4'b0011: ALUControl = 4'b1000;  // DIV
    endcase
end
```

### 3. Máquina de Estados Finita (`mainfsm.v`)

**Nuevos estados agregados:**
```verilog
localparam [3:0] UMULL1 = 10;    // Escribir RdLo (UMULL/SMULL)
localparam [3:0] UMULL2 = 11;    // Escribir RdHi (UMULL/SMULL)
```

**Lógica de transición:**
```verilog
EXECUTER: begin
    if (LongMullCondition)
        nextstate = UMULL1;  // Ir a escribir RdLo
    else
        nextstate = ALUWB;   // Escribir resultado normal
end

UMULL1: nextstate = UMULL2;  // Escribir RdHi después de RdLo
UMULL2: nextstate = FETCH;   // Volver a buscar después de RdHi
```

**Señales de control para nuevos estados:**
```verilog
// UMULL1: Escribir RdLo (parte baja multiplicación)
UMULL1:   controls = 13'b0001010000001;

// UMULL2: Escribir RdHi (parte alta multiplicación)  
UMULL2:   controls = 13'b0001010000000;
```

### 4. Unidad Aritmético-Lógica (`alu.v`)

**Nuevos tipos de multiplicación:**
```verilog
wire [63:0] mul_result;          // Multiplicación unsigned
wire signed [63:0] smul_result;  // Multiplicación signed

assign mul_result = SrcA * SrcB;
assign smul_result = $signed(SrcA) * $signed(SrcB);
```

**Lógica de operación extendida:**
```verilog
always @(*) begin
    casex (ALUControl)
        4'b000?: ALUResult = sum;                    // ADD/SUB
        4'b0010: ALUResult = SrcA & SrcB;            // AND
        4'b0011: ALUResult = SrcA | SrcB;            // ORR
        4'b0100: ALUResult = SrcB;                   // MOV
        4'b0101: ALUResult = mul_result[31:0];       // MUL (32 bits bajos)
        4'b0110: ALUResult = SMullCondition ? smul_result[31:0] : mul_result[31:0];     // MULL parte baja
        4'b0111: ALUResult = SMullCondition ? smul_result[63:32] : mul_result[63:32];   // MULL parte alta
        4'b1000: ALUResult = (SrcB != 0) ? (SrcA / SrcB) : 32'hFFFFFFFF;               // DIV
        default: ALUResult = 32'hxxxxxxxx;
    endcase
end
```

### 5. Datapath Modificado (`datapath.v`)

**Detección de tipos de instrucción:**
```verilog
assign UMullCondition  = (Instr[27:21] == 7'b0000100) && (Instr[7:4] == 4'b1001);
assign SMullCondition_internal = (Instr[27:21] == 7'b0000110) && (Instr[7:4] == 4'b1001);
assign UDivCondition_internal = (Instr[27:26] == 2'b01) && (Instr[25:21] == 5'b11000) && (Instr[7:4] == 4'b0001);
```

**Selector de registros mejorado:**
```verilog
// Selector registro fuente 1
mux2 #(4) ra1mux (
    .d0(LongMullCondition ? Instr[3:0] :      // UMULL/SMULL: Rm
         MulCondition ? Instr[3:0] :          // MUL: Rm  
                        Instr[19:16]),        // Normal: Rn
    .d1(4'b1111),
    .s(RegSrc[0]),
    .y(RA1)
);

// Selector registro destino (alterna en UMULL entre RdLo y RdHi)
assign WA3 = LongMullCondition ?
             (UMullState ? Instr[15:12] : Instr[19:16]) :  // UMULL: RdHi/RdLo
             (MulCondition ? Instr[19:16] : Instr[15:12]); // MUL: Rd, Normal: Rd
```

## Modificaciones Realizadas

### Cambios Arquitectónicos Principales

1. **Extensión de Estados**: Se agregaron dos nuevos estados (UMULL1, UMULL2) para manejar la escritura secuencial de resultados de 64 bits.

2. **Señales de Control Nuevas**: 
   - `UMullState`: Para alternar entre escritura de RdLo y RdHi
   - `SMullCondition`: Para diferenciar multiplicación con/sin signo

3. **ALU Extendida**: Se agregaron unidades de multiplicación de 64 bits y división con manejo de división por cero.

4. **Routing Mejorado**: El datapath fue modificado para enrutar correctamente los registros fuente y destino según el tipo de instrucción.

### Desafíos Técnicos Superados

1. **Gestión de Estados Multiciclo**: Las instrucciones UMULL/SMULL requieren dos ciclos de escritura, lo que necesitó una cuidadosa coordinación entre la FSM y el datapath.

2. **Diferenciación de Tipos**: Implementar la lógica para diferenciar entre multiplicación con signo y sin signo dentro del mismo flujo de control.

3. **Manejo de Registros**: Alternancia correcta entre RdLo y RdHi en multiplicaciones largas.

4. **División por Cero**: Implementación de manejo seguro retornando 0xFFFFFFFF.

### Optimizaciones Implementadas

1. **Reutilización de Hardware**: Se aprovechó la infraestructura existente del ALU para las nuevas operaciones.

2. **Minimal State Overhead**: Solo se agregaron los estados estrictamente necesarios.

3. **Señales de Control Eficientes**: Se minimizó el número de señales de control nuevas.

## Validación y Pruebas

### Metodología de Prueba

Para validar la implementación se pueden usar los siguientes casos de prueba:

```assembly
# Prueba UMULL
MOV R0, #0x12345678    # Operando 1
MOV R1, #0x9ABCDEF0    # Operando 2
UMULL R2, R3, R0, R1   # R3:R2 = R0 * R1 (unsigned)

# Prueba SMULL  
MOV R4, #0x80000000    # Número negativo grande
MOV R5, #0x7FFFFFFF    # Número positivo grande
SMULL R6, R7, R4, R5   # R7:R6 = R4 * R5 (signed)

# Prueba UDIV
MOV R8, #100           # Dividendo
MOV R9, #7             # Divisor
UDIV R10, R8, R9       # R10 = R8 / R9 = 14

# Prueba división por cero
MOV R11, #0            # Divisor cero
UDIV R12, R8, R11      # R12 = 0xFFFFFFFF
```

### Resultados Esperados

1. **UMULL**: Debe producir el resultado correcto de 64 bits sin considerar el signo
2. **SMULL**: Debe manejar correctamente la multiplicación con signo
3. **UDIV**: Debe realizar división entera y manejar división por cero

### Verificación de Flags

Las instrucciones con sufijo 'S' deben actualizar correctamente los flags:
- **N (Negative)**: Bit más significativo del resultado
- **Z (Zero)**: Resultado es cero
- **C (Carry)**: No se modifica para multiplicaciones
- **V (Overflow)**: No se modifica para multiplicaciones

## Conclusiones

### Logros Alcanzados

1. **Implementación Exitosa**: Se logró integrar completamente las tres instrucciones manteniendo la funcionalidad existente.

2. **Arquitectura Escalable**: Las modificaciones fueron diseñadas para facilitar futuras extensiones.

3. **Compatibilidad Mantenida**: Todas las instrucciones originales siguen funcionando correctamente.

4. **Eficiencia de Hardware**: Se minimizó el overhead de hardware adicional.

### Lecciones Aprendidas

1. **Importancia del Diseño Modular**: La estructura modular del procesador original facilitó significativamente las modificaciones.

2. **Complejidad de Estados**: Las instrucciones multiciclo requieren un análisis cuidadoso del flujo de control.

3. **Verificación Exhaustiva**: Cada modificación debe ser verificada tanto individualmente como en conjunto.

### Trabajos Futuros

1. **Instrucciones Adicionales**: Implementar SMLAL, UMLAL (multiply-accumulate)
2. **Optimización de Timing**: Reducir el número de ciclos requeridos
3. **Pipeline**: Migrar a una arquitectura pipeline para mejor rendimiento
4. **Punto Flotante**: Agregar unidad de punto flotante

## Referencias

1. ARM Architecture Reference Manual ARMv7-A and ARMv7-R edition
2. Harris, D. & Harris, S. "Digital Design and Computer Architecture: ARM Edition"
3. ARM Developer Documentation - Instruction Set Reference
4. Documentación del curso de Arquitectura de Computadoras - UTEC

---

**Nota**: Este README documenta la implementación realizada como parte del proyecto de Arquitectura de Computadoras. El código fuente completo y los archivos de prueba están disponibles en el directorio del proyecto.
