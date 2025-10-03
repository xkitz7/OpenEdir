/* linker.ld */

ENTRY(_start)

SECTIONS
{
    /* Bootloader starts at 1MB + 64KB */
    . = 0x100000;
    
    /* Multiboot header must be in the first 8KB */
    .multiboot BLOCK(4K) : ALIGN(4K)
    {
        *(.multiboot)
    }
    
    /* Executable code */
    .text BLOCK(4K) : ALIGN(4K)
    {
        *(.text)
        *(.text.*)
    }
    
    /* Read-only data */
    .rodata BLOCK(4K) : ALIGN(4K)
    {
        *(.rodata)
        *(.rodata.*)
    }
    
    /* Read-write data (initialized) */
    .data BLOCK(4K) : ALIGN(4K)
    {
        *(.data)
        *(.data.*)
    }
    
    /* Read-write data (uninitialized) and stack */
    .bss BLOCK(4K) : ALIGN(4K)
    {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    }
    
    /* Kernel ends here */
    kernel_end = .;
    
    /* Discard unnecessary sections */
    /DISCARD/ :
    {
        *(.comment)
        *(.note.*)
    }
}

/* Memory layout */
MEMORY
{
    /* 1MB to 16MB for kernel */
    ram (rwx) : ORIGIN = 0x100000, LENGTH = 15M
}
