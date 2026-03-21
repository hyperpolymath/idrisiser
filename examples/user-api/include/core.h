/* Minimal C header for testing idrisiser parsing */

#ifndef CORE_H
#define CORE_H

#include <stddef.h>
#include <stdint.h>

int process_item(void* input, size_t len);
int reduce(void* a, void* b, void* out);
void* allocate_buffer(size_t size);
void free_buffer(void* buf);

#endif
