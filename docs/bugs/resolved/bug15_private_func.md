# Bug #15: 非export関数がモジュール内export関数から呼び出せない

> Cm v0.14.1、`--target=uefi` (x86_64)
>
> バグ一覧: [README.md](../README.md)

**発見日**: 2026-02-17  
**再現確認**: Cm v0.14.1、`--target=uefi` のみ  
**回避策あり**: 全関数にexportを付ける

---

## 症状

`.cm` モジュール内でexportしていない（private）関数を、
同一モジュール内のexport関数から呼び出すと、
コンパイラが `'func_name' is not a function` エラーを出す。

通常のプログラミング言語では、モジュール内のprivate関数は
同一モジュール内から自由に呼び出せるが、
CmのUEFIターゲットではこの動作が正しく機能しない。

## 再現コード

```cm
//! platform: uefi
import ../config;

// ❌ private関数 — export関数から呼び出すとエラー
ulong read_byte(ulong addr) {
    ulong result = 0;
    __asm__(`
        movq ${r:addr}, %rdi;
        xorq %rax, %rax;
        movb (%rdi), %al;
        movq %rax, ${=r:result}
    `);
    return result;
}

// export関数がprivate関数を呼ぶ → コンパイルエラー
export ulong get_value(ulong addr) {
    return read_byte(addr);  // error: 'read_byte' is not a function
}
```

## エラーメッセージ

```
error: 'read_byte' is not a function
   --> kernel/efi_main.cm:1:1
   |
 1 | //! platform: uefi
   | ^
   |
```

## 回避策

全関数に `export` を付ける:

```cm
export ulong read_byte(ulong addr) { ... }  // ✅ exportに変更
export ulong get_value(ulong addr) {
    return read_byte(addr);  // OK
}
```

> **注意**: Bug #14（export関数数制限）と組み合わせると矛盾する。
> 多くの関数をexportにする必要があるが、export数が多すぎるとハングする。
> → ディスパッチパターン（Bug #14参照）で1関数にまとめることで両方を回避。

## CosmOSでの対応

`cosmfs.cm` の全ヘルパー関数を `cosmfs_op()` 内にインライン化し、
export関数数を最小限にしつつprivate関数解決問題を回避。
