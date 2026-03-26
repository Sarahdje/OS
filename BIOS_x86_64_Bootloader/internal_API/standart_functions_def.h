// this file contains definitions of the standard functions provided to the bootloader

#include <iterator>
#include <stdint.h>
#include <uchar.h>

// include the asm func to change the cursor position wherever we want
extern "C" volatile void setCursorPos(uint32_t pos);

void memcpy(int* dest, int* src, uint64_t size);

void memset(int* ptr, char8_t value, uint64_t size);

void memset(int* ptr, char16_t value, uint64_t size);

int strlen(const char* str);

int printf(const char* str, int line);

char* itoa(int number, char* str, int base);
