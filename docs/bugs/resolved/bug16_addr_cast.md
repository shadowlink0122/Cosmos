# Bug #16: `&local as ulong` のキャスト型エラー

> Cm v0.14.1、`--target=uefi` (x86_64)
>
> バグ一覧: [README.md](../README.md)

**発見日**: 2026-02-17  
**再現確認**: Cm v0.14.1、`--target=uefi`  
**回避策あり**: 型付きポインタ経由でキャスト

---

## 症状

ローカル変数のアドレスを `&var as ulong` で直接 `ulong` にキャストしようとすると、
型ミスマッチエラーが発生する。

## 再現コード

```cm
//! platform: uefi

struct Foo {
    ulong x;
}

ulong efi_main(void* image_handle, void* system_table) {
    Foo foo;
    ulong addr = &foo as ulong;  // ❌ error: Type mismatch
    return 0;
}
```

## エラーメッセージ

```
error: Type mismatch in variable declaration 'addr': expected 'ulong', got '*ulong'
```

## 推定原因

`&foo` の型が `Foo*` ではなく `*ulong`（ポインタ型のulong幅表現）として
推論されているため、`as ulong` のキャストルールに合致しない。

## 回避策

型付きポインタ変数を経由してキャストする:

```cm
// ❌ 直接キャスト → エラー
ulong addr = &foo as ulong;

// ✅ 型付きポインタ経由 → OK
Foo* ref = &foo;
ulong addr = ref as ulong;
```

## CosmOSでの対応

`efi_main.cm` で `Heap` のアドレスをグローバルに保存する際に使用:

```cm
// ✅ 回避策適用済み
Heap* heap_ref = &heap;
ulong heap_addr_val = heap_ref as ulong;
```
