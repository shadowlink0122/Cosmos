/* Cosmo Linux リンカスクリプト
 * 1MiBベース（Multiboot2仕様）
 * 参照: linux/arch/x86/kernel/vmlinux.lds.S
 */

ENTRY(_start)

SECTIONS
{
    . = 1M;

    .multiboot_header :
    {
        *(.multiboot_header)
    }

    .text ALIGN(4K) :
    {
        *(.text)
        *(.text.*)
    }

    .rodata ALIGN(4K) :
    {
        *(.rodata)
        *(.rodata.*)
    }

    .data ALIGN(4K) :
    {
        *(.data)
        *(.data.*)
    }

    .bss ALIGN(4K) :
    {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        __bss_end = .;
    }

    __kernel_end = .;

    /DISCARD/ :
    {
        *(.comment)
        *(.note.*)
    }
}
