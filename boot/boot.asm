; boot.asm - Primary bootloader that sets up protected mode and loads the kernel
bits 16                         ; 16-bit real mode
org 0x7C00                      ; BIOS loads bootloader at this address

start:
    ; Set up segment registers
    cli                         ; Disable interrupts
    xor ax, ax                  ; Zero AX
    mov ds, ax                  ; Data segment = 0
    mov es, ax                  ; Extra segment = 0
    mov ss, ax                  ; Stack segment = 0
    mov sp, 0x7C00              ; Stack pointer below bootloader
    sti                         ; Enable interrupts

    ; Save boot drive number
    mov [boot_drive], dl

    ; Load kernel from disk
    mov bx, KERNEL_LOAD_SEGMENT ; ES:BX = buffer address
    mov es, bx
    xor bx, bx
    
    mov ah, 0x02                ; BIOS read sector function
    mov al, KERNEL_SECTOR_COUNT ; Number of sectors to read
    mov ch, 0x00                ; Cylinder number
    mov cl, 0x02                ; Sector number (1-based, boot sector is 1)
    mov dh, 0x00                ; Head number
    mov dl, [boot_drive]        ; Drive number
    int 0x13                    ; BIOS disk interrupt
    
    jc disk_error               ; Jump if error (carry flag set)

    ; Check if all sectors were read
    cmp al, KERNEL_SECTOR_COUNT
    jne disk_error

    ; Switch to protected mode
    switch_to_pm:
        cli                     ; Disable interrupts
        lgdt [gdt_descriptor]   ; Load GDT descriptor
        
        ; Set protection enable bit in CR0
        mov eax, cr0
        or eax, 0x1
        mov cr0, eax
        
        ; Far jump to flush pipeline and load CS with 32-bit segment
        jmp CODE_SEG:init_pm

disk_error:
    mov si, disk_error_msg
    call print_string
    jmp $

; 16-bit real mode print function
print_string:
    mov ah, 0x0E                ; BIOS teletype function
.print_char:
    lodsb                       ; Load byte from SI into AL
    cmp al, 0                   ; Check for null terminator
    je .done
    int 0x10                    ; Print character
    jmp .print_char
.done:
    ret

bits 32                         ; 32-bit protected mode

init_pm:
    ; Set up segment registers for protected mode
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Set up stack
    mov ebp, 0x90000
    mov esp, ebp
    
    ; Jump to kernel entry point
    jmp KERNEL_LOAD_ADDRESS

; Global Descriptor Table (GDT)
gdt_start:
    ; Null descriptor
    gdt_null:
        dd 0x0
        dd 0x0

    ; Code segment descriptor
    gdt_code:
        dw 0xFFFF               ; Limit (bits 0-15)
        dw 0x0                  ; Base (bits 0-15)
        db 0x0                  ; Base (bits 16-23)
        db 10011010b            ; Access byte
        db 11001111b            ; Flags + Limit (bits 16-19)
        db 0x0                  ; Base (bits 24-31)

    ; Data segment descriptor
    gdt_data:
        dw 0xFFFF               ; Limit (bits 0-15)
        dw 0x0                  ; Base (bits 0-15)
        db 0x0                  ; Base (bits 16-23)
        db 10010010b            ; Access byte
        db 11001111b            ; Flags + Limit (bits 16-19)
        db 0x0                  ; Base (bits 24-31)

gdt_end:

; GDT descriptor
gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Size of GDT
    dd gdt_start                ; Start address of GDT

; Segment selector constants
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; Constants
KERNEL_LOAD_SEGMENT equ 0x1000  ; Segment where kernel is loaded
KERNEL_LOAD_ADDRESS equ 0x10000 ; Physical address where kernel is loaded
KERNEL_SECTOR_COUNT equ 64      ; Number of sectors to load (adjust as needed)

; Data
boot_drive db 0
disk_error_msg db 'DISK ERORR!', 0

; Boot signature
times 510-($-$$) db 0
dw 0xAA55
