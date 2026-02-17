# Bug #14: UEFIターゲットでexport関数数が多いとコンパイラがハング（重大）

> Cm v0.14.1、`--target=uefi` (x86_64)
>
> バグ一覧: [README.md](../README.md)

**発見日**: 2026-02-17  
**再現確認**: Cm v0.14.1、`--target=uefi` のみ  
**回避策あり**: ディスパッチパターンでexport関数数を削減

---

## 症状

1つの `.cm` ファイルに **7つ以上のexport関数** を定義し、
それを既に多数のモジュールをインポートしている `efi_main.cm` からインポートすると、
コンパイラが無限にハングするか、OSの OOM Killer により `Killed: 9` で強制終了する。

## 再現条件

| 条件 | 結果 |
|------|------|
| efi_main.cm（40+インポート）+ 新モジュール 1 export関数 | ✅ 正常 (313ms) |
| efi_main.cm + 新モジュール 4 export関数 | ✅ 正常 (314ms) |
| efi_main.cm + 新モジュール 6 export関数 | ✅ 正常 (320ms) |
| efi_main.cm + 新モジュール 17 export関数 | ❌ **ハング/Killed: 9** |
| efi_main.cm + 新モジュール 2 export関数（大規模） | ✅ 正常 (333ms) |

閾値は正確には不明だが、6〜17の間にある。
既存のefi_main.cmのインポート数が多いほど閾値は低くなると推定。

## 最小再現コード

```cm
//! platform: uefi
import ../config;

// 以下のexport関数を7つ以上定義すると再現
export ulong func1(ulong a) { return a; }
export ulong func2(ulong a) { return a; }
export ulong func3(ulong a) { return a; }
export ulong func4(ulong a) { return a; }
export ulong func5(ulong a) { return a; }
export ulong func6(ulong a) { return a; }
export ulong func7(ulong a) { return a; }
// ... さらに追加するとハング確率が上がる
```

## 推定原因

コンパイラのシンボル登録またはリンク解決フェーズで
export関数の総数に対して指数関数的な処理が発生している可能性。
efi_main.cmの既存インポートチェーンで既に大量のシンボルが登録されているため、
追加モジュールのexport関数数が増えるとメモリまたはCPU時間の限界を超える。

## 回避策: ディスパッチパターン

複数の操作を **1つのexport関数** に集約し、引数で操作を切り替える:

```cm
// ❌ NG: 多数のexport
export ulong fs_find(ulong name) { ... }
export ulong fs_size(ulong name) { ... }
export ulong fs_delete(ulong name) { ... }
// ... 7+でハング

// ✅ OK: ディスパッチパターン
const ulong OP_FIND = 5;
const ulong OP_SIZE = 3;
const ulong OP_DELETE = 4;

export ulong cosmfs_op(ulong op, ulong arg1, ulong arg2, ulong arg3, ulong arg4) {
    if (op == OP_FIND) { /* find処理 */ }
    if (op == OP_SIZE) { /* size処理 */ }
    if (op == OP_DELETE) { /* delete処理 */ }
    return 0;
}
```

## CosmOSでの対応

`kernel/fs/cosmfs.cm` で `cosmfs_init()` + `cosmfs_op()` の2 export関数のみに統合。
10種類の操作を `op` 引数で分岐するディスパッチ方式で回避済み。

## 影響範囲

今後の全てのカーネルモジュール追加時に同じ制限が適用される。
新モジュールでは **export関数数を最小限** にする設計が必要。
