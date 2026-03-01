---
description: GitHub PRの作成とレビュールール
---

# PR作成・レビュールール

## 言語
- すべて**日本語**で記述

## PRタイトル形式
```
<種類>: <簡潔な説明>

種類: feat, fix, docs, refactor, test, chore
```

## PR作成時
1. テンプレートに従って本文を記入
2. 変更ファイル一覧と変更理由を記載
3. チェックリストを確認

## レビュー時の確認項目
1. **typedef/interface/impl** パターンの準拠
   - 新しい型は typedef 定義済みか
   - デバイスやサブシステムは interface 化されているか
   - impl ブロックで正しく実装されているか
2. **ドキュメント**
   - `docs/cosmo-linux/` に 00N_ ドキュメントが追加/更新されているか
   - バグがあれば 00N_bug_ ドキュメントが作成されているか
3. **セキュリティ**
   - ローカルパス情報 (`/Users/`, `/home/`) が含まれていないこと
   - 確認: `grep -rn "/Users/" cosmo-linux/ .agent/ --include="*.md" --include="*.cm"`
4. **ビルド・テスト**
   - `make -C cosmo-linux` でビルド成功
   - `make -C cosmo-linux test` でテスト成功

## マージ条件
- テスト全パス
- typedef/interface/impl ルール準拠
- 00N_ ドキュメント更新済み
