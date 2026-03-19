;; this program is the Assembly main of the bootloader
;; it is launched by the early bootsector program
;; it is responsible to launch the C main and switch to long mode from real mode
bits 16         ; set to the real mode

align 4
IDT:
    .Length       dw 0
    .Base         dd 0

%define PAGE_PRESENT (1 << 0)
%define PAGE_WRITE (1 << 1)
%define CODE_SEG 0x0008

section .text
    global _start   
_start: jmp init16


init16: 
    ;; no, it's time to switch to 32 bits protected mode
    db 0x66                         ; 32-bit operand override
    db 0x8D                         ; lea ebx, [Addr]
    db 0x1E                         
    dd GtdDesc
    db 0x0F                          ; lgdt [bx]
    db 0x01
    db 0x17
    mov eax, cr0                    ; Get control register 0
    or eax, 1                       ; Activate Protected Mode
    mov cr0, eax                    ; Protected mode is now activated !
    jmp $+2                         ; to flush the instruction queue
    db 0x66                         ; 32-bit operand override
    db 0xEA                         ; far jmp
    dd init32                       ; 32-bit offset
    dw 0x08                         ; 16-bit selector

GDT:
    ;; Gdt[0] : Null entry, never used
    dd 0                
    dd 0         
    ;; Gdt[1] : Executable, read-only code, base adress of 0, limit of FFFFFh, granularity bit (G) set (making the limit 4G)
    dw 0xFFFF           ; limit [15..0]
    dw 0x0              ; base [15..0]
    db 0x0              ; base [23..16]
    db 10011010b        ; P(1) DPL(00) S(1) 1 C(0) R(1) A(0)
    db 11001111b        ; G(1) D(1) 0 0 Limit [19..16]
    db 0x0              ; Base [31..24]
    ;; GDT[2] : Writable data segment, covering the save adress than GDT[1]
    dw 0xFFFF           ; limit [15..0]
    dw 0x0              ; base [15..0]
    db 0x0              ; base [23..16]
    db 10010010b        ; P(1) DPL(00) S(1) 0 E(0) W(1) A(0)
    db 11001111b        ; G(1) D(1) 0 0 Limit [19..16]
    db 0x0              ; Base [31..24]

GDT_SIZE equ $ - GDT    ; Size, in bytes

GtdDesc:                ; GTD descriptor 
    dw GDT_SIZE - 1     ; GDT limit
    dd GDT              ; GDT base adress

bits 32

;; reserve the minimal 4096 bytes of space for the P2, P3 and P4 tables
p4_table equ 0x3000     ; hard coded adress for P4 table ([beginning adress]*8)     
p3_table equ 0x4000     ; hard coded adress for P3 table ([beginning adress]*8 + 4096)
p2_table equ 0x5000     ; hard coded adress for P2 table ([beginning adress]*8 + 4096*2)
PML4T_table equ 0x6000  ; A page map level 4 table, which replaces the p4 table as the root

; Access bits
PRESENT        equ 1 << 7
NOT_SYS        equ 1 << 4
EXEC           equ 1 << 3
DC             equ 1 << 2
RW             equ 1 << 1
ACCESSED       equ 1 << 0

; Flags bits
GRAN_4K       equ 1 << 7
SZ_32         equ 1 << 6
LONG_MODE     equ 1 << 5

GDT64:
    .Null: equ $ - GDT64
        dq 0
    .Code: equ $ - GDT64
        .Code.limit_lo: dw 0xffff
        .Code.base_lo: dw 0
        .Code.base_mid: db 0
        .Code.access: db PRESENT | NOT_SYS | EXEC | RW
        .Code.flags: db GRAN_4K | LONG_MODE | 0xF   ; Flags & Limit (high, bits 16-19)
        .Code.base_hi: db 0
    .Data: equ $ - GDT64
        .Data.limit_lo: dw 0xffff
        .Data.base_lo: dw 0
        .Data.base_mid: db 0
        .Data.access: db PRESENT | NOT_SYS | RW
        .Data.Flags: db GRAN_4K | SZ_32 | 0xF       ; Flags & Limit (high, bits 16-19)
        .Data.base_hi: db 0
    .Pointer:
        dw $ - GDT64 - 1
        dq GDT64

init32:
    ;; initialize all segment registers to 0x10 (entry #2 in the GDT)
    mov ax, 0x10                    ; entry #2 in GDT
    mov ds, ax                      ; ds = 0x10
    mov es, ax                      ; es = 0x10
    mov fs, ax                      ; fs = 0x10
    mov gs, ax                      ; gs = 0x10
    mov ss, ax                      ; ss = 0x10
    ;; set the top of the stack to an arbitrary location
    mov esp, 0xF000
    ;; the VGA ptr will be considered edx
    ;; erase the vga memory
    mov edi, 0xb8000         ; Set pointer to VGA memory
    mov ah, 0x07             ; Set attribute (white on black)
    mov ecx, 80 * 25         ; 80 columns × 25 rows = 2000 characters
    xor al, al               ; Clear character (null)
    rep stosw                ; Write 2000 times: [0x0007] pairs   
    ;; now, it's time to enter long mode -- 64 bit
    ;; we first need to check wether CPUID is supported on our CPU or not by trying to flip the ID bit (bit 21)
    ;; if we can flip it, CPUID is supported.
    pushfd
    pop eax                         ; Copy flags into eax via the stack
    mov ecx, eax                    ; Copy to ecx to compare later on
    xor eax, 1 << 21                ; flip the ID bit
    push eax                        ; push eax
    popfd                           ; Copy eax to FLAGS via the stack
    pushfd                          ; push FLAGS
    pop eax                         ; Copy flags back to eax (With the flipped bit if CPUID is supported)
    push ecx                        ; push the original FLAGS 
    popfd                           ; Restore flags from the old version stored in ecx (i.e : flipping the ID bit back)
    cmp ecx, eax                    ; compare eax and ecx. if equal, then that means that the bit wasn't flipped, and CPUID isn't supported.
    je .error_missing_required_CPU_Feature
    ;; no that we have confirmed that CPUID is indeed supported, we can use it to check if our CPU supports long mode.
    ;; test if extended processor info is avalaible
    mov eax, 0x80000000                                     ; implicit argument for cpuid
    cpuid                                                   ; get highest supported argument
    cmp eax, 0x80000001                                     ; it needs to be at least 0x80000001
    jb .error_missing_required_CPU_Feature                  ; if it's less, the CPU is too old for long mode
    ;; use extended info to test if
    mov eax, 0x80000001                                     ; argument for extended processor info
    cpuid                                                   ; returns various feature bits in ecx and edx
    test edx, 1 << 29                                       ; test if the LM-bit is set in the D-register
    jz .error_missing_required_CPU_Feature                  ; If it's not set, there is no long mode
    ;; setup page tables
    ;; we first need to erase the previous content of the tables to avoid any bugs
    mov edi, p4_table
    mov ecx, 4096*5
    xor eax, eax
    rep stosb
    ;; link the first PML4T table entry to the P4 table
    mov eax, p4_table
    or eax, PAGE_PRESENT | PAGE_WRITE           ; present + writable
    mov [PML4T_table], eax
    ;; link the first P4 entry to the P3 table
    mov eax, p3_table
    or eax, PAGE_PRESENT | PAGE_WRITE           ; present + writable
    mov [p4_table], eax
    ;; link the first P3 entry to the P2 table
    mov eax, p2_table
    or eax, PAGE_PRESENT | PAGE_WRITE           ; present + writable
    mov [p3_table], eax
    ;; now we need to map each p2 table entry to a 4096 Bytes page
    ;; this way our kernel will have 2Mib of virtual memory directly
    ;; we *could* use 1Gb pages, but they would break compatibility with older intel CPU from before 2010
    ;; in order to achieve this, we need a loop which maps physical pages from 0x0 forward in memory
    mov ecx, 0                      ; counted variable
    mov eax, PAGE_PRESENT | PAGE_WRITE          ; present + writable
.map_p2_table:
    ;; map the ecx entry of the p2_table to a page that starts at adress 0x0 * ecx 
    mov [p2_table + ecx*8], eax     ; map ecx-th entry
    add eax, 0x1000                 ; 4096 Bytes
    inc ecx                         ; increase counter
    cmp ecx, 512                    ; check if we succesfully mapped all pages
    jnae .map_p2_table              ; if it's not done yet, continue. else, exit the loop.
    ;; no, we enable paging directly using the cr3 CPU register
    mov eax, PML4T_table            ; eax contains the adress of the P4 table
    mov cr3, eax                    ; mov this adress in the cr3 control register
    ;; enable PAE-flag in cr4 (Physical Adress Extension)
    mov eax, cr4
    or eax, 10100000b
    mov cr4, eax
    ;; disable IRQs
    mov al, 0xFF                      ; Out 0xFF to 0xA1 and 0x21 to disable all IRQs.
    out 0xA1, al
    out 0x21, al
    lidt [IDT]                        ; Load a zero length IDT so that any NMI causes a triple fault.
    ;; set the long mode bit in the EFER MSR (model specific register)
    mov ecx, 0xC0000080             ; read from the EFER MSR
    rdmsr
    or eax, 0x00000100              ; set the LME limit
    wrmsr
    ;; enable paging in the cr0 register
    mov eax, cr0
    or eax, 0x80000001              ; enable paging and protection simultaneously
    mov cr0, eax
    ;; no, the CPU is still not in 64-bit mode -- it's still in a 32 bit compatibility submode
    ;; to truly use 64 bit, an essential legacy step is still the GDT table -- the 64 bit one, this time around
    lgdt [GDT64.Pointer]                 ; loads the GDT table
    ;; far jmp to the 64 bit main to flush everything nicely 
    jmp CODE_SEG:init64             ; jumps to the x86_64 entry and flushes the instruction stream

.error_missing_required_CPU_Feature:
    ;; placeholder, for now
    ;; maybe later an error message
    hlt

bits 64

extern C_main

init64:
    cli                             ; no interruptions
    ;; load 1 << 1 into all data segment registers
    mov ax, 1 << 1
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    ;; finally ! here we are in 64 bit mode.
    mov rdi, 0xB8000
    mov ah, 0x07
    mov rcx, 0
.print:
    mov al, [msg1 + rcx]
    mov [rdi], ax 
    add rdi, 2
    inc rcx
    mov bl, [msg1 + rcx]
    cmp bl, 0
    jne .print
    ;; set cursor position to where we stopped. 
    push rcx                        ; the cursor position is now right on top of the stack -> useful for later on
    mov ebx, ecx  
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    mov al, bl
    out dx, al
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    mov al, bh
    out dx, al
    ;; finally, load and launch the C main the scan disks and mount the ext2 partition 
    mov rsp, 0xF000                 ; set the top of the stack
    lea rax, C_main
    call rax                        ; now, we officially handed control of everything to the C main.



msg1 db "succesfully entered long mode, and initialized bootloader...", 0

