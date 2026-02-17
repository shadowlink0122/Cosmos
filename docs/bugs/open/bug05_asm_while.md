# Bug #5: `__asm__` 出力変数の while 条件不具合

> Cm v0.14.1 / `--target=uefi` (x86_64) / 2026-02-16発見

**重要度**: 重大

## 症状

`__asm__`の出力制約（`${=r:var}`）で更新された変数を`while(var != 0)`の条件で使用すると、
変数が0に更新されてもループが停止しない。

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

## 推定原因

定数畳み込みまたはSSA最適化がASM出力変数の更新をwhile条件の再評価に伝播していない。

## 回避策

```cm
while (true) {
    ulong byte_val = 0;  // ループ内でスコープ宣言
    __asm__(`... movq %rax, ${=r:byte_val}`);
    if (byte_val == 0) { break; }
    outb(0xE9, byte_val);
}
```
