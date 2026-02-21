.section .text

// inicio de biblis/texs.fpb

// inicio de biblis/texs.asm
// fn: [texcmp]
// x0: ponteiro para o texto 1
// x1: ponteiro para o texto 2
// w0: retorno(1 se verdadeiro, 0 se falso)
.align 2
texcmp:
    // x2 e x3 são usados para carregar os bytes
    
1:  // inicio do loop de comparação
    ldrb w2, [x0] // carrega o byte atual do texto 1(t1)
    ldrb w3, [x1] // carrega o byte atual do texto 2(t2)

    cmp w2, w3 // compara os dois bytes
    b.ne 3f // se forem diferentes salta pra FALSO(3f)
    // se os bytes são iguais, verifica se é o fim do texto
    // se w2(que é igual a w3) for zero, ambos os textos terminaram
    // ao mesmo tempo, logo são iguais
    cbz w2, 2f// Se w2 for zero, salta para VERDADEIRO(2f)
    // se os bytes são iguais E não são zero, continua o loop
    add x0, x0, 1 // avança o ponteiro t1
    add x1, x1, 1 // avança o ponteiro t2
    b 1b // volta ao inicio do loop
2:  // VERDADEIRO: os textos são iguais
    mov w0, 1 // define o retorno w0 = 1
    b 4f // salta para o fim da função
    
3:  // FALSO: os bytes foram diferentes em algum ponto
    mov w0, 0 // define o retorno w0 = 0
    
4:
    ret
// fim: [texcmp]
// fim de biblis/texs.asm


// fim de biblis/texs.fpb

.global ns_abrir
// fn: [ns_abrir] (vars: 16, total: 144)
.align 2
ns_abrir:
  sub sp, sp, 144
  stp x29, x30, [sp, 128]
  add x29, sp, 128
  ldr x0, = .tex_comb_0
  bl _escrever_tex
  mov w0, 0
  mov w19, w0
  str x0, [x29, 128]
.B24:
  ldr w0, [x29, 128]
  mov w19, w0
  mov w0, 64
  mov w1, w19
  cmp w1, w0
  cset w0, lt
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B25
  ldr w0, [x29, 128]
  mov w1, w0
  str w1, [sp, -16]!
  mov w0, 0 // byte: 0x00
  ldr w1, [sp], 16
  ldr x2, = global_comando
  add x2, x2, x1
  strb w0, [x2]
  ldr w0, [x29, 128]
  add w0, w0, 1
  str x0, [x29, 128]
  b .B24
.B25:
  add sp, sp, 0  // limpa temporarios
  bl ns_loop
  b 1f
// epilogo
1:
  ldp x29, x30, [sp, 128]
  add sp, sp, 144
  ret
// fim: [ns_abrir]
// fn: [ns_loop] (vars: 32, total: 160)
.align 2
ns_loop:
  sub sp, sp, 160
  stp x29, x30, [sp, 144]
  add x29, sp, 144
  add sp, sp, 0  // limpa temporarios
  bl _obter_car
  mov w19, w0
  strb w0, [x29, -32]
  ldrb w0, [x29, -32]
  mov w19, w0
  mov w0, 8 // byte: 0x08
  mov w1, w19
  cmp w1, w0
  cset w0, eq
  str w0, [sp, -16]!
  ldrb w0, [x29, -32]
  mov w19, w0
  mov w0, 127 // byte: 0x7F
  mov w1, w19
  cmp w1, w0
  cset w0, eq
  ldr w1, [sp], 16
  cmp w1, 0
  cset w1, ne
  cmp w0, 0
  cset w0, ne
  orr w0, w1, w0
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B26
  ldr x0, = global_conta
  ldr w0, [x0]
  mov w19, w0
  mov w0, 0
  mov w1, w19
  cmp w1, w0
  cset w0, gt
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B27
  ldr x0, = global_conta
  ldr w0, [x0]
  sub w0, w0, 1
  ldr x1, = global_conta
  str w0, [x1]
  ldr x0, = global_conta
  ldr w0, [x0]
  mov w1, w0
  str w1, [sp, -16]!
  mov w0, 0
  ldr w1, [sp], 16
  ldr x2, = global_comando
  add x2, x2, x1
  strb w0, [x2]
  mov w0, 8 // byte: 0x08
  bl _escrever_car
  mov w0, 32
  bl _escrever_car
  mov w0, 8 // byte: 0x08
  bl _escrever_car
  b .B28
.B27:
.B28:
  b .B29
.B26:
  ldrb w0, [x29, -32]
  mov w19, w0
  mov w0, 13 // byte: 0x0D
  mov w1, w19
  cmp w1, w0
  cset w0, eq
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B30
  mov w0, 10
  bl _escrever_car
  ldr x0, = global_comando
  str x0, [sp, -16]!  // salva param 0 (ponteiro/longo)
  ldr x0, = .tex_8
  str w0, [sp, -16]!  // salva param 1 (int/bool/char/byte)
  ldr w1, [sp, 0]  // carrega param 1 (int/bool) em w1
  mov x1, x1  // estende pra 64 bits
  ldr x0, [sp, 16]  // carrega param 0 (ptr/longo) em x0
  add sp, sp, 32  // limpa temporarios
  bl texcmp
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B31
  ldr x0, = .tex_comb_1
  bl _escrever_tex
  b .B32
.B31:
  ldr x0, = global_comando
  str x0, [sp, -16]!  // salva param 0 (ponteiro/longo)
  ldr x0, = .tex_12
  str w0, [sp, -16]!  // salva param 1 (int/bool/char/byte)
  ldr w1, [sp, 0]  // carrega param 1 (int/bool) em w1
  mov x1, x1  // estende pra 64 bits
  ldr x0, [sp, 16]  // carrega param 0 (ptr/longo) em x0
  add sp, sp, 32  // limpa temporarios
  bl texcmp
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B33
  ldr x0, = .tex_comb_2
  bl _escrever_tex
  b .B34
.B33:
  ldr x0, = global_comando
  str x0, [sp, -16]!  // salva param 0 (ponteiro/longo)
  ldr x0, = .tex_17
  str w0, [sp, -16]!  // salva param 1 (int/bool/char/byte)
  ldr w1, [sp, 0]  // carrega param 1 (int/bool) em w1
  mov x1, x1  // estende pra 64 bits
  ldr x0, [sp, 16]  // carrega param 0 (ptr/longo) em x0
  add sp, sp, 32  // limpa temporarios
  bl texcmp
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B35
  add sp, sp, 0  // limpa temporarios
  bl mudar_cor
  b .B36
.B35:
  ldr x0, = global_comando
  str x0, [sp, -16]!  // salva param 0 (ponteiro/longo)
  ldr x0, = .tex_18
  str w0, [sp, -16]!  // salva param 1 (int/bool/char/byte)
  ldr w1, [sp, 0]  // carrega param 1 (int/bool) em w1
  mov x1, x1  // estende pra 64 bits
  ldr x0, [sp, 16]  // carrega param 0 (ptr/longo) em x0
  add sp, sp, 32  // limpa temporarios
  bl texcmp
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B37
  mov w0, 100
  str w0, [sp, -16]!  // salva param 0 (int/bool/char/byte)
  mov w0, 100
  str w0, [sp, -16]!  // salva param 1 (int/bool/char/byte)
  mov w0, 400
  str w0, [sp, -16]!  // salva param 2 (int/bool/char/byte)
  mov w0, 200
  str w0, [sp, -16]!  // salva param 3 (int/bool/char/byte)
  movz w0, 0 // byte: 0xFFFF0000
  movk w0, 65535, lsl 16
  str w0, [sp, -16]!  // salva param 4 (int/bool/char/byte)
  ldr w4, [sp, 0]  // carrega param 4 (int/bool) em w4
  mov x4, x4  // estende pra 64 bits
  ldr w3, [sp, 16]  // carrega param 3 (int/bool) em w3
  mov x3, x3  // estende pra 64 bits
  ldr w2, [sp, 32]  // carrega param 2 (int/bool) em w2
  mov x2, x2  // estende pra 64 bits
  ldr w1, [sp, 48]  // carrega param 1 (int/bool) em w1
  mov x1, x1  // estende pra 64 bits
  ldr w0, [sp, 64]  // carrega param 0 (int/bool) em w0
  mov x0, x0  // estende pra 64 bits
  add sp, sp, 80  // limpa temporarios
  bl _render_retangulo
  add sp, sp, 0  // limpa temporarios
  bl _att_tela
  b .B38
.B37:
  ldr x0, = global_conta
  ldr w0, [x0]
  mov w19, w0
  mov w0, 0
  mov w1, w19
  cmp w1, w0
  cset w0, gt
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B39
  ldr x0, = .tex_19
  bl _escrever_tex
  ldr x0, = global_comando
  bl _escrever_tex
  ldr x0, = .tex_20
  bl _escrever_tex
  b .B40
.B39:
.B40:
.B38:
.B36:
.B34:
.B32:
  mov w0, 0
  mov w19, w0
  str x0, [x29, 144]
.B42:
  ldr w0, [x29, 144]
  mov w19, w0
  mov w0, 64
  mov w1, w19
  cmp w1, w0
  cset w0, lt
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B43
  ldr w0, [x29, 144]
  mov w1, w0
  str w1, [sp, -16]!
  mov w0, 0
  ldr w1, [sp], 16
  ldr x2, = global_comando
  add x2, x2, x1
  strb w0, [x2]
  ldr w0, [x29, 144]
  add w0, w0, 1
  str x0, [x29, 144]
  b .B42
.B43:
  mov w0, 0
  mov w19, w0
  mov w0, w19
  ldr x1, = global_conta
  str w0, [x1]
  ldr x0, = .tex_7
  bl _escrever_tex
  b .B44
.B30:
  ldrb w0, [x29, -32]
  mov w19, w0
  mov w0, 32 // byte: 0x20
  mov w1, w19
  cmp w1, w0
  cset w0, ge
  str w0, [sp, -16]!
  ldrb w0, [x29, -32]
  mov w19, w0
  mov w0, 126 // byte: 0x7E
  mov w1, w19
  cmp w1, w0
  cset w0, le
  ldr w1, [sp], 16
  cmp w1, 0
  cset w1, ne
  cmp w0, 0
  cset w0, ne
  and w0, w1, w0
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B45
  ldr x0, = global_conta
  ldr w0, [x0]
  mov w19, w0
  mov w0, 63
  mov w1, w19
  cmp w1, w0
  cset w0, lt
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B46
  ldrb w0, [x29, -32]
  bl _escrever_car
  ldr x0, = global_conta
  ldr w0, [x0]
  mov w1, w0
  str w1, [sp, -16]!
  ldrb w0, [x29, -32]
  ldr w1, [sp], 16
  ldr x2, = global_comando
  add x2, x2, x1
  strb w0, [x2]
  ldr x0, = global_conta
  ldr w0, [x0]
  add w0, w0, 1
  ldr x1, = global_conta
  str w0, [x1]
  b .B47
.B46:
.B47:
  b .B48
.B45:
.B48:
.B44:
.B29:
// inicio assembly manual
ldp x29, x30, [sp, 144]
add sp, sp, 160
b ns_loop

// fim assembly manual
  b 1f
// epilogo
1:
  ldp x29, x30, [sp, 144]
  add sp, sp, 160
  ret
// fim: [ns_loop]
// fn: [mudar_cor] (vars: 0, total: 128)
.align 2
mudar_cor:
  sub sp, sp, 128
  stp x29, x30, [sp, 112]
  add x29, sp, 112
  ldr x0, = global_cor
  ldr w0, [x0]
  mov w19, w0
  movz w0, 0 // byte: 0xFFFF0000
  movk w0, 65535, lsl 16
  mov w1, w19
  cmp w1, w0
  cset w0, eq
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B49
  movz w0, 65280 // byte: 0xFF00FF00
  movk w0, 65280, lsl 16
  mov w19, w0
  mov w0, w19
  ldr x1, = global_cor
  str w0, [x1]
  ldr x0, = .tex_21
  bl _escrever_tex
  b .B50
.B49:
  ldr x0, = global_cor
  ldr w0, [x0]
  mov w19, w0
  movz w0, 65280 // byte: 0xFF00FF00
  movk w0, 65280, lsl 16
  mov w1, w19
  cmp w1, w0
  cset w0, eq
  mov w19, w0
  mov w0, w19
  cmp w0, 0
  beq .B51
  movz w0, 255 // byte: 0xFF0000FF
  movk w0, 65280, lsl 16
  mov w19, w0
  mov w0, w19
  ldr x1, = global_cor
  str w0, [x1]
  ldr x0, = .tex_22
  bl _escrever_tex
  b .B52
.B51:
  movz w0, 0 // byte: 0xFFFF0000
  movk w0, 65535, lsl 16
  mov w19, w0
  mov w0, w19
  ldr x1, = global_cor
  str w0, [x1]
  ldr x0, = .tex_23
  bl _escrever_tex
.B52:
.B50:
  ldr x0, = global_cor
  ldr w0, [x0]
  str w0, [sp, -16]!  // salva param 0 (int/bool/char/byte)
  ldr w0, [sp, 0]  // carrega param 0 (int/bool) em w0
  mov x0, x0  // estende pra 64 bits
  add sp, sp, 16  // limpa temporarios
  bl _limpar_tela
  add sp, sp, 0  // limpa temporarios
  bl _att_tela
  b 1f
// epilogo
1:
  ldp x29, x30, [sp, 112]
  add sp, sp, 128
  ret
// fim: [mudar_cor]
.section .rodata
.align 2
.tex_1: .asciz "[Neon Script]: abrindo sess\303\243o...\n"
.tex_2: .asciz "[Neon Script]: sess\303\243o iniciada\n\n"
.tex_7: .asciz "~ $ "
.tex_8: .asciz "-status"
.tex_12: .asciz "-ajuda"
.tex_17: .asciz "-cor"
.tex_18: .asciz "-render"
.tex_19: .asciz "Erro: '"
.tex_20: .asciz "' n\303\243o reconhecido\n"
.tex_21: .asciz "[Neon Script]: tela verde\n"
.tex_22: .asciz "[Neon Script]: tela azul\n"
.tex_23: .asciz "[Neon Script]: tela vermelha\n"
.section .text


.section .data
.align 3
global_comando:
  .space 64
.align 3
global_conta:
  .word 0
.align 3
global_cor:
  .word -65536

.section .rodata
.align 2
.tex_comb_0: .asciz "[FPB]: teste de FPB funcionando\n[Neon Script]: abrindo sess\303\243o...\n[Neon Script]: sess\303\243o iniciada\n\n[NEON]: Inicializado com sucesso\n[Direitos Autorais]: Foca-do Est\303\272dios\n[Autor]: Shiniga-OP\n\nDigite \"-ajuda\" para ver todos os comandos!\n\n~ $ "
.tex_comb_1: .asciz "[Kernel]: Neon 0.0.1\n[Arquitetura]: ARM64\n[Bibliotecas]: Neon Script 0.0.2\n[Pilha]: 16 KB\n"
.tex_comb_2: .asciz "[Comandos]:\n-status: status do kernel\n-cor: muda a cor da tela (azul, vermelho e verde)\n-render: desenha um retangulo vermelho na tela\n"
