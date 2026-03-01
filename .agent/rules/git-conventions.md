# コミット・ブランチルール

## ブランチ命名規則
```
feature/cosmo_linux_<version>  - 機能開発
fix/<issue>                    - バグ修正
hotfix/<description>           - 緊急修正
release/v<version>             - リリース準備
```

## コミットメッセージ
- **日本語**で記述
- 1行目: 変更の要約（50文字以内）
- プレフィックス: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`

## コミット前チェック
// turbo
1. `make -C cosmo-linux` でビルド確認
2. `make -C cosmo-linux test` でテスト確認
3. 不要な変更・デバッグ出力がないか確認
4. ローカルパス情報(`/Users/`等)が含まれていないか確認
