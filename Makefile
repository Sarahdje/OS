all: qemu

bootloader := BIOS_x86_64_Bootloader

bootloader:
	nasm -f bin "${bootloader}"/bootloader.asm -o "${bootloader}"/bootloader
	nasm -f elf64 "${bootloader}"/early_boot.asm -o "${bootloader}"/early_boot.o
	gcc -ffreestanding -O3 -c -o "${bootloader}"/main.o "${bootloader}"/main.c
	ld -T "${bootloader}"/linker.ld "${bootloader}"/early_boot.o "${bootloader}"/main.o 

bootdisk: bootloader
	dd if=/dev/zero of=disk.img bs=512 count=2880
	dd conv=notrunc if="${bootloader}"/bootloader of=disk.img bs=512 count=1 seek=0
	dd conv=notrunc if="${bootloader}"/early_boot of=disk.img bs=512 count=1 seek=1 

qemu: bootdisk
	qemu-system-x86_64 -vga cirrus -display gtk -machine q35 -m 5G -serial stdio -fda disk.img -no-reboot -d int,guest_errors,cpu_reset,mmu 

debug: bootdisk
	qemu-system-x86_64 -vga cirrus -display gtk -machine q35 -m 5G -fda disk.img -gdb tcp::26000 -S &
	gdb -ex "target remote localhost:26000"
