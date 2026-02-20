# CosmOS - 統合Makefile
#
# 使い方:
#   make              - カーネルをコンパイル＆リンク（EFI生成）
#   make compile      - カーネルのコンパイルのみ
#   make all          - カーネルをコンパイル＆リンク
#   make run          - QEMUで実行（OVMFを自動ダウンロード）
#   make test         - カーネルテスト（QEMUブートフロー検証）
#   make clean        - カーネル生成ファイル削除
#
# Cmコンパイラ操作:
#   make cm-build     - Cmコンパイラをビルド
#   make cm-test      - Cmユニットテスト
#   make cm-test-all  - Cm全テスト
#   make cm-clean     - Cmビルドディレクトリをクリーン
#   make cm CMD="..."   - Cm Makefileの任意ターゲットを実行
#
# 統合操作:
#   make build-all    - Cmコンパイラ + カーネルを全ビルド
#   make clean-all    - 全ビルド成果物を削除

CM ?= cm
CLANG ?= /opt/homebrew/opt/llvm@17/bin/clang
LLD ?= lld-link
QEMU ?= qemu-system-x86_64

# Cmコンパイラのサブディレクトリ
CM_DIR = Cm

# OVMFファームウェアの配置先
OVMF_DIR ?= .tmp/ovmf
OVMF_FW ?= $(OVMF_DIR)/OVMF.fd

# OVMF ダウンロードURL (Arch: x86_64, Release build)
OVMF_URL ?= https://retrage.github.io/edk2-nightly/bin/RELEASEX64_OVMF.fd

# カーネルソース
KERNEL_DIR = kernel
KERNEL_SRC = $(KERNEL_DIR)/efi_main.cm
KERNEL_OBJ = .tmp/build/kernel.o
CHKSTK_SRC = $(KERNEL_DIR)/lib/chkstk.c
CHKSTK_OBJ = .tmp/build/chkstk.o
EFI = .tmp/build/BOOTX64.EFI
ESP_DIR = .tmp/esp
ESP_BOOT = $(ESP_DIR)/EFI/BOOT

# テスト
TEST_DIR = tests
TEST_KERNEL_SRC = $(KERNEL_DIR)/efi_main_test.cm
TEST_KERNEL_OBJ = .tmp/build/kernel_test.o
TEST_KERNEL_EFI = .tmp/build/BOOTX64_TEST.EFI
TEST_SERIAL_SRC = $(TEST_DIR)/test_serial.cm
TEST_SERIAL_OBJ = .tmp/build/test_serial.o
TEST_SERIAL_EFI = .tmp/build/TEST_SERIAL.EFI
TEST_LOG = .tmp/serial.log
QEMU_TIMEOUT ?= 15
TIMEOUT := $(shell which timeout 2>/dev/null || which gtimeout 2>/dev/null || echo "")

.PHONY: all compile link run clean setup-esp download-ovmf test test-serial \
        cm-build cm-test cm-test-all cm-clean cm build-all clean-all help

# ============================================================
# デフォルト + ヘルプ
# ============================================================

all: $(EFI)

help:
	@echo "CosmOS - 統合Makefile"
	@echo ""
	@echo "カーネル操作:"
	@echo "  make              - カーネルをコンパイル＆リンク"
	@echo "  make compile      - カーネルのコンパイルのみ"
	@echo "  make all          - カーネルをコンパイル＆リンク"
	@echo "  make run          - QEMUで実行"
	@echo "  make test         - カーネルテスト（ブートフロー検証）"
	@echo "  make test-serial  - シリアル単体テスト"
	@echo "  make clean        - カーネル生成ファイル削除"
	@echo ""
	@echo "Cmコンパイラ操作:"
	@echo "  make cm-build     - Cmコンパイラをビルド"
	@echo "  make cm-test      - Cmユニットテスト"
	@echo "  make cm-test-all  - Cm全テスト"
	@echo "  make cm-clean     - Cmビルドをクリーン"
	@echo "  make cm CMD=<target> - Cm Makefileの任意ターゲットを実行"
	@echo ""
	@echo "統合操作:"
	@echo "  make build-all    - Cmコンパイラ + カーネルを全ビルド"
	@echo "  make clean-all    - 全ビルド成果物を削除"

# ============================================================
# 独立アプリケーションビルド
# ============================================================

OBJCOPY ?= /opt/homebrew/opt/llvm@17/bin/llvm-objcopy

# アプリケーションパス
APP_HELP_SRC  = $(KERNEL_DIR)/apps/help/help.cm
APP_HELP_OBJ  = .tmp/build/apps/app_help.o
APP_HELP_EFI  = .tmp/build/apps/app_help.efi
APP_HELP_BIN  = .tmp/build/apps/help.bin
APP_HELP_COSM = .tmp/build/apps/help.cosmexe

# helpアプリの独立ビルド（CosmEXEをESPに配置する方式）
app-help: $(APP_HELP_COSM)
$(APP_HELP_COSM): $(APP_HELP_SRC) $(shell find $(KERNEL_DIR)/apps/libcosm -name '*.cm' 2>/dev/null)
	@echo "=== helpアプリ独立ビルド ==="
	@mkdir -p .tmp/build/apps
	$(CM) compile --target=uefi -o $(APP_HELP_OBJ) $(APP_HELP_SRC)
	$(LLD) /subsystem:efi_application /entry:efi_main /out:$(APP_HELP_EFI) $(APP_HELP_OBJ)
	python3 ./scripts/pe2cosmexe.py $(APP_HELP_EFI) $(APP_HELP_COSM)
	@echo "✓ helpアプリビルド完了 ($(APP_HELP_COSM))"

# ============================================================
# カーネルビルド
# ============================================================

# カーネル全.cmファイルを依存関係に含める（importされるファイルの変更も検出）
KERNEL_SOURCES := $(shell find $(KERNEL_DIR) -name '*.cm' 2>/dev/null)

# Cmソースをコンパイル（uefiターゲット）
compile: $(KERNEL_OBJ) $(CHKSTK_OBJ)
$(KERNEL_OBJ): $(KERNEL_SOURCES)
	@mkdir -p .tmp/build
	$(CM) compile --target=uefi -o $(KERNEL_OBJ) $(KERNEL_SRC)

# スタックプローブスタブ（___chkstk_ms）
$(CHKSTK_OBJ): $(CHKSTK_SRC)
	@mkdir -p .tmp/build
	$(CLANG) -target x86_64-unknown-windows-msvc -c -o $(CHKSTK_OBJ) $(CHKSTK_SRC)

# PE/COFF EFIアプリケーションにリンク
link: $(EFI)
$(EFI): $(KERNEL_OBJ) $(CHKSTK_OBJ)
	$(LLD) /subsystem:efi_application /entry:efi_main /out:$(EFI) $(KERNEL_OBJ) $(CHKSTK_OBJ)

# ESP (EFI System Partition) ディレクトリ構造を作成
setup-esp: $(EFI) $(APP_HELP_COSM)
	@mkdir -p $(ESP_BOOT)
	@cp $(EFI) $(ESP_BOOT)/BOOTX64.EFI
	@cp $(APP_HELP_COSM) $(ESP_DIR)/help.cosmexe

# OVMFファームウェアをダウンロード
download-ovmf:
	@if [ ! -f "$(OVMF_FW)" ]; then \
		echo "OVMFファームウェアをダウンロード中..."; \
		mkdir -p $(OVMF_DIR); \
		curl -L -o "$(OVMF_FW)" "$(OVMF_URL)" 2>/dev/null || \
		wget -q -O "$(OVMF_FW)" "$(OVMF_URL)" 2>/dev/null || \
		{ echo "エラー: ダウンロードに失敗しました"; \
		  echo "手動で取得してください: $(OVMF_URL)"; \
		  echo "配置先: $(OVMF_FW)"; \
		  exit 1; }; \
		echo "ダウンロード完了: $(OVMF_FW)"; \
	else \
		echo "OVMF: $(OVMF_FW) (キャッシュ済み)"; \
	fi

# QEMUでUEFIアプリケーションを実行（GUI）
run: setup-esp download-ovmf
	@echo "=== CosmOS QEMU 起動 ==="
	@echo "OVMF: $(OVMF_FW)"
	@echo "EFI:  $(EFI)"
	@echo "=========================="
	$(QEMU) \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF_FW) \
		-drive format=raw,file=fat:rw:$(ESP_DIR) \
		-net none \
		-device virtio-gpu-pci \
		-display default,show-cursor=on \
		-serial mon:stdio

# ============================================================
# カーネルテスト
# ============================================================

DEBUG_LOG = .tmp/debug.log

# QEMU共通テストオプション
# isa-debug-exit: ゲストがport 0xf4に書き込むとQEMUが即座に終了
# 終了コード = (書き込み値 << 1) | 1
QEMU_TEST_OPTS = \
	-drive if=pflash,format=raw,readonly=on,file=$(OVMF_FW) \
	-drive format=raw,file=fat:rw:$(ESP_DIR) \
	-net none \
	-display none \
	-debugcon file:$(DEBUG_LOG) \
	-global isa-debugcon.iobase=0xE9 \
	-device isa-debug-exit,iobase=0xf4,iosize=0x04

# シリアル単体テスト
test-serial: download-ovmf
	@echo "=== シリアル単体テスト ==="
	@mkdir -p .tmp/build
	$(CM) compile --target=uefi -o $(TEST_SERIAL_OBJ) $(TEST_SERIAL_SRC)
	$(LLD) /subsystem:efi_application /entry:efi_main /out:$(TEST_SERIAL_EFI) $(TEST_SERIAL_OBJ)
	@mkdir -p $(ESP_BOOT)
	@cp $(TEST_SERIAL_EFI) $(ESP_BOOT)/BOOTX64.EFI
	@rm -f $(DEBUG_LOG)
	@echo "QEMU起動中（$(QEMU_TIMEOUT)秒タイムアウト）..."
	@$(TIMEOUT) $(QEMU_TIMEOUT) $(QEMU) $(QEMU_TEST_OPTS) 2>/dev/null || true
	@echo ""
	@echo "--- デバッグログ ---"
	@cat $(DEBUG_LOG) 2>/dev/null || echo "(ログなし)"
	@echo ""
	@echo "--- テスト結果 ---"
	@if [ ! -f "$(DEBUG_LOG)" ]; then \
		echo "✗ FAIL: デバッグログが生成されなかった"; \
	elif grep -q "ALL TESTS PASSED" $(DEBUG_LOG); then \
		TOTAL=$$(grep -c "\[PASS\]" $(DEBUG_LOG)); \
		echo "✓ ALL PASS ($$TOTAL tests)"; \
	else \
		grep "\[PASS\]\|\[FAIL\]" $(DEBUG_LOG) 2>/dev/null || echo "(テスト出力なし)"; \
		echo "✗ 一部テスト失敗"; \
	fi

# メインカーネルテスト（テスト専用バイナリを使用）
# isa-debug-exitでテスト完了時にQEMUが即座終了する
# exit 1 = テスト成功(fail=0), exit >1 = テスト失敗
test: download-ovmf
	@echo "=== メインカーネルテスト ==="
	@mkdir -p .tmp/build
	$(CM) compile --target=uefi -o $(TEST_KERNEL_OBJ) $(TEST_KERNEL_SRC)
	$(CLANG) -target x86_64-unknown-windows-msvc -c -o $(CHKSTK_OBJ) $(CHKSTK_SRC)
	$(LLD) /subsystem:efi_application /entry:efi_main /out:$(TEST_KERNEL_EFI) $(TEST_KERNEL_OBJ) $(CHKSTK_OBJ)
	@mkdir -p $(ESP_BOOT)
	@cp $(TEST_KERNEL_EFI) $(ESP_BOOT)/BOOTX64.EFI
	@if [ -f "$(APP_HELP_COSM)" ]; then cp $(APP_HELP_COSM) $(ESP_DIR)/help.cosmexe; fi
	@rm -f $(DEBUG_LOG)
	@QEMU_EXIT=0; \
	$(TIMEOUT) $(QEMU_TIMEOUT) $(QEMU) $(QEMU_TEST_OPTS) 2>/dev/null; \
	QEMU_EXIT=$$?; \
	echo ""; \
	grep "\[TEST\] PASS:\|\[TEST\] FAIL:" $(DEBUG_LOG) 2>/dev/null | while read line; do \
		echo "  $$line"; \
	done; \
	if [ ! -f "$(DEBUG_LOG)" ]; then \
		echo "✗ FAIL: デバッグログが生成されなかった"; \
		exit 1; \
	fi; \
	PASS=0; FAIL=0; \
	if grep -q "\[TEST\] PASS:" $(DEBUG_LOG) 2>/dev/null; then \
		PASS=$$(grep -c "\[TEST\] PASS:" $(DEBUG_LOG)); \
	fi; \
	if grep -q "\[TEST\] FAIL:" $(DEBUG_LOG) 2>/dev/null; then \
		FAIL=$$(grep -c "\[TEST\] FAIL:" $(DEBUG_LOG)); \
	fi; \
	echo ""; \
	echo "結果: $$PASS passed, $$FAIL failed"; \
	if [ $$FAIL -gt 0 ]; then \
		echo "✗ テスト失敗 ($$FAIL件のFAIL)"; \
		exit 1; \
	elif [ $$PASS -eq 0 ]; then \
		echo "✗ テスト失敗 (テスト結果なし)"; \
		exit 1; \
	elif [ $$QEMU_EXIT -eq 1 ]; then \
		echo "✓ テスト完了（QEMU正常終了, $$PASS PASS）"; \
	else \
		echo "✓ テスト完了（$$PASS PASS, QEMU exit=$$QEMU_EXIT）"; \
	fi

# ============================================================
# Cmコンパイラ操作（Cm/Makefileへの委譲）
# ============================================================

# Cmコンパイラをビルド
cm-build:
	@echo "=== Cmコンパイラビルド ==="
	@$(MAKE) -C $(CM_DIR) build

# Cmユニットテスト
cm-test:
	@echo "=== Cmユニットテスト ==="
	@$(MAKE) -C $(CM_DIR) test

# Cm全テスト
cm-test-all:
	@echo "=== Cm全テスト ==="
	@$(MAKE) -C $(CM_DIR) test-all

# Cmビルドをクリーン
cm-clean:
	@$(MAKE) -C $(CM_DIR) clean

# Cm Makefileの任意ターゲットを実行
# 使い方: make cm CMD="test-llvm"
CMD ?=
cm:
	@if [ -z "$(CMD)" ]; then \
		echo "使い方: make cm CMD=<target>"; \
		echo "例: make cm CMD=test-llvm"; \
		echo ""; \
		$(MAKE) -C $(CM_DIR) help; \
	else \
		$(MAKE) -C $(CM_DIR) $(CMD); \
	fi

# ============================================================
# 統合操作
# ============================================================

# Cmコンパイラ + カーネルを全ビルド
build-all: cm-build all
	@echo ""
	@echo "=========================================="
	@echo "✅ 全ビルド完了（Cmコンパイラ + カーネル）"
	@echo "=========================================="

# 全ビルド成果物を削除
clean-all: clean cm-clean
	@echo ""
	@echo "✅ 全クリーン完了"

# カーネル生成ファイル削除
clean:
	rm -rf .tmp/build .tmp/esp .tmp/serial.log
