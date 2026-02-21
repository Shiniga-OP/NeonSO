// drivers/virt/disco.asm
.global _carregar_kernel

// registradores
MAGICO = 0x00
AMBIENTE_ID = 0x08
DRIVER_RECURSOS = 0x20
QUEUE_SEL = 0x30
QUEUE_NUM = 0x38
QUEUE_PRONTA = 0x44
QUEUE_NOTIFICAR = 0x50
INTERRUPCAO_STATUS = 0x60
STATUS = 0x70
QUEUE_DESC_BAIXA = 0x80
VIRTIO_QUEUE_DESC_ALTA = 0x84
QUEUE_DRIVER_BAIXA = 0x90
QUEUE_DRIVER_ALTA = 0x94
QUEUE_AMBIENTE_BAIXA = 0xa0
QUEUE_AMBIENTE_ALTA = 0xa4

// marcações:
DESC_F_PROXIMO = 1
DESC_F_GRAVAR = 2
BLK_T_ENTRADA = 0

.section .text
_carregar_kernel:
    stp x29, x30, [sp, -64]!
    mov x29, sp
    stp x19, x20, [sp, 16]
    stp x21, x22, [sp, 32]
    stp x23, x24, [sp, 48]

    ldr x0, = msg_iniciando
    bl _escrever_tex

    // busca dispositivo virtIO-blk
    bl _encontrar_blk
    cbz x0, erro_nao_encontrado

    mov x19, x0 // salva endereço base

    // inicia dispositivo
    bl _inicia_dispositivo
    cbnz x0, erro_inicializacao

    // carrega kernel do setor 64
    mov x0, 64 // setor
    mov x1, 64 // numero de setores
    ldr x2, = 0x40200000 // destino(endereço do kernel)
    mov x3, x19
    bl _ler_setores
    cbnz x0, erro_leitura

    ldr x0, = msg_sucesso
    bl _escrever_tex
    
    // retorna sucesso, bootloader executa o kernel
    mov x0, 0
    b fim
    
erro_nao_encontrado:
    ldr x0, = msg_nao_encontrado
    bl _escrever_tex
    mov x0, 1
    b fim
erro_inicializacao:
    ldr x0, = msg_erro_inicio
    bl _escrever_tex
    mov x0, 1
    b fim
erro_leitura:
    ldr x0, = msg_erro_leitura
    bl _escrever_tex
    mov x0, 1
fim:
    ldp x23, x24, [sp, 48]
    ldp x21, x22, [sp, 32]
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 64
    ret
_inicia_queue:
    // x0 = base_endereco
    stp x29, x30, [sp, -16]!
    mov x29, sp

    // 1. seleciona a fila 0
    mov w1, 0
    str w1, [x0, QUEUE_SEL]

    // 2. informa o tamanho da fila(8 descritores)
    mov w1, 8
    str w1, [x0, QUEUE_NUM]

    // x1 como o endereço de 64 bits e x2 pra armazenar a parte ALTA

    // 3. configura a tabela de descritores(desc_tabela)
    ldr x1, = desc_tabela
    lsr x2, x1, 32 // x2 = (x1 >> 32) -> parte ALTA
    str w1, [x0, QUEUE_DESC_BAIXA] // endereço BAIXA(pos 0x80)
    str w2, [x0, VIRTIO_QUEUE_DESC_ALTA] // endereço ALTA(pos 0x84)

    // 4. configura o driver area(disponivel_anel)
    ldr x1, = disponivel_anel
    lsr x2, x1, 32
    str w1, [x0, QUEUE_DRIVER_BAIXA] // pos 0x90
    str w2, [x0, QUEUE_DRIVER_ALTA] // pod 0x94

    // 5. configura o ambiente area(usado_anel)
    ldr x1, = usado_anel
    lsr x2, x1, 32
    str w1, [x0, QUEUE_AMBIENTE_BAIXA] // pos 0xa0
    str w2, [x0, QUEUE_AMBIENTE_ALTA] // pos 0xa4

    // 6. fila pronta
    mov w1, 1
    str w1, [x0, QUEUE_PRONTA]

    mov x0, 0
    ldp x29, x30, [sp], 16
    ret
_encontrar_blk:
    stp x29, x30, [sp, -32]!
    mov x29, sp
    stp x19, x20, [sp, 16]
    // x19: endereço atual
    // x20: contador

    ldr x0, = msg_procurando
    bl _escrever_tex
    /* 
    * config
    * base: 0x0a000000
    * tamanho por dispositivo: 0x200(512 bytes)
    * total de slots: 32
    */
    ldr x19, = 0x0a000000
    bl _verificar_blk
    cbz w0, encontrado
    
    ldr x19, = 0x0a000200  
    bl _verificar_blk
    cbz w0, encontrado
    
    ldr x19, = 0x0a000400
    bl _verificar_blk
    cbz w0, encontrado
    mov x20, 0 // contador de slots(0 até 31)
buscar_loop:
    cmp x20, 32
    b.ge nao_encontrado

    // verifica o endereço atual(x19)
    bl _verificar_blk
    // se w0 retorna 0, encontramos
    cbz w0, encontrado

    // proximo slot
    add x19, x19, 0x200 // incrementa 512 bytes
    add x20, x20, 1
    b buscar_loop
encontrado:
    ldr x0, = msg_encontrado
    bl _escrever_tex
    mov x0, x19
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    mov x0, x19
    b buscar_fim
nao_encontrado:
    mov x0, 0
buscar_fim:
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret
_inicia_dispositivo:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    str x19, [sp, -16]!
    // x19 tem o endereço base do dispositivo(0x0a003e00)
    bl _verificar_registradores
    
    ldr x0, = msg_iniciando2
    bl _escrever_tex
    
    // 1. reinicia ambiente
    ldr x0, = msg_reinicio_ambiente
    bl _escrever_tex
    mov x0, 0
    str w0, [x19, STATUS]

    // 2. define ACKNOWLEDGE(status = 1)
    ldr x0, = msg_def_ack
    bl _escrever_tex
    mov x0, 1
    str w0, [x19, STATUS]

    // 3. define driver(status = 3)
    ldr x0, = msg_def_driver
    bl _escrever_tex
    mov x0, 3
    str w0, [x19, STATUS]

    // 4. negociação de recursos(0)
    ldr x0, = msg_negociar_recursos
    bl _escrever_tex
    mov x0, 0
    str w0, [x19, DRIVER_RECURSOS]

    // 5. define RECURSOS_OK(status = 11)
    ldr x0, = msg_def_recursos_ok
    bl _escrever_tex
    mov x0, 11 
    str w0, [x19, STATUS]

    // 6. configura queue 0
    ldr x0, = msg_config_queue
    bl _escrever_tex
    mov x0, 0
    str w0, [x19, QUEUE_SEL]

    // 6.1. define tamanho da queue(8)
    ldr x0, = msg_def_queue_tam
    bl _escrever_tex
    mov x0, 8
    str w0, [x19, QUEUE_NUM]

    // 6.2. configura endereços da desc_tabela, disponivel_anel e usado_anel
    
    // configurando tabela de descritores(usando label)
    ldr x0, = msg_config_descritores
    bl _escrever_tex
    ldr x0, = desc_tabela // carrega o endereço real do linker
    
    mov x2, x0 // salva o endereço para debug/restauração
    
    // debug: mostra endereço da desc_tabela
    mov x1, x2 // x1 = endereço correto
    ldr x0, = msg_desc_tabela_endereco
    bl _escrever_tex
    mov x0, x1
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    mov x0, x2 // restaura o endereço correto de desc_tabela(de x2)
    
    lsr x1, x0, 32 // x1 = parte ALTA
    str w0, [x19, QUEUE_DESC_BAIXA]
    str w1, [x19, VIRTIO_QUEUE_DESC_ALTA]

    // configurando driver anel(disponivel anel)
    ldr x0, = msg_config_disponivel_anel
    bl _escrever_tex
    ldr x0, = disponivel_anel // carrega o endereço real do linker

    mov x2, x0 
    
    // debug: mostra endereço do disponivel_anel
    mov x1, x2
    ldr x0, = msg_disponivel_anel_endereco
    bl _escrever_tex
    mov x0, x1
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    mov x0, x2
    
    lsr x1, x0, 32
    str w0, [x19, QUEUE_DRIVER_BAIXA]
    str w1, [x19, QUEUE_DRIVER_ALTA]

    // configurando ambiente anel(usado anel)
    ldr x0, = msg_config_usado_anel
    bl _escrever_tex
    ldr x0, = usado_anel // carrega o endereço real do linker

    mov x2, x0 
    
    // debug: mostra endereço do usado_anel
    mov x1, x2
    ldr x0, = msg_usado_anel_addr
    bl _escrever_tex
    mov x0, x1
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    mov x0, x2 
    
    lsr x1, x0, 32
    str w0, [x19, QUEUE_AMBIENTE_BAIXA]
    str w1, [x19, QUEUE_AMBIENTE_ALTA]

    // 7. def QUEUE_PRONTA
    ldr x0, = msg_def_queue_pronta
    bl _escrever_tex
    mov x0, 1
    str w0, [x19, QUEUE_PRONTA]

    // 8. def DRIVER_OK(status = 15)
    ldr x0, = msg_def_driver_ok
    bl _escrever_tex
    mov x0, 15
    str w0, [x19, STATUS]

    ldr x0, = msg_inicio_sucesso
    bl _escrever_tex
    
    bl _verificar_config
    // fim = sucesso
    mov x0, 0
    
    ldr x19, [sp], 16
    ldp x29, x30, [sp], 16
    ret
_ler_setores:
    // x0 = setor, x1 = conta, x2 = buffer, x3 = base_endereco
    stp x29, x30, [sp, -80]!
    mov x29, sp
    stp x19, x20, [sp, 16]
    stp x21, x22, [sp, 32]
    stp x23, x24, [sp, 48]
    stp x25, x26, [sp, 64]

    mov x19, x0 // setor
    mov x20, x1 // conta
    mov x21, x2 // buffer(destino: 0x40200000)
    mov x23, x3 // base_endereco

ler_loop:
    cbz x20, ler_sucesso
    
    // debug
    ldr x0, = msg_lendo_setor
    bl _escrever_tex
    mov x0, x19
    bl _escrever_decimal
    ldr x0, = msg_nova_linha
    bl _escrever_tex

    // 0. limpa o status byte com um valor "sujo"(0xFF)
    // se ler 0 no final, foi o dispositivo
    // se ler 0xFF, o dispositivo não tocou nele
    ldr x0, = status_byte
    mov w1, 0xFF
    strb w1, [x0]

    // 1. prepara blk_req
    ldr x0, = blk_req
    mov w1, BLK_T_ENTRADA
    str w1, [x0]
    mov w1, 0
    str w1, [x0, 4]
    str x19, [x0, 8] // setor

    // 2. zera desc_tabela
    ldr x0, = desc_tabela
    mov x1, x0
    mov w2, 16 * 8
1:
    str xzr, [x1], 8
    subs w2, w2, 8
    b.ne 1b

    // 3. configura descritores
    ldr x0, = desc_tabela
    
    // descritor 0: blk_req
    ldr x1, = blk_req
    str x1, [x0]
    mov w1, 16
    str w1, [x0, 8]
    mov w1, DESC_F_PROXIMO
    strh w1, [x0, 12]
    mov w1, 1
    strh w1, [x0, 14]

    // descritor 1: buffer de leitura
    ldr x0, = desc_tabela 
    add x0, x0, 16
    str x21, [x0] 
    mov w1, 512
    str w1, [x0, 8]
    mov w1, DESC_F_GRAVAR | DESC_F_PROXIMO
    strh w1, [x0, 12]
    mov w1, 2
    strh w1, [x0, 14]

    // descritor 2: status byte
    ldr x0, = desc_tabela 
    add x0, x0, 32
    ldr x1, = status_byte
    str x1, [x0]
    mov w1, 1
    str w1, [x0, 8]
    mov w1, DESC_F_GRAVAR
    strh w1, [x0, 12]
    
    // 4. atualizar anel disponivel
    ldr x4, = disponivel_anel
    ldrh w5, [x4, 2] // idc atual
    
    and w6, w5, 7
    lsl w6, w6, 1
    add x6, x6, 4
    add x6, x4, x6
    
    mov w7, 0 // cabeca indice = 0
    strh w7, [x6]

    // 5. atualiza disponivel->idc
    add w5, w5, 1
    strh w5, [x4, 2]

    // 6. notifica
    ldr x0, = msg_notificando
    bl _escrever_tex
    mov w0, 0
    str w0, [x23, QUEUE_NOTIFICAR]

    // 7. loop de espera
    // esperamos ate que usado->idc(w7) seja igual a disponivel->idc(w5)
    // w5 ja contem o valor alvo(o valor que acabou de escrever)
    mov x9, 0x100000 // contador grande
2:
    // delay pequeno pra não saturar o barramento
    nop
    nop
    
    ldr x6, = usado_anel
    ldrh w7, [x6, 2] // usado idc(volatile)
    
    // se w7 == w5, o dispositivo alcançou nosso índice = sucesso
    cmp w7, w5
    b.eq ler_concluido
    
    // checagem de timeout
    sub x9, x9, 1
    cbnz x9, 2b // se não zerou, continua loop
    
    // se chegou aqui, deu timeout
    b ler_timeout
ler_concluido:
    // limpar interrupção
    mov w0, 1
    str w0, [x23, INTERRUPCAO_STATUS]

    // 8. verifica status do bloco
    ldr x0, = status_byte
    ldrb w0, [x0]
    
    // se for 0, sucesso
    // se for 0xFF(nosso valor inicial), o dispositivo nem tocou
    cbnz w0, ler_erro 
    // proximo setor
    add x19, x19, 1
    add x21, x21, 512
    sub x20, x20, 1
    b ler_loop
ler_timeout:
    ldr x0, = msg_timeout
    bl _escrever_tex
    bl _verificar_queue_timeout
    mov x0, 2
    b ler_fim
ler_erro:
    ldr x0, = msg_erro_status
    bl _escrever_tex
    // debug: imprime qual foi o codigo de erro
    ldr x0, = status_byte
    ldrb w0, [x0]
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    mov x0, 1
    b ler_fim
ler_sucesso:
    mov x0, 0
ler_fim:
    ldp x25, x26, [sp, 64]
    ldp x23, x24, [sp, 48]
    ldp x21, x22, [sp, 32]
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 80
    ret
_verificar_config:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    
    ldr x0, = msg_verificando_config
    bl _escrever_tex
    
    // verifica endereços das estruturas
    ldr x0, = msg_desc_tabela
    bl _escrever_tex
    ldr x0, = desc_tabela
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    ldr x0, = msg_disponivel_anel
    bl _escrever_tex  
    ldr x0, = disponivel_anel
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    ldr x0, = msg_usado_anel
    bl _escrever_tex
    ldr x0, = usado_anel
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    ldp x29, x30, [sp], 16
    ret
_verificar_queue_timeout:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    
    ldr x0, = msg_usado_idc
    bl _escrever_tex
    ldr x0, = usado_anel
    ldrh w0, [x0, 2] // usado_anel->idc
    bl _escrever_decimal
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    ldr x0, = msg_disponivel_idc
    bl _escrever_tex  
    ldr x0, = disponivel_anel
    ldrh w0, [x0, 2] // disponivel_anel->idc
    bl _escrever_decimal
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    ldr x0, = msg_debug_status
    bl _escrever_tex
    ldr x0, = status_byte
    ldrb w0, [x0]
    bl _escrever_decimal
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    ldp x29, x30, [sp], 16
    ret
_verificar_registradores:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    
    // verifica valor magico no pos correto
    ldr x0, = msg_magico
    bl _escrever_tex
    ldr w0, [x19, 0x00] // MAGICO na pos 0x00
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    // verifica versão
    ldr x0, = msg_versao
    bl _escrever_tex
    ldr w0, [x19, 0x04] // VERSAO na pos 0x04
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    // verifica AMBIENTE_ID
    ldr x0, = msg_ambienteId
    bl _escrever_tex
    ldr w0, [x19, 0x08] // AMBIENTE_ID na pos 0x08
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    ldp x29, x30, [sp], 16
    ret
_verificar_descritores:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    
    ldr x0, = msg_desc0_endereco
    bl _escrever_tex
    ldr x0, = desc_tabela
    ldr x0, [x0] // desc[0].endereco
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    ldr x0, = msg_desc0_tam
    bl _escrever_tex
    ldr x0, = desc_tabela
    ldr w0, [x0, 8] // desc[0].tam
    bl _escrever_decimal
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    ldr x0, = msg_desc0_marcacoes
    bl _escrever_tex
    ldr x0, = desc_tabela
    ldrh w0, [x0, 12] // desc[0].marcacoes
    bl _escrever_hex
    ldr x0, = msg_nova_linha
    bl _escrever_tex
    
    ldp x29, x30, [sp], 16
    ret
_verificar_blk:
    // x19 = endereço pra verificar
    // retorna: w0 = 0 se for VirtIO-blk valido
    stp x29, x30, [sp, -16]!
    mov x29, sp

    // verifica valor magico
    ldr w0, [x19, MAGICO]
    ldr w1, =0x74726976
    cmp w0, w1
    b.ne verificar_falha

    // verifica ambiente id
    ldr w0, [x19, AMBIENTE_ID]
    cmp w0, 2  // ambiente bloqueado
    b.ne verificar_falha

    mov w0, 0
    b verificar_fim
verificar_falha:
    mov w0, 1
verificar_fim:
    ldp x29, x30, [sp], 16
    ret

.section .bss
// estruturas virtIO
.align 12
desc_tabela: .space 16 * 8
.align 12
disponivel_anel: .space 4 + (2 * 8) + 2
.align 12
usado_anel: .space 4 + (8 * 8) + 2

// dados
.align 8
blk_req: .space 16
.align 4
status_byte: .space 1

.section .rodata
msg_iniciando: .asciz "Iniciando carregamento...\r\n"
msg_procurando: .asciz "Procurando dispositivo VirtIO-blk...\r\n"
msg_encontrado: .asciz "Dispositivo encontrado em: "
msg_nao_encontrado: .asciz "Dispositivo não encontrado\r\n"
msg_iniciando2: .asciz "Inicializando dispositivo...\r\n"
msg_erro_inicio: .asciz "Erro na inicializacao\r\n"
msg_lendo_setor: .asciz "Lendo setor: "
msg_erro_leitura: .asciz "Erro na leitura\r\n"
msg_sucesso: .asciz "Kernel carregado\r\n"
msg_nova_linha: .asciz "\r\n"
msg_timeout: .asciz "Timeout na leitura\r\n"
msg_erro_status: .asciz "Erro de status\r\n"
msg_base_encontrada: .asciz "Dispositivo encontrado em: "
msg_falha_leitura: .asciz "Erro na leitura\n"
msg_carregando: .asciz "Carregando kernel...\n"
msg_reinicio_ambiente: .asciz "Reiniciando dispositivo...\r\n"
msg_def_ack: .asciz "Definindo ACKNOWLEDGE...\r\n"
msg_def_driver: .asciz "Definindo DRIVER...\r\n"
msg_negociar_recursos: .asciz "Negociando features...\r\n"
msg_def_recursos_ok: .asciz "Definindo RECURSOS_OK...\r\n"
msg_config_queue: .asciz "Configurando queue 0...\r\n"
msg_def_queue_tam: .asciz "Definindo tamanho da queue...\r\n"
msg_config_descritores: .asciz "Configurando descritores...\r\n"
msg_desc_tabela_endereco: .asciz "Endereço desc_tabela: "
msg_config_disponivel_anel: .asciz "Configurando disponivel_anel...\r\n"
msg_disponivel_anel_endereco: .asciz "Endereço disponivel_anel: "
msg_config_usado_anel: .asciz "Configurando usado_anel...\r\n"
msg_usado_anel_addr: .asciz "Endereço usado_anel: "
msg_def_queue_pronta: .asciz "Definindo QUEUE_PRONTA...\r\n"
msg_def_driver_ok: .asciz "Definindo DRIVER_OK...\r\n"
msg_inicio_sucesso: .asciz "Dispositivo inicializado com sucesso\r\n"
msg_inicio_erro: .asciz "Erro na inicializacao do dispositivo\r\n"
msg_verificando_config: .asciz "Verificando configuracao VirtIO...\r\n"
msg_desc_tabela: .asciz "desc_tabela: "
msg_disponivel_anel: .asciz "disponivel_anel: "  
msg_usado_anel: .asciz "usado_anel: "
msg_usado_idc: .asciz "Usado indice: "
msg_disponivel_idc: .asciz "Disponivel indice: "  
msg_debug_status: .asciz "Status byte: "
msg_notificando: .asciz "Notificando dispositivo...\r\n"
msg_magico: .asciz "VirtIO Magico: "
msg_versao: .asciz "VirtIO Versão: "
msg_ambienteId: .asciz "VirtIO Ambiente ID: "
msg_desc0_endereco: .asciz "Desc[0] endereço: "
msg_desc0_tam: .asciz "Desc[0] tamanho: "
msg_desc0_marcacoes: .asciz "Desc[0] marcações: "
