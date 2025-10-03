#ifndef MEMORY_H
#define MEMORY_H

#include "types.h"

void* memset(void* ptr, int value, size_t num);
void* memcpy(void* destination, const void* source, size_t num);

#endif
