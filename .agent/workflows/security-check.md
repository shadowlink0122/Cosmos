---
description: セキュリティチェック - ローカルパス情報の検出と削除
---

# セキュリティチェック

## 概要
コミット前にローカルパス情報が含まれていないことを確認する。

## チェック手順

// turbo
1. ローカルパスの検出
```bash
grep -rn "/Users/"  .agent/ --include="*.md" --include="*.cm"
grep -rn "/home/"  .agent/ --include="*.md" --include="*.cm"
```

// turbo
2. 絶対パスの検出
```bash
grep -rn "file:///"  .agent/ --include="*.md"
```

3. 検出された場合は相対パスに修正
