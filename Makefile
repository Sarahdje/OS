all: qemu

bootloader := BIOS_x86_64_Bootloader
bootloader_flags := -ffreestanding -O2 -mno-red-zone -fno-exceptions -fno-rtti -fno-stack-protector -fno-pic -m64

bootloader:
	nasm -f bin "${bootloader}"/bootloader.asm -o "${bootloader}"/bootloader.bin
	nasm -f elf64 "${bootloader}"/early_boot.asm -o "${bootloader}"/early_boot.o
	g++ $(bootloader_flags) -c -o "${bootloader}"/internal_API/standart_functions.o "${bootloader}"/internal_API/standart_functions.cpp
	g++ $(bootloader_flags) -c -o "${bootloader}"/main.o "${bootloader}"/main.cpp
	g++ $(bootloader_flags) -c -o "${bootloader}"/Peripherals/PCI.o "${bootloader}"/Peripherals/PCI.c
	ld -r "${bootloader}"/main.o "${bootloader}"/internal_API/standart_functions.o "${bootloader}"/Peripherals/PCI.o -o "${bootloader}"/c_combined.o
	ld -T "${bootloader}"/linker.ld "${bootloader}"/early_boot.o "${bootloader}"/c_combined.o --oformat binary -o "${bootloader}"/early_boot.bin

bootdisk: bootloader
	dd if=/dev/zero of=disk.img bs=512 count=2880
	dd conv=notrunc if="${bootloader}"/bootloader.bin of=disk.img bs=512 count=1 seek=0
	dd conv=notrunc if="${bootloader}"/early_boot.bin of=disk.img bs=512 count=8 seek=1

qemu: bootdisk
	qemu-system-x86_64 -vga cirrus -display gtk -machine q35 -m 5G -serial stdio -fda disk.img -no-reboot -d int,guest_errors,cpu_reset,mmu

debug: bootdisk
	qemu-system-x86_64 -vga cirrus -display gtk -machine q35 -m 5G -fda disk.img -gdb tcp::26000 -S &
	gdb -ex "target remote localhost:26000"
