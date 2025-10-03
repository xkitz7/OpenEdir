#include "memory.h"

void* memset(void* ptr, int value, size_t num) {
    uint8_t* p = (uint8_t*)ptr;
    for (size_t i = 0; i < num; i++) {
        p[i] = (uint8_t)value;
    }
    return ptr;
}

void* memcpy(void* destination, const void* source, size_t num) {
    uint8_t* dst = (uint8_t*)destination;
    const uint8_t* src = (const uint8_t*)source;
    for (size_t i = 0; i < num; i++) {
        dst[i] = src[i];
    }
    return destination;
}
