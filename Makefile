# Cosmos プロジェクト — ルート Makefile
#
# 使い方:
#   make build  - Cosmo Linux カーネルビルド
#   make run    - QEMU起動
#   make test   - テスト実行
#   make clean  - クリーン

.PHONY: build run test clean

build:
	$(MAKE) -C cosmo-linux

run:
	$(MAKE) -C cosmo-linux run

test:
	$(MAKE) -C cosmo-linux test

clean:
	$(MAKE) -C cosmo-linux clean
