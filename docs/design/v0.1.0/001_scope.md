# CosmOS v0.1.0 (Foundation) — 設計と実装記録

> v0.1.0は当初Phase 1（ブートストラップ）のみの計画だったが、
> Phase 3（タスク管理）+ファイルシステム+アプリ基盤まで一気に実装した。

## 実装フェーズ一覧

| # | 旧バージョン | 内容 | 状態 |
|---|------------|------|------|
| 1 | v0.1.0 | UEFIブート・GDT・シリアル・フレームバッファ | ✅ |
| 2 | v0.2.0 | IDT・ISR・PIC | ✅ |
| 3 | v0.3.0 | PMM・ページング・ヒープ | ✅ |
| 4 | v0.4.0 | PIT・TCB・コンテキストスイッチ・スケジューラ | ✅ |
| 5 | v0.5.0 | TSS・キーボード・プリエンプティブスケジューリング・シェル | ✅ |
| 6 | v0.7.0 | CosmFS・Aria・CosmEXEローダー・Syscall | ✅ |

---

## Phase 1: カーネルブートストラップ

**ゴール**: UEFI → ExitBootServices → カーネル起動 → 画面出力

| コンポーネント | 詳細 | ファイル |
|-------------|------|---------|
| BootInfo構造体 | メモリマップ・GOP情報の引き渡し | `efi_main.cm` |
| ExitBootServices | Boot Services終了、リトライ処理 | `efi_main.cm` |
| GDT | フラットセグメント + `lgdt` + セグメントリロード | `arch/gdt.cm` |
| シリアルコンソール | UART COM1 (0x3F8) 115200 8N1 | `drivers/serial.cm` |
| フレームバッファ | GOP FBに8x16フォントで描画 | `lib/print.cm`, `lib/font.cm` |

---

## Phase 2: 割り込み基盤

**ゴール**: CPU例外の捕捉、ハードウェア割り込み処理

| コンポーネント | 詳細 | ファイル |
|-------------|------|---------|
| IDT | 256エントリ、16B Gate Descriptor | `arch/idt.cm` |
| ISR (0-31) | 例外ハンドラ、エラーコード対応、リカバリ機構 | `arch/isr.cm` |
| PIC 8259A | ICW1-4初期化、IRQ→ベクタ32-47リマップ | `drivers/pic.cm` |

**割り込みフレーム (Ring0→Ring0)**:
```
[RSP+16] RFLAGS
[RSP+8]  CS
[RSP]    RIP
(エラーコードがある場合はさらにpush)
```

---

## Phase 3: メモリ管理

**ゴール**: 物理/仮想メモリ管理 + カーネルヒープ

| コンポーネント | 方式 | ファイル |
|-------------|------|---------|
| PMM | ビットマップ方式 (1bit=4KBページ) | `mm/pmm.cm` |
| VMM | UEFI CR3継承 (アイデンティティマップ) | `mm/vmm.cm` |
| Heap | Bump Allocator (alloc/free対応) | `mm/heap.cm` |

**UEFIメモリマップ**: Type 7 (`EfiConventionalMemory`) をOS利用可能領域として解析。

---

## Phase 4: タスク管理

**ゴール**: マルチタスク (カーネルスレッド)

| コンポーネント | 詳細 | ファイル |
|-------------|------|---------|
| PIT | 8254 Channel 0, 100Hz Rate Generator | `drivers/pit.cm` |
| TCB | タスクID、状態、RSP、スタック | `sched/task.cm` |
| コンテキストスイッチ | ASM push/pop + RSP切替 | `sched/context.cm` |
| スケジューラ | ラウンドロビン、タイムスライス10tick | `sched/scheduler.cm` |

---

## Phase 5: 入力とシェル

**ゴール**: 対話的カーネルシェル

| コンポーネント | 詳細 | ファイル |
|-------------|------|---------|
| PS/2キーボード | IRQ1、スキャンコード→ASCII、リングバッファ | `drivers/keyboard.cm` |
| TSS | 104B構造体、RSP0設定、`ltr` | `arch/gdt.cm` |
| シェル | コマンド入力ループ、履歴、カーソル編集 | `shell/shell.cm` |
| 組込みコマンド | ps, mem, uptime, clear, env | `apps/` |

---

## Phase 6: ファイルシステム・アプリ基盤

**ゴール**: ファイル操作 + テキストエディタ + 外部バイナリ実行

### CosmFS (インメモリファイルシステム)

| 項目 | 値 |
|------|-----|
| ブロックサイズ | 4KB |
| 最大ファイル数 | 256 |
| ファイル名最大長 | 56B |
| API | create, read, write, delete, stat, mkdir |

ファイル: `fs/cosmfs.cm`, `fs/initramfs.cm`, `fs/path.cm`

### Aria テキストエディタ 🎵

- **モーダル**: Normal / Insert / Command (vim準拠)
- **操作**: h/j/k/l移動、i挿入、:w保存、:q終了
- ファイル: `apps/aria/aria.cm`

### CosmEXEローダー + Syscall

- **CosmEXE形式**: 32Bヘッダ + VA配置フラットバイナリ
- **Syscall**: `int 0x80` (RAX=番号, RDI/RSI/RDX=引数)
- **ビルド**: `pe2cosmexe.py`でPEから直接生成
- ファイル: `sys/loader.cm`, `sys/syscall.cm`

### シェルコマンド (19コマンド)

```
help, ps, mem, uptime, clear, env,
ls, touch, cat, rm, write, append, mkdir, cp, mv,
aria, cm, a.out
```

---

## 技術的知見

### Cmコンパイラのバグ回避パターン

| # | 問題 | 回避策 |
|---|------|-------|
| 1 | `__asm__`出力変数のwhile条件問題 | ポインタ経由書き込み |
| 2 | 整数リテラル型推論 | `as ulong`キャスト |
| 7 | ローカル配列+ポインタ変数 | ASM直接構築 |
| 8 | インライン展開レジスタ割当変更 | `${r:varname}`入力変数構文 |
| 9 | インライン展開ret先不在 | ラベルアドレス明示push |

### iretqスタック問題

Cm関数のプロローグ(`push rsi; push rdi; sub rsp,$0xa8`)が自動生成されるため、`iretq`前に固定メモリ(`0xDA0`)経由でRSPを巻き戻す必要がある。

### PEセクションVA配置

`objcopy -O binary`はPEのセクションをVAオフセットに配置しない。`.text`→`.rdata`のVAギャップ(0x1000)とファイルギャップ(0x600)の不一致でRIPリレーティブが壊れる。`pe2cosmexe.py`で正しくVA配置。
