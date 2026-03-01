# ビルドと実行手順

## 前提条件

- `cm` (Cmコンパイラ) がパスに存在すること
- `nasm` (アセンブラ) がインストール済みであること
- `qemu-system-x86_64` がインストール済みであること
- `ld` (ELF対応リンカ) が利用可能であること

## ビルド

```bash
# カーネルビルド
make -C cosmo-linux

# または統合Makefileから
make cosmo-linux-build
```

## 実行

```bash
# QEMUで実行（シリアルコンソール）
make -C cosmo-linux run

# テスト実行（自動終了、結果検証）
make -C cosmo-linux test
```

## 出力確認

正常起動時、シリアルコンソールに以下が出力される:

```
========================================
  Cosmo Linux v0.1.0
  Written in Cm — A Linux reimagined
========================================

[INFO] start_kernel() entered
[INFO] Parsing Multiboot2 info...
[INFO] GDT initialized
[INFO] IDT initialized
[INFO] Kernel initialization complete
```

## トラブルシューティング

| 症状 | 原因と対処 |
|------|-----------|
| QEMU即座にリセット | Multiboot2ヘッダ不正 → `header.S`のマジック・チェックサム確認 |
| トリプルフォルト | IDT未設定 or GDT不正 → `gdt.cm`/`idt.cm`のアドレス確認 |
| シリアル出力なし | ポートアドレス(0x3F8)かFIFO設定確認 |
