; =============================================================================
; Cosmo Linux - Multiboot1 ブートヘッダ + Long Mode 遷移
;
; QEMUが直接 -kernel でロード可能なMultiboot1形式。
; 32bit保護モード → 64bit Long Mode → Cm言語の main() を呼び出す。
;
; 参照: linux/arch/x86/boot/header.S
; =============================================================================

bits 32

; =============================================================================
; Multiboot1 ヘッダ
; =============================================================================
section .multiboot_header
align 4

MULTIBOOT_MAGIC   equ 0x1BADB002
; ビット0: アラインメント, ビット1: メモリ情報要求
MULTIBOOT_FLAGS   equ 0x03
MULTIBOOT_CHECKSUM equ -(MULTIBOOT_MAGIC + MULTIBOOT_FLAGS)

header_start:
    dd MULTIBOOT_MAGIC
    dd MULTIBOOT_FLAGS
    dd MULTIBOOT_CHECKSUM
header_end:

; =============================================================================
; エントリポイント
; =============================================================================
section .text
global _start
extern main

_start:
    cli

    ; Multiboot1情報を保存
    ; EAX = マジック (0x2BADB002), EBX = Multiboot info構造体ポインタ
    mov edi, ebx                  ; RDI = MB info
    mov esi, eax                  ; RSI = MB magic

    ; ページテーブル初期化 (0-4GiB アイデンティティマッピング)
    ; フレームバッファ (0xFD000000) をカバーするため 4GiB 必要
    ;
    ; メモリレイアウト:
    ;   0x1000: PML4
    ;   0x2000: PDPT
    ;   0x3000: PD0 (0-1GiB)
    ;   0x4000: PD1 (1-2GiB)
    ;   0x5000: PD2 (2-3GiB)
    ;   0x6000: PD3 (3-4GiB)

    ; PML4[0] → PDPT
    mov eax, 0x2000
    or eax, 0x03
    mov [0x1000], eax

    ; PDPT[0] → PD0 (0-1GiB)
    mov eax, 0x3000
    or eax, 0x03
    mov [0x2000], eax

    ; PDPT[1] → PD1 (1-2GiB)
    mov eax, 0x4000
    or eax, 0x03
    mov [0x2008], eax

    ; PDPT[2] → PD2 (2-3GiB)
    mov eax, 0x5000
    or eax, 0x03
    mov [0x2010], eax

    ; PDPT[3] → PD3 (3-4GiB)
    mov eax, 0x6000
    or eax, 0x03
    mov [0x2018], eax

    ; PD0: 512 × 2MiB ページ (0x00000000 - 0x3FFFFFFF)
    mov ecx, 0
    mov eax, 0x83                 ; Present + Write + 2MiB
.fill_pd0:
    mov [0x3000 + ecx * 8], eax
    add eax, 0x200000
    inc ecx
    cmp ecx, 512
    jne .fill_pd0

    ; PD1: 512 × 2MiB ページ (0x40000000 - 0x7FFFFFFF)
    mov ecx, 0
    mov eax, 0x40000083           ; 1GiB + Present + Write + 2MiB
.fill_pd1:
    mov [0x4000 + ecx * 8], eax
    add eax, 0x200000
    inc ecx
    cmp ecx, 512
    jne .fill_pd1

    ; PD2: 512 × 2MiB ページ (0x80000000 - 0xBFFFFFFF)
    mov ecx, 0
    mov eax, 0x80000083           ; 2GiB + Present + Write + 2MiB
.fill_pd2:
    mov [0x5000 + ecx * 8], eax
    add eax, 0x200000
    inc ecx
    cmp ecx, 512
    jne .fill_pd2

    ; PD3: 512 × 2MiB ページ (0xC0000000 - 0xFFFFFFFF)
    mov ecx, 0
    mov eax, 0xC0000083           ; 3GiB + Present + Write + 2MiB
.fill_pd3:
    mov [0x6000 + ecx * 8], eax
    add eax, 0x200000
    inc ecx
    cmp ecx, 512
    jne .fill_pd3

    ; CR3 ← PML4
    mov eax, 0x1000
    mov cr3, eax

    ; PAE有効化
    mov eax, cr4
    or eax, (1 << 5)
    mov cr4, eax

    ; Long Mode有効化 (EFER.LME)
    mov ecx, 0xC0000080
    rdmsr
    or eax, (1 << 8)
    wrmsr

    ; ページング有効化
    mov eax, cr0
    or eax, (1 << 31)
    mov cr0, eax

    ; 64ビットGDTロード → far jump
    lgdt [gdt64_ptr]
    jmp 0x08:long_mode_entry

; =============================================================================
; 64ビット GDT（最小構成）
; =============================================================================
section .rodata
align 16

gdt64:
    dq 0                                                    ; NULL
    dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53)      ; Code64
    dq (1 << 41) | (1 << 44) | (1 << 47)                   ; Data64
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dq gdt64

; =============================================================================
; 64ビット Long Mode エントリ
; =============================================================================
section .text
bits 64

long_mode_entry:
    ; セグメントレジスタ設定
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; スタック初期化
    mov rsp, stack_top

    ; Cm エントリ呼出し
    movzx rdi, edi                ; MB info (32→64bit)
    movzx rsi, esi                ; MB magic
    call main

.halt:
    hlt
    jmp .halt

; =============================================================================
; 初期スタック (16KiB)
; =============================================================================
section .bss
align 16

stack_bottom:
    resb 16384
stack_top:
