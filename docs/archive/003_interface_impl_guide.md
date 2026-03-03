# interface/impl 設計ガイド

## 概要

Cosmo Linux では Cm言語の `interface` / `impl` パターンを徹底する。
全デバイスドライバ、サブシステムは interface を通じて抽象化し、
テスト容易性と交換可能性を確保する。

## パターン

### 1. typedef による型安全

```cm
// ulongの直接使用を避け、意味的な型を定義
export typedef IoPort = ulong;
export typedef PhysAddr = ulong;
export typedef AsciiChar = ulong;
```

### 2. interface による抽象化

```cm
// 出力デバイスの共通インターフェース
export interface Writer {
    void putc(AsciiChar ch);
    void puts(void* data);
    void println(void* data);
    void print_hex(ulong value);
}
```

### 3. impl による実装

```cm
// 自身のメソッド
impl SerialPort {
    overload self(IoPort port_addr) {
        self.port = port_addr;
        // 初期化...
    }
    void wait_ready() { ... }
}

// インターフェース実装
impl SerialPort for Writer {
    void putc(AsciiChar ch) {
        self.wait_ready();
        outb(self.port, ch);
    }
    // ...
}
```

## Cosmo Linux で定義するインターフェース

| interface | 用途 | 実装例 |
|-----------|------|--------|
| `Writer` | テキスト出力 | SerialPort, DebugPort |
| `MemoryAllocator` | メモリ割当 | BuddyAllocator, SlabAllocator |
| `BlockDevice` | ブロックI/O | VirtioBlk, AtaDisk |
| `FileSystem` | FS操作 | Ext2, DevFs, ProcFs |
| `Scheduler` | スケジューリング | CFScheduler |
