---
name: build-check
description: Cosmo Linux ビルドとテストの完全チェック
---

# Cosmo Linux ビルド・テストチェック

カーネルのビルドからQEMUテストまでの完全な検証スキル。

## 実行手順

### 1. クリーンビルド
// turbo
```bash
make clean
make
```

### 2. QEMUブートテスト
// turbo
```bash
make test
```

### 3. シリアルログ確認
// turbo
```bash
cat .tmp/serial.log
```

### 4. 結果判定
- [ ] ビルドエラーなし
- [ ] リンクエラーなし
- [ ] "Cosmo Linux" バナーがシリアルに出力されている
- [ ] "Kernel initialization complete" が出力されている
- [ ] 例外（#DE, #DF, #GP, #PF）が発生していない

## トラブルシューティング

| 症状 | 対処 |
|------|------|
| NASM エラー | `header.S` のセクション・アラインメント確認 |
| Cm コンパイルエラー | `cm compile --target=uefi` でデバッグ |
| リンクエラー | `linker.ld` のセクション名確認 |
| QEMU即リセット | Multiboot2ヘッダのマジック・チェックサム確認 |
| トリプルフォルト | GDT/IDTのアドレス・サイズ確認 |
| シリアル出力なし | COM1 (0x3F8) の初期化確認 |
