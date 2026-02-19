# Cm コンパイラ — バグ・制約事項

> CosmOS開発中に発見されたCmコンパイラのバグ・制約をまとめたドキュメント。
>
> 対象: Cm v0.14.1、`--target=uefi` (x86_64)、macOS環境
> 最終更新: 2026-02-19

## サマリー

> **統合リファレンス**: 全バグの詳細を1つにまとめた [BUGS.md](./BUGS.md) も参照。

| カテゴリ | 件数 | 説明 |
|---------|------|------|
| [open/](./open/) | 3件 | 未修正バグ（回避策あり） |
| [workaround/](./workaround/) | 1件 | コンパイラ未修正だがCosmOS側で回避済 |
| [resolved/](./resolved/) | 13件 | コンパイラ更新で修正済 |

---

## 未修正バグ（open）

| # | バグ | 重要度 | 回避策 | 詳細 |
|---|------|--------|--------|------|
| 7 | `must { __asm__() }` の制御フロー干渉 | 低 | mustなしで直接使用 | [bug07](./open/bug07_must_asm.md) |
| 11 | インライン展開によるASMレジスタ割当変更 | 重大 | `${r:var}` 構文 | [bug11](./open/bug11_asm_register.md) |
| 12 | インライン展開時のret先不在 | 重大 | 数値ラベルでpush | [bug12](./open/bug12_inline_ret.md) |

## 回避済バグ（workaround）

| # | バグ | 重要度 | 回避方法 | 詳細 |
|---|------|--------|---------|------|
| 17 | `___chkstk_ms` 未定義シンボル | 中 | no-opスタブ提供 | [bug17](./workaround/bug17_chkstk_ms.md) |

## 修正済バグ（resolved）

| # | バグ | 修正バージョン | 詳細 |
|---|------|---------------|------|
| 1 | 3引数関数でのポインタ破損 | v0.2.0 | [bug01](./resolved/bug01_3arg_pointer.md) |
| 2 | `ushort*`/`uint*` デリファレンス非対応 | v0.2.0 | [bug02](./resolved/bug02_ushort_deref.md) |
| 3 | `self` コピー問題 | v0.2.0 | [bug03](./resolved/bug03_self_copy.md) |
| 4 | 整数リテラルが `i32` に推論 | v0.2.0 | [bug04](./resolved/bug04_i32_inference.md) |
| 5 | `__asm__`出力変数のwhile条件不具合 | v0.14.1 | [bug05](./resolved/bug05_asm_while.md) |
| 6 | `stoll: out of range` | v0.14.1 | [bug06](./resolved/bug06_stoll_range.md) |
| 8 | const式でのI/Oポート計算 | v0.14.1 | [bug08](./resolved/bug08_const_io.md) |
| 9 | スタックオフセット重複 | v0.14.1 | [bug09](./resolved/bug09_stack_offset.md) |
| 10 | ポインタ経由impl self変更消失 (3種) | v0.14.1 | [bug10](./resolved/bug10_impl_self.md) |
| 13 | インライン展開時のレジスタ上書き | v0.14.1 | [bug13](./resolved/bug13_register_clobber.md) |
| 14 | export関数数超過でハング | v0.14.1 | [bug14](./resolved/bug14_export_limit.md) |
| 15 | 非export関数がexport関数から呼出不可 | v0.14.1 | [bug15](./resolved/bug15_private_func.md) |
| 16 | `&local as ulong` キャスト型エラー | v0.14.1 | [bug16](./resolved/bug16_addr_cast.md) |
