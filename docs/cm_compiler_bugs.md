# Cm コンパイラ — UEFI開発で発見された問題点と回避策

> Cosmos OS開発中に発見されたCmコンパイラの制約・バグとその回避策をまとめたドキュメント。
> 対象: `--target=uefi` (x86_64)、macOS環境

---

## 1. `__asm__` 出力変数の while 条件不具合（重大）

### 概要
`__asm__`の出力制約（`${=r:var}`）で更新された変数を`while(var != 0)`の条件で使用すると、
変数が0に更新されてもループが停止しない。

### 再現コード
```cm
ulong byte_val = 0;
__asm__(`
    movq ${r:addr}, %r10;
    xorq %rax, %rax;
    movzbl (%r10), %eax;
    movq %rax, ${=r:byte_val}
`);
while (byte_val != 0) {   // ← byte_val == 0 でもループ継続
    outb(0xE9, byte_val);
    __asm__(`... movq %rax, ${=r:byte_val}`);
}
```

### 推定原因
定数畳み込みまたはSSA最適化がASM出力変数の更新をwhile条件の再評価に伝播していない。

### 回避策
```cm
while (true) {
    ulong byte_val = 0;  // ループ内でスコープ宣言
    __asm__(`... movq %rax, ${=r:byte_val}`);
    if (byte_val == 0) { break; }
    outb(0xE9, byte_val);
}
```

---

## 2. 整数リテラル型推論の不具合

### 概要
`ulong`コンテキストで使用される小さい整数リテラル（`0xFF`、`1`、`15`等）が`i32`として型推論され、
LLVM IRレベルで型不一致エラーが発生する。

### 再現コード
```cm
ulong packed = some_value;
ulong byte_val = (packed >> shift) & 0xFF;  // ← 0xFF が i32 扱い
ulong mask = 1 << bit_pos;                  // ← 1 が i32 扱い
```

### エラーメッセージ
```
Both operands to a binary operator are not of the same type!
  %bitand = and i64 %load, i32 255
```

### 回避策
```cm
ulong mask_ff = 0xFF as ulong;
ulong byte_val = (packed >> shift) & mask_ff;

ulong one = 1 as ulong;
ulong mask = one << bit_pos;
```

---

## 3. `stoll: out of range` — 大きな16進リテラル

### 概要
`ulong`型に`0x8000000000000000`以上の値を代入すると、コンパイラ内部の`stoll`（signed long long変換）でオーバーフローエラーが発生する。

### 再現コード
```cm
ulong val = 0xFE6C6C0000000000;  // ← stoll: out of range
```

### 回避策
ビット演算で構築する:
```cm
// 0xFE6C6C0000000000 を回避
ulong val = (0x7E6C6C0000000000) | (0x0080000000000000 << 1);
```
または、上位ビットが立たない値に設計を変更する。

---

## 4. `must { __asm__() }` の制御フロー干渉

### 概要
`must { }` ブロックで `__asm__` をラップすると、ASM出力変数や周囲の制御フローに悪影響を与える。

### 症状
- `must`内の`__asm__`出力変数がスコープ外で正常に動作しない
- `while(true) { must { __asm__("hlt"); } }` がhaltループから脱出する

### 回避策
```cm
// ✅ mustなしで直接使用
__asm__("hlt");
```

---

## 5. const式でのI/Oポート計算

### 概要
`const`定数を使った加算式が関数引数で正しく評価されない場合がある。

### 再現コード
```cm
const ulong COM1_PORT = 0x3F8;
const ulong REG_IER = 1;
outb(COM1_PORT + REG_IER, 0x00);  // 期待: 0x3F9、実際: 不定
```

### 回避策
```cm
outb(0x3F9, 0x00);  // リテラル値を直接使用
```

---

## 7. ローカル配列とポインタ変数のスタックオフセット重複（重大）

### 概要
ローカル配列（例: `ulong[3] gdt;`）とそのアドレスを格納する変数（例: `void* gdt_raw = &gdt as void*;`）が同一スタックオフセットに配置される。

### 症状
配列の最終要素が上書きされ、GDT等のテーブルが破壊。x86_64ではトリプルフォルト再起動ループ。

### 回避策
ASM内で直接スタック上にテーブルを構築し、ローカル配列+ポインタ変数の組み合わせを避ける。

### 発見日
2026-02-16

---

## 影響範囲

| 項目 | 値 |
|-----|-----|
| **Cmバージョン** | 最新（2026-02-16時点） |
| **ターゲット** | `--target=uefi` (x86_64 PE/COFF) |
| **リンカ** | lld-link |
| **OS** | macOS (Apple Silicon) |
| **影響** | ブートローダー動作不良、GDTクラッシュ、フォントレンダリング失敗、コンパイルエラー |

