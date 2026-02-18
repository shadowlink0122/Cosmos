# CosmOS

> **全てCm言語で書かれた軽量オペレーティングシステム**

CosmOS は、自作プログラミング言語 [Cm](https://github.com/shadowlink0122/Cm) で一から開発するOSプロジェクトです。
x86_64 UEFI環境で動作し、カーネルからユーザランドまで**外部C依存ゼロ**で構築しています。

## コンセプト

- **Pure Cm** — カーネル、シェル、アプリケーション全てがCm言語
- **軽量** — 最小限のメモリフットプリント、不要な抽象化を排除
- **段階的進化** — モノリシック → マイクロカーネルへの自然な移行設計

## 現在のバージョン: v0.1.0 (Foundation)

### 主要機能

| カテゴリ | 機能 |
|---------|------|
| **ブート** | UEFIブートローダ、ExitBootServices、GDT/TSS |
| **割り込み** | IDT/ISR (例外0-31)、PIC、リカバリ機構 |
| **メモリ** | PMM (ビットマップ)、ページング、ヒープ (256KB) |
| **タスク** | PIT (100Hz)、ラウンドロビンスケジューラ |
| **ドライバ** | PS/2キーボード、フレームバッファコンソール、シリアル (COM1) |
| **ファイルシステム** | CosmFS (インメモリ)、initramfs、パス解析 |
| **シェル** | 19コマンド、コマンド履歴、カーソル編集 |
| **アプリ実行** | CosmEXEローダ、Syscall (int 0x80) |
| **その他** | 環境変数、Ariaテキストエディタ |

### シェルコマンド

```
CosmOS > help
Available commands:
  help            - Show this help
  ps              - List tasks
  mem             - Show memory usage
  uptime          - Show system uptime
  clear           - Clear screen
  env             - Show environment
  ls              - List files
  touch <name>    - Create file
  cat <name>      - Show file
  rm <name>       - Delete file
  write <n> <d>   - Write to file
  append <n> <d>  - Append to file
  mkdir <name>    - Create directory
  cp <src> <dst>  - Copy file
  mv <src> <dst>  - Move/rename file
  aria <file>     - Text editor
  cm <file>       - Compile .cm file
  a.out           - Run compiled program
```

## ロードマップ

| バージョン | コードネーム | 内容 | 状態 |
|-----------|------------|------|------|
| **v0.1.0** | **Foundation** | カーネル基盤 + シェル + CosmFS | 🚧 |
| v0.2.0 | Isolation | ユーザモード + プロセス分離 | 📋 |
| v0.3.0 | Storage | ディスクI/O + 永続FS | 📋 |
| v0.4.0 | Network | ネットワークスタック | 📋 |
| v0.5.0 | Canvas | GUI + ウィンドウマネージャ | 📋 |
| v1.0.0 | Horizon | 自己ホスト (CosmOS上でCmコンパイル) | 🌟 |

詳細は [docs/ROADMAP.md](docs/ROADMAP.md) を参照。

## 必要環境

| ツール | 用途 |
|--------|------|
| **Cm コンパイラ** | `--target=uefi` でカーネルをコンパイル |
| **lld-link** | PE/COFF (EFI) リンカ |
| **QEMU** | x86_64 エミュレータ |
| **OVMF** | UEFI ファームウェア（自動ダウンロード） |

## ビルドと実行

```bash
# ビルド（カーネル + helpアプリ）
make

# QEMU で実行
make run

# テスト（QEMU ヘッドレス）
make test

# クリーン
make clean
```

## ディレクトリ構成

```
Cosmos/
├── Cm/                          # Cmコンパイラ（サブモジュール）
├── kernel/
│   ├── efi_main.cm              # UEFIエントリ + カーネルメイン
│   ├── config.cm                # 固定メモリアドレスマップ
│   ├── arch/                    # IDT, ISR, GDT
│   ├── mm/                      # PMM, VMM, ヒープ
│   ├── sched/                   # スケジューラ, タスク管理
│   ├── drivers/                 # キーボード, PIT, シリアル
│   ├── fs/                      # CosmFS, initramfs, パス解析
│   ├── sys/                     # Syscall, ローダー, 環境変数
│   ├── shell/                   # シェル本体
│   ├── apps/                    # アプリケーション
│   │   ├── help/                # helpコマンド (CosmEXE)
│   │   ├── libcosm/             # ユーザランドライブラリ
│   │   └── ...                  # ps, mem, fs, aria等
│   ├── lib/                     # フォント, 出力
│   └── tests/                   # ユニット/統合テスト
├── scripts/                     # ビルドスクリプト
├── docs/
│   ├── ROADMAP.md               # ロードマップ
│   └── design/                  # 設計ドキュメント
├── Makefile
└── VERSION
```

## ドキュメント

- [ロードマップ](docs/ROADMAP.md) — v0.1.0〜v1.0.0の計画
- [アーキテクチャ設計](docs/design/os_design.md) — カーネル設計、メモリレイアウト、Syscall ABI

## ライセンス

MIT License