# Phase 1: メモリ管理設計

## 概要

Linuxカーネルのメモリ管理サブシステムをCmで再実装する。
参照: `linux/mm/`

## コンポーネント

### 1. PMM (Physical Memory Manager) — Buddy System

Multiboot2から受け取ったメモリマップに基づき、4KiBページ単位で物理メモリを管理。
Linux の `struct page` + buddy allocator に相当。

```
オーダー 0:   4KiB (1ページ)
オーダー 1:   8KiB (2ページ)
オーダー 2:  16KiB (4ページ)
...
オーダー 10:  4MiB (1024ページ) — 最大
```

**interface**: `PageAllocator`
- `alloc_pages(order)` → PhysAddr
- `free_pages(addr, order)`

### 2. VMM (Virtual Memory Manager) — 4レベルページング

x86_64の4レベルページテーブル (PML4→PDPT→PD→PT) を管理。
カーネル空間とユーザ空間のマッピングを制御。

**機能**:
- `map_page(virt, phys, flags)` — ページマッピング
- `unmap_page(virt)` — マッピング解除
- カーネル空間: 上位アドレス (0xFFFF8000_00000000〜)

### 3. kmalloc — カーネルヒープ

任意サイズのカーネル内部メモリ割り当て。
サイズクラス別のフリーリスト方式（簡易SLAB）。

**interface**: `Allocator`
- `alloc(size)` → void*
- `free(ptr)`

### 4. ページフォルトハンドラ

IDTベクタ14 (#PF) を改善し、Demand Pagingを実装。

## ファイル構成

```
cosmo-linux/
├── include/
│   ├── page_alloc.cm    # PageAllocator interface
│   └── allocator.cm     # Allocator interface (kmalloc用)
└── mm/
    ├── pmm.cm           # Buddy System PMM
    ├── vmm.cm           # 4レベルページテーブル
    ├── kmalloc.cm        # カーネルヒープ
    └── page_fault.cm    # ページフォルトハンドラ
```
