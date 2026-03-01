---
description: リリース準備の手順
---

# リリースワークフロー

## 1. カーネル検証
// turbo-all
1. `make clean && make` - クリーンビルド
2. `make run` - QEMUで動作確認
3. 主要機能の手動テスト

## 2. ドキュメント整備

### 2.1 完了ドキュメントのアーカイブ
実装済みのドキュメントを`docs/archive/`に移動：
```bash
mv docs/design/implemented_feature.md docs/archive/
```

### 2.2 リリースノート作成
`docs/releases/vX.Y.Z.md`にリリースノートを記載：
- 新機能の説明
- 破壊的変更の有無
- 既知の問題

### 2.3 README.md更新
- 実装状況の更新
- 実行方法の確認

## 3. バージョン更新
// turbo
1. `VERSION`ファイルを更新

## 4. 最終確認
// turbo
1. `git status` - 未コミット変更なし
2. `git log --oneline -10` - コミット履歴確認
3. 一貫性確認チェック：
   - [ ] カーネル機能
   - [ ] QEMUテスト
   - [ ] docs
   - [ ] README
   - [ ] VERSION

## 5. リリース実行
```bash
git tag v<version>
git push origin v<version>
```
GitHub Releaseを作成
