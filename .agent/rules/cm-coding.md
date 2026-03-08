# Cm言語 コーディングルール

## Cm 組み込み型

| 型 | サイズ | 符号 |
|----|--------|------|
| `utiny` | 8bit | 符号なし |
| `tiny` | 8bit | 符号付き |
| `ushort` | 16bit | 符号なし |
| `short` | 16bit | 符号付き |
| `uint` | 32bit | 符号なし |
| `int` | 32bit | 符号付き |
| `ulong` | 64bit | 符号なし |
| `long` | 64bit | 符号付き |

## 型定義（typedef 必須）

生のプリミティブを直接使用せず、**必ず `typedef` で意味的な型を定義**する:

```cm
// ✗ 悪い例
ulong port = 0x3F8;
ulong addr = 0x1000;

// ✓ 良い例
typedef IoPort = ushort;    // I/Oポートは16bit
typedef PhysAddr = ulong;   // 物理アドレスは64bit
typedef AsciiChar = utiny;  // ASCII文字は8bit
IoPort port = 0x3F8 as ushort;
PhysAddr addr = 0x1000;
```

## インターフェース（interface 必須）

デバイスドライバ、サブシステム等は**必ず `interface` で抽象化**する:

```cm
export interface Writer {
    void putc(AsciiChar ch);
    void puts(void* data);
    void println(void* data);
    void print_hex(ulong value);
}
```

## 実装（impl 必須）

構造体のメソッドは `impl` ブロックで定義。インターフェース実装は `impl X for Y`:

```cm
// 固有メソッド
impl SerialPort {
    overload self(IoPort port_addr) { ... }
    void wait_ready() { ... }
}

// インターフェース実装
impl SerialPort for Writer {
    void putc(AsciiChar ch) { ... }
    void puts(void* data) { ... }
}
```

## 命名規約

| 対象 | スタイル | 例 |
|------|---------|---|
| typedef 型名 | PascalCase | `PhysAddr`, `IoPort` |
| struct 名 | PascalCase | `SerialPort`, `BootInfo` |
| interface 名 | PascalCase | `Writer`, `Allocator` |
| 関数名 | snake_case | `serial_init`, `gdt_init` |
| 定数 | UPPER_SNAKE_CASE | `COM1`, `PAGE_SIZE` |
| 変数名 | snake_case | `boot_info`, `entry_size` |

## ファイル構成

- `//! platform: baremetal` を全 `.cm` ファイル先頭に記述
- `import` でモジュール参照（グローバル変数を避ける）
- `export` で公開API、内部関数は非export
- 1ファイル300行目安（超える場合は分割検討）

## ASM使用ルール

- `__asm__` はハードウェア操作の**最小限**に留める
- I/O操作（`outb`/`inb`）等のラッパー関数を作り、呼び出し側は直接ASMを書かない
- レジスタ変数バインド: `${r:変数名}` (入力), `${=r:変数名}` (出力)

## 禁止事項

- `ulong` を型宣言なしで公開APIの引数に使用
- `interface` なしのドライバ実装
- `impl` なしの構造体メソッド直接定義
- マジックナンバー（定数定義を使用）
