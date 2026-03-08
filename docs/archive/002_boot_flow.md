# ブートフロー設計

## ブートシーケンス

```
GRUB2 / qemu -kernel (Multiboot2)
    │
    ▼
boot/header.S          [ASM] 32ビット保護モード
    ├── Multiboot2ヘッダ検証
    ├── ページテーブル設定 (0-1GiB アイデンティティマッピング)
    ├── PAE → Long Mode → ページング有効化
    ├── 64ビットGDTロード
    └── start_kernel() 呼出し → Cm言語へ
    │
    ▼
boot/entry.cm          [Cm] start_kernel()
    ├── 001: serial_init()          シリアルコンソール確立
    ├── 002: mb2_parse()            Multiboot2情報解析
    ├── 003: gdt_init()             GDT再設定
    ├── 004: idt_init()             IDT設定 (例外ハンドラ)
    ├── 005: cpu_info()             CPU情報表示
    └── 006: idle loop              hltループ
```

## Multiboot2プロトコル

- GRUB2がMultiboot2ヘッダを検出し32ビットプロテクトモードで起動
- `qemu -kernel`による直接起動をサポート
- メモリマップ、フレームバッファ情報をタグ経由で受領

## メモリレイアウト (Phase 0)

```
0x0000_1000   PML4 ページテーブル
0x0000_2000   PDPT
0x0000_3000   PD (512 × 2MiB = 1GiB)
0x0007_0000   初期スタック (16KiB)
0x0008_0000   GDT テーブル
0x0008_1000   IDT テーブル (256ベクタ × 16B = 4KiB)
0x0010_0000   カーネル .text (1MiB〜)
```
