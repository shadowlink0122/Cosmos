---
name: cm-code-review
description: Cm言語のコードレビューチェックリスト（typedef/interface/impl準拠確認）
---

# Cm コードレビュースキル

Cosmo Linux の Cm コードが設計パターンに準拠しているかを確認する。

## チェック項目

### 1. typedef 準拠
- [ ] 公開APIの引数・戻り値に生の `ulong`/`long` を使用していないか
- [ ] 新しい概念には typedef 型が定義されているか
- [ ] typedef は `include/types.cm` に集約されているか

### 2. interface 準拠
- [ ] デバイスドライバに interface が定義されているか
- [ ] interface は `include/` に配置されているか
- [ ] interface メソッドに適切なドキュメントコメントがあるか

### 3. impl 準拠
- [ ] 構造体メソッドは `impl <Struct> { }` で定義されているか
- [ ] コンストラクタは `overload self(...)` パターンか
- [ ] インターフェース実装は `impl <Struct> for <Interface>` か

### 4. 命名規約
- [ ] typedef/struct/interface → PascalCase
- [ ] 関数/変数 → snake_case
- [ ] 定数 → UPPER_SNAKE_CASE

### 5. ファイル構成
- [ ] `//! platform: baremetal` がファイル先頭にあるか
- [ ] `export` が適切に使われているか
- [ ] ASMは `__asm__` ラッパー関数に閉じ込められているか

## 確認コマンド

```bash
# typedef の使用状況
grep -rn "typedef" include/

# interface の定義
grep -rn "interface" include/

# impl の実装確認
grep -rn "^impl " 

# 生のulong引数（潜在的な問題）
grep -rn "export.*ulong "  --include="*.cm" | grep -v "const\|typedef"
```
