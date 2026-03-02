# Phase 3: VFS (Virtual File System) 設計

## 概要

Linux VFSアーキテクチャを参考に、ファイルシステム抽象化レイヤを実装する。
初期ファイルシステムとして ramfs（メモリ上FS）を採用。
参照: `linux/fs/`, `linux/include/linux/fs.h`

## アーキテクチャ

```
┌──────────────────────────────────────┐
│  Shell (cat, ls, write, touch)       │
├──────────── syscall ─────────────────┤
│  VFS Layer (open/read/write/close)   │
├──────────────────────────────────────┤
│  FD Table (fd → inode+offset)        │
├──────────────────────────────────────┤
│  ramfs (inode + direntry + data)     │
├──────────────────────────────────────┤
│  PMM (データページ確保用)             │
└──────────────────────────────────────┘
```

## コンポーネント

### 1. VFS interface (`include/vfs.cm`)

ファイルシステム共通の構造体定義:
- `Inode` — ino, mode, size, nlink, data_addr
- `DirEntry` — name, ino, entry_type
- `FileDesc` — ino, offset, flags, fs_type

### 2. ramfs (`fs/ramfs.cm`)

メモリ上ファイルシステム:
- inodeテーブル（128エントリ）
- ディレクトリテーブル（64エントリ）
- ファイルデータ: 各4KiB (PMMから1ページ確保)

### 3. FDテーブル (`fs/fd_table.cm`)

ファイルディスクリプタ管理:
- 16エントリ固定
- fd 0/1/2 はstdin/stdout/stderr予約

### 4. VFS コア (`fs/vfs.cm`)

公開API: `vfs_open`, `vfs_read`, `vfs_write`, `vfs_close`, `vfs_readdir`

## ファイル構成

```
cosmo-linux/
├── include/
│   └── vfs.cm          # VFS構造体 + 定数
└── fs/
    ├── vfs.cm          # VFSコア（公開API）
    ├── ramfs.cm        # ramfs実装
    └── fd_table.cm     # FDテーブル管理
```
