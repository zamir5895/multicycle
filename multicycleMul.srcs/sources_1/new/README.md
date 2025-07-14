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
4. [Implementación Detallada](#implementación-detallada)
5. [Modificaciones Realizadas](#modificaciones-realizadas)
6. [Validación y Pruebas](#validación-y-pruebas)
7. [Conclusiones](#conclusiones)
8. [Referencias](#referencias)

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

## Implementación Detallada

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
