---
name: kernel-debug
description: カーネルデバッグ・例外調査スキル
---

# カーネルデバッグスキル

QEMU上でのカーネル例外、ブート失敗、シリアル出力異常を調査するスキル。

## デバッグ用QEMU起動

### GDBデバッグ
```bash
# ターミナル1: GDBサーバ付きQEMU起動
qemu-system-x86_64 \
  -kernel .tmp/cosmo-linux.elf \
  -m 256M -smp 1 -serial stdio -display none \
  -no-reboot -S -gdb tcp::1234

# ターミナル2: GDB接続
gdb .tmp/cosmo-linux.elf
> target remote :1234
> break start_kernel
> continue
```

### QEMU高度なログ
```bash
# 割り込みログ
qemu-system-x86_64 \
  -kernel .tmp/cosmo-linux.elf \
  -m 256M -smp 1 -serial stdio -display none \
  -d int,cpu_reset -D .tmp/qemu.log \
  -no-reboot
```

## 問題切り分けフロー

```
ブート失敗?
├── QEMU即終了 → Multiboot2ヘッダ確認
├── トリプルフォルト → GDT/IDT確認
│   ├── GDTアドレス・エントリ確認
│   └── IDTアドレス・ハンドラ確認
├── シリアル出力なし → COM1初期化確認
│   ├── outb/inb動作確認
│   └── FIFO/ボーレート確認
└── 例外発生 → CR2/エラーコード確認
    ├── #PF → ページテーブル確認
    ├── #GP → セグメント/特権確認
    └── #DE → ゼロ除算箇所特定
```

## バグ記録テンプレート

バグ発見時は `docs/00N_bug_<概要>.md` を作成:

```markdown
# Bug: <概要>

## 再現手順
1. `make test`
2. シリアルログを確認

## 期待される動作
<期待される出力>

## 実際の動作
<実際の出力/例外>

## 原因
<原因分析>

## 修正
<修正内容>

## 確認
<テスト結果>
```
