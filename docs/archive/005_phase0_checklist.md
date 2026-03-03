# Phase 0 実装チェックリスト

## Phase 0: ブート〜シリアル出力

- [x] `boot/header.S` — Multiboot2 + Long Mode遷移
- [x] `include/types.cm` — typedef型定義
- [x] `include/errno.cm` — エラーコード定数
- [x] `include/config.cm` — カーネル設定定数
- [x] `include/writer.cm` — Writer interface
- [x] `drivers/serial.cm` — SerialPort + DebugPort (impl Writer)
- [x] `lib/string.cm` — memcpy/memset/strlen
- [x] `lib/printk.cm` — printk (Writer使用)
- [x] `arch/x86_64/cpu.cm` — CPUID, MSR, I/O
- [x] `arch/x86_64/gdt.cm` — GDT初期化
- [x] `arch/x86_64/idt.cm` — IDT + 例外ハンドラ
- [x] `boot/multiboot2.cm` — MB2情報パーサ
- [x] `boot/entry.cm` — start_kernel()
- [x] `linker.ld` — リンカスクリプト
- [x] `Makefile` — ビルドシステム
- [ ] QEMUでブートテスト実施

## Phase 1: メモリ管理 (予定)
- [ ] Buddy System PMM
- [ ] SLAB カーネルアロケータ
- [ ] ページフォルトハンドラ
