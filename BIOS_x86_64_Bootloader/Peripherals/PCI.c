#include <stdint.h>
#include "PCI.h"

static inline void outl(uint16_t port, uint32_t value) {
    asm volatile("outl %0, %w1" : : "a"(value), "Nd"(port));            // output IO
}
static inline uint32_t inl(uint16_t port) {
    uint32_t value;
    asm volatile("inl %w1, %0" : "=a"(value) : "Nd"(port));             // input IO
    return value;
}

static inline uint32_t pci_read32(uint8_t bus, uint8_t slot, uint8_t func, uint8_t offset) {
    uint32_t addr = (1u   << 31)
                  | (bus  << 16)
                  | (slot << 11)
                  | (func <<  8)
                  | (offset & 0xFC);
    outl(0xCF8, addr);
    return inl(0xCFC);
}


int scan_pci_devices(uint32_t* device_IDs_array, int MAX_PCI_DEVICES) {
    int number_of_pci_devices = 0;                                  // if the max number of devices is reached, exit
    int ptr = 0;
    for (uint16_t bus = 0; bus < 256; bus++) {
        for (uint8_t slot = 0; slot < 32; slot++) {
            for (uint8_t func = 0; func < 8; func++) {
                // first check if the max number of devices was reached
                if (number_of_pci_devices >= MAX_PCI_DEVICES) {
                    bus = 512;                                         // to break from the main loop

                    break;                                             // exit the third loop
                }
                // try out with func = 0
                uint32_t value = pci_read32(bus, slot, func, 0x00);
                // now, check if the device exists or not
                if ((value & 0xFFFF) == 0xFFFF) {
                    continue;                                          // the pci device does not exist
                }
                // the pci device exists.
                number_of_pci_devices++;
                device_IDs_array[ptr] = ((uint32_t)bus << 16) | ((uint32_t)slot << 8) | func;
            }
        }
    }
    return number_of_pci_devices;
}
