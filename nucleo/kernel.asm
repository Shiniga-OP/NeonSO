// nucleo/kernel.asm
.global _inicio

.section .text.kernel
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
    msr spsel, 1
    
    // configura pilha
    ldr x0, = _pilha_fim
    mov sp, x0
    
    // configura UART
    bl _config_uart
    
    // mensagem de confirmação
    ldr x0, = msg_kernel
    bl _escrever_tex
    
    bl _iniciar_video
    
    bl ns_abrir

    // loop infinito
1: 
    wfe
    b 1b

// liga MMU em EL1, identidade 1:1
// tabela L1
.section .bss
.align 12
tt_l1:
    .skip 4096

.section .text
.align 3
ligar_mmu:
    // prologo: salva o endereço de retorno(x30) na pilha
    // se não fizer isso, o "bl" la embaixo sobrescreve o retorno do kernel
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    // preparar endereço da tabela
    adrp x0, tt_l1
    add x0, x0, :lo12:tt_l1

    // limpar a tabela (4KB)
    mov x1, xzr
    mov x2, 512
limpar_mmu_loop:
    str x1, [x0], 8
    subs x2, x2, 1
    b.ne limpar_mmu_loop

    // reinicia x0 pro inicio da tabela
    adrp x0, tt_l1
    add x0, x0, :lo12:tt_l1

    // mapea perifericos(0x00000000 - 0x3FFFFFFF) -> ambiente nGnRE(Attr 1)
    mov x1, 0x00000000
    orr x1, x1, (1 << 10) // AF = 1
    orr x1, x1, (1 << 2) // AttrIndx[1]
    orr x1, x1, 0x1 // valida o bloco
    str x1, [x0, 0] // L1[0]

    // mapea RAM(0x40000000 - 0x7FFFFFFF) -> normal WBWA(Attr 0)
    ldr x1, = 0x40000000
    orr x1, x1, (1 << 10) // AF = 1
    
    orr x1, x1, 0x1 // valida o bloco
    str x1, [x0, 8] // L1[1]

    // força os dados da tabela a sairem do cache e irem pra RAM fisica
    dc cvac, x0                 
    dsb sy
    isb

    // configura registradores de controle
    // MAIR: Attr0=normal(0xFF), Attr1=ambiente(0x04)
    ldr x1, = 0x04FF
    msr mair_el1, x1

    // TCR: T0SZ=25(39-bit VA), TG0=4KB, checavel, compartilhavel
    ldr x1, = 0x80803519
    msr tcr_el1, x1

    // TTBR0: aponta pra tabela
    msr ttbr0_el1, x0

    // invalidador TLB(limpa traduções antigas/fantasmas)
    dsb sy
    tlbi vmalle1is
    dsb sy
    isb

    // ativação no SCTLR_EL1
    mrs x1, sctlr_el1
    orr x1, x1, 0x1 // bit M(MMU Ativada)
    bic x1, x1, (1 << 1) // desabilita o checamento de alinhamento
    msr sctlr_el1, x1
    
    isb // sincroniza com a nova realidade virtual

    ldr x0, = debug_mmu
    bl _escrever_tex

    // epilogo: recupera o x30 e volta pro Kernel
    ldp x29, x30, [sp], 16
    ret
.section .text
.align 3

_config_excecao:
    // salva os registradores:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    
    // === passo 1, localização ===
    // define o VBAR_EL1 pra apontar pra uma area qualquer
    ldr x0, = 0x40210000 // endereço arbitrario na memória
    msr vbar_el1, x0 // configura vetor base
    isb // sincroniza
    
    // preenche o vetor com codigo
    ldr x1, = 0x14000000
    str w1, [x0]
    
    dc cvac, x0
    dsb sy
    isb
    
    ldr x0, = debug_excecoes_l
    bl _escrever_tex
    
    // restaura os registtadores
    ldp x29, x30, [sp], 16
    ret
.section .rodata
msg_kernel: .asciz "[Kernel]: Executando, Sistema carregado com sucesso\r\n"
msg_vetores: .asciz "[Kernel]: Vetores configurados\r\n"
msg_erro: .asciz "[Kernel]: Testando erro de memória\nmov x0, 0\nldr x1, [x0]\r\n"
debug_mmu: .asciz "[MMU]: Tudo ocorreu bem, MMU ativada\r\n"
debug_excecoes_l: .asciz "[EXC]: Localização feita\r\n"
debug_excecoes_t: .asciz "[EXC]: Tabela feita\r\n"
msg_erro_fatal: .asciz "\r\n[ALERTA]: Falha Grave de Segmentação. Endereço: "
msg_quebra_linha: .asciz "\r\nCausa (ESR): "
