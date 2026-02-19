# Bug #9: ローカル配列とポインタ変数のスタックオフセット重複（重大）

> 詳細調査レポート — Cm v0.14.1、`--target=uefi` (x86_64)
>
> バグ一覧: [cm_compiler_bugs_open.md](./cm_compiler_bugs_open.md)

**発見日**: 2026-02-16  
**詳細調査日**: 2026-02-17  
**再現確認**: Cm v0.14.1、`--target=uefi` のみ（JITでは再現しない）

---

## 症状

ローカル配列のアドレスを`&arr`で取得してポインタ変数に格納すると、
配列のスタック配置が1要素分ずれ、最終要素が重複・上書きされる。

- 配列インデックスが1つシフト（`arr[0]`読み出しで`arr[1]`に代入した値が返る）
- `arr[n-2]`と`arr[n-1]`が同一値になる
- ポインタ変数がなければ正常動作

## 再現条件

| 条件 | 結果 |
|------|------|
| `ulong[3] arr;` のみ（ポインタ変数なし） | ✅ 正常 |
| `ulong[3] arr;` + `void* p = &arr as void*;` | ❌ **バグ再現** |
| `ulong[3] arr;` + `ulong x = 0xDEAD;`（アドレス取得なし） | ✅ 正常 |
| JITモード（`cm run`） | ✅ 正常（UEFIターゲットのみ再現） |

## 最小再現コード

```cm
//! platform: uefi
import ../kernel/drivers/serial;

ulong efi_main(void* image_handle, void* system_table) {
    SerialPort serial(0x3F8);

    // テストA: 配列のみ（正常動作）
    ulong[3] a;
    a[0] = 0xAAAA000000000000;
    a[1] = 0xBBBB000000000000;
    a[2] = 0xCCCC000000000000;
    serial.puts("a[0] = " as void*); serial.print_hex(a[0]); serial.println("" as void*);
    serial.puts("a[1] = " as void*); serial.print_hex(a[1]); serial.println("" as void*);
    serial.puts("a[2] = " as void*); serial.print_hex(a[2]); serial.println("" as void*);

    // テストB: 配列 + アドレス取得ポインタ変数（バグ再現）
    ulong[3] b;
    b[0] = 0x1111000000000000;
    b[1] = 0x2222000000000000;
    b[2] = 0x3333000000000000;
    void* b_ptr = &b as void*;  // ← この行を追加するとバグ発生
    serial.puts("b[0] = " as void*); serial.print_hex(b[0]); serial.println("" as void*);
    serial.puts("b[1] = " as void*); serial.print_hex(b[1]); serial.println("" as void*);
    serial.puts("b[2] = " as void*); serial.print_hex(b[2]); serial.println("" as void*);

    while (true) { __asm__("hlt"); }
    return 0;
}
```

## 再現手順

```bash
# 1. 上記コードを .tmp/bug9_uefi.cm として保存
# 2. UEFI向けコンパイル＆リンク
cm compile --target=uefi -o .tmp/build/bug9.o .tmp/bug9_uefi.cm
lld-link /subsystem:efi_application /entry:efi_main /out:.tmp/build/BUG9.EFI .tmp/build/bug9.o

# 3. QEMU実行
# .tmp/esp/EFI/BOOT/BOOTX64.EFI にコピーして起動
```

## 期待される出力

```
a[0] = 0xAAAA000000000000   // テストA: 正常
a[1] = 0xBBBB000000000000
a[2] = 0xCCCC000000000000
b[0] = 0x1111000000000000   // テストB: 正常であるべき
b[1] = 0x2222000000000000
b[2] = 0x3333000000000000
```

## 実際の出力（バグ再現）

```
a[0] = 0xAAAA000000000000   // テストA: ✅ 正常
a[1] = 0xBBBB000000000000
a[2] = 0xCCCC000000000000
b[0] = 0x2222000000000000   // テストB: ❌ インデックス1つシフト
b[1] = 0x3333000000000000   // ❌ arr[2]の値が返される
b[2] = 0x3333000000000000   // ❌ arr[1]と同値（最終要素が重複）
```

## 推定原因

配列のアドレスを`&arr`で取得してポインタ変数に格納する際、
コンパイラが配列とポインタ変数に同一のスタックベースオフセットを割り当てる。
その結果、配列の先頭要素がポインタ変数のスロットと重なり、
配列全体のインデックスが1つ後方にシフトする。

## 回避策

ローカル配列のアドレスを変数に格納しない。  
代わりに以下のいずれかで対処:
- ASM内でスタック上にテーブルを直接構築する
- 固定メモリアドレスに配列を配置する

## CosmOSでの対応

GDTはASM内で固定アドレス(0x800)に直接構築する方式に変更済み。
