# BUG-001: 初回ビルドテスト修正

**発見日**: 2026-03-01
**修正コミット**: Phase 1-2 ビルドテスト修正

## 修正一覧

| # | 問題 | 修正内容 |
|---|------|----------|
| 1 | `//! platform: baremetal` 不一致 | `baremetal-x86` に統一 |
| 2 | `arch/x86_64/` の import パス | `../` → `../../` (2階層上) |
| 3 | `string.cm` が予約語と衝突 | `kstring.cm` にリネーム |
| 4 | `fn_addr()` 未定義関数 | `func as ulong` キャストに置換 |
| 5 | ASM出力で utiny 変数使用 | `ulong` 中間変数に変更 |
| 6 | `PAGE_FREE/USED` が utiny 定数 | `ulong` 定数に変更 |
| 7 | `start_kernel` シンボル未エクスポート | `main` にリネーム（Cm自動エクスポート） |
| 8 | `export void main` 不正 | `export` 削除（main は暗黙グローバル） |

## 根本原因

- Cmの `--target=uefi` は PE/COFF 出力 → ELFリンカと互換不可
- Cmの `__asm__` 出力変数は `movq` を使うため 64bit 幅が必須
- Cmの `main` は自動的にグローバルシンボルとなり `export` は不可
- Cmのモジュール名は予約語と衝突してはならない
