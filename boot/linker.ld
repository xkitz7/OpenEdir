ENTRY(_start)

SECTIONS
{
    . = 0x100000;
    
    .multiboot BLOCK(4K) : ALIGN(4K)
    {
        *(.multiboot)
    }
    
    .text BLOCK(4K) : ALIGN(4K)
    {
        *(.text)
    }
    
    .rodata BLOCK(4K) : ALIGN(4K)
    {
        *(.rodata)
    }
    
    .data BLOCK(4K) : ALIGN(4K)
    {
        *(.data)
    }
    
    .bss BLOCK(4K) : ALIGN(4K)
    {
        *(COMMON)
        *(.bss)
    }
    
    kernel_end = .;
}

MEMORY
{
    ram (rwx) : ORIGIN = 0x100000, LENGTH = 15M
}
