# Bug #11: インライン展開によるASMレジスタ割当変更

> Cm v0.14.1 / `--target=uefi` (x86_64) / 2026-02-16発見

**重要度**: 重大

## 症状

`__asm__` 内で `%rdi` や `%rsi` を直接参照してSystem V ABIのパラメータレジスタを
前提にすると、インライン展開された場合にパラメータがスタック上のローカル変数や
別のレジスタに配置されるため、不正な動作になる。

- コンテキストスイッチ関数 `switch_to(old_rsp, new_rsp)` が `%rdi`/`%rsi` を使用
- 単体テストでは動作するが、`schedule()` にインライン展開されると `%rdi`/`%rsi` に
  無関係な値が入り、#GP や #UD 例外が発生

## 回避策

`${r:varname}` 入力変数構文を使用してCmの変数をASMレジスタにバインドする:

```cm
export void switch_to(ulong old_rsp_ptr, ulong new_rsp) {
    __asm__(`
        movq ${r:old_rsp_ptr}, %r10;   // Cmが適切なレジスタに配置
        movq ${r:new_rsp}, %r11;       // 同上
    `);
}
```
