// this is the file reponsible to scan the differents disks and parse the ext2 partition in order to load the kernel
// the function C_main is directly called by the Assembly code and launched in long mode
void C_main() {
    asm("ud2");
}