# v0.1.0 スコープ定義 — Phase 1: カーネルブートストラップ

> `docs/design/001_os_design.md` の Phase 1 を v0.1.0 として実装する。

## ゴール

**UEFI → ExitBootServices → カーネル起動 → 画面出力**

UEFIベースプログラム（`kernel/boot/`）を土台に、UEFI Boot Servicesを終了してOS側が完全に制御を取得するまでを実現する。

---

## 実装タスク

### 1. ブートローダ改修

**目的:** ExitBootServices呼び出し前に必要な情報をすべて取得・保存する

| タスク | 詳細 | 状態 |
|-------|------|------|
| BootInfo構造体定義 | メモリマップ、フレームバッファ情報、ACPIポインタ等をまとめる構造体 | ❌ |
| メモリマップ保存 | GetMemoryMap → BootInfo に格納 | ❌ |
| GOP情報保存 | FBアドレス、解像度、ストライドを BootInfo に格納 | ❌ |

**新規ファイル:**
- `kernel/boot/boot_info.cm` — BootInfo構造体定義

### 2. ExitBootServices

**目的:** UEFI Boot Servicesを終了し、OS側に制御を完全移行

| タスク | 詳細 | 状態 |
|-------|------|------|
| ExitBootServices呼び出し | Boot Services関数テーブルから呼び出し | ❌ |
| メモリマップキー管理 | ExitBootServices に渡す MapKey の取得と整合性 | ❌ |
| リトライ処理 | MapKeyが古い場合の再取得ループ | ❌ |

> [!CAUTION]
> `ExitBootServices()` 後は ConOut, AllocatePool, GetMemoryMap 等の Boot Services が**一切使用不可**になる。

### 3. GDT設定

**目的:** x86_64 Long Modeのフラットセグメントを設定

| タスク | 詳細 | 状態 |
|-------|------|------|
| GDTテーブル定義 | Nullセグメント + カーネルCS/DS | ❌ |
| GDTR構造体 | ベースアドレス + リミット | ❌ |
| `lgdt` + セグメント再ロード | ASMによるGDT適用 | ❌ |

**新規ファイル:**
- `kernel/boot/gdt.cm` — GDT定義＋ロード

### 4. シリアルコンソール

**目的:** ExitBootServices後のデバッグ出力手段

| タスク | 詳細 | 状態 |
|-------|------|------|
| UART 0x3F8 初期化 | ボーレート設定、FIFO有効化 | ❌ |
| 文字出力 | 1バイト出力関数 | ❌ |
| 文字列出力 | シリアル版 println 相当 | ❌ |

**新規ファイル:**
- `kernel/drivers/serial.cm` — UART ドライバ

### 5. フレームバッファ出力

**目的:** ExitBootServices後の画面出力

| タスク | 詳細 | 状態 |
|-------|------|------|
| FB直接描画 | BootInfoから取得したFBアドレスに直接ピクセル書込み | ❌ |
| カーネルprintk相当 | フォントレンダリング + FB出力 | ❌ |
| 起動メッセージ表示 | 「Cosmos OS v0.1.0 booted successfully」の表示 | ❌ |

**既存活用:**
- `kernel/boot/util/graphics.cm` の描画プリミティブを再利用

---

## v0.1.0 に含めないもの（Phase 2以降）

- IDT設定 / 例外ハンドラ
- PIC/APIC初期化
- 物理/仮想メモリマネージャ
- ページテーブル構築
- ヒープアロケータ
- タスク管理 / スケジューラ
- ユーザモード

---

## ディレクトリ構成（v0.1.0 完成時）

```
kernel/
├── boot/
│   ├── efi_main.cm          # エントリポイント（ExitBootServices含む）
│   ├── boot_info.cm         # [NEW] BootInfo構造体
│   ├── gdt.cm               # [NEW] GDT設定
│   ├── libs/                # UEFI ライブラリ（既存）
│   └── util/                # ユーティリティ（既存）
├── drivers/
│   └── serial.cm            # [NEW] UART ドライバ
└── lib/
    └── print.cm             # [NEW] カーネル printk
```

---

## 完了条件

- [ ] BootInfo構造体にメモリマップ・GOP情報を格納できる
- [ ] ExitBootServicesが正常に完了する
- [ ] GDTが設定され、セグメントレジスタが再ロードされる
- [ ] シリアルコンソール（UART 0x3F8）でデバッグ出力が確認できる
- [ ] ExitBootServices後にフレームバッファに文字列を表示できる
- [ ] QEMUの `-serial mon:stdio` で起動メッセージが出力される
- [ ] README.md が整備されている

---

## マイルストーン

| # | 内容 | 依存 |
|---|------|------|
| M1 | ベースプログラム動作確認（`make run`で既存メニュー起動） | なし |
| M2 | BootInfo構造体 + メモリマップ/GOP情報保存 | M1 |
| M3 | ExitBootServices 実装 | M2 |
| M4 | GDT設定（`lgdt` + セグメントリロード） | M3 |
| M5 | シリアルコンソール（UART出力） | M3 |
| M6 | フレームバッファ直接描画（ExitBootServices後） | M3 |
| M7 | README.md整備、CI確認、v0.1.0 リリース | M4-M6 |
