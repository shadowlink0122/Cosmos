# Cm言語バグ・制約事項

Cosmos OS開発中に発見されたCm言語コンパイラのバグおよび制約事項をまとめる。

## Bug #1: 3引数関数でのポインタ破損

**発見日**: 2026-02-16  
**状態**: ✅ Cm v0.2.0で修正済み  
**重要度**: 高

### 症状
構造体ポインタを3番目の引数として渡すと、呼び出し先で値が破損する。

```
// 3番目の引数 pmm が 0x0D に化ける
sched_spawn(entry_fn, pmm)  // 2引数 → task_create(count, entry_fn, pmm) を呼ぶ

// task_create側では pmm = 0x000000000000000D (不正）
```

### 再現条件
- 関数Aが2引数で受け取り、内部で関数Bを3引数で呼ぶ
- 3番目の引数が構造体ポインタ（`PMM*`など）
- UEFI（Windows x64 ABI: RCX, RDX, R8, R9）環境

### 回避策
ポインタを固定メモリアドレスに保存し、関数内部で読み取る方式に変更。

```
// 回避前: 引数渡し
export ulong sched_spawn(ulong entry_fn, PMM* pmm) { ... }

// 回避後: 固定アドレス経由
const ulong SCHED_PMM_ADDR = 0xA18;
export void sched_set_pmm(PMM* pmm) {
    ulong* ptr = SCHED_PMM_ADDR as ulong*;
    *ptr = pmm as ulong;
}
export ulong sched_spawn(ulong entry_fn) {
    PMM* pmm = sched_get_pmm();  // 固定アドレスから取得
    ...
}
```

---

## Bug #2: `ushort*` / `uint*` デリファレンス非対応

**発見日**: 2026-02-16  
**状態**: ✅ Cm v0.2.0で修正済み  
**重要度**: 中

### 症状
`ushort*` や `uint*` 型のポインタをデリファレンスすると、コンパイルエラー「Cannot dereference non-pointer」が発生。

```
// コンパイルエラー
ushort* ptr = addr as ushort*;
ulong val = *ptr as ulong;  // error: Cannot dereference non-pointer
```

### 回避策
インラインASMでバイト単位の読み書きを行う。

```
// 2バイト読取り
ulong result = 0;
ulong addr = 0xB86;
__asm__(`
    movq ${r:addr}, %rdi;
    xorq %rax, %rax;
    movb (%rdi), %al;
    movb 1(%rdi), %ah;
    movq %rax, ${=r:result}
`);

// 2バイト書込み
ulong lo_val = value & 0xFF;
ulong hi_val = (value >> 8) & 0xFF;
__asm__(`
    movq ${r:addr}, %rdi;
    movq ${r:lo_val}, %rax;
    movb %al, (%rdi);
    movq ${r:hi_val}, %rax;
    movb %al, 1(%rdi)
`);
```

---

## Bug #3: `self` コピー問題（構造体メソッド）

**発見日**: 2026-02-16（過去のバグ再確認）  
**状態**: 既知の仕様制約  
**重要度**: 中

### 症状
`impl` ブロックのメソッド内で `self` はコピーとして渡される。
`self.field -= 1` などの変更は呼び出し元の構造体に反映されない。

```
impl PMM {
    ulong alloc_page() {
        self.free_pages -= 1;  // コピーのみ変更、元の構造体は不変
        return page_idx << PAGE_SHIFT;
    }
}
```

### 影響
- `pmm->alloc_page()` で `free_pages` カウンタが元のPMM構造体で減らない
- ビットマップ操作はポインタ経由で直接メモリを変更するため正常動作

### 回避策
- カウンタなどの状態は固定メモリアドレスに配置して直接読み書き
- ポインタ経由のメモリ操作は正常に動作するため、ビットマップ等は問題なし

---

## Bug #4: 整数リテラルがi32に推論される（二項演算）

**発見日**: 2026-02-16  
**状態**: ✅ Cm v0.2.0で修正済み  
**重要度**: 中

### 症状
`ulong` 変数と整数リテラルの二項演算で、リテラルが `i32` に推論され、LLVM IR生成時に型不一致エラーが発生。

```
// エラー: Both operands to a binary operator are not of the same type!
//   %bitand = and i64 %load11, i32 63
ulong new_read = (read_idx + 1) & 63;
```

### 再現条件
- `ulong` 型変数との `&`（AND）演算に整数リテラルを直接使用
- UEFI（x86_64）ターゲット

### 回避策
整数リテラルを明示的に `ulong` にキャストする。

```
// 回避前: コンパイルエラー
ulong new_read = (read_idx + 1) & 63;

// 回避後: 明示的キャスト
ulong ring_mask = 63 as ulong;
ulong new_read = (read_idx + 1) & ring_mask;
```
