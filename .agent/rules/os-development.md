# OS開発ルール

## プロジェクト目標

**Cm言語で Linux カーネルサブシステムを再実装したOS「Cosmo Linux」を開発する**

## 設計原則

| 原則 | 説明 |
|------|------|
| Cm First | 全コードをCm言語で記述。ASMは最小限 |
| interface/impl 徹底 | デバイスドライバ・サブシステムは interface で抽象化 |
| typedef 型安全 | 意味的型エイリアスで生の ulong を排除 |
| Linux ABI 互換 | x86_64 Linux syscall ABI に準拠 |
| 段階的開発 | Phase 0→5 の段階的実装 |

## ディレクトリ構造

```

├── docs/           # 番号付き設計文書 (00N_xxx.md)
├── boot/           # ブートローダ + エントリポイント
├── arch/x86_64/    # アーキテクチャ依存コード
├── mm/             # メモリ管理
├── sched/          # プロセス管理
├── sys/            # syscall
├── fs/             # ファイルシステム
├── drivers/        # デバイスドライバ
├── lib/            # ユーティリティ
├── include/        # 共有型定義・interface
└── Makefile
```

## ドキュメント管理

### 00N_ プレフィックスルール
すべての設計・確認ドキュメントに **`00N_` プレフィックス**を付ける:
```
001_design_overview.md       # 設計概要
002_boot_flow.md             # ブートフロー
003_interface_impl_guide.md  # interface/impl ガイド
004_build_and_run.md         # ビルド手順
005_phase0_checklist.md      # チェックリスト
006_bug_xxxxx.md             # バグ記録
```

### バグ記録
バグ発見時は**必ず** `docs/` に `00N_bug_<概要>.md` を作成:
- 再現手順
- 原因分析
- 修正内容
- 確認方法

## interface 一覧（成長中）

| interface | 用途 | ファイル |
|-----------|------|---------|
| `Writer` | テキスト出力 | `include/writer.cm` |
| `Allocator` | メモリ割当 | `include/allocator.cm` (Phase 1) |
| `BlockDevice` | ブロックI/O | `include/block_device.cm` (Phase 3) |
| `FileSystem` | FS操作 | `include/filesystem.cm` (Phase 3) |

## ビルド・テスト

```bash
make          # ビルド
make run      # QEMU起動
make test     # テスト（自動検証）
```
