# Bug #6: `stoll: out of range` — 大きな16進リテラル

**修正**: Cm v0.14.1

## 症状（修正前）

`ulong`型に`0x8000000000000000`以上の値を代入すると、コンパイラ内部の
`stoll`（signed long long変換）でオーバーフローエラーが発生。

```cm
ulong val = 0xFE6C6C0000000000;  // ← stoll: out of range
```

## 検証結果

Cm v0.14.1 で JIT / UEFI 共に正常動作を確認。
