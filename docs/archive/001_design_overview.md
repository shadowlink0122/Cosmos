# Cosmo Linux 設計概要

## プロジェクト概要

Cosmo Linux は、Cm言語で Linux カーネルの主要サブシステムを再実装した OS。
`torvalds/linux` を設計リファレンスとしてサブモジュールに含み、
QEMU上で動作する自己完結型の Linux 互換 OS を目指す。

## 設計原則

| 原則 | 説明 |
|------|------|
| Cm First | 全コードをCm言語で記述。`__asm__`はハードウェア操作の最小限に |
| interface/impl 徹底 | `interface`で抽象化、`impl`で実装を分離 |
| typedef 型安全 | `typedef`で意味的型エイリアスを定義、生のulongを排除 |
| Linux ABI 互換 | x86_64 Linux syscall ABI に準拠 |
| 段階的開発 | Phase 0→5 の段階的実装 |

## アーキテクチャ

```
┌──────────────────────────────────────────┐
│  User Space (init, sh, coreutils)        │
├──────────── syscall ─────────────────────┤
│  Syscall Dispatch (Linux x86_64 ABI)     │
├──────┬──────┬──────┬─────────────────────┤
│ Sched│  MM  │  VFS │  Net Stack          │
├──────┴──────┴──────┴─────────────────────┤
│  Arch Layer (x86_64: GDT/IDT/Paging)    │
├──────────────────────────────────────────┤
│  Drivers (Serial/KB/PCI/virtio)          │
├──────────────────────────────────────────┤
│  Hardware (QEMU x86_64)                  │
└──────────────────────────────────────────┘
```

## ディレクトリ構造

```
cosmo-linux/
├── docs/           # 番号付き設計文書 (00N_xxx.md)
├── boot/           # ブートローダ + エントリポイント
├── arch/x86_64/    # アーキテクチャ依存コード
├── mm/             # メモリ管理
├── sched/          # プロセス管理・スケジューラ
├── sys/            # syscall
├── fs/             # ファイルシステム
├── drivers/        # デバイスドライバ
├── net/            # ネットワーク
├── lib/            # ユーティリティ
├── include/        # 共有型定義
├── init/           # カーネル初期化
├── Makefile        # ビルドシステム
└── linker.ld       # リンカスクリプト
```
