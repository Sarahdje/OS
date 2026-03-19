org 0x7C00          ; tells nasm that the code will start at thet adress (convention)
bits 16             ; set ro the real mode
start: jmp boot     ; set the boot function


boot:
    ;; basic init of the system
    cli             ; no interrupts
    cld             ; init the system
    ;; set the buffer index
    mov ax, 0x50
    mov es, ax
    xor bx, bx
    mov al, 8       ; read Heigt sectors
    mov ch, 0       ; track 0
    mov cl, 2       ; sectors to read (the second sector)
    mov dh, 0       ; head number
    mov dl, 0       ; drive number
    mov ah, 0x02    ; read sectors for disk
    int 0x13        ; call the BIOS routine
    jc disk_error   ; catch the failed reads
    jmp 0x50:0x0    ; boot the operating system

disk_error:
    mov ah, 0x0E    ; BIOS teletype output function
    mov al, '!'     ; Character to print
    int 0x10        ; Call BIOS interrupt   
    hlt             ; halt the system in case something went wrong

times 510 - ($ - $$) db 0   ; we have to be 512 bytes long. erase the rest of the bytes
dw 0xAA55                   ; boot signature
