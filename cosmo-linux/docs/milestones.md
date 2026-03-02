# Cosmo Linux マイルストーン

## 完了済み

### v0.0.1 — カーネルブートストラップ
- [x] Multiboot1 ブート
- [x] GDT/IDT セットアップ
- [x] シリアルコンソール
- [x] PMM (Buddy System)
- [x] VMM (4-level paging)
- [x] kmalloc (SLAB-like)

### v0.0.2 — マルチタスクとUI
- [x] PIC/PIT タイマー
- [x] ラウンドロビンスケジューラ
- [x] コンテキストスイッチ
- [x] VGA テキストモード
- [x] PS/2 キーボードドライバ
- [x] 対話的シェル

### v0.0.3 — ファイルシステムとシェル拡張
- [x] RamFS (メモリ上FS)
- [x] VFS レイヤー
- [x] FD テーブル
- [x] ProcFS (/proc)
- [x] シェルコマンド 28個
- [x] Tab補完、履歴、パイプ

### v0.0.4 — struct/impl リファクタリング (完了)
- [x] 全モジュール struct/impl 化 (Batch 1-4)
- [x] 互換ラッパー整備

---

## 計画中

### v0.0.5 — ファイル分割リファクタリング
- [x] shell.cm を 9ファイルに分割 (1 struct/impl = 1ファイル)
- [x] 各 struct/impl を独立ファイルに

### v0.0.6 — シグナルとプロセス拡張
- [x] シグナルインフラ (SIGKILL/SIGTERM/SIGINT)
- [x] プロセスライフサイクル (do_exit/do_wait/find_by_pid)
- [x] syscall追加 (getppid/kill/wait4)
- [x] kill コマンド

### v0.0.7 — ページフォルト対応と仮想メモリ拡張
- [x] Demand Paging (VMA連携)
- [x] mmap/munmap syscall (匿名マッピング)
- [x] brk syscall (ヒープ管理)
- [x] vmstat コマンド

---

## 計画中

### v0.0.8 — DevFS + パイプ + I/Oリダイレクト
- [ ] /dev/null, /dev/zero, /dev/random
- [ ] DevFS 実装
- [ ] pipe() syscall
- [ ] dup2() syscall

### v0.1.0 — ELF ローダーとユーザー空間
- [ ] ELF64 バイナリパーサ
- [ ] ユーザー空間プロセス実行
- [ ] Ring 3 遷移
- [ ] ユーザースタック/カーネルスタック分離
