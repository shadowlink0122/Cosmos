# Cm コンパイラ バグレポート (UEFI開発で発見)

## 報告日: 2026-02-15

## バグ1: `__asm__` 出力変数の while 条件不具合（重大）

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
// byte_val == 0 のとき、ループが停止すべきだが停止しない
while (byte_val != 0) {
    outb(0xE9, byte_val);  // NULバイト(0x00)が出力される→値は0
    ...
    __asm__(`... movq %rax, ${=r:byte_val}`);
}
```

### 症状
- `byte_val`は0に更新されている（port 0xE9にNULバイト出力で確認）
- しかし`while (byte_val != 0)`の条件が`false`にならずループ継続
- NUL終端文字列の読み取りが停止せず、.rdataセクション全体を出力

### 回避策
```cm
// while(true) + if + break パターンを使うと正常動作する
while (true) {
    ulong byte_val = 0;  // ループ内でのスコープ宣言
    __asm__(`... movq %rax, ${=r:byte_val}`);
    if (byte_val == 0) {
        break;
    }
    outb(0xE9, byte_val);
}
```

### 推定原因
コンパイラがASM出力変数の更新をwhile条件の再評価に伝播できていない。
定数畳み込みまたはSSA最適化の不具合。`if(var == 0) break`では正しく評価される。

---

## バグ2: 整数リテラル型推論の不具合

### 概要
`ulong`コンテキストで使用される整数リテラルが`i32`として型推論され、
LLVM IRレベルで型不一致エラーが発生する。

### 再現コード
```cm
ulong value = some_value;
ulong mask = 15;           // i32として推論される
ulong result = value & mask;  // LLVM: "and i64 %val, i32 15" → エラー
```

### LLVM IRエラー
```
Both operands to a binary operator are not of the same type!
  %bitand = and i64 %load22, i32 15
```

### 回避策
```cm
ulong mask = 15 as ulong;  // 明示的キャスト
```

---

## バグ3: `must { __asm__() }` の制御フロー干渉

### 概要
`must { }` ブロックで `__asm__` をラップすると、
ASM出力変数や周囲の制御フローに悪影響を与える。

### 症状
- `must`内の`__asm__`出力変数がスコープ外で期待どおりに動作しない
- `while(true) { must { __asm__("hlt"); } }` がhaltループから脱出する

### 回避策
```cm
// ❌ 使用禁止
must { __asm__("hlt"); }

// ✅ mustなしで直接使用
__asm__("hlt");
```

---

## 影響範囲とテスト環境

- **Cmバージョン**: 最新（2026-02-15時点）
- **ターゲット**: `--target=uefi` (x86_64)
- **LLVM**: lld-link使用
- **OS**: macOS
- **全バグの影響**: UEFIブートローダーの動作不良（メモリマップ取得不能、ExitBootServices失敗、haltループ脱出）
