; =============================================================================
; Cosmo Linux - Multiboot2 ブートヘッダ + Long Mode 遷移
;
; GRUB2/qemuがMultiboot2ヘッダを検出 → 32bit保護モード → 64bit Long Mode
; → Cm言語の start_kernel() を呼び出す。
;
; 参照: linux/arch/x86/boot/header.S
; =============================================================================

bits 32

; =============================================================================
; Multiboot2 ヘッダ
; =============================================================================
section .multiboot_header
align 8

header_start:
    dd 0xE85250D6                 ; Multiboot2 マジック
    dd 0                          ; アーキテクチャ: i386
    dd header_end - header_start  ; ヘッダ長
    dd -(0xE85250D6 + 0 + (header_end - header_start)) ; チェックサム

    ; フレームバッファ要求タグ（オプション）
    align 8
    dw 5                          ; タグ: フレームバッファ
    dw 1                          ; フラグ: optional
    dd 20                         ; サイズ
    dd 0                          ; 幅: 自動
    dd 0                          ; 高さ: 自動
    dd 32                         ; BPP: 32

    ; 終端タグ
    align 8
    dw 0
    dw 0
    dd 8
header_end:

; =============================================================================
; エントリポイント
; =============================================================================
section .text
global _start
extern start_kernel

_start:
    cli

    ; Multiboot2情報を保存
    mov edi, ebx                  ; RDI = MB2 info
    mov esi, eax                  ; RSI = MB2 magic

    ; ページテーブル初期化 (0-1GiB アイデンティティマッピング)
    ; PML4[0] → PDPT
    mov eax, 0x2000
    or eax, 0x03
    mov [0x1000], eax

    ; PDPT[0] → PD
    mov eax, 0x3000
    or eax, 0x03
    mov [0x2000], eax

    ; PD: 512 × 2MiB ページ
    mov ecx, 0
    mov eax, 0x83                 ; Present + Write + 2MiB
.fill_pd:
    mov [0x3000 + ecx * 8], eax
    add eax, 0x200000
    inc ecx
    cmp ecx, 512
    jne .fill_pd

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
    movzx rdi, edi                ; MB2 info (32→64bit)
    movzx rsi, esi                ; MB2 magic
    call start_kernel

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
