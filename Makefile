FPB=./compiladores/fpb

# arquivo FPB sem extensão
FPB_FONTE := teste
FPB_FONTE_CAMINHO := fpb/$(FPB_FONTE)

# compilar FPB => gera fpb/*.asm
compilar_fpb:
	chmod +x compiladores/fpb
	$(FPB) fpb/$(FPB_FONTE) -asm


AS=as
LD=ld
OBJCOPY=objcopy

BOOTLOADER_CODIGOS= \
	arquiteturas/boot.asm \
	drivers/virt/terminal.asm \
	drivers/virt/disco.asm

BOOTLOADER_OBJETOS=$(BOOTLOADER_CODIGOS:.asm=.o)

# todos os .asm reais dentro de fpb/
FPB_ASM := $(wildcard fpb/*.asm)

KERNEL_CODIGOS= \
	nucleo/kernel.asm \
	biblis/ns.asm \
	drivers/virt/terminal.asm \
	$(FPB_ASM)

KERNEL_OBJETOS=$(KERNEL_CODIGOS:.asm=.o)

bootloader.bin: bootloader.elf
	$(OBJCOPY) -O binary $< $@

bootloader.elf: $(BOOTLOADER_OBJETOS)
	$(LD) -EL -nostdlib -T drivers/virt/linker.ld $^ -o $@

# kernel sem elf
kernel.bin: $(KERNEL_OBJETOS)
	$(LD) -EL -nostdlib -T drivers/virt/kernel.ld -o kernel.tmp $^
	$(OBJCOPY) -O binary kernel.tmp $@
	rm -f kernel.tmp
	@echo "=== kernel info ==="
	@echo "Tamanho do kernel:"
	@stat -c%s kernel.bin
	@echo "Primeiros bytes (hex):"
	@od -x kernel.bin | head -3
	@echo "Primeiros bytes (hex - bytes):"
	@od -t x1 kernel.bin | head -5

disco.img: bootloader.bin kernel.bin
	@echo "=== criando disco ==="
	@echo "Tamanho do bootloader:" `stat -c%s bootloader.bin` "bytes"
	@echo "Tamanho do kernel:" `stat -c%s kernel.bin` "bytes"
	dd if=/dev/zero of=$@ bs=512 count=2048 2>/dev/null
	dd if=bootloader.bin of=$@ bs=512 conv=notrunc 2>/dev/null
	dd if=kernel.bin of=$@ bs=512 seek=64 conv=notrunc 2>/dev/null
	@echo "Disco criado. Verificando setor 64:"
	@dd if=disco.img bs=512 skip=64 count=1 2>/dev/null | od -x | head -3

%.o: %.asm
	$(AS) -EL $< -o $@

limpar:
	rm -f $(BOOTLOADER_OBJETOS) $(KERNEL_OBJETOS) \
		bootloader.elf bootloader.bin \
		kernel.bin kernel.tmp \
		disco.img

qemu: disco.img
	qemu-system-aarch64 \
	-machine virt,virtualization=on \
	-cpu cortex-a53 \
	-m 128M \
	-device loader,file=bootloader.bin,addr=0x40100000,cpu-num=0 \
	-drive if=none,file=disco.img,format=raw,id=hd0 \
	-device virtio-blk-device,drive=hd0 \
	-global virtio-mmio.force-legacy=false \
	-serial stdio \
	-display none \
	-d in_asm -D qemu.log

.PHONY: limpar qemu