# Cosmo Linux マイルストーン: 正規Homebrew動作への道

## 現状 (v0.2.0)

| カテゴリ | 実装済み |
|---------|---------| 
| **FS** | RamFS, DevFS, ProcFS, Pipe, VFS, FDテーブル, 9pFS書き込み |
| **Exec** | ELF64パーサ (ET_EXEC + ET_DYN/PIE), PT_LOADローダ, auxv/argc/argv構築 |
| **Syscall** | 90+種 (FS/Net/Signal/Timer/Process/MM) |
| **MM** | Buddy PMM, 4-level VMM, SLAB kmalloc, VMA mmap |
| **Net** | virtio-net, ARP, ICMP ping, DNS解決, UDP, TCP, Socket API, BSD Socket syscall |
| **ストレージ** | 9pFS (virtio-9p, ホストFS共有, 読み書き対応) |
| **パッケージ** | gen (9pFS経由), brew (HTTP経由) |

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

## Milestone 5: マルチプロセス — clone/fork + execve 🔄

bash/busyboxのシェルスクリプト実行に必須のマルチプロセス基盤。

| 項目 | syscall | 状態 |
|------|---------|:----:|
| プロセス複製 | `clone`(56), `fork`(57), `vfork`(58) | ❌ |
| プログラム置換 | `execve`(59) | ❌ |
| 子プロセス待ち改善 | `wait4`(61) 拡張 | ⚠️ |
| プロセスグループ | `setpgid`(109), `getpgid`(121), `setsid`(112) | ❌ |
| I/O多重化 | `select`(23) | ❌ |
| ファイル切り詰め | `ftruncate`(77) | ❌ |

### 達成基準
- `exec busybox sh` でシェルが起動 → コマンド入力 → 子プロセスとして実行
- パイプライン: `echo hello | cat` が動作

---

## Milestone 6: 動的リンカー (PT_INTERP)

glibc/musl動的リンクバイナリの実行に必要。

| 項目 | 内容 |
|------|------|
| ELFローダー | PT_INTERP解析 → インタープリターELFのロード |
| 動的リンカー | `ld-linux-x86-64.so.2` / `ld-musl-x86_64.so.1` |
| 再配置 | GOT/PLT、R_X86_64_*リロケーション処理 |
| mmap拡張 | `MAP_FIXED` サポート |

### 達成基準
- 動的リンクされた `hello` バイナリが実行可能

---

## Milestone 7: Homebrew依存ツールのポート

Homebrew実行に必要なツールチェーンを静的ビルドで導入。

| ツール | 必要バージョン | ビルド方法 |
|--------|:-------------:|------------|
| bash | 5.x+ | musl-static cross-compile |
| Ruby | 2.6+ | Portable Ruby (musl-static) |
| Git | 2.x+ | musl-static cross-compile |
| curl | 7.x+ | musl-static + TLS (mbedtls/bearssl) |
| GCC/make | — | musl-static cross-compile |

### 達成基準
- `ruby --version`, `git --version`, `curl --version` がCosmo上で動作

---

## Milestone 8: 正規Homebrewインストール

公式Homebrewインストールスクリプトの実行。

| 項目 | 内容 |
|------|------|
| インストール | `bash -c "$(curl -fsSL https://...install.sh)"` |
| パッケージ | `brew install hello` → bottles (プリコンパイル済み) |
| procfs拡張 | `/proc/cpuinfo`, `/proc/meminfo` |
| スレッド | `clone` + `futex` 拡張 |

### 達成基準
- `brew install hello && hello` が動作

---

## 次のステップ

**今すぐ**: Milestone 5 (`clone`/`fork` + `execve`) の実装開始
