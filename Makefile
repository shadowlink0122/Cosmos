# Cosmos プロジェクト — ルート Makefile
#
# 使い方:
#   make build  - Cosmo Linux カーネルビルド
#   make run    - QEMU起動
#   make test   - テスト実行
#   make clean  - クリーン

.PHONY: build run test clean serve

build:
	$(MAKE) -C cosmo-linux build

run:
	$(MAKE) -C cosmo-linux run

serve:
	$(MAKE) -C cosmo-linux serve

test:
	$(MAKE) -C cosmo-linux test

clean:
	$(MAKE) -C cosmo-linux clean
