/* krnl/linker.ld */

ENTRY(_start)

SECTIONS
{
    /* Kernel loaded at 1MB */
    . = 0x100000;
    
    /* Multiboot header must be first */
    .multiboot : {
        KEEP(*(.multiboot))
    }
    
    /* Text section */
    .text : {
        *(.text)
        *(.text.*)
    }
    
    /* Read-only data */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }
    
    /* Initialized data */
    .data : {
        *(.data)
        *(.data.*)
    }
    
    /* Uninitialized data */
    .bss : {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    }
    
    /* End of kernel */
    end = .;
}

/* Define symbols for memory management */
PROVIDE(kernel_start = 0x100000);
PROVIDE(kernel_end = end);
