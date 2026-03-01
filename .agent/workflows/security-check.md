---
description: セキュリティチェック - ローカルパス情報の検出と削除
---

# セキュリティチェック

## 目的
コードやドキュメントにローカル環境の情報（ユーザーパス等）が含まれていないことを確認する。

## ⚠️ 重要：ローカルパス情報は絶対禁止

以下のようなパスは**絶対に**コミットしてはいけない：
- `/Users/<username>/...`
- `/home/<username>/...`
- `C:\Users\<username>\...`
- その他のマシン固有のパス

## チェックコマンド

// turbo
1. ローカルパスの検索
```bash
grep -rn "/Users/\|/home/\|C:\\\\Users\\\\" docs/ .agent/ kernel/ --include="*.md" --include="*.cm" --include="*.yaml"
```

// turbo
2. 結果が空であることを確認

## 修正方法

ローカルパスが見つかった場合は相対パスに変換する。

## 正しいパス形式

- ✅ `kernel/boot/efi_main.cm`
- ✅ `docs/os_design.md`
- ❌ `/home/user/project/kernel/...`

## コミット前チェック

このチェックは以下のタイミングで必ず実行：
1. PR作成前
2. ドキュメント編集後
3. 新規ファイル追加時
