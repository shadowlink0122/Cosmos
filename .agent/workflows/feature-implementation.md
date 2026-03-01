---
description: 新機能の実装手順
---

# 新機能実装ワークフロー

## 0. 事前確認
- ROADMAPとの整合性確認
- 既存 interface に追加すべきか、新規 interface が必要か判断
- 影響範囲の確認

## 1. 設計フェーズ
// turbo
1. `docs/cosmo-linux/`に設計ドキュメント作成
   - ファイル名に`00N_`プレフィックスを付ける
   - 例: `006_memory_management.md`
2. typedef / interface / impl の設計を明記
3. 既存機能への影響分析

## 2. 型・インターフェース定義
// turbo
1. 必要な typedef を `include/types.cm` に追加
2. 新規 interface を `include/<name>.cm` に定義
3. エラーコードが必要なら `include/errno.cm` に追加
4. 設定定数は `include/config.cm` に追加

## 3. 実装フェーズ
1. 構造体定義 (`struct`)
2. `impl <Struct>` で固有メソッド実装
3. `impl <Struct> for <Interface>` でインターフェース実装
4. テスト用のシリアル出力を追加

## 4. ビルド検証
// turbo
1. `make -C cosmo-linux` でビルド確認
2. `make -C cosmo-linux test` でテスト

## 5. ドキュメント更新
// turbo
1. `docs/cosmo-linux/005_phase0_checklist.md` を更新
2. 必要であれば新規チェックリスト作成

## 6. コミット
// turbo
1. 変更をコミット（日本語メッセージ）
2. 一貫性チェック:
   - [ ] typedef 定義 ✓
   - [ ] interface 定義 ✓
   - [ ] impl 実装 ✓
   - [ ] ドキュメント更新 ✓
