// nucleo/excecoes.asm
// tabela de vetores de exceção e casos

.global _tabela_vetores
.global _config_excecao
// MACROS
// macro que salva todos os registradores de proposito geral na pilha
.macro salvar_contexto
    sub sp, sp, 288
    stp x0, x1, [sp, 0]
    stp x2, x3, [sp, 16]
    stp x4, x5, [sp, 32]
    stp x6, x7, [sp, 48]
    stp x8, x9, [sp, 64]
    stp x10, x11, [sp, 80]
    stp x12, x13, [sp, 96]
    stp x14, x15, [sp, 112]
    stp x16, x17, [sp, 128]
    stp x18, x19, [sp, 144]
    stp x20, x21, [sp, 160]
    stp x22, x23, [sp, 176]
    stp x24, x25, [sp, 192]
    stp x26, x27, [sp, 208]
    stp x28, x29, [sp, 224]
    str x30, [sp, #240]
    mrs x0, elr_el1
    mrs x1, spsr_el1
    stp x0, x1, [sp, #248]
    mrs x0, esr_el1
    mrs x1, far_el1
    stp x0, x1, [sp, 264]  // esr e far por último(usados nos casos)
.endm

// macro que restaura contexto e volta da exceção
.macro restaurar_contexto
    ldp x0, x1, [sp, 248]
    msr elr_el1, x0
    msr spsr_el1, x1
    ldp x0, x1, [sp, 0]
    ldp x2, x3, [sp, 16]
    ldp x4, x5, [sp, 32]
    ldp x6, x7, [sp, 48]
    ldp x8, x9, [sp, 64]
    ldp x10, x11, [sp, 80]
    ldp x12, x13, [sp, 96]
    ldp x14, x15, [sp, 112]
    ldp x16, x17, [sp, 128]
    ldp x18, x19, [sp, 144]
    ldp x20, x21, [sp, 160]
    ldp x22, x23, [sp, 176]
    ldp x24, x25, [sp, 192]
    ldp x26, x27, [sp, 208]
    ldp x28, x29, [sp, 224]
    ldr x30, [sp, 240]
    add sp, sp, 288
    eret
.endm

// macro que preenche cada entrada do vetor(128 bytes cada)
// o vetor precisa ser alinhado em 2KB(11 bits)
.macro entrada_vetor caso
    .align 7 // cada entrada = 128 bytes = 2^7
    b \caso
.endm

// TABELA DE VETORES(VBAR_EL1)
// deve estar alinhada em 2KB(0x800)
.section .text
.align 11
_tabela_vetores:
    // === EL1t(SP_EL0) ===
    entrada_vetor caso_sinc_el1t
    entrada_vetor caso_irq_el1t
    entrada_vetor caso_fiq_el1t
    entrada_vetor caso_errosistema_el1t

    // === EL1h(SP_EL1) ===
    entrada_vetor caso_sinc_el1h
    entrada_vetor caso_irq_el1h
    entrada_vetor caso_fiq_el1h
    entrada_vetor caso_errosistema_el1h

    // === EL0 64-bit ===
    entrada_vetor caso_sinc_el0_64
    entrada_vetor caso_irq_el0_64
    entrada_vetor caso_fiq_el0_64
    entrada_vetor caso_errosistema_el0_64

    // === EL0 32-bit(ARM32) ===
    entrada_vetor caso_sinc_el0_32
    entrada_vetor caso_irq_el0_32
    entrada_vetor caso_fiq_el0_32
    entrada_vetor caso_errosistema_el0_32

// configuração: aponta VBAR_EL1 pra tabela
.section .text
.align 3
_config_excecao:
    stp x29, x30, [sp, -16]!
    mov x29, sp

    adrp x0, _tabela_vetores
    add  x0, x0, :lo12:_tabela_vetores
    msr  vbar_el1, x0
    isb

    ldr x0, = msg_exc_configurado
    bl _escrever_tex

    ldp x29, x30, [sp], 16
    ret

// CASO GENERICO DE ERRO FATAL
// mostra o tipo, ESR_EL1(causa), FAR_EL1(endereço) e trava
.section .text
.align 3
// x19 = ponteiro pro texto do tipo de erro(ja salvo antes de chamar)
_caso_fatal:
    // imprime o cabeçalho de panico
    ldr x0, = msg_panico
    bl _escrever_tex

    // imprime o tipo especifico do erro
    mov x0, x19
    bl _escrever_tex

    // le e imprime ESR_EL1(causa da exceção)
    ldr x0, = msg_esr
    bl _escrever_tex
    mrs x0, esr_el1
    bl _escrever_hex64

    // le e imprime FAR_EL1(endereço que causou a falha)
    ldr x0, = msg_far
    bl _escrever_tex
    mrs x0, far_el1
    bl _escrever_hex64

    // le e imprime ELR_EL1(onde a instrução problematica tava)
    ldr x0, = msg_elr
    bl _escrever_tex
    mrs x0, elr_el1
    bl _escrever_hex64

    // le e imprime SPSR_EL1
    ldr x0, = msg_spsr
    bl _escrever_tex
    mrs x0, spsr_el1
    bl _escrever_hex64

    ldr x0, = msg_travado
    bl _escrever_tex

    // trava: desabilita interrupções e entra em loop infinito
_loop_trava:
    msr daifset, 0xf
    wfe
    b _loop_trava

// CASOS ESPECIFICOS
// cada um salva x19, carrega a mensagem de tipo, e chama _caso_fatal
// === EL1t ===
caso_sinc_el1t:
    ldr x19, = msg_tipo_sinc_el1t
    b _caso_fatal
caso_irq_el1t:
    ldr x19, = msg_tipo_irq
    b _caso_fatal
caso_fiq_el1t:
    ldr x19, = msg_tipo_fiq
    b _caso_fatal
caso_errosistema_el1t:
    ldr x19, =msg_tipo_errosistema
    b _caso_fatal
// === EL1h ===
caso_sinc_el1h:
    ldr x19, = msg_tipo_sinc_el1h
    b _caso_fatal
caso_irq_el1h:
    ldr x19, = msg_tipo_irq
    b _caso_fatal
caso_fiq_el1h:
    ldr x19, = msg_tipo_fiq
    b _caso_fatal
caso_errosistema_el1h:
    ldr x19, =msg_tipo_errosistema
    b _caso_fatal
/* === EL0 64-bit ===
* verifica se é SVC(EC=0x15) antes de tratar como erro fatal
* x8 = número da chamada de sistema
* x0–x5 = argumentos
* x0 = retorno
*/
caso_sinc_el0_64:
    salvar_contexto
    mrs x0, esr_el1
    lsr x0, x0, 26
    and x0, x0, 0x3F
    cmp x0, 0x15
    b.eq _tratar_chamadasistema
    ldr x19, = msg_tipo_sinc_el0
    b _caso_fatal
/*
* _tratar_chamadasistema
* Salva contexto completo, recupera argumentos originais,
* chama o despachador e restaura contexto
* ELR_EL1 é avançado em 4 bytes para retornar a instrução
* seguinte ao "svc 0"
*/
_tratar_chamadasistema:
    ldr x0, [sp, 0]
    ldr x1, [sp, 8]
    ldr x2, [sp, 16]
    ldr x3, [sp, 24]
    ldr x4, [sp, 32]
    ldr x5, [sp, 40]
    ldr x8, [sp, 64]

    bl _despachador_chamadasistema

    str x0, [sp, 0]
    restaurar_contexto

caso_irq_el0_64:
    ldr x19, = msg_tipo_irq
    b _caso_fatal
caso_fiq_el0_64:
    ldr x19, = msg_tipo_fiq
    b _caso_fatal
caso_errosistema_el0_64:
    ldr x19, = msg_tipo_errosistema
    b _caso_fatal
// === EL0 32-bit ===
caso_sinc_el0_32:
    ldr x19, = msg_tipo_aarch32
    b _caso_fatal
caso_irq_el0_32:
    ldr x19, = msg_tipo_irq
    b _caso_fatal
caso_fiq_el0_32:
    ldr x19, = msg_tipo_fiq
    b _caso_fatal
caso_errosistema_el0_32:
    ldr x19, = msg_tipo_errosistema
    b _caso_fatal
// DADOS
.section .rodata
// mensagens de panico
msg_panico:
    .asciz "\r\n\r\n======================================\r\n  !! ERRO GRAVE NO SISTEMA !!\r\n======================================\r\n"
// mensagem de tipos de exceção
msg_tipo_sinc_el1t:
    .asciz "Tipo   : Excecao Sincrona(EL1, pilha EL0)\r\n"
msg_tipo_sinc_el1h:
    .asciz "Tipo   : Excecao Sincrona(EL1, pilha EL1)\r\n"
msg_tipo_sinc_el0:
    .asciz "Tipo   : Excecao Sincrona(EL0 / modo usuario)\r\n"
msg_tipo_irq:
    .asciz "Tipo   : Interrupcao IRQ inesperada\r\n"
msg_tipo_fiq:
    .asciz "Tipo   : Interrupcao Rapida inesperada\r\n"
msg_tipo_errosistema:
    .asciz "Tipo   : Erro do Sistema - possivel falha de barramento\r\n"
msg_tipo_aarch32:
    .asciz "Tipo   : Excecao de codigo ARM64(não suportado)\r\n"
// textos dos registradores
msg_esr:
    .asciz "\nCausa : "
msg_far:
    .asciz "\nEndereço : "
msg_elr:
    .asciz "\nInstrução : "
msg_spsr:
    .asciz "\nEstado : "
msg_travado:
    .asciz "\r\nSistema travado. Reinicie o dispositivo\r\n======================================\r\n"
msg_exc_configurado:
    .asciz "[EXC]: Vetores de exceção configurados\r\n"
msg_nova_linha:
    .asciz "\r\n"