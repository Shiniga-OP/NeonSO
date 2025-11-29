// nucleo/kernel.asm
.global _inicio

.section .text
_inicio:
    mov x30, xzr
    // zerar a sessão BSS
    ldr x0, = _bss_inicio
    ldr x1, = _bss_fim 
    mov x2, 0 // valor pra zerar
zerar_bss:
    cmp x0, x1
    b.ge fim_zerar_bss
    str x2, [x0], 8 // zera 8 bytes e avança
    b zerar_bss
fim_zerar_bss:
    // configura pilha
    ldr x0, = _pilha_fim
    mov sp, x0
    // configura UART
    bl _config_uart
    
    // mensagem de confirmação
    ldr x0, = msg_kernel
    bl _escrever_tex
    
    bl fpb
    
    // inicia uma sessão NS:
    bl ns_abrir
    // loop infinito
1: 
    wfe
    b 1b

.section .rodata
msg_kernel: .asciz "[Kernel]: Executando, Sistema carregado com sucesso\r\n"
