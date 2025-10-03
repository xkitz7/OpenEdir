; multiboot.asm
section .multiboot
align 4

MULTIBOOT_HEADER_MAGIC equ 0x1BADB002
MULTIBOOT_HEADER_FLAGS equ 0x00000003
MULTIBOOT_HEADER_CHECKSUM equ -(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_FLAGS)

multiboot_header:
    dd MULTIBOOT_HEADER_MAGIC
    dd MULTIBOOT_HEADER_FLAGS
    dd MULTIBOOT_HEADER_CHECKSUM
    dd multiboot_header
    dd _start
    dd 0
    dd 0
    dd _start

section .bss
align 16

stack_bottom:
    resb 16384
stack_top:

multiboot_info_ptr:
    resd 1
multiboot_magic:
    resd 1

section .text
global _start

_start:
    mov [multiboot_magic], eax
    mov [multiboot_info_ptr], ebx
    mov esp, stack_top
    cld

    ; Initialize systems
    call init_gdt
    call init_idt
    
    ; Call kernel main
    extern kernel_main
    push ebx
    push eax
    call kernel_main

    cli
.hang:
    hlt
    jmp .hang

init_gdt:
    lgdt [gdt_ptr]
    jmp 0x08:.reload_cs
.reload_cs:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ret

init_idt:
    lidt [idt_ptr]
    ret

section .data
align 4

gdt:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF

gdt_ptr:
    dw $ - gdt - 1
    dd gdt

idt:
    times 256 dq 0

idt_ptr:
    dw $ - idt - 1
    dd idt
