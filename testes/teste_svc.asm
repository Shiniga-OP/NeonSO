// testes/teste_svc.asm
.global _testar_svc
.global _svc_retorno_el1

// pilha dedicada pra EL0(separada da pilha do kernel EL1)
.section .bss
.align 4 // alinha a 16 bytes
_pilha_el0_base:
    .skip 4096
_pilha_el0_topo: // sp_el0 aponta aqui(topo = endereço maior)

.section .text
.align 3
_testar_svc:
    stp x29, x30, [sp, -16]!
    mov x29, sp

    ldr x0, = msg_teste_descendo
    bl _escrever_tex

    // SP_EL0: pilha de usuario
    ldr x0, =_pilha_el0_topo
    msr sp_el0, x0

    // ELR_EL1: entrada em EL0
    adr x0, _codigo_el0
    msr elr_el1, x0

    /* SPSR_EL1: EL0 AArch64 + DAIF=1111(mascara Erro de sistema/IRQ/FIQ)
    * bits 9:6 = 1111 -> 0x3C0
    * bits 3:0 = 0000 -> EL0

    * SVC é sincrono e NUNCA é mascarado por DAIF
    * erro de sistema virtual pendente do VirtIO(EC=0x00) não dispara mais
    */
    mov x0, 0x3C0
    msr spsr_el1, x0

    // drena qualquer operação pendente antes de descer
    dsb sy
    isb

    // salva o endereço de retorno pro EL1(usado pelo svc 93 pra voltar aqui)
    ldr x1, =_svc_retorno_el1
    str x30, [x1]

    eret // _codigo_el0 em EL0
// _codigo_el0  –  executa em EL0
// so se comunica com o kernel via svc
.align 3
_codigo_el0:

    // TESTE 1: escrever fd=1
    mov x8, 64 // escrever
    mov x0, 1 // saida
    ldr x1, = msg_escrever // buffer
    mov x2, 42  // tamanho
    svc 0
    // x0 = bytes escritos(positivo = ok)

    // TESTE 2: escrever 9(invalido -> -9)
    mov x8, 64
    mov x0, 9 // saida invalido
    ldr x1, = msg_escrever
    mov x2, 42
    svc 0
    // x0 deve ser -9, sem saida na UART

    // TESTE 3: chamada inexistente -> -38
    mov x8, 999
    svc 0
    // x0 deve ser -38; imprime msg_sistema_naoimpl na UART

    // ENCERRA: svc 93(saida)
    mov x8, 93
    mov x0, 0
    svc 0

    // segurança: se saida retornar por algum motivo
_el0_loop_seguro:
    b _el0_loop_seguro

// DADOS
.section .data
.align 3
_svc_retorno_el1: .quad 0 // endereço de retorno ao kernel(salvo antes do eret)

.section .rodata
msg_teste_descendo:
    .asciz "[TesteSVC]: Descendo pra EL0, DAIF mascarado...\r\n"
msg_escrever:
    .asciz "[TesteSVC EL0]: svc escrever 1 funcionou\r\n"
msg_escrever_fim: