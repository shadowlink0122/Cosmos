# Cosmo Linux - ビルドシステム
#
# 使い方:
#   make       - カーネルビルド
#   make run   - QEMU実行（シリアルコンソール）
#   make test  - テスト実行（自動終了）
#   make clean - クリーン

# ============================================================
# ツール設定
# ============================================================

CM ?= cm
NASM ?= nasm
LD ?= ld
QEMU ?= qemu-system-x86_64

# Cmフラグ（baremetalターゲット = ELF出力）
CM_FLAGS = --target=uefi

# NASMフラグ
NASM_FLAGS = -f elf64

# リンカフラグ
LD_FLAGS = -T linker.ld -nostdlib -static -z noexecstack

# ============================================================
# ファイル設定
# ============================================================

BUILD = ../.tmp/cosmo-linux
ELF   = $(BUILD)/cosmo-linux.elf

# ソース
BOOT_ASM    = boot/header.S
BOOT_OBJ    = $(BUILD)/header.o
KERNEL_SRC  = boot/entry.cm
KERNEL_OBJ  = $(BUILD)/kernel.o

# 依存関係追跡用
CM_SOURCES = $(shell find . -name '*.cm' 2>/dev/null)

# QEMU設定
QEMU_MEM    ?= 256M
QEMU_TIMEOUT ?= 10
TIMEOUT := $(shell which timeout 2>/dev/null || which gtimeout 2>/dev/null || echo "")

# ============================================================
# ビルド
# ============================================================

.PHONY: all run test clean help

all: $(ELF)

help:
	@echo "Cosmo Linux ビルドシステム"
	@echo "  make       - ビルド"
	@echo "  make run   - QEMU起動"
	@echo "  make test  - テスト"
	@echo "  make clean - クリーン"

$(BOOT_OBJ): $(BOOT_ASM)
	@mkdir -p $(BUILD)
	@echo "[ASM]  $<"
	$(NASM) $(NASM_FLAGS) -o $@ $<

$(KERNEL_OBJ): $(CM_SOURCES)
	@mkdir -p $(BUILD)
	@echo "[CM]   $(KERNEL_SRC)"
	$(CM) compile $(CM_FLAGS) -o $@ $(KERNEL_SRC)

$(ELF): $(BOOT_OBJ) $(KERNEL_OBJ)
	@echo "[LD]   → $@"
	$(LD) $(LD_FLAGS) -o $@ $(BOOT_OBJ) $(KERNEL_OBJ)
	@echo "✓ ビルド完了: $@"

# ============================================================
# QEMU
# ============================================================

run: $(ELF)
	@echo "=== Cosmo Linux 起動 ==="
	$(QEMU) \
		-kernel $(ELF) \
		-m $(QEMU_MEM) \
		-smp 1 \
		-serial stdio \
		-display none \
		-no-reboot

test: $(ELF)
	@echo "=== Cosmo Linux テスト ==="
	@rm -f $(BUILD)/serial.log
	@if [ -n "$(TIMEOUT)" ]; then \
		$(TIMEOUT) $(QEMU_TIMEOUT) $(QEMU) \
			-kernel $(ELF) -m $(QEMU_MEM) -smp 1 \
			-serial file:$(BUILD)/serial.log \
			-display none \
			-device isa-debug-exit,iobase=0xf4,iosize=0x04 \
			-no-reboot 2>/dev/null; \
	else \
		$(QEMU) \
			-kernel $(ELF) -m $(QEMU_MEM) -smp 1 \
			-serial file:$(BUILD)/serial.log \
			-display none \
			-device isa-debug-exit,iobase=0xf4,iosize=0x04 \
			-no-reboot 2>/dev/null & \
		sleep $(QEMU_TIMEOUT); kill $$! 2>/dev/null || true; \
	fi
	@echo ""
	@echo "--- シリアル出力 ---"
	@cat $(BUILD)/serial.log 2>/dev/null || echo "(出力なし)"
	@echo ""
	@echo "--- 結果 ---"
	@if grep -q "Cosmo Linux" $(BUILD)/serial.log 2>/dev/null; then \
		echo "✓ PASS"; \
	else \
		echo "✗ FAIL"; exit 1; \
	fi

clean:
	rm -rf $(BUILD)
	@echo "✓ クリーン完了"
