# bootzilla
Clonezilla with upgraded boot management capabilities

## Windows
All Windows images must be bootable without an additional boot partition. This allows the grub bootloader to chainload directly into the image partition, avoiding multiple boot menus and allowing the partition to be independently bootable. This can be achieved by installing the Windows bootloader directly to the partition before capturing the image. The following command can be used from any Windows installation (including the target installation) to setup the bootloader: "bcdboot (Target Windows Installation Drive Letter):Windows /s (Target Windows Installation Drive Letter): /f ALL". Note that this command adds all necessary files to the partition to load in EFI (preferred) or Legacy mode. 