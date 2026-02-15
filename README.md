# Cosmos OS

> **Cm言語で開発するオペレーティングシステム**

Cosmos は、自作プログラミング言語 [Cm](https://github.com/shadowlink0122/Cm) で一から開発するOSプロジェクトです。
x86_64 UEFI環境で動作し、フレームバッファ描画やシリアルコンソールを備えた独自カーネルを構築しています。

## 現在のバージョン: v0.1.0

### 実装済み機能

- **UEFI ブートローダ** — `efi_main` エントリポイント、Boot Services 活用
- **ExitBootServices** — UEFI Boot Services 終了、リトライ処理付き
- **BootInfo 構造体** — メモリマップ・GOP フレームバッファ情報の収集と引き渡し
- **GDT 設定** — x86_64 Long Mode フラットセグメント（`lgdt` + セグメントリロード）
- **シリアルコンソール** — UART COM1 (0x3F8) 115200 8N1、デバッグ出力
- **フレームバッファコンソール** — 8x16 ビットマップフォントによるテキスト描画
- **グラフィックス描画** — ピクセル、線分、矩形（塗りつぶし含む）、Bresenham アルゴリズム

### ブートフロー

```
UEFI Firmware
  → efi_main (UEFI エントリ)
    → シリアル初期化 (COM1 115200 8N1)
    → GOP 情報収集 (フレームバッファ)
    → メモリマップ取得
    → ExitBootServices
    → kernel_main
      → GDT 設定
      → フレームバッファに起動メッセージ表示
      → HLT ループ
```

## 必要環境

| ツール | 用途 |
|--------|------|
| **Cm コンパイラ** | `--target=uefi` でカーネルをコンパイル |
| **lld-link** | PE/COFF (EFI) リンカ |
| **QEMU** | x86_64 エミュレータ |
| **OVMF** | UEFI ファームウェア（自動ダウンロード） |

## ビルドと実行

```bash
# ビルド（コンパイル + リンク）
make

# QEMU で実行（OVMF自動ダウンロード）
make run

# テスト（QEMU ヘッドレス + デバッグポート）
make test

# シリアル単体テスト
make test-serial

# クリーン
make clean
```

## ディレクトリ構成

```
Cosmos/
├── Cm/                      # サブモジュール（Cmコンパイラ）
├── kernel/
│   ├── efi_main.cm          # UEFIエントリポイント + ExitBootServices
│   ├── boot_info.cm         # BootInfo構造体
│   ├── gdt.cm               # GDT設定
│   ├── drivers/
│   │   ├── serial.cm        # UART シリアルドライバ
│   │   └── debug_port.cm    # QEMU デバッグポートドライバ
│   ├── lib/
│   │   ├── font.cm          # 8x16 ビットマップフォント
│   │   └── print.cm         # フレームバッファ printk
│   ├── libs/                # UEFI プロトコルライブラリ
│   └── util/                # ユーティリティ（グラフィックス等）
├── tests/
│   └── test_serial.cm       # シリアル単体テスト
├── docs/
│   └── design/              # 設計ドキュメント
├── Makefile
└── VERSION
```

## ロードマップ

| バージョン | 内容 | 状態 |
|-----------|------|------|
| **v0.1.0** | カーネルブートストラップ（UEFI→ExitBootServices→GDT→画面出力） | ✅ |
| v0.2.0 | IDT設定・例外ハンドラ・割り込みコントローラ | 📋 |
| v0.3.0 | 物理/仮想メモリ管理・ヒープアロケータ | 📋 |
| v0.4.0 | タスク管理・スケジューラ | 📋 |

## ライセンス

MIT License