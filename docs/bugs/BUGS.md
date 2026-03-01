# Cm コンパイラ バグ・制約事項 — 統合リファレンス

> CosmOS開発中に発見されたCmコンパイラ（v0.14.1、`--target=uefi` x86_64）のバグ・制約事項。
>
> 最終更新: 2026-02-19

---

## サマリー

| # | バグ名 | 重要度 | 状態 | カテゴリ |
|---|--------|--------|------|----------|
| 7 | `must { __asm__() }` 制御フロー干渉 | 低 | ⚠️ 未修正 | ASM |
| 11 | インライン展開ASMレジスタ割当変更 | 重大 | ⚠️ 未修正 | インライン展開 |
| 12 | インライン展開時ret先不在 | 重大 | ⚠️ 未修正 | インライン展開 |
| 17 | `___chkstk_ms` 未定義シンボル | 中 | 🔧 回避済 | リンカ |

凡例: 🔧 CosmOS側で回避済、⚠️ 未修正（回避策のみ）

> [!IMPORTANT]
> 全バグは **UEFIターゲット (`--target=uefi`) 固有** であり、JITモード (`cm run`) では再現しない。

---

## 未修正バグ（open）

### Bug #7: `must { __asm__() }` の制御フロー干渉 — 低

**カテゴリ**: ASM  
**発見日**: 2026-02-16  
**対象**: Cm v0.14.1 / `--target=uefi` (x86_64)  
**最終確認**: 2026-02-19（QEMU実行で再現確認済み）

#### 症状

`must { }` ブロックで `__asm__` をラップすると、`while(true)` ループから脱出してしまう。

#### 再現コード

```cm
//! platform: uefi

ulong efi_main(void* image_handle, void* system_table) {
    void* ih = image_handle;
    void* st = system_table;

    ulong count = 0;
    while (true) {
        must { __asm__("hlt"); }
        count = count + 1;
        if (count > 3) { break; }
    }
    // ❌ must内hltが制御フローを破壊し、ここに到達する

    // QEMU終了
    ulong exit_port = 0xF4;
    ulong exit_val = 0x00;
    __asm__(` movq ${r:exit_port}, %rdx; movq ${r:exit_val}, %rax; outl %eax, %dx `);
    return 0;
}
```

#### 再現手順

```bash
cm compile --target=uefi -o .tmp/build/bug7.o test_bug7.cm
lld-link /subsystem:efi_application /entry:efi_main /out:.tmp/build/BUG7.EFI .tmp/build/bug7.o
# QEMU実行 → hltで停止せず、ループ脱出してQEMU終了
```

#### 回避策

```cm
// ✅ mustなしで直接使用
while (true) { __asm__("hlt"); }
```

---

### Bug #11: インライン展開によるASMレジスタ割当変更 — 重大

**カテゴリ**: インライン展開  
**発見日**: 2026-02-16  
**対象**: Cm v0.14.1 / `--target=uefi` (x86_64)  
**最終確認**: 2026-02-19（QEMU実行で不正値出力を確認 — クラッシュはしないが計算結果が不正）

> [!TIP]
> v0.14.1でコンパイラが `%rdi`/`%rsi` のUEFIターゲットでの直接参照を検出し、警告を出すようになった。
> ただし警告のみでコード生成は修正されていない。

#### 症状

`__asm__` 内で `%rdi`/`%rsi` 等のABIレジスタを直接参照し、関数パラメータの配置を前提にすると、インライン展開時に不正な値で計算される。

- 以前はクラッシュしていたが、現在はクラッシュしない代わりに不正値を返す
- `add_via_abi(0x30, 0x11)` の期待値 `0x41` に対し、実際の出力は `0x98`

#### 再現コード

```cm
//! platform: uefi

export ulong add_via_abi(ulong a, ulong b) {
    ulong result = 0;
    // ❌ System V ABIのrdi/rsiを直接参照
    __asm__(`
        movq %rdi, %rax;
        addq %rsi, %rax;
        movq %rax, ${=r:result}
    `);
    return result;
}

ulong efi_main(void* image_handle, void* system_table) {
    void* ih = image_handle;
    void* st = system_table;
    ulong port = 0xE9;
    ulong sum = add_via_abi(0x30, 0x11);  // 期待: 0x41, 実際: 0x98
    __asm__(` movq ${r:port}, %rdx; movq ${r:sum}, %rax; outb %al, %dx `);

    ulong exit_port = 0xF4;
    ulong exit_val = 0x00;
    __asm__(` movq ${r:exit_port}, %rdx; movq ${r:exit_val}, %rax; outl %eax, %dx `);
    while (true) { __asm__("hlt"); }
    return 0;
}
```

#### 再現手順

```bash
cm compile --target=uefi -o .tmp/build/bug11.o test_bug11.cm
lld-link /subsystem:efi_application /entry:efi_main /out:.tmp/build/BUG11.EFI .tmp/build/bug11.o
# QEMU実行 → デバッグポートに0x98が出力される（期待値: 0x41）
```

#### 回避策

```cm
// ✅ ${r:var} で変数をバインド
export ulong add_safe(ulong a, ulong b) {
    ulong result = 0;
    __asm__(`
        movq ${r:a}, %rax;
        addq ${r:b}, %rax;
        movq %rax, ${=r:result}
    `);
    return result;
}
```

---

### Bug #12: インライン展開時のret先不在 — 重大

**カテゴリ**: インライン展開  
**発見日**: 2026-02-16  
**対象**: Cm v0.14.1 / `--target=uefi` (x86_64)

> [!TIP]
> v0.14.1でコンパイラが `ret`/`iret` 命令をASM内で検出し、警告を出すようになった。
> ただし警告のみでインライン展開の動作は修正されていない。

#### 症状

`__asm__` 内で `ret` 命令を使う関数がインライン展開されると、`call` 命令が省略されスタック上にreturn addressがない。クラッシュ。

#### 再現コード

```cm
//! platform: uefi

export void context_switch(ulong old_rsp_ptr, ulong new_rsp) {
    __asm__(`
        movq ${r:old_rsp_ptr}, %r10;
        movq %rsp, (%r10);
        movq ${r:new_rsp}, %rsp;
        ret;   // ← return addressがない → クラッシュ
    `);
}

ulong efi_main(void* image_handle, void* system_table) {
    void* ih = image_handle;
    void* st = system_table;
    ulong old_rsp = 0;
    ulong new_rsp = 0x80000;
    context_switch(old_rsp, new_rsp);
    while (true) { __asm__("hlt"); }
    return 0;
}
```

#### 再現手順

```bash
cm compile --target=uefi -o .tmp/build/bug12.o test_bug12.cm
lld-link /subsystem:efi_application /entry:efi_main /out:.tmp/build/BUG12.EFI .tmp/build/bug12.o
# QEMU実行 → ret命令で不正アドレスにジャンプしてクラッシュ
```

#### 回避策

```cm
// ✅ 数値ラベルでreturn addressをpush
__asm__(`
    leaq 1f(%rip), %rax;
    pushq %rax;
    movq ${r:old_rsp_ptr}, %r10;
    movq %rsp, (%r10);
    movq ${r:new_rsp}, %rsp;
    ret;
1:
    nop
`);
```

> [!CAUTION]
> 名前付きラベルは複数回インライン展開で重複エラー。必ず数値ラベル (`1:`) を使用。

---

## 回避済バグ（workaround）

### Bug #17: `___chkstk_ms` 未定義シンボル — 中

**カテゴリ**: リンカ  
**発見日**: 2026-02-17  
**対象**: Cm v0.14.1 / `--target=uefi` (x86_64)

#### 症状

LLVMが4KB以上のスタックフレームにスタックプローブ `___chkstk_ms` を自動挿入。ベアメタルでは未定義。

#### 回避策（必須）

```c
// kernel/lib/chkstk.c
void ___chkstk_ms(void) { /* no-op */ }
```

```bash
clang -target x86_64-unknown-windows-msvc -c -o .tmp/build/chkstk.o kernel/lib/chkstk.c
lld-link ... .tmp/build/kernel.o .tmp/build/chkstk.o
```

> [!NOTE]
> LLVMの仕様上の動作であり、Cmコンパイラのバグではない。ベアメタルでは常にこのスタブが必要。

---

## CosmOSアーキテクチャへの影響

1. **`${r:var}` 構文の使用必須**: Bug #11 により ABIレジスタ直接参照は禁止
2. **`ret` 使用時の数値ラベル**: Bug #12 によりインライン展開でreturn addressを明示的にpush
3. **`must`ブロック内ASM禁止**: Bug #7 により `must { __asm__() }` は使用しない

> [!IMPORTANT]
> これらの制約はCmコンパイラのUEFIバックエンド固有の問題であり、JITモード (`cm run`) では再現しない。
