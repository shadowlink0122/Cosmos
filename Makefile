# Cosmos OS Makefile
# 使い方:
#   make          - コンパイル＆リンク
#   make compile  - コンパイルのみ
#   make run      - QEMUで実行（OVMFを自動ダウンロード）
#   make clean    - 生成ファイル削除

CM ?= cm
LLD ?= lld-link
QEMU ?= qemu-system-x86_64

# OVMFファームウェアの配置先
OVMF_DIR ?= .tmp/ovmf
OVMF_FW ?= $(OVMF_DIR)/OVMF.fd

# OVMF ダウンロードURL (Arch: x86_64, Release build)
OVMF_URL ?= https://retrage.github.io/edk2-nightly/bin/RELEASEX64_OVMF.fd

# カーネルソース
KERNEL_DIR = kernel
KERNEL_SRC = $(KERNEL_DIR)/efi_main.cm
KERNEL_OBJ = .tmp/build/kernel.o
EFI = .tmp/build/BOOTX64.EFI
ESP_DIR = .tmp/esp
ESP_BOOT = $(ESP_DIR)/EFI/BOOT

# テスト
TEST_DIR = tests
TEST_SERIAL_SRC = $(TEST_DIR)/test_serial.cm
TEST_SERIAL_OBJ = .tmp/build/test_serial.o
TEST_SERIAL_EFI = .tmp/build/TEST_SERIAL.EFI
TEST_LOG = .tmp/serial.log
QEMU_TIMEOUT ?= 15
TIMEOUT := $(shell which timeout 2>/dev/null || which gtimeout 2>/dev/null || echo "")

.PHONY: all compile link run clean setup-esp download-ovmf test test-serial

all: $(EFI)

# Cmソースをコンパイル（uefiターゲット）
compile: $(KERNEL_OBJ)
$(KERNEL_OBJ): $(KERNEL_SRC)
	@mkdir -p .tmp/build
	$(CM) compile --target=uefi -o $(KERNEL_OBJ) $(KERNEL_SRC)

# PE/COFF EFIアプリケーションにリンク
link: $(EFI)
$(EFI): $(KERNEL_OBJ)
	$(LLD) /subsystem:efi_application /entry:efi_main /out:$(EFI) $(KERNEL_OBJ)

# ESP (EFI System Partition) ディレクトリ構造を作成
setup-esp: $(EFI)
	@mkdir -p $(ESP_BOOT)
	@cp $(EFI) $(ESP_BOOT)/BOOTX64.EFI

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
	@echo "=== Cosmos OS QEMU 起動 ==="
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
# テストターゲット
# ============================================================
# テスト出力はQEMUデバッグポート(0xE9)経由でdebug.logに出力。
# OVMFのシリアル出力とは独立したクリーンなチャネル。

DEBUG_LOG = .tmp/debug.log

# QEMU共通テストオプション
QEMU_TEST_OPTS = \
	-drive if=pflash,format=raw,readonly=on,file=$(OVMF_FW) \
	-drive format=raw,file=fat:rw:$(ESP_DIR) \
	-net none \
	-display none \
	-debugcon file:$(DEBUG_LOG) \
	-global isa-debugcon.iobase=0xE9

# シリアル単体テスト: UART COM1 + デバッグポート出力を検証
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

# メインカーネルテスト: デバッグポートでブートフローを検証
test: setup-esp download-ovmf
	@echo "=== メインカーネルテスト ==="
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
	else \
		PASS=0; FAIL=0; \
		if grep -q "\[BOOT\] serial_init" $(DEBUG_LOG); then \
			echo "✓ PASS: シリアル初期化"; PASS=$$((PASS+1)); \
		else \
			echo "✗ FAIL: シリアル初期化"; FAIL=$$((FAIL+1)); \
		fi; \
		if grep -q "\[BOOT\] ExitBootServices OK" $(DEBUG_LOG); then \
			echo "✓ PASS: ExitBootServices"; PASS=$$((PASS+1)); \
		else \
			echo "✗ FAIL: ExitBootServices"; FAIL=$$((FAIL+1)); \
		fi; \
		if grep -q "\[BOOT\] kernel_main entered" $(DEBUG_LOG); then \
			echo "✓ PASS: カーネル起動"; PASS=$$((PASS+1)); \
		else \
			echo "✗ FAIL: カーネル起動"; FAIL=$$((FAIL+1)); \
		fi; \
		if grep -q "\[BOOT\] gdt_init: done" $(DEBUG_LOG); then \
			echo "✓ PASS: GDT初期化"; PASS=$$((PASS+1)); \
		else \
			echo "✗ FAIL: GDT初期化"; FAIL=$$((FAIL+1)); \
		fi; \
		if grep -q "\[BOOT\] PIC initialized" $(DEBUG_LOG); then \
			echo "✓ PASS: PIC初期化"; PASS=$$((PASS+1)); \
		else \
			echo "✗ FAIL: PIC初期化"; FAIL=$$((FAIL+1)); \
		fi; \
		if grep -q "\[BOOT\] IDT initialized" $(DEBUG_LOG); then \
			echo "✓ PASS: IDT初期化"; PASS=$$((PASS+1)); \
		else \
			echo "✗ FAIL: IDT初期化"; FAIL=$$((FAIL+1)); \
		fi; \
		if grep -q "\[BOOT\] ISR registered" $(DEBUG_LOG); then \
			echo "✓ PASS: ISR登録"; PASS=$$((PASS+1)); \
		else \
			echo "✗ FAIL: ISR登録"; FAIL=$$((FAIL+1)); \
		fi; \
		echo ""; \
		echo "結果: $$PASS passed, $$FAIL failed"; \
	fi

clean:
	rm -rf .tmp/build .tmp/esp .tmp/serial.log
