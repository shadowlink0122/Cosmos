# Cosmo Linux アーキテクチャ設計書

## 概要

Cosmo Linux は Cm 言語で書かれた Linux ライクなカーネルである。
QEMU x86_64 上で動作し、Multiboot1 プロトコルでブートする。

## ディレクトリ構成

```
cosmo-linux/
├── arch/x86_64/     # アーキテクチャ固有 (GDT/IDT/CPU/Context)
├── boot/            # ブートローダ連携 (Multiboot/Entry)
├── drivers/         # デバイスドライバ (Serial/PIT/Keyboard)
├── fs/              # ファイルシステム (RamFs/VFS/FdTable/ProcFs)
├── include/         # 共通型・定数・インターフェース定義
├── init/            # 初期化処理
├── lib/             # ライブラリ (kstring/printk)
├── mm/              # メモリ管理 (PMM/VMM/kmalloc)
├── net/             # ネットワーク (未実装)
├── sched/           # スケジューラ・プロセス管理
├── sys/             # システムコール
└── ui/              # ユーザーインターフェース (Shell/VGA/Keyboard入力)
```

## struct/impl 設計原則

1. **1 struct/impl = 1 ファイル** を原則とする
2. ファイル名は `snake_case.cm` で struct名に対応
3. `include/` 配下にインターフェース（typedef/定数）を定義
4. `export struct` + `impl` でモジュール内 API を公開
5. 互換ラッパーは変換過渡期のみ使用し、最終的には削除

## メモリマップ

| 範囲 | 用途 |
|------|------|
| 0x001000 | PML4 (ページテーブル) |
| 0x010000 | カーネルロード領域 |
| 0x091000 | スケジューラ/プロセスポインタ |
| 0x094000 | シェルコマンドバッファ |
| 0x095000 | シェル状態 (VGA/Serial/履歴/環境変数) |
| 0x099000 | パイプバッファ |
| 0x0B8000 | VGA テキストモードバッファ |
| 0x300000 | プロセステーブル |
| 0x400000 | RamFS inode/direntry/name |
| 0x500000+ | BuddyAllocator 管理領域 |

## 技術的制約

- **utiny\* バグ**: Cm の `utiny*` ポインタ読み取りに問題があるため、バイトアクセスは `__asm__(movzbl)` で代替
- **LLVM memset**: 構造体初期化で LLVM が `memset` C ABI シンボルを直接参照するため、`memset` はフリー関数として維持必須
- **関数ポインタ制約**: IDT 例外ハンドラ、syscall_entry_stub など `as ulong` で関数ポインタ化する関数はモジュールレベル維持
