; multiboot.asm
section .multiboot
align 4

; Multiboot header constants
MULTIBOOT_HEADER_MAGIC equ 0x1BADB002
MULTIBOOT_HEADER_FLAGS equ 0x00000003  ; Align modules and provide memory map
MULTIBOOT_HEADER_CHECKSUM equ -(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_FLAGS)

; Multiboot header
multiboot_header:
    dd MULTIBOOT_HEADER_MAGIC
    dd MULTIBOOT_HEADER_FLAGS
    dd MULTIBOOT_HEADER_CHECKSUM

    ; Additional fields (optional)
    dd multiboot_header          ; header_addr
    dd _start                    ; load_addr
    dd 0                         ; load_end_addr
    dd 0                         ; bss_end_addr
    dd _start                    ; entry_addr

section .bss
align 16

; Stack configuration
stack_bottom:
    resb 16384                   ; 16 KB stack
stack_top:

; Multiboot information structure pointer
multiboot_info_ptr:
    resd 1

; Multiboot magic value
multiboot_magic:
    resd 1

section .text
global _start

_start:
    ; Save multiboot information
    mov [multiboot_magic], eax   ; Multiboot magic number
    mov [multiboot_info_ptr], ebx ; Multiboot info structure

    ; Set up stack
    mov esp, stack_top

    ; Clear direction flag
    cld

    ; Initialize essential subsystems
    call init_gdt
    call init_idt
    call init_pic

    ; Call kernel main function
    extern kernel_main
    push ebx                     ; Multiboot info structure
    push eax                     ; Multiboot magic number
    call kernel_main

    ; If kernel_main returns, halt
    cli
.hang:
    hlt
    jmp .hang

; Initialize Global Descriptor Table
init_gdt:
    ; Load GDT
    lgdt [gdt_ptr]
    
    ; Reload segment registers
    jmp 0x08:.reload_cs
.reload_cs:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ret

; Initialize Interrupt Descriptor Table
init_idt:
    ; Load IDT
    lidt [idt_ptr]
    ret

; Initialize Programmable Interrupt Controller
init_pic:
    ; Remap PIC
    mov al, 0x11
    out 0x20, al                 ; Initialize master PIC
    out 0xA0, al                 ; Initialize slave PIC
    
    mov al, 0x20
    out 0x21, al                 ; Master PIC vector offset
    mov al, 0x28
    out 0xA1, al                 ; Slave PIC vector offset
    
    mov al, 0x04
    out 0x21, al                 ; Tell master PIC about slave
    mov al, 0x02
    out 0xA1, al                 ; Tell slave PIC cascade identity
    
    mov al, 0x01
    out 0x21, al                 ; Set master PIC to 8086 mode
    out 0xA1, al                 ; Set slave PIC to 8086 mode
    
    ; Mask all interrupts initially
    mov al, 0xFF
    out 0x21, al
    out 0xA1, al
    
    ret

; GDT
section .data
align 4

gdt:
    ; Null descriptor
    dq 0x0000000000000000
    
    ; Code segment descriptor
    dq 0x00CF9A000000FFFF
    
    ; Data segment descriptor
    dq 0x00CF92000000FFFF

gdt_ptr:
    dw $ - gdt - 1
    dd gdt

; IDT (initialized to zero for now)
idt:
    times 256 dq 0

idt_ptr:
    dw $ - idt - 1
    dd idt
