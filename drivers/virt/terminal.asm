// drivers/virt/terminal.asm
.global _escrever_saida
.global _escrever_tex
.global _escrever_car
.global _escrever_hex
.global _escrever_decimal
.global _obter_car
.global _config_uart

.section .bss
uart_base_real: .quad 0
.align 4
hex_buffer: .space 17
    .byte 0
.align 8
dec_buffer: .space 21

.section .text
_config_uart:
    // inicia uart_base_real so uma vez
    ldr x9, = UART_BASE
    ldr x10, = uart_base_real
    str x9, [x10]
    
    // habilita TX
    mov w1, 0x301
    ldr x2, = UART_CR
    str w1, [x9, x2]
    ret
_escrever_car:
    // pega UART base diretamente
    ldr x9, = uart_base_real
    ldr x9, [x9]
    // escreve direto
    ldr x3, = UART_DR
    strb w0, [x9, x3]
    ret
_obter_car:
    ldr x9, = uart_base_real
    ldr x9, [x9]
1:
    ldr x3, = UART_FR
    ldr w1, [x9, x3]
    ldr x2, = FR_RXFE
    ands w1, w1, w2
    b.ne 1b
    ldr x3, = UART_DR
    ldrb w0, [x9, x3]
    ret
_escrever_tex:
    stp x0, x1, [sp, -16]!
    stp x2, x4, [sp, -16]!
    
    mov x1, 0x09000000      // UART base hardcoded, não usa variável!
    
1:
    ldrb w2, [x0], 1
    cbz w2, 2f
    ldr x4, = UART_DR
    strb w2, [x1, x4]
    b 1b
2:
    ldp x2, x4, [sp], 16
    ldp x0, x1, [sp], 16
    ret
_escrever_saida:
    // x0 = buffer, x1 = conta
    stp x2, x3, [sp, -16]! // preserva x2, x3
    stp x4, x5, [sp, -16]! // preserva x4, x5
    
    mov x2, x0 // buffer pra x2
    mov x3, x1 // conta pra x3
    
    ldr x4, = uart_base_real
    ldr x4, [x4]
    ldr x5, = UART_DR
1:
    cbz x3, 2f // Se conta == 0, termina
    ldrb w0, [x2], 1 // carrega caractere em w0
    strb w0, [x4, x5] // escreve caractere na uart
    sub x3, x3, 1 // decrementa conta
    b 1b
2:
    ldp x4, x5, [sp], 16
    ldp x2, x3, [sp], 16
    mov x0, x1 // retorna conta original
    ret
_escrever_hex:
    // x0 = valor pra escrever
    stp x29, x30, [sp, -48]!
    mov x29, sp
    stp x19, x20, [sp, 16]
    str x21, [sp, 32]

    mov x19, x0
    mov w20, 16
    ldr x21, = hex_buffer
1:
    sub w20, w20, 1
    and w0, w19, 0xf
    cmp w0, 9
    b.gt 2f
    add w0, w0, '0'
    b 3f
2:
    add w0, w0, 'a' - 10
3:
    strb w0, [x21, x20]
    lsr x19, x19, 4
    cbnz w20, 1b

    ldr x0, = hex_buffer
    bl _escrever_tex

    ldr x21, [sp, 32]
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 48
    ret
_escrever_decimal:
    // x0 = valor pra escrever
    stp x29, x30, [sp, -48]!
    mov x29, sp
    stp x19, x20, [sp, 16]
    str x21, [sp, 32]

    mov x19, x0
    ldr x21, = dec_buffer
    add x21, x21, 20
    mov w0, 0
    strb w0, [x21], -1

    mov x20, 10
1:
    udiv x0, x19, x20
    msub x1, x0, x20, x19
    add w1, w1, '0'
    strb w1, [x21], -1
    mov x19, x0
    cbnz x19, 1b

    add x0, x21, 1
    bl _escrever_tex

    ldr x21, [sp, 32]
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 48
    ret
    