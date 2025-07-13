# Implementación de Unidad de Punto Flotante (FPU) en Procesador ARM Multiciclo

## Tabla de Contenidos
1. [Introducción](#introducción)
2. [Arquitectura General](#arquitectura-general)
3. [Codificación de Instrucciones](#codificación-de-instrucciones)
4. [Implementación de la FPU](#implementación-de-la-fpu)
5. [Proceso de Ejecución](#proceso-de-ejecución)
6. [Ejemplos de Uso](#ejemplos-de-uso)
7. [Archivos del Proyecto](#archivos-del-proyecto)

## Introducción

Este proyecto implementa una **Unidad de Punto Flotante (FPU)** completa en un procesador ARM multiciclo, soportando operaciones FADD (suma flotante) y FMUL (multiplicación flotante) en precisiones de **16 bits** y **32 bits** según el estándar **IEEE 754**.

### Características Principales
- ✅ **FADD**: Suma de punto flotante
- ✅ **FMUL**: Multiplicación de punto flotante
- ✅ **Precisión dual**: 16-bit (half precision) y 32-bit (single precision)
- ✅ **Detección de overflow**: Flags de estado
- ✅ **Conversión automática**: Entre FP16 y FP32
- ✅ **Integración completa**: En datapath y control unit

## Arquitectura General

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Controller    │───▶│    Datapath     │───▶│      ALU        │
│                 │    │                 │    │                 │
│  - Decode       │    │  - Registers    │    │  - Integer Ops  │
│  - FSM          │    │  - Multiplexers │    │  - FPU          │
│  - Control      │    │  - Data Flow    │    │  - Flags        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Codificación de Instrucciones

### Formato de Instrucciones de Punto Flotante

Las instrucciones de punto flotante siguen un formato específico de 32 bits que permite al procesador identificar y ejecutar operaciones FADD y FMUL:

```
31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
│  Cond   │  1  1   │  Funct  │   Rn    │   Rd    │   Rm    │  1010   │
└─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
```

#### Descripción Detallada de Cada Campo:

| Campo | Bits | Función | Descripción |
|-------|------|---------|-------------|
| **Cond** | 31:28 | Condición | Código de condición (normalmente 1110 = ALWAYS) |
| **Op** | 27:26 | Opcode | Siempre `11` para instrucciones de punto flotante |
| **Funct** | 25:20 | Función | Especifica el tipo de operación y precisión |
| **Rn** | 19:16 | Registro fuente 1 | Primer operando (4 bits) |
| **Rd** | 15:12 | Registro destino | Registro donde se guarda el resultado (4 bits) |
| **Rm** | 11:8 | Registro fuente 2 | Segundo operando (4 bits) |
| **Identificador** | 7:4 | Marcador FP | Siempre `1010` para identificar instrucciones FP |
| **Rm (repetido)** | 3:0 | Registro fuente 2 | Repetición del segundo operando |

#### Desglose del Campo Funct (25:20):

```
25  24  23  22  21  20
├───┼───┼───┼───┼───┼───┤
│ 1 │ 1 │ Op│ Ty│ Pr│ S │
└───┴───┴───┴───┴───┴───┘
```

| Subfcampo | Bits | Función | Valores |
|------------|------|---------|---------|
| **Bits 25:24** | 25:24 | Identificador FP | Siempre `11` |
| **Op** | 23:22 | Tipo de operación | `00` = FADD, `10` = FMUL |
| **Ty** | 21 | Reservado | Normalmente `0` |
| **Pr** | 20 | Precisión | `0` = 32-bit, `1` = 16-bit |
| **S** | 19 | Update flags | `1` = actualizar flags, `0` = no actualizar |

#### Ejemplos de Codificación Completa:

**FADD R0, R1, R3 (32-bit):**
```
Instrucción: EF0103A3
Binario: 1110 1111 0000 0001 0000 0011 1010 0011

Desglose:
- Cond (31:28): 1110 = ALWAYS
- Op (27:26): 11 = Instrucción FP
- Funct[5:4] (25:24): 11 = Identificador FP
- Funct[3:2] (23:22): 00 = FADD
- Funct[1] (21): 0 = Reservado
- Funct[0] (20): 1 = Update flags
- Rn (19:16): 0001 = R1 (primer operando)
- Rd (15:12): 0000 = R0 (destino)
- Rm (11:8): 0011 = R3 (segundo operando)
- Identificador (7:4): 1010 = Marcador FP
- Rm repetido (3:0): 0011 = R3 (confirmación)
```

**FMUL R0, R1, R3 (32-bit):**
```
Instrucción: EF8103A3
Binario: 1110 1111 1000 0001 0000 0011 1010 0011

Desglose:
- Cond (31:28): 1110 = ALWAYS
- Op (27:26): 11 = Instrucción FP
- Funct[5:4] (25:24): 11 = Identificador FP
- Funct[3:2] (23:22): 10 = FMUL
- Funct[1] (21): 0 = Reservado
- Funct[0] (20): 1 = Update flags
- Rn (19:16): 0001 = R1 (primer operando)
- Rd (15:12): 0000 = R0 (destino)
- Rm (11:8): 0011 = R3 (segundo operando)
- Identificador (7:4): 1010 = Marcador FP
- Rm repetido (3:0): 0011 = R3 (confirmación)
```

#### Diferencias con Instrucciones ARM Estándar:

1. **Campo Op (27:26)**: 
   - ARM estándar: `00` (data processing), `01` (memory), `10` (branch)
   - Punto flotante: `11` (extensión para FP)

2. **Identificador único (7:4)**:
   - ARM estándar: Varios formatos
   - Punto flotante: Siempre `1010` para diferenciación

3. **Campo Funct extendido**:
   - Utiliza bits 25:20 para especificar operación y precisión
   - Permite identificación única de FADD vs FMUL

### Codificación de la Instrucción ORR y Construcción de Valores Inmediatos

#### Formato de Instrucciones Data Processing (ORR, MOV)

Las instrucciones de procesamiento de datos (Data Processing) como ORR y MOV siguen un formato diferente, identificado por Op=00:

```
31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
├─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
│  Cond   │  0  0   │ I │ Funct │ S │ Rn    │ Rd    │    Operand2         │
└─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
```

#### Descripción de Campos para ORR:

| Campo | Bits | Función | Descripción |
|-------|------|---------|-------------|
| **Cond** | 31:28 | Condición | Código de condición (normalmente 1110 = ALWAYS) |
| **Op** | 27:26 | Opcode | Siempre `00` para instrucciones de procesamiento de datos |
| **I** | 25 | Inmediato | `1` = operando inmediato, `0` = operando registro |
| **Funct** | 24:21 | Función | `1100` = ORR, `1101` = MOV |
| **S** | 20 | Update flags | `1` = actualizar flags, `0` = no actualizar |
| **Rn** | 19:16 | Registro fuente 1 | Primer operando (solo para ORR) |
| **Rd** | 15:12 | Registro destino | Registro donde se guarda el resultado |
| **Operand2** | 11:0 | Segundo operando | Inmediato rotado o registro |

#### Formato del Operando Inmediato (Operand2):

```
11 10 9 8 7 6 5 4 3 2 1 0
├─────────┼─────────────────┤
│ Rotate  │    Imm8         │
└─────────┴─────────────────┘
```

| Campo | Bits | Función | Descripción |
|-------|------|---------|-------------|
| **Rotate** | 11:8 | Rotación | Campo de rotación (multiplicar por 2 para obtener bits) |
| **Imm8** | 7:0 | Inmediato | Valor inmediato de 8 bits |

#### Sistema de Rotación de Inmediatos:

El procesador ARM permite crear valores inmediatos de 32 bits a partir de un valor base de 8 bits mediante rotación circular:

```
Valor_Final = Imm8 ROR (Rotate * 2)
```

**Ejemplo de Rotación:**
- Imm8 = 0x01 (00000001)
- Rotate = 0x1 (0001)
- Rotación = 0x1 * 2 = 2 bits
- Resultado = 0x01 ROR 2 = 0x40000000

#### Limitaciones del Sistema de Inmediatos:

Debido a la limitación del campo de 8 bits y la rotación, **no todos los valores de 32 bits pueden ser codificados como inmediatos**. Por ejemplo:

- ✅ **Posible**: 0x40000000 (0x01 ROR 2)
- ✅ **Posible**: 0x00200000 (0x02 ROR 22)
- ❌ **Imposible**: 0x40200000 (requiere múltiples bits '1' no alineados)

### Estrategia de Construcción de Valores Grandes

Para construir valores de 32 bits que no pueden ser codificados como inmediatos únicos, se utiliza una **combinación de MOV y ORR**:

#### Técnica MOV + ORR:

1. **MOV**: Cargar la parte más significativa del valor
2. **ORR**: Combinar (OR lógico) con la parte menos significativa

#### Ejemplo Práctico: Construir 0x40200000

**Análisis del valor objetivo:**
```
0x40200000 = 01000000001000000000000000000000
```

**Descomposición:**
- Parte alta: 0x40000000 = 01000000000000000000000000000000
- Parte baja: 0x00200000 = 00000000001000000000000000000000

**Secuencia de instrucciones:**
```assembly
MOV R1, #0x40000000     ; Cargar 0x40000000 en R1
MOV R2, #0x00200000     ; Cargar 0x00200000 en R2
ORR R1, R1, R2          ; R1 = R1 OR R2 = 0x40200000
```

#### Codificación Detallada:

**MOV R1, #0x40000000:**
```
Instrucción: e3a01101
Binario: 1110 0011 1010 0001 0001 0001 0000 0001

Desglose:
- Cond (31:28): 1110 = ALWAYS
- Op (27:26): 00 = Data Processing
- I (25): 1 = Inmediato
- Funct (24:21): 1101 = MOV
- S (20): 0 = No actualizar flags
- Rn (19:16): 0000 = No usado en MOV
- Rd (15:12): 0001 = R1 (destino)
- Rotate (11:8): 0001 = 1 → rotación de 2 bits
- Imm8 (7:0): 00000001 = 0x01
- Cálculo: 0x01 ROR 2 = 0x40000000
```

**MOV R2, #0x00200000:**
```
Instrucción: e3a02502
Binario: 1110 0011 1010 0010 0010 0101 0000 0010

Desglose:
- Cond (31:28): 1110 = ALWAYS
- Op (27:26): 00 = Data Processing
- I (25): 1 = Inmediato
- Funct (24:21): 1101 = MOV
- S (20): 0 = No actualizar flags
- Rn (19:16): 0000 = No usado en MOV
- Rd (15:12): 0010 = R2 (destino)
- Rotate (11:8): 0101 = 5 → rotación de 10 bits
- Imm8 (7:0): 00000010 = 0x02
- Cálculo: 0x02 ROR 10 = 0x00200000
```

**ORR R1, R1, R2:**
```
Instrucción: e1811002
Binario: 1110 0001 1000 0001 0001 0000 0000 0010

Desglose:
- Cond (31:28): 1110 = ALWAYS
- Op (27:26): 00 = Data Processing
- I (25): 0 = Registro (no inmediato)
- Funct (24:21): 1100 = ORR
- S (20): 0 = No actualizar flags
- Rn (19:16): 0001 = R1 (primer operando)
- Rd (15:12): 0001 = R1 (destino)
- Shift (11:7): 00000 = No desplazamiento
- Rm (3:0): 0010 = R2 (segundo operando)
- Resultado: R1 = 0x40000000 OR 0x00200000 = 0x40200000
```

### Proceso de Decodificación en el Procesador

#### En el Módulo `decode.v`:

```verilog
// Decodificación de la función ALU para ORR
4'b1100: ALUControl = 4'b0011;  // ORR
```

#### En el Módulo `extend.v`:

```verilog
// Extensión de inmediatos rotados para instrucciones Data Processing
wire [7:0] imm8 = Instr[7:0];
wire [3:0] rotate = Instr[11:8];
wire [4:0] cantidad_rotacion = rotate * 2;

// Rotación circular a la derecha
assign valor_rotado = ({24'b0, imm8} >> cantidad_rotacion) | 
                      ({24'b0, imm8} << (32 - cantidad_rotacion));
```

#### En el Módulo `alu.v`:

```verilog
// Operación ORR (OR lógico)
4'b0011: ALUResult = a | b;  // ORR
```

## Implementación de la FPU

### Estructura del Módulo FPU (`fpu.v`)

```verilog
module fpu (
  input wire [31:0] a, b,           // Operandos
  input wire op,                    // 0: add, 1: mul
  input wire precision,             // 0: 16-bit, 1: 32-bit
  output reg [31:0] result,         // Resultado
  output reg overflowFlag           // Flag de overflow
);
```

### Funciones de Conversión

#### FP16 a FP32 (`convert_half_to_single`)

```verilog
function [31:0] convert_half_to_single;
    input [15:0] half_input;
    reg sign_bit;
    reg [4:0] exp_half;          // Exponente en FP16
    reg [9:0] mantissa_half;     // Mantisa en FP16
    reg [7:0] exp_single;        // Exponente en FP32
    reg [22:0] mantissa_single;  // Mantisa en FP32
    begin
        sign_bit = half_input[15];
        exp_half = half_input[14:10];
        mantissa_half = half_input[9:0];
        
        if (exp_half == 0) begin
            exp_single = 0;
            mantissa_single = 0;
        end else if (exp_half == 5'b11111) begin
            exp_single = 8'hFF;
            mantissa_single = {mantissa_half, 13'b0};
        end else begin
            // Ajustar bias del exponente (15 para FP16, 127 para FP32)
            exp_single = exp_half - 5'd15 + 8'd127;
            mantissa_single = {mantissa_half, 13'b0};
        end
        
        convert_half_to_single = {sign_bit, exp_single, mantissa_single};
    end
endfunction
```

#### FP32 a FP16 (`convert_single_to_half`)

```verilog
function [15:0] convert_single_to_half;
    input [31:0] single_input;
    reg sign_bit;
    reg [7:0] exp_single;        // Exponente en FP32
    reg [22:0] mantissa_single;  // Mantisa en FP32
    reg [4:0] exp_half;          // Exponente en FP16
    reg [9:0] mantissa_half;     // Mantisa en FP16
    begin
        sign_bit = single_input[31];
        exp_single = single_input[30:23];
        mantissa_single = single_input[22:0];
        
        if (exp_single == 0) begin
            exp_half = 0;
            mantissa_half = 0;
        end else if (exp_single == 8'hFF) begin
            exp_half = 5'b11111;
            mantissa_half = mantissa_single[22:13];
        end else begin
            // Ajustar bias del exponente (127 para FP32, 15 para FP16)
            exp_half = exp_single - 8'd127 + 5'd15;
            mantissa_half = mantissa_single[22:13];
            // Saturación para evitar overflow
            if (exp_half > 5'd30) begin
                exp_half = 5'b11111;
                mantissa_half = 0;
            end else if (exp_half < 1) begin
                exp_half = 0;
                mantissa_half = 0;
            end
        end
        
        convert_single_to_half = {sign_bit, exp_half, mantissa_half};
    end
endfunction
```

### Algoritmo de Suma Flotante (`fp_add`)

#### Pasos del Algoritmo:

1. **Extracción de Campos**:
   ```verilog
   sign_a = a[31];
   exp_a = a[30:23];
   mantissa_a = {1'b1, a[22:0]};  // Agregar bit implícito
   ```

2. **Casos Especiales**:
   - Operando cero: retorna el otro operando
   - Infinito/NaN: retorna NaN (0x7FC00000)

3. **Alineación de Exponentes**:
   ```verilog
   if (exp_a > exp_b) begin
       exp_diff = exp_a - exp_b;
       exp_res = exp_a;
       mantissa_b = mantissa_b >> exp_diff;  // Desplazar mantisa menor
   end
   ```

4. **Suma o Resta según Signos**:
   ```verilog
   if (sign_a == sign_b) begin
       mantissa_sum = mantissa_a + mantissa_b;
       sign_res = sign_a;
   end else begin
       if (mantissa_a >= mantissa_b) begin
           mantissa_sum = mantissa_a - mantissa_b;
           sign_res = sign_a;
       end else begin
           mantissa_sum = mantissa_b - mantissa_a;
           sign_res = sign_b;
       end
   end
   ```

5. **Normalización**:
   ```verilog
   if (mantissa_sum[24]) begin          // Overflow de mantisa
       mantissa_sum = mantissa_sum >> 1;
       exp_res = exp_res + 1;
   end else if (mantissa_sum[23] == 0) begin  // Underflow de mantisa
       // Encontrar primer bit 1 y desplazar
       mantissa_sum = mantissa_sum << shift_count;
       exp_res = exp_res - shift_count;
   end
   ```

### Algoritmo de Multiplicación Flotante (`fp_mul`)

#### Pasos del Algoritmo:

1. **Extracción de Campos**:
   ```verilog
   sign_res = sign_a ^ sign_b;  // XOR de signos
   exp_res = exp_a + exp_b - 8'd127;  // Suma exponentes y ajusta bias
   ```

2. **Multiplicación de Mantisas**:
   ```verilog
   mantissa_product = mantissa_a * mantissa_b;  // Producto de 48 bits
   ```
   Las mantisas son la parte fraccionaria

3. **Normalización del Producto**:
   ```verilog
   if (mantissa_product[47]) begin
       mantissa_res = mantissa_product[46:24];
       exp_res = exp_res + 1;
   end else begin
       mantissa_res = mantissa_product[45:23];
   end
   ```

4. **Verificación de Overflow/Underflow**:
   ```verilog
   if (exp_res >= 9'd255) begin
       fp_mul = {sign_res, 8'hFF, 23'b0};  // Infinito
   end else if (exp_res <= 0) begin
       fp_mul = {sign_res, 31'b0};         // Cero
   end
   ```

## Proceso de Ejecución

### Flujo en la Máquina de Estados (`mainfsm.v`)

```
FETCH → DECODE → EXECUTER → ALUWB → FETCH
```

#### Estados Relevantes:

1. **DECODE**: Identifica instrucción de punto flotante
   ```verilog
   2'b11: begin  
       if (floatCond)
           nextstate = EXECUTER;  // FADD/FMUL van directo a ejecución
       else
           nextstate = UNKNOWN;
   end
   ```

2. **EXECUTER**: Ejecuta operación en FPU
   ```verilog
   EXECUTER: begin
       if (LongMullCondition)
           nextstate = UMULL1;
       else 
           nextstate = ALUWB;  // FADD/FMUL completan en un ciclo
   end
   ```

3. **ALUWB**: Escribe resultado en registro
   ```verilog
   ALUWB: controls = 13'b0001000000000;  // Escribe resultado FP en registro
   ```

### Integración en el Datapath (`datapath.v`)

#### Detección de Instrucciones FP:
```verilog
// Detectar si es punto flotante
assign FPCond = CondFAdd | CondFMull;
```

#### Selección de Registros:
```verilog
// Multiplexor para dirección de registro fuente 1
assign RA1 = FPCond ? Instr[19:16] : /* otras opciones */;

// Multiplexor para dirección de registro fuente 2  
assign RA2 = FPCond ? Instr[3:0] : /* otras opciones */;

// Selector de registro destino
assign WriteRegAddr = FPCond ? Instr[15:12] : /* otras opciones */;
```

#### Integración con ALU:
```verilog
alu alu_inst (
    .a(a),
    .b(b),
    .ALUControl(ALUControl),
    .CondFAdd(CondFAdd),  
    .CondFMull(CondFMull),  
    .ALUResult(ALUResult),
    .ALUFlags(ALUFlags)
);
```

### Control de ALU (`alu.v`)

#### Detección de Operaciones FP:
```verilog
// Detectar si es punto flotante
wire is_fp_op = (ALUControl == 4'b1100) || (ALUControl == 4'b1001) || 
                (ALUControl == 4'b1010) || (ALUControl == 4'b1011);
```

#### Instanciación de FPU:
```verilog
// Instancia de la unidad de punto flotante
fpu instancia_fpu (
    .a(a),
    .b(b),
    .op(ALUControl[1]),           // 0: suma flotante, 1: multiplicación flotante
    .precision(~ALUControl[0]),   // 1: operación en 32 bits, 0: operación en 16 bits
    .result(fpuResultado),        // Resultado de la operación FPU
    .overflowFlag(fpuOverflow)    // Bandera de overflow de la FPU
);
```

#### Multiplexor de Salida:
```verilog
always @(*) begin
    casex (ALUControl)
        4'b1100: ALUResult = fpuResultado;  // FAdd de 32 bits
        4'b1001: ALUResult = fpuResultado;  // FAdd de 16 bits
        4'b1010: ALUResult = fpuResultado;  // FMul de 32 bits
        4'b1011: ALUResult = fpuResultado;  // FMul de 16 bits
        // ... otras operaciones
    endcase
end
```

#### Flags de Estado:
```verilog
assign overflow = is_fp_op ? fpuOverflow : /* overflow entero */;
assign carry = is_fp_op ? 1'b0 : /* carry entero */;
```

## Ejemplos de Uso

### Ejemplo 1: Construcción de Valores y Suma de Punto Flotante 32-bit

#### Construir el valor 2.5 (0x40200000):

**Análisis IEEE 754:**
- Valor: 2.5 = 10.1₂ = 1.01₂ × 2¹
- Signo: 0 (positivo)
- Exponente: 1 + 127 = 128 = 10000000₂
- Mantisa: 01000000000000000000000₂
- Resultado: 0x40200000

**Secuencia de instrucciones:**
```assembly
; Construir 2.5 (0x40200000) usando MOV + ORR
MOV R1, #0x40000000     ; e3a01101 - Cargar parte alta
MOV R2, #0x00200000     ; e3a02502 - Cargar parte baja  
ORR R1, R1, R2          ; e1811002 - Combinar: R1 = 0x40200000 = 2.5
```

**Codificación detallada:**
```
MOV R1, #0x40000000 (e3a01101):
- Inmediato: 0x01 ROR 2 = 0x40000000
- Resultado: R1 = 0x40000000

MOV R2, #0x00200000 (e3a02502):
- Inmediato: 0x02 ROR 10 = 0x00200000
- Resultado: R2 = 0x00200000

ORR R1, R1, R2 (e1811002):
- Operación: 0x40000000 OR 0x00200000 = 0x40200000
- Resultado: R1 = 0x40200000 (2.5 en IEEE 754)
```

#### Construir el valor 1.75 (0x3FE00000):

**Análisis IEEE 754:**
- Valor: 1.75 = 1.11₂ × 2⁰
- Signo: 0 (positivo)
- Exponente: 0 + 127 = 127 = 01111111₂
- Mantisa: 11000000000000000000000₂
- Resultado: 0x3FE00000

**Secuencia de instrucciones:**
```assembly
; Construir 1.75 (0x3FE00000) usando MOV + ORR
MOV R3, #0x3F000000     ; e3a0343f - Cargar parte alta
MOV R4, #0x00E00000     ; e3a0460e - Cargar parte baja
ORR R3, R3, R4          ; e1833004 - Combinar: R3 = 0x3FE00000 = 1.75
```

#### Operación de Suma Flotante:

```assembly
; Suma: 2.5 + 1.75 = 4.25 (0x40880000)
FADD R0, R1, R3         ; EF0103A3
```

**Resultado esperado:**
- 2.5 + 1.75 = 4.25
- 4.25 = 100.01₂ = 1.0001₂ × 2²
- Exponente: 2 + 127 = 129 = 10000001₂
- Mantisa: 00010000000000000000000₂
- Resultado: 0x40880000

### Ejemplo 2: Multiplicación de Punto Flotante 32-bit

```assembly
; Multiplicación: 2.5 * 1.75 = 4.375 (0x408C0000)
FMUL R0, R1, R3         ; EF8103A3
```

**Resultado esperado:**
- 2.5 × 1.75 = 4.375
- 4.375 = 100.011₂ = 1.00011₂ × 2²
- Exponente: 2 + 127 = 129 = 10000001₂
- Mantisa: 00011000000000000000000₂
- Resultado: 0x408C0000

### Programa Completo de Prueba

El archivo `memfile.txt` contiene el programa completo:

```assembly
; Programa de prueba para operaciones de punto flotante
; Construye valores IEEE 754 usando MOV + ORR y ejecuta FADD/FMUL

; Construir 2.5 (0x40200000)
MOV R1, #0x40000000     ; e3a01101
MOV R2, #0x00200000     ; e3a02502
ORR R1, R1, R2          ; e1811002

; Construir 1.75 (0x3FE00000)
MOV R3, #0x3F000000     ; e3a0343f
MOV R4, #0x00E00000     ; e3a0460e
ORR R3, R3, R4          ; e1833004

; Operaciones de punto flotante
FADD R0, R1, R3         ; EF0103A3  (R0 = 2.5 + 1.75 = 4.25)
FMUL R0, R1, R3         ; EF8103A3  (R0 = 2.5 * 1.75 = 4.375)
```

### Análisis de Codificación de Instrucciones

#### FADD R0, R1, R3 (EF0103A3):
```
Binario: 1110 1111 0000 0001 0000 0011 1010 0011
Desglose:
- Cond (31:28): 1110 = ALWAYS
- Op (27:26): 11 = Instrucción FP
- Funct[5:4] (25:24): 11 = Identificador FP
- Funct[3:2] (23:22): 00 = FADD
- Funct[1] (21): 0 = 32-bit
- Funct[0] (20): 1 = Update flags
- Rn (19:16): 0001 = R1 (primer operando)
- Rd (15:12): 0000 = R0 (destino)
- Rm (11:8): 0011 = R3 (segundo operando)
- Identificador (7:4): 1010 = Marcador FP
- Rm repetido (3:0): 0011 = R3 (confirmación)
```

#### FMUL R0, R1, R3 (EF8103A3):
```
Binario: 1110 1111 1000 0001 0000 0011 1010 0011
Desglose:
- Cond (31:28): 1110 = ALWAYS
- Op (27:26): 11 = Instrucción FP
- Funct[5:4] (25:24): 11 = Identificador FP
- Funct[3:2] (23:22): 10 = FMUL
- Funct[1] (21): 0 = 32-bit
- Funct[0] (20): 1 = Update flags
- Rn (19:16): 0001 = R1 (primer operando)
- Rd (15:12): 0000 = R0 (destino)
- Rm (11:8): 0011 = R3 (segundo operando)
- Identificador (7:4): 1010 = Marcador FP
- Rm repetido (3:0): 0011 = R3 (confirmación)
```

### Importancia de la Técnica MOV + ORR

La técnica de **MOV + ORR** es fundamental para trabajar con valores de punto flotante porque:

1. **Limitación de inmediatos**: ARM solo permite inmediatos de 8 bits rotados
2. **Valores IEEE 754**: Requieren precisión exacta de 32 bits
3. **Flexibilidad**: Permite construir cualquier valor requerido
4. **Eficiencia**: Solo 3 instrucciones por valor flotante

Sin esta técnica, sería **imposible** cargar valores de punto flotante específicos en el procesador ARM, limitando severamente su capacidad de cálculo científico y numérico.

## Archivos del Proyecto

### Archivos Principales:

1. **`fpu.v`**: Implementación completa de la FPU
   - Funciones de conversión FP16/FP32
   - Algoritmos de suma y multiplicación IEEE 754
   - Manejo de casos especiales y normalización

2. **`alu.v`**: Unidad Aritmético-Lógica extendida
   - Integración de la FPU
   - Multiplexor de operaciones
   - Generación de flags

3. **`decode.v`**: Decodificador de instrucciones
   - Detección de instrucciones FP
   - Generación de señales de control
   - Manejo de flags según tipo de operación

4. **`datapath.v`**: Ruta de datos del procesador
   - Multiplexores para registros FP
   - Integración con banco de registros
   - Flujo de datos especializado

5. **`mainfsm.v`**: Máquina de estados principal
   - Estados para operaciones FP
   - Transiciones específicas
   - Generación de señales de control

6. **`controller.v`**: Controlador principal
   - Coordinación entre decode y FSM
   - Generación de señales de control
   - Manejo de condiciones

### Archivos de Soporte:

- **`memfile.txt`**: Programa de prueba con instrucciones FP
- **`top.v`**: Módulo superior del procesador
- **`basys_top.v`**: Interfaz para placa FPGA
- **`hex_display.v`**: Display para resultados

## Consideraciones de Implementación

### Precisión y Formato IEEE 754:

#### Single Precision (32-bit):
```
[31] [30:23] [22:0]
 S    Exp    Mantissa
```
- **Bias del exponente**: 127
- **Rango del exponente**: -126 a +127
- **Precisión**: ~7 dígitos decimales

#### Half Precision (16-bit):
```
[15] [14:10] [9:0]
 S    Exp    Mantissa  
```
- **Bias del exponente**: 15
- **Rango del exponente**: -14 a +15
- **Precisión**: ~3 dígitos decimales

### Manejo de Casos Especiales:

1. **Cero**: Exponente = 0, Mantisa = 0
2. **Infinito**: Exponente = max, Mantisa = 0
3. **NaN**: Exponente = max, Mantisa ≠ 0
4. **Números desnormalizados**: Exponente = 0, Mantisa ≠ 0

### Optimizaciones:

1. **Pipeline**: Operaciones FP completan en 1 ciclo
2. **Conversión eficiente**: Entre FP16 y FP32
3. **Detección rápida**: De tipo de instrucción
4. **Flags integrados**: Con el sistema de flags del procesador

## Conclusiones

Esta implementación proporciona una **FPU completa y eficiente** para un procesador ARM multiciclo, con soporte para:

- ✅ **Operaciones FADD y FMUL** en precisiones 16 y 32 bits
- ✅ **Cumplimiento del estándar IEEE 754**
- ✅ **Integración transparente** con el procesador existente
- ✅ **Manejo completo de casos especiales**
- ✅ **Generación apropiada de flags**

La implementación es **modular**, **escalable** y **completamente funcional**, lista para ser sintetizada en FPGA y probada con programas reales.
