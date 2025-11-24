// biblis/ns.asm
.global ns_abrir

msg_coisa: .asciz "alguma coisa\r\n"

.align 2
1:
    ldr x0, = msg_coisa
    bl _escrever_tex
    b ns_abrir // volta pro loop
// loop de obter e escrever
ns_abrir:
    bl _obter_car
    mov w1, '@'
    cmp w0, w1 // verifica se digitou "@"
    b.eq 1b
    bl _escrever_car
    mov w0, 0x0A
    bl _escrever_car
    b ns_abrir
.end
