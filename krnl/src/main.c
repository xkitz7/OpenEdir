#include "terminal.h"
#include "types.h"
#include "memory.h"

// Simple delay function
void delay(uint32_t milliseconds) {
    // Very basic delay - in a real OS you'd use the PIT or HPET
    for (volatile uint32_t i = 0; i < milliseconds * 10000; i++) {
        asm volatile ("nop");
    }
}

// Kernel main function
void kernel_main(uint32_t multiboot_magic, void* multiboot_info) {
    // Initialize terminal
    terminal_initialize();
    
    // Print "Hi!" after 5 seconds
    delay(5000);
    terminal_writestring("Hi!\n");
    
    // OpenEdir animation loop
    const char* frames[] = {
        "OpenEdir.",
        "OpenEdir..", 
        "OpenEdir...",
        "OpenEdir.."
    };
    
    uint32_t frame_count = sizeof(frames) / sizeof(frames[0]);
    uint32_t current_frame = 0;
    
    while (1) {
        terminal_setcolor(VGA_COLOR_LIGHT_GREEN);
        terminal_writestring(frames[current_frame]);
        delay(500);  // 500ms between frames
        
        // Clear the line by writing backspaces
        for (int i = 0; i < 12; i++) {
            terminal_putchar('\b');
        }
        
        // Move to next frame
        current_frame = (current_frame + 1) % frame_count;
    }
}
