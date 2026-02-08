// drivers/virt/video.asm
.global _iniciar_video
.global _escrever_pixel
.global _limpar_tela
.global _desenhar_retangulo
.global _att_tela

// constantes VirtIO GPU(MMIO)
MAGICO = 0x00
STATUS = 0x70
QUEUE_SEL = 0x30
QUEUE_NUM = 0x38
QUEUE_PRONTA = 0x44
QUEUE_NOTIFICAR = 0x50
QUEUE_DESC_BAIXA = 0x80
QUEUE_DESC_ALTA = 0x84
QUEUE_DRIVER_BAIXA = 0x90
QUEUE_DRIVER_ALTA = 0x94
QUEUE_AMBIENTE_BAIXA = 0xa0
QUEUE_AMBIENTE_ALTA = 0xa4

// IDs de comando VirtIO GPU
CMD_RECURSO_CRIAR_2D  = 0x0101
CMD_RECURSO_ANEXAR_SUPPORTE = 0x0106
CMD_DEFINIR_VERIFICACAO = 0x0103
CMD_TRANSFERIR_PRA_DONO_2D = 0x0105
CMD_DESCARGA_RECURSOS = 0x0104

// formato
VIRTIO_GPU_FORMATO = 1

QUADROBUFFER = 0x44000000 
LARGURA = 1024
ALTURA  = 768

.section .data
.align 8
msg_buscando: .asciz "[Video]: Iniciando GPU...\r\n"
msg_ok: .asciz "[Video]: Fila configurada. Enviando comandos...\r\n"
msg_video_ativo: .asciz "[Video]: Tela inicializada\r\n"

.section .bss
.align 16
gpu_mmio_base: .quad 0
.align 16
gpu_desc: .space 4096   
.align 16
gpu_avail: .space 1024   
.align 16
gpu_used: .space 1024   

.align 16
req_gpu: .space 256
.align 16
resp_gpu: .space 256

.section .text
_iniciar_video:
    stp x29, x30, [sp, -16]!
    
    ldr x0, = msg_buscando
    bl _escrever_tex

    // busca o dispositivo GPU
    mov x1, 0x0000
    movk x1, 0x0a00, lsl 16
    mov x2, 0x200
encontrar_loop:
    ldr w3, [x1, MAGICO]
    ldr w4, [x1, 0x08]
    ldr w5, = 0x74726976
    cmp w3, w5
    b.ne proximo_dev
    cmp w4, 16
    b.eq encontrar_ok
proximo_dev:
    add x1, x1, x2
    mov x6, 0x4000
    movk x6, 0x0a00, lsl 16 
    cmp x1, x6
    b.lt encontrar_loop
    b _fim_iniciar
encontrar_ok:
    ldr x10, = gpu_mmio_base
    str x1, [x10]

    // reinicio do dispositivo
    str wzr, [x1, STATUS]
    dsb sy
    
    // ACKNOWLEDGE
    mov w3, 1             
    str w3, [x1, STATUS]
    dsb sy
    
    // DRIVER
    mov w3, 3             
    str w3, [x1, STATUS]
    dsb sy
    
    // configura queue 0(controlq)
    mov w3, 0
    str w3, [x1, QUEUE_SEL]
    
    mov w3, 16            
    str w3, [x1, QUEUE_NUM]

    ldr x4, = gpu_desc
    str w4, [x1, QUEUE_DESC_BAIXA]
    lsr x4, x4, 32
    str w4, [x1, QUEUE_DESC_ALTA]

    ldr x4, = gpu_avail
    str w4, [x1, QUEUE_DRIVER_BAIXA]
    lsr x4, x4, 32
    str w4, [x1, QUEUE_DRIVER_ALTA]

    ldr x4, = gpu_used
    str w4, [x1, QUEUE_AMBIENTE_BAIXA]
    lsr x4, x4, 32
    str w4, [x1, QUEUE_AMBIENTE_ALTA]

    mov w3, 1
    str w3, [x1, QUEUE_PRONTA]
    dsb sy
    
    // DRIVER_OK
    mov w3, 7             
    str w3, [x1, STATUS]
    dsb sy

    ldr x0, = msg_ok
    bl _escrever_tex

    // === COMANDO 1: CRIAR_2D ===
    ldr x0, = req_gpu
    
    // Leitor(24 bytes)
    mov w1, CMD_RECURSO_CRIAR_2D 
    str w1, [x0, 0] // tipo
    str wzr, [x0, 4] // marcações
    str xzr, [x0, 8] // cerca_id
    str wzr, [x0, 16] // ctx_id
    str wzr, [x0, 20] // preenchimento
    
    // corpo do comando(16 bytes)
    mov w1, 1 // recurso_id
    str w1, [x0, 24]       
    mov w1, VIRTIO_GPU_FORMATO
    str w1, [x0, 28] // formato
    mov w1, LARGURA
    str w1, [x0, 32] // largura
    mov w1, ALTURA
    str w1, [x0, 36] // altura
    
    mov x1, 40 // tamanho total
    bl _enviar_comando

    // === COMANDO 2: ANEXAR_RETORNO ===
    ldr x0, = req_gpu
    
    // leitor
    mov w1, CMD_RECURSO_ANEXAR_SUPPORTE
    str w1, [x0, 0]
    str wzr, [x0, 4]
    str xzr, [x0, 8]
    str wzr, [x0, 16]
    str wzr, [x0, 20]
    
    // Corpo do comando
    mov w1, 1 // recurso_id
    str w1, [x0, 24]       
    mov w1, 1 // nr_entradas
    str w1, [x0, 28]
    
    // entrada da mem_entrada(16 bytes cada)
    ldr x2, = QUADROBUFFER
    str x2, [x0, 32] // endereço
    mov w1, LARGURA
    mov w2, ALTURA
    mul w1, w1, w2
    lsl w1, w1, 2 // largura * altura * 4 bytes
    str w1, [x0, 40] // tamanho
    str wzr, [x0, 44] // preenchimento
    
    mov x1, 48
    bl _enviar_comando

    // === COMANDO 3: DEFINIR_VERIFICACAO ===
    ldr x0, = req_gpu
    
    // leitor(24 bytes: posições 0-23)
    mov w1, CMD_DEFINIR_VERIFICACAO
    str w1, [x0, 0] // tipo
    str wzr, [x0, 4] // marcações
    str xzr, [x0, 8] // cerca_id
    str wzr, [x0, 16] // ctx_id
    str wzr, [x0, 20] // preenchimento
    
    // corpo: struct virtio_gpu_rect r(16 bytes: posições 24-39)
    str wzr, [x0, 24] // r.x
    str wzr, [x0, 28] // r.y
    mov w1, LARGURA
    str w1, [x0, 32] // r.largura
    mov w1, ALTURA
    str w1, [x0, 36] // r.altura
    
    // campos finais(8 bytes: posições 40-47)
    str wzr, [x0, 40] // digitalizacao_id = 0
    mov w1, 1 // recurso_id = 1
    str w1, [x0, 44]
    
    mov x1, 48 // tamanho total
    bl _enviar_comando

    // limpa a tela com azul
    mov w0, 0xFF0000FF
    bl _limpar_tela
    
    bl _att_tela

    ldr x0, = msg_video_ativo
    bl _escrever_tex

_fim_iniciar:
    ldp x29, x30, [sp], 16
    ret
_enviar_comando:
    // x0 = endereço do comando
    // x1 = tamanho do comando
    
    stp x19, x20, [sp, -16]!
    stp x21, x22, [sp, -16]!
    
    mov x19, x0 // salva endereço
    mov x20, x1 // salva tamanho
    
    // configura descritor 0(comando de saida)
    ldr x2, = gpu_desc
    str x19, [x2, 0] // endereço
    str w20, [x2, 8] // tamanho
    mov w3, 1 // marcações = proximo
    strh w3, [x2, 12]
    mov w3, 1 // proximo = 1
    strh w3, [x2, 14]
    
    // configurar descritor 1(resposta de entrada)
    add x2, x2, 16
    ldr x4, = resp_gpu
    str x4, [x2, 0] // endereço
    mov w1, 24 // tamanho (leitor de resposta)
    str w1, [x2, 8]
    mov w3, 2 // marcações = escrever
    strh w3, [x2, 12]
    strh wzr, [x2, 14] // proximo = 0
    
    dsb sy
    
    // adiciona fila disponivel
    ldr x2, = gpu_avail
    ldrh w21, [x2, 2] // idc atual
    and w4, w21, 15
    add x5, x2, 4
    strh wzr, [x5, x4, lsl 1]  // anel[idc] = 0
    
    dsb sy
    add w21, w21, 1
    strh w21, [x2, 2] // incrementa idc
    dsb sy
    
    // notifica dispositivo
    ldr x1, = gpu_mmio_base
    ldr x1, [x1]
    mov w0, 0
    str w0, [x1, QUEUE_NOTIFICAR]
    dsb sy
    
    // espera resposta
    mov x7, 0x10000000
    ldr x2, = gpu_used
esperar_gpu:
    dsb sy
    ldrh w22, [x2, 2]
    cmp w21, w22
    b.eq pronta_gpu
    subs x7, x7, 1
    b.ne esperar_gpu
    
pronta_gpu:
    ldp x21, x22, [sp], 16
    ldp x19, x20, [sp], 16
    ret

_att_tela:
    stp x29, x30, [sp, -16]!
    
    // === TRANSFERIR_PRA_DONO_2D ===
    ldr x0, = req_gpu
    
    // leitor
    mov w1, CMD_TRANSFERIR_PRA_DONO_2D
    str w1, [x0, 0]
    str wzr, [x0, 4]
    str xzr, [x0, 8]
    str wzr, [x0, 16]
    str wzr, [x0, 20]
    
    // corpo: struct virtio_gpu_rect r
    str wzr, [x0, 24] // r.x
    str wzr, [x0, 28] // r.y
    mov w1, LARGURA
    str w1, [x0, 32] // r.largura
    mov w1, ALTURA
    str w1, [x0, 36] // r.altura
    
    // campos finais
    str xzr, [x0, 40] // posição(64-bit)
    mov w1, 1 // recurso_id
    str w1, [x0, 48]
    str wzr, [x0, 52] // preenchimento
    
    mov x1, 56
    bl _enviar_comando
    
    // === DESCARGA_RECURSOS ===
    ldr x0, = req_gpu
    
    // leitor
    mov w1, CMD_DESCARGA_RECURSOS
    str w1, [x0, 0]
    str wzr, [x0, 4]
    str xzr, [x0, 8]
    str wzr, [x0, 16]
    str wzr, [x0, 20]
    
    // corpo: struct virtio_gpu_rect r
    str wzr, [x0, 24] // r.x
    str wzr, [x0, 28] // r.y
    mov w1, LARGURA
    str w1, [x0, 32] // r.largura
    mov w1, ALTURA
    str w1, [x0, 36] // r.altura
    
    // recurso_id
    mov w1, 1
    str w1, [x0, 40]
    str wzr, [x0, 44] // preenchimento
    
    mov x1, 48
    bl _enviar_comando
    
    ldp x29, x30, [sp], 16
    ret

_limpar_tela:
    // x0 = cor no formato BGRA
    stp x29, x30, [sp, -16]!
    
    // salva a cor em w19
    mov w19, w0
    
    // preenche a tela com a cor recebida
    ldr x1, = QUADROBUFFER
    
    mov x2, LARGURA
    mov x3, ALTURA
    mul x2, x2, x3 // total de pixels
loop_limpar:
    str w19, [x1], 4
    subs x2, x2, 1
    b.ne loop_limpar
    
    ldp x29, x30, [sp], 16
    ret

_escrever_pixel:
    // x0 = x(coluna)
    // x1 = y(linha)
    // w2 = cor(formato BGRA)
    
    // valida coordenadas
    mov x3, LARGURA
    cmp x0, x3
    b.ge pixel_fora // se x >= LARGURA, retorna
    
    mov x3, ALTURA
    cmp x1, x3
    b.ge pixel_fora // se y >= ALTURA, retorna
    
    // calcula o posição: (y * LARGURA + x) * 4
    mov x3, LARGURA
    mul x3, x1, x3  // y * LARGURA
    add x3, x3, x0  // + x
    lsl x3, x3, 2   // * 4 bytes
    
    // escreve no quadrobuffer
    ldr x4, = QUADROBUFFER
    str w2, [x4, x3]
pixel_fora:
    ret

_render_retangulo:
    // x0 = x inicial
    // x1 = y inicial
    // x2 = largura
    // x3 = altura
    // w4 = cor(formato BGRA)
    
    stp x19, x20, [sp, -16]!
    stp x21, x22, [sp, -16]!
    stp x23, x24, [sp, -16]!
    
    // salva parametros
    mov x19, x0 // x inicial
    mov x20, x1 // y inicial
    mov x21, x2 // largura
    mov x22, x3 // altura
    mov w23, w4 // cor
    
    // valida se o retangulo esta dentro da tela
    mov x5, LARGURA
    add x6, x19, x21 // x_fim = x + largura
    cmp x6, x5
    b.gt ret_invalido
    
    mov x5, ALTURA
    add x6, x20, x22 // y_fim = y + altura
    cmp x6, x5
    b.gt ret_invalido
    
    // loop externo(linhas)
    mov x24, x20 // y atual
loop_y_ret:
    // loop interno(colunas)
    mov x0, x19 // x atual
loop_x_ret:
    // calcula posição e escreve pixel
    mov x5, LARGURA
    mul x5, x24, x5 // y * LARGURA
    add x5, x5, x0 // + x
    lsl x5, x5, 2 // * 4 bytes
    
    ldr x6, = QUADROBUFFER
    str w23, [x6, x5]
    
    // proxima coluna
    add x0, x0, 1
    add x7, x19, x21 // x_fim = x_inicial + largura
    cmp x0, x7
    b.lt loop_x_ret
    
    // proxima linha
    add x24, x24, 1
    add x7, x20, x22 // y_fim = y_inicial + altura
    cmp x24, x7
    b.lt loop_y_ret
ret_invalido:
    ldp x23, x24, [sp], 16
    ldp x21, x22, [sp], 16
    ldp x19, x20, [sp], 16
    ret
    