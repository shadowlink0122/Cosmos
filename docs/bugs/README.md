# Cm コンパイラ — バグ・制約事項

> CosmOS開発中に発見されたCmコンパイラのバグ・制約をまとめたドキュメント。
>
> 対象: Cm v0.14.1、`--target=uefi` (x86_64)、macOS環境
> 最終更新: 2026-02-17

## サマリー

| カテゴリ | 件数 | 説明 |
|---------|------|------|
| [open/](./open/) | 5件 | 未修正バグ（回避策あり） |
| [resolved/](./resolved/) | 6件 | コンパイラ更新で修正済 |
| [workaround/](./workaround/) | 2件 | コンパイラ未修正だがCosmOS側で回避済 |

---

## 未修正バグ（open）

| # | バグ | 重要度 | 回避策 | 詳細 |
|---|------|--------|--------|------|
| 5 | `__asm__`出力変数のwhile条件不具合 | 重大 | ループ内スコープ宣言 | [bug05](./open/bug05_asm_while.md) |
| 7 | `must { __asm__() }` の制御フロー干渉 | 低 | mustなしで直接使用 | [bug07](./open/bug07_must_asm.md) |
| 9 | スタックオフセット重複 | 重大 | ASM内で直接構築 | [bug09](./open/bug09_stack_offset.md) |
| 11 | インライン展開によるASMレジスタ割当変更 | 重大 | `${r:var}` 構文 | [bug11](./open/bug11_asm_register.md) |
| 12 | インライン展開時のret先不在 | 重大 | 数値ラベルでpush | [bug12](./open/bug12_inline_ret.md) |

## 回避済バグ（workaround）

| # | バグ | 重要度 | 回避方法 | 詳細 |
|---|------|--------|---------|------|
| 10 | ポインタ経由implでself変更消失 | 重大 | ポインタ内包型impl設計 | [bug10](./workaround/bug10_impl_self.md) |
| 13 | インライン展開時のレジスタ上書き | 致命的 | efi_main引数退避 | [bug13](./workaround/bug13_register_clobber.md) |

## 修正済バグ（resolved）

| # | バグ | 修正バージョン | 詳細 |
|---|------|---------------|------|
| 1 | 3引数関数でのポインタ破損 | v0.2.0 | [bug01](./resolved/bug01_3arg_pointer.md) |
| 2 | `ushort*`/`uint*` デリファレンス非対応 | v0.2.0 | [bug02](./resolved/bug02_ushort_deref.md) |
| 3 | `self` コピー問題（1段メソッド呼出し） | v0.2.0 | [bug03](./resolved/bug03_self_copy.md) |
| 4 | 整数リテラルが `i32` に推論される | v0.2.0 | [bug04](./resolved/bug04_i32_inference.md) |
| 6 | `stoll: out of range`（大きな16進リテラル） | v0.14.1 | [bug06](./resolved/bug06_stoll_range.md) |
| 8 | const式でのI/Oポート計算 | v0.14.1 | [bug08](./resolved/bug08_const_io.md) |
