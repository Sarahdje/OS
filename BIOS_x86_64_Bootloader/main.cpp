// this is the file reponsible to scan the differents disks and parse the ext2 partition in order to load the kernel
// the function C_main is directly called by the Assembly code and launched in long mode

#include "Peripherals/PCI.h"

#define MAX_PCI_DEVICES 512                     // the max of PCI devices supported by this bootloader
pci_device* PCI_DEVICES = (pci_device*)0x100000;// we'll write all the PCI devices metadata right in this array -- hard coded adress right after the VGA memory
uint32_t* PCI_FOUND_DEVICES = (uint32_t*)(0x100000 + sizeof(pci_device)* MAX_PCI_DEVICES);     // and we'll store the device IDs in this array right here. as always, hard coded adress -- no malloc or smart memory management yet!

extern "C" void C_main() {
    // now, we first need to scan all the peripherals to find the different disks connected via USB, SATA or IDE
    // we don't need to parse the AML tables just yet -- the operating system will do it later on
    // first : enumerate the PCI devices
    auto number_of_found_pci_devices = scan_pci_devices(PCI_FOUND_DEVICES, MAX_PCI_DEVICES);   // now, the number of found pci devices is contained in this variable. we'll use it later on.
    if (number_of_found_pci_devices > 0) {
        asm volatile("hlt");
    }
    asm volatile("hlt");
}
