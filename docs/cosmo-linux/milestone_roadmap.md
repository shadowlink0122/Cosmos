# Cosmo Linux マイルストーン: パッケージ管理とプログラム実行

## 現状 (v0.2.0)

| カテゴリ | 実装済み |
|---------|---------| 
| **FS** | RamFS, DevFS, ProcFS, Pipe, VFS, FDテーブル |
| **Exec** | ELF64パーサ (ET_EXEC + ET_DYN/PIE), PT_LOADローダ, auxv/argc/argv構築 |
| **Syscall** | 50+種: read/write/open/close/fstat/lseek/stat/openat/newfstatat/readlinkat/faccessat/getdents64/pread64/pwrite64/readv/writev/fcntl/dup/dup2/exit/fork/getpid/getppid/kill/wait4/uname/getcwd/chdir/brk/mmap/munmap/mprotect/pipe/ioctl/access/arch_prctl/set_tid_address/exit_group/clock_gettime/nanosleep/rt_sigaction/rt_sigprocmask/prlimit64/getrandom/getuid/getgid/geteuid/getegid/socket/connect/accept/sendto/recvfrom/bind/listen/setsockopt/getsockopt |
| **MM** | Buddy PMM, 4-level VMM, SLAB kmalloc, VMA mmap |
| **Net** | virtio-net, ARP, ICMP ping, DNS解決, UDP, TCP, Socket API, BSD Socket syscall |
| **ストレージ** | 9pFS (virtio-9p, ホストFS共有) |
| **Brew** | 独自パッケージマネージャ (9pFS経由でホストからELFコピー→exec) |

## ゴール

`cosmo:/$ brew install hello` → パッケージダウンロード → ELF実行

---

## Milestone 1: ホストファイルシステム共有 (virtio-9p) ✅

QEMUの9P/virtio-9pでホストディレクトリをゲストにマウント。

---

## Milestone 2: ABI拡張 — 静的ELF実行 ✅

musl-libc静的リンクバイナリ対応のsyscall + ELFローダー拡張を実装。

### 追加syscall (Phase 1-4)

| カテゴリ | syscall |
|---------|---------|
| **FS基本** | lseek, pread64, pwrite64, readv, dup, fcntl |
| **FS拡張** | openat, newfstatat, readlinkat, faccessat, getdents64 |
| **シグナル** | rt_sigaction, rt_sigprocmask |
| **タイマー** | nanosleep, clock_gettime |
| **プロセス** | getuid/getgid/geteuid/getegid, prlimit64, getrandom |
| **ネットワーク** | socket, connect, bind, listen, accept, sendto, recvfrom, setsockopt, getsockopt |

### ELFローダー強化
- PIE (Position Independent Executable) サポート
- auxv (auxiliary vector) 構築
- argc/argv/envp スタック構築

---

## Milestone 3: TCP/IPスタック — HTTP通信 ✅

パッケージダウンロードにはHTTP(TCP)が必要。

---

## Milestone 4: パッケージマネージャ (brew) ✅

Homebrew風パッケージマネージャ。ホストFSからELFバイナリをインストール。

---

## Milestone 5: シェルスクリプトと応用

| 項目 | 内容 |
|------|------|
| シェルスクリプト実行 (`#!`) | shebang解析 + スクリプト逐次実行 |
| 環境変数の永続化 | `/etc/profile` から読み込み |
| マルチプロセス強化 | `&` バックグラウンド実行 |
| **検証** | `./install.sh` でスクリプト実行 |

---

## 次のステップ

1. musl-libc静的リンクバイナリの実行テスト（hello, busybox等）
2. 既存テストの#GP例外修正
3. 環境変数/PATH対応
