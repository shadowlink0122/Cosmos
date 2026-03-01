# Bug #2: `ushort*` / `uint*` デリファレンス非対応

**修正**: Cm v0.2.0

## 症状

`ushort*` や `uint*` 型のポインタをデリファレンスすると、コンパイルエラー
「Cannot dereference non-pointer」が発生。

```cm
ushort* ptr = addr as ushort*;
ulong val = *ptr as ulong;  // error: Cannot dereference non-pointer
```

## 回避策（修正前の対処法）

インラインASMでバイト単位の読み書きを行う。
