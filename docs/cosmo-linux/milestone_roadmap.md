# Cosmo Linux マイルストーン: 正規Homebrew動作への道

## 現状 (v0.3.0)

| カテゴリ | 実装済み |
|---------|---------|
| **FS** | RamFS, DevFS, ProcFS, Pipe, VFS, FDテーブル, 9pFS書き込み |
| **Exec** | ELF64パーサ (ET_EXEC + ET_DYN/PIE), PT_LOADローダ, auxv/argc/argv構築, shebang (#!) 対応 |
| **Syscall** | 110+種 (FS/Net/Signal/Timer/Process/MM) |
| **MM** | Buddy PMM, 4-level VMM, SLAB kmalloc, VMA mmap |
| **Net** | virtio-net, ARP, ICMP ping, DNS解決, UDP, TCP, Socket API, BSD Socket syscall |
| **ストレージ** | 9pFS (virtio-9p, ホストFS共有, 読み書き対応) |
| **パッケージ** | gen (9pFS経由), brew (HTTP経由) |
| **ツール** | bash 5.2.37, Git 2.47.1, Ruby 3.4.2, curl 8.11.1 (全てmusl静的ビルド) |

## ゴール

`cosmo:/$ brew install hello` → 正規Homebrewでパッケージ管理

---

## Milestone 1: ホストファイルシステム共有 (virtio-9p) ✅

QEMUの9P/virtio-9pでホストディレクトリをゲストにマウント。

---

## Milestone 2: ABI拡張 — 静的ELF実行 ✅

musl-libc静的リンクバイナリ対応のsyscall + ELFローダー拡張を実装。

---

## Milestone 3: TCP/IPスタック — HTTP通信 ✅

パッケージダウンロードにはHTTP(TCP)が必要。

---

## Milestone 4: パッケージマネージャ (brew/gen) + 9pFS書き込み ✅

ホストFSからELFバイナリをインストール + 9pFSへの書き込みサポート。

---

## Milestone 5: マルチプロセス — clone/fork + execve ✅

bash/busyboxのシェルスクリプト実行に必須のマルチプロセス基盤。

| 項目 | syscall | 状態 |
|------|---------|:----:|
| プロセス複製 | `clone`(56), `fork`(57), `vfork`(58) | ✅ |
| プログラム置換 | `execve`(59) | ✅ |
| 子プロセス待ち | `wait4`(61) | ✅ |
| プロセスグループ | `setpgid`(109), `getpgid`(121), `setsid`(112) | ✅ |
| I/O多重化 | `select`(23), `poll`(7), `epoll` | ✅ |
| ファイル切り詰め | `ftruncate`(77) | ✅ |

---

## Milestone 6: 動的リンカー (PT_INTERP) ✅

glibc/musl動的リンクバイナリの実行に必要。

| 項目 | 状態 |
|------|:----:|
| ELFローダー PT_INTERP解析 | ✅ |
| インタープリターELFロード | ✅ |
| auxv (AT_BASE, AT_ENTRY, AT_EXECFN) | ✅ |

---

## Milestone 7: Homebrew依存ツールのポート ✅

Homebrew実行に必要なツールチェーンを静的ビルドで導入。

| ツール | バージョン | サイズ | 状態 |
|--------|:----------:|:------:|:----:|
| bash | 5.2.37 | 1.1MB | ✅ |
| Ruby | 3.4.2 | 3.4MB | ✅ |
| Git | 2.47.1 | 3.8MB | ✅ |
| curl | 8.11.1 | — | ✅ |

### Dockerfileビルド
```bash
# bash
docker build --platform linux/amd64 -f Dockerfile.bash -t cosmo-bash .
# Git
docker build --platform linux/amd64 -f Dockerfile.git -t cosmo-git .
# Ruby
docker build --platform linux/amd64 -f Dockerfile.ruby -t cosmo-ruby .
```

---

## Milestone 8: 正規Homebrewインストール 🔄

公式Homebrewインストールスクリプトの実行。

| 項目 | 内容 | 状態 |
|------|------|:----:|
| Shebang (#!) 対応 | execveでスクリプト実行 | ✅ |
| 依存ツール静的ビルド | bash/Git/Ruby/curl | ✅ |
| Homebrew環境構築 | リポジトリ配置・PATH設定 | 🔄 |
| procfs拡張 | `/proc/cpuinfo`, `/proc/meminfo` | ❌ |
| スレッド | `clone` + `futex` 拡張 | ⚠️ |

### 達成基準
- `brew install hello && hello` が動作

---

## Milestone 9: syscall拡張 (Homebrew完全対応) ✅

bash/Git/Ruby実行に必要な追加syscall。

| syscall | 番号 | 用途 |
|---------|:----:|------|
| rt_sigreturn | 15 | シグナルハンドラ復帰 |
| getdents | 78 | ディレクトリ読み取り (旧API) |
| setitimer/getitimer | 38/36 | タイマー |
| alarm | 37 | アラーム |
| flock | 73 | ファイルロック |
| chmod/chown/lchown | 90/92/94 | パーミッション |
| rename | 82 | ファイル名変更 |
| sendmsg/recvmsg | 46/47 | ソケットメッセージ (stub) |
| get/setgroups | 115/116 | グループ操作 |
| setuid/setgid | 105/106 | UID/GID設定 |
| getsid | 124 | セッションID |
| mincore | 27 | メモリ状態 |
| clock_getres | 229 | クロック解像度 |

---

## 次のステップ

**今すぐ**: Milestone 8 — Homebrewリポジトリの構造整備とインストーラテスト
