# Cosmo Linux — 現状と機能一覧

> 更新日: 2026-03-04

## 概要

**Cosmo Linux** はCm言語で書かれた自作OS。x86_64アーキテクチャ上でMultiboot2ブートし、
VGA・シリアル・キーボード・ネットワーク・9p共有FS等のドライバを搭載し、
プリエンプティブマルチタスクと50種以上のLinux互換syscallでユーザープロセスを実行する。

**最新成果**: BusyBox v1.35.0（musl-libc静的リンク）の実行に成功。

---

## アーキテクチャ

```
┌──────────────────────────────────────────────────┐
│                Shell (VGA + Serial)              │
├──────────────────────────────────────────────────┤
│   exec (ELF)  │  syscall (50+)  │  scheduler    │
├───────────────┼─────────────────┼───────────────┤
│  VFS (RamFS / DevFS / ProcFS / 9pFS / Pipe)     │
├──────────────────────────────────────────────────┤
│  MM (Buddy PMM / 4-Level VMM / SLAB / mmap)     │
├──────────────────────────────────────────────────┤
│  Net (Ethernet / IP / ICMP / UDP / TCP / DNS)    │
├──────────────────────────────────────────────────┤
│  Drivers (PCI / virtio-net / virtio-9p / PIT)    │
├──────────────────────────────────────────────────┤
│  arch/x86_64 (IDT / GDT / TSS / Paging / CPU)   │
└──────────────────────────────────────────────────┘
```

---

## サブシステム別実装状況

### boot / arch

| コンポーネント | 状態 | 説明 |
|-------------|:---:|------|
| Multiboot2ヘッダ | ✅ | header.S + entry.cm |
| GDT (Ring 0/3) | ✅ | カーネル/ユーザーCS/DS + TSS |
| IDT (割り込み) | ✅ | タイマー/キーボード/PF/GP/DF ハンドラ |
| 4-Level Paging | ✅ | PML4→PDPT→PD→PT、ユーザー空間マッピング |
| TSS (Ring切替) | ✅ | RSP0カーネルスタック設定 |
| syscall/sysret | ✅ | LSTAR MSR、Ring3←→Ring0遷移 |

### ドライバ (drivers/)

| ドライバ | 状態 | 説明 |
|---------|:---:|------|
| Serial (COM1) | ✅ | デバッグ出力、ログ |
| PS/2 Keyboard | ✅ | スキャンコード→ASCII変換 |
| PIT (タイマー) | ✅ | 10ms周期割り込み、uptime計測 |
| PCI バス | ✅ | デバイス検出、BAR読み取り |
| virtio-net | ✅ | パケット送受信、MAC取得 |
| virtio-9p | ✅ | ホストFSマウント、ファイルR/W |

### ファイルシステム (fs/)

| FS | 状態 | 説明 |
|----|:---:|------|
| VFS | ✅ | 統一I/Fレイヤ |
| RamFS | ✅ | インメモリFS (create/read/write/unlink) |
| DevFS | ✅ | /dev/null, /dev/zero, /dev/urandom |
| ProcFS | ✅ | /proc/self/maps 等 |
| 9pFS | ✅ | /mnt/host → ホストディレクトリ共有 |
| Pipe | ✅ | プロセス間パイプ通信 |
| FDテーブル | ✅ | ファイルディスクリプタ管理 |

### メモリ管理 (mm/)

| コンポーネント | 状態 | 説明 |
|-------------|:---:|------|
| Buddy PMM | ✅ | 物理ページアロケータ |
| 4-Level VMM | ✅ | 仮想アドレスマッピング |
| SLAB kmalloc | ✅ | カーネルヒープ |
| VMA mmap | ✅ | ユーザー空間メモリマッピング |
| Page Fault | ✅ | TSS RSP0ベースフレーム解析 |

### ネットワーク (net/)

| プロトコル | 状態 | 説明 |
|-----------|:---:|------|
| Ethernet | ✅ | フレーム送受信 |
| ARP | ✅ | アドレス解決、キャッシュ |
| IPv4 | ✅ | パケットルーティング |
| ICMP | ✅ | ping送受信 |
| UDP | ✅ | データグラム通信 |
| TCP | ✅ | 3-way handshake、FIN |
| DNS | ✅ | A/AAAAレコード解決 |
| HTTP | ✅ | GET/POST クライアント |
| HTTP Server | ✅ | 簡易Webサーバ |
| BSD Socket API | ✅ | socket/connect/bind/listen/accept |
| Loopback | ✅ | ループバックインターフェース |

### プロセス管理 (sched/)

| 機能 | 状態 | 説明 |
|------|:---:|------|
| Process構造体 | ✅ | PID/状態/スタック/ページテーブル |
| プリエンプティブスケジューラ | ✅ | ラウンドロビン、タイムスライス |
| コンテキストスイッチ | ✅ | callee-saved + カーネルスタック切替 |
| fork / wait4 | ✅ | 子プロセス生成・終了待ち |
| Signal (SIGTERM/SIGKILL) | ✅ | シグナル送信・処理 |

### ELFローダ (exec/)

| 機能 | 状態 | 説明 |
|------|:---:|------|
| ELF64パーサ | ✅ | ヘッダ/PHDRバリデーション |
| ET_EXEC ロード | ✅ | 固定アドレスバイナリ |
| ET_DYN/PIE ロード | ✅ | PIC実行ファイル |
| PT_LOAD マッピング | ✅ | TEXT/DATAセグメント |
| auxv構築 | ✅ | AT_PAGESZ/AT_RANDOM/AT_PHDR等 |
| argc/argv/envp | ✅ | Linux ABI準拠スタック |

---

## syscall一覧 (50種以上)

### ファイル / I/O

| nr | syscall | 状態 | 備考 |
|----|---------|:---:|------|
| 0 | read | ✅ | fd/devfs/pipe/ramfs |
| 1 | write | ✅ | stdout/stderr→シリアル、fd |
| 2 | open | ✅ | RamFS/DevFS |
| 3 | close | ✅ | FD解放 |
| 5 | fstat | ✅ | ファイル情報 |
| 8 | lseek | ✅ | オフセット変更 |
| 16 | ioctl | ✅ | TIOCGWINSZ等 |
| 17 | pread64 | ✅ | |
| 18 | pwrite64 | ✅ | |
| 19 | readv | ✅ | scatter read |
| 20 | writev | ✅ | gather write |
| 21 | access | ⚠️ | -ENOENT固定 |
| 22 | pipe | ✅ | |
| 32 | dup | ✅ | |
| 33 | dup2 | ✅ | |
| 72 | fcntl | ✅ | F_GETFD/SETFD |
| 257 | openat | ✅ | AT_FDCWD対応 |
| 262 | newfstatat | ✅ | |
| 267 | readlinkat | ✅ | /proc/self/exe |
| 269 | faccessat | ✅ | |
| 217 | getdents64 | ✅ | ディレクトリ読み込み |

### メモリ

| nr | syscall | 状態 |
|----|---------|:---:|
| 9 | mmap | ✅ |
| 10 | mprotect | ✅ |
| 11 | munmap | ✅ |
| 12 | brk | ✅ |

### プロセス

| nr | syscall | 状態 |
|----|---------|:---:|
| 39 | getpid | ✅ |
| 60 | exit | ✅ |
| 61 | wait4 | ✅ |
| 62 | kill | ✅ |
| 63 | uname | ✅ |
| 79 | getcwd | ✅ |
| 80 | chdir | ✅ |
| 102 | getuid | ✅ |
| 104 | getgid | ✅ |
| 107 | geteuid | ✅ |
| 108 | getegid | ✅ |
| 110 | getppid | ✅ |
| 158 | arch_prctl | ✅ |
| 218 | set_tid_address | ✅ |
| 228 | clock_gettime | ✅ |
| 231 | exit_group | ✅ |
| 302 | prlimit64 | ✅ |
| 318 | getrandom | ✅ |

### シグナル

| nr | syscall | 状態 |
|----|---------|:---:|
| 13 | rt_sigaction | ✅ |
| 14 | rt_sigprocmask | ✅ |

### タイマー

| nr | syscall | 状態 |
|----|---------|:---:|
| 35 | nanosleep | ✅ |

### ネットワーク

| nr | syscall | 状態 |
|----|---------|:---:|
| 41 | socket | ✅ |
| 42 | connect | ✅ |
| 43 | accept | ✅ |
| 44 | sendto | ✅ |
| 45 | recvfrom | ✅ |
| 49 | bind | ✅ |
| 50 | listen | ✅ |
| 54 | setsockopt | ✅ |
| 55 | getsockopt | ✅ |

---

## シェルコマンド (30種以上)

| カテゴリ | コマンド |
|---------|---------|
| **システム** | `help` `ps` `free` `uname` `uptime` `vmstat` `date` `clear` `reboot` |
| **ファイル** | `ls` `cat` `touch` `write` `echo` `rm` `mkdir` `cp` `mv` `wc` `tail` `hexdump` |
| **プロセス** | `exec` `kill` `sleep` |
| **ネットワーク** | `ping` `curl` `wget` `httpd` |
| **パッケージ** | `brew install/list/search/run` |
| **その他** | `env` `export` `cd` `pwd` `test` パイプ(`|`) Tab補完 コマンド履歴 |

---

## 動作確認済みプログラム

| プログラム | バージョン | リンク方式 | 状態 |
|-----------|-----------|-----------|:---:|
| hello (自作テスト) | - | musl static | ✅ |
| BusyBox | v1.35.0 | musl static | ✅ |

---

## 既知の制限

- **単一CPU**: SMP未対応
- **ストレージ**: ブロックデバイス/永続FSなし（RamFSのみ）
- **ユーザー空間**: シングルアドレス空間（全プロセス共有ページテーブル）
- **スレッド**: 未対応（clone/pthread未実装）
- **動的リンク**: 未対応（ld-linux.so未実装）
- **MMU保護**: ユーザー空間の完全な分離は未完成
- **FS**: 書き込みは9pFS経由では未対応（読み取り専用）

---

## QEMU起動方法

```bash
# ビルド
cd cosmo-linux
../Cm/cm compile --target=baremetal-x86 -o ../.tmp/cosmo-linux/kernel.o boot/entry.cm
x86_64-elf-ld -T linker.ld -nostdlib -static -z noexecstack \
  -o ../.tmp/cosmo-linux/cosmo-linux64.elf ../.tmp/cosmo-linux/header.o ../.tmp/cosmo-linux/kernel.o
x86_64-elf-objcopy -O elf32-i386 ../.tmp/cosmo-linux/cosmo-linux64.elf ../.tmp/cosmo-linux/cosmo-linux.elf

# 実行
qemu-system-x86_64 \
  -kernel ../.tmp/cosmo-linux/cosmo-linux.elf \
  -m 256M -smp 1 \
  -serial stdio \
  -virtfs local,path=./rootfs,mount_tag=host,security_model=none,id=host0 \
  -nic user,model=virtio-net-pci
```

---

## 次のステップ

1. **BusyBox完全動作**: 追加syscall実装（mmap拡張、sigaction等）
2. **Cmコンパイラ互換**: Cosmo Linux上でCmコンパイラを実行
3. **パッケージ管理**: `brew`コマンドでgit, clang等のツールをインストール
4. **プロセス分離**: 独立アドレス空間の実装
5. **スレッド**: clone + futex実装
