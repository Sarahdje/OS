// this file contains the standard functions provided to the bootloader
#include <stdint.h>
#include <uchar.h>
#include "standart_functions_def.h"

volatile char* VGA_MEMORY = (char*)0xB8000;
volatile char* VGA_TMP_BUFFER = (char*)0x3000;

void memcpy(int* dest, int* src, uint64_t size) {
    // since the 1st arg, dest, is contained in %rdi, we do not need to move it
    // since the 2nd arg, src, is contained in %rsi, we do not need to move it
    asm volatile("cld                 \n\t"
                 "rep movsb           \n\t"
                 :  "+D" (dest),
                    "+c" (size),
                    "+S" (src)
                 :  // everything is modified
                 : "memory", "cc");
}

void memset(int* ptr, char8_t value, uint64_t n) {
    asm volatile("cld               \n\t"
                 "rep stosb         \n\t"
                 : "+c"(n), "+D"(ptr)
                 : "a"((unsigned char)value)
                 : "cc", "memory");
}


void memset(int* ptr, char16_t value, uint64_t n) {
    asm volatile("cld               \n\t"
                 "rep stosw         \n\t"
                 : "+c"(n), "+D"(ptr)
                 : "a"(value)
                 : "cc", "memory");
}

int strlen(const char* str) {
    int len = 0;
    while (1) {
        if (str[len] == 0) {
            return len;
        }
        len++;
    }
}

int printf(const char* str, int line) {
    int lenMessage = strlen(str);
    int numberOfLines = ( lenMessage + 79 ) / 80;
    char16_t placeholder = 0x0700;
    if (25 - line >= numberOfLines) {
        memset((int*)(VGA_MEMORY + line*160), placeholder, numberOfLines*80);
        for (int i = 0; i < lenMessage*2; i+=2) {
            VGA_MEMORY[i + line*160] = str[i/2];
            VGA_MEMORY[i + 1 + line*160] = 0x07;
        }
        line += numberOfLines;
    } else {
        int neededLines = (25 - line - numberOfLines) * -1;
        memcpy((int*)(VGA_TMP_BUFFER), (int*)(VGA_MEMORY + neededLines * 160), (25 - neededLines) * 160);
        memcpy((int*)(VGA_MEMORY), (int*)(VGA_TMP_BUFFER), (25 - neededLines) * 160);
        memset((int*)(VGA_MEMORY + (25 - neededLines) * 160), placeholder, neededLines*80);
        for (int i = 0; i < lenMessage*2; i+=2) {
            VGA_MEMORY[(25 - neededLines)*160 + i] = str[i/2];
            VGA_MEMORY[(25 - neededLines)*160 + i + 1] = 0x07;
        }
        line = 25;
    }
    uint32_t index = (line - 1) * 80 + lenMessage;
    setCursorPos(index);
    return line;
}

char* itoa(int number, char* str, int base) {
    int index = 0;
    if (number == 0) {
        str[index] = '0';
        index++;
    } else {
        if (base < 2 || base > 36) {
            // nothing happens.
            // we cannot throw an error as early in the boot process : it would make the hole operating system just crash.
        } else {
            if (number < 0 && base == 10) {
                str[index] = '-';
                index++;
                number = -number;
            }
            static const char digits[] = "0123456789ABCDEFGHIGKLMNOPQRSTUVWXYZ";
            int i = 0;
            int64_t tmp;
            int j = 0;
            while (number > 0) {
                i++;
                int64_t result = number %base;
                number /= base;
                // push the result onto the stack, and pop it later so we can simply & without any heap inverse the results
                asm volatile("pushq %0"
                            :
                            : "r"(result)
                            : "memory"
                );
            }
            for (; j < i; j++) {
                asm volatile("popq %0"
                            : "=r"(tmp)
                            :
                            : "memory"
                );
                str[j + index] = digits[tmp];
            }
            index += j;
        }
    }
    str[index] = 0;
    return str;
}
