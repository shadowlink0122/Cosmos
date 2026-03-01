# Bug #3: `self` コピー問題（構造体メソッド）

**修正**: Cm v0.2.0

## 症状

`impl` ブロックのメソッド内で `self` はコピーとして渡され、
`self.field -= 1` などの変更は呼び出し元の構造体に反映されない。

```cm
impl PMM {
    ulong alloc_page() {
        self.free_pages -= 1;  // コピーのみ変更、元の構造体は不変
        return page_idx << PAGE_SHIFT;
    }
}
```

> [!WARNING]
> v0.2.0で修正されたのは**ローカル変数への1段メソッド呼出し**のみ。
> ポインタ経由（`ptr->method()`）でのself書き戻しは依然として未修正。
> → [Bug #10 (workaround)](../workaround/bug10_impl_self.md)
