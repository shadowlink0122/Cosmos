/* Cosmo Linux ユーザープログラム リンカスクリプト
 * ユーザー空間ELF用 (0x400000〜)
 * 参照: linux/scripts/ld/x86_64.lds
 */

ENTRY(_start)

SECTIONS
{
    . = 0x400000;

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

    __data_end = .;

    /DISCARD/ :
    {
        *(.comment)
        *(.note.*)
        *(.eh_frame*)
        *(.pdata)
        *(.xdata)
    }
}
