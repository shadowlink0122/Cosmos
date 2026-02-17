# Bug #4: 整数リテラルが `i32` に推論される

**修正**: Cm v0.2.0

## 症状

`ulong` 変数と整数リテラルの二項演算で、リテラルが `i32` に推論され、
LLVM IR生成時に型不一致エラーが発生。

```cm
ulong new_read = (read_idx + 1) & 63;
// error: Both operands to a binary operator are not of the same type!
//   %bitand = and i64 %load11, i32 63
```

## 回避策（修正前の対処法）

```cm
ulong ring_mask = 63 as ulong;
ulong new_read = (read_idx + 1) & ring_mask;
```
