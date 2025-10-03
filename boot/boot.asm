; boot.asm
bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Save boot drive
    mov [boot_drive], dl

    ; Print loading message
    mov si, loading_msg
    call print_string

    ; Load kernel from disk
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    xor bx, bx
    
    mov ah, 0x02
    mov al, KERNEL_SECTOR_COUNT
    mov ch, 0x00
    mov cl, 0x02
    mov dh, 0x00
    mov dl, [boot_drive]
    int 0x13
    
    jc disk_error
    cmp al, KERNEL_SECTOR_COUNT
    jne disk_error

    ; Switch to protected mode
    switch_to_pm:
        cli
        lgdt [gdt_descriptor]
        mov eax, cr0
        or eax, 0x1
        mov cr0, eax
        jmp CODE_SEG:init_pm

disk_error:
    mov si, disk_error_msg
    call print_string
    jmp $

print_string:
    mov ah, 0x0E
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

bits 32

init_pm:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov ebp, 0x90000
    mov esp, ebp
    
    ; Jump to kernel
    jmp KERNEL_LOAD_ADDRESS

; GDT
gdt_start:
    gdt_null:
        dd 0x0
        dd 0x0
    gdt_code:
        dw 0xFFFF
        dw 0x0
        db 0x0
        db 10011010b
        db 11001111b
        db 0x0
    gdt_data:
        dw 0xFFFF
        dw 0x0
        db 0x0
        db 10010010b
        db 11001111b
        db 0x0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

KERNEL_LOAD_SEGMENT equ 0x1000
KERNEL_LOAD_ADDRESS equ 0x10000
KERNEL_SECTOR_COUNT equ 32

boot_drive db 0
loading_msg db 'Loading OpenEdir...', 0x0D, 0x0A, 0
disk_error_msg db 'Disk error!', 0

times 510-($-$$) db 0
dw 0xAA55
