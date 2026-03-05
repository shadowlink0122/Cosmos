---
description: リリース準備の手順
---

# リリース準備ワークフロー

## 1. バージョン更新
// turbo
1. `include/config.cm` のバージョン定数を更新
2. `boot/entry.cm` のバナー文字列を更新

## 2. テスト
// turbo-all
1. `make clean`
2. `make`
3. `make test`

## 3. ドキュメント確認
1. 全 00N_ ドキュメントが最新か確認
2. チェックリストの完了状態を確認
3. README.md を更新

## 4. タグ作成
1. `git tag -a v<version> -m "リリース v<version>"`
2. `git push origin v<version>`
