# CosmOS アーキテクチャ設計

> 全てCm言語で書かれた軽量オペレーティングシステム

## 設計理念

| 原則 | 説明 |
|------|------|
| **Pure Cm** | カーネルからユーザランドまで全てCm言語で実装。外部C依存ゼロ |
| **軽量** | 最小限のカーネルフットプリント。メモリ効率を最優先 |
| **段階的進化** | モノリシック → マイクロカーネル → ハイブリッドへの自然な移行 |
| **自己ホスト** | 将来的にCosmOS上でCmコンパイラを動作させ、OS自身をビルド |

## アーキテクチャ概要

```mermaid
graph TB
    subgraph "User Space (将来)"
        APP["Cm Applications"]
        GUI["Window Manager"]
        FS_SRV["FS Server"]
    end

    subgraph "Kernel Space"
        SHELL["Shell / CLI"]
        LOADER["CosmEXE Loader"]
        SYSCALL["Syscall Layer (int 0x80)"]
        COSMFS["CosmFS (in-memory)"]
        SCHED["Scheduler"]
        MM["Memory Manager"]
        subgraph "Hardware Abstraction"
            IDT["IDT / ISR"]
            PIC["PIC"]
            PIT["PIT Timer"]
            KBD["PS/2 Keyboard"]
            FB["Framebuffer"]
            SERIAL["Serial (COM1)"]
        end
        GDT["GDT / TSS"]
    end

    subgraph "Firmware"
        UEFI["UEFI Boot"]
    end

    APP --> SYSCALL
    GUI --> SYSCALL
    FS_SRV --> SYSCALL
    SHELL --> LOADER
    SHELL --> COSMFS
    SYSCALL --> FB
    LOADER --> MM
    SCHED --> PIT
    KBD --> IDT
    PIT --> IDT
    IDT --> PIC
    UEFI --> GDT
```

## ブートフロー

```
UEFI Firmware
  → efi_main
    → シリアル初期化 (COM1 115200 8N1)
    → GOP/メモリマップ取得
    → ExitBootServices
    → kernel_main
      → GDT/TSS設定
      → PIC初期化 → IDT/ISR登録
      → PMM初期化 (ビットマップ) → ページング有効化
      → ヒープ初期化
      → PIT (100Hz) → スケジューラ起動 → 割り込み有効化
      → PS/2キーボード初期化
      → Syscallハンドラ登録 (vector 0x80)
      → CosmFS初期化 → initramfs展開
      → シェル起動 → アイドルループ
```

## メモリレイアウト

| アドレス | 用途 | サイズ |
|---------|------|--------|
| `0x000–0x0FF` | GDT/セグメント | 256B |
| `0x100–0x8FF` | IDT テーブル | 2KB |
| `0x900–0xBFF` | スケジューラ/PMM状態 | 768B |
| `0xC00–0xCFF` | キーボードバッファ | 256B |
| `0xD00–0xDFF` | シェル/リカバリ状態 | 256B |
| `0xE00–0xFFF` | FBConsole状態/Usermode | 512B |
| `0x1000–0x1FFF` | TCB配列 | 4KB |
| `0x3000–0x37FF` | IPCメッセージキュー | 2KB |
| `0x3800–0x383F` | IPC通知ビットマスク | 64B |
| `0x7E00000+` | PMM ビットマップ | 動的 |
| `0x7E01000+` | カーネルヒープ | 256KB |

## CosmEXE バイナリ形式

CosmOSの実行バイナリ形式。PEセクションをVAオフセットに配置し、RIPリレーティブアドレッシングを保持。

```
Offset  Size  Field
0x00    8B    Magic: "CosmEXE\0"
0x08    8B    Entry offset (コード先頭からの相対)
0x10    8B    Code size
0x18    8B    Flags (予約)
0x20    ...   Flat binary (VA配置済みセクション)
```

## Syscall ABI

| レジスタ | 用途 |
|---------|------|
| `RAX` | syscall番号 / 戻り値 |
| `RDI` | 第1引数 |
| `RSI` | 第2引数 |
| `RDX` | 第3引数 |

### 基本 I/O (0-9)

| 番号 | 名前 | 説明 |
|------|------|------|
| `0` | `SYS_EXIT` | `exit(code)` |
| `1` | `SYS_WRITE` | `write(fd, buf, len)` |
| `2` | `SYS_READ` | `read(fd, buf, len)` |
| `3` | `SYS_OPEN` | `open(path, flags)` |
| `4` | `SYS_CLOSE` | `close(fd)` |
| `5` | `SYS_STAT` | `stat(path, buf)` |

### 画面 I/O (10-19)

| 番号 | 名前 | 説明 |
|------|------|------|
| `10` | `SYS_SCREEN_CLEAR` | 画面クリア |
| `11-18` | `SYS_SCREEN_*` | putc/puts/color/cursor/newline/print |

### ファイルシステム (20-29)

| 番号 | 名前 | 説明 |
|------|------|------|
| `20-25` | `SYS_FS_*` | open/read/write/create/size/memcpy |

### プロセス管理 (30-39)

| 番号 | 名前 | 説明 |
|------|------|------|
| `30` | `SYS_SPAWN` | `spawn(entry)` → pid |
| `31` | `SYS_KILL` | `kill(pid)` |
| `34` | `SYS_WAIT` | `wait(pid)` → exit_code |
| `35` | `SYS_GETPID` | `getpid()` → pid |

### メモリ管理 (40-49)

| 番号 | 名前 | 説明 |
|------|------|------|
| `40` | `SYS_SBRK` | `sbrk(increment)` → addr |
| `45` | `SYS_MMAP` | `mmap(addr, len, prot)` → addr |
| `46` | `SYS_MUNMAP` | `munmap(addr, len)` |

### IPC メッセージパッシング (50-59)

| 番号 | 名前 | 説明 |
|------|------|------|
| `50` | `SYS_SEND` | `send(pid, type, arg0, arg1)` |
| `51` | `SYS_RECV` | `recv(pid_filter)` → msg |
| `52` | `SYS_REPLY` | `reply(pid, result)` |
| `53` | `SYS_NOTIFY` | `notify(pid, bits)` |
| `54` | `SYS_GET_NOTIFY` | `get_notify()` → bits |
| `55` | `SYS_PIPE` | `pipe(fds)` |
| `56` | `SYS_DUP2` | `dup2(old, new)` → fd |

## マイクロカーネル設計

### カーネルコア（Ring 0）

```mermaid
graph TB
    subgraph "Kernel Core"
        SCHED["Scheduler"]
        MM["Memory Manager"]
        IPC["IPC Message Passing"]
        INT["Interrupt Handler"]
    end
    subgraph "User Servers (将来)"
        FS_SRV["FS Server"]
        SCREEN_SRV["Screen Server"]
        NET_SRV["Network Server"]
    end
    subgraph "User Applications"
        APP1["App 1"]
        APP2["App 2"]
    end
    APP1 -->|send/recv| IPC
    APP2 -->|send/recv| IPC
    IPC -->|dispatch| FS_SRV
    IPC -->|dispatch| SCREEN_SRV
    FS_SRV -->|syscall| MM
```

### IPC メッセージ構造

```
64バイト固定メッセージ:
  sender(8) | receiver(8) | type(8) | arg0(8) | arg1(8) | arg2(8) | arg3(8) | status(8)
```

## Cm言語固有の設計考慮

### 利点
- **`__asm__`**: GDT/IDT/CR3操作、コンテキストスイッチを直接記述
- **型安全性**: ポインタ操作を含む低レベルコードでもCmの型システムが有効
- **`no_std`**: ランタイム依存排除の純粋ベアメタルコード
- **PE/COFF出力**: UEFIとの直接互換性

### 制約と対策
| 制約 | 対策 |
|------|------|
| Cmプロローグ自動生成 | iretq前に固定メモリ経由でRSP復元 |
| グローバル変数制限 | 固定メモリアドレスマップ方式 |
| 浮動小数点 | カーネル内ではFPU無効化 |

## 参考資料

- [OSDev Wiki](https://wiki.osdev.org/) — OS開発百科事典
- [Writing an OS in Rust](https://os.phil-opp.com/) — UEFIベースOS開発
- Intel SDM — x86_64アーキテクチャリファレンス
- UEFI Specification — ExitBootServices等のAPI仕様
