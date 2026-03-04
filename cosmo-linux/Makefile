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

CM ?= ../Cm/cm
NASM ?= nasm
LD := x86_64-elf-ld
QEMU ?= qemu-system-x86_64

# Cmフラグ（baremetalターゲット = ELF出力）
CM_FLAGS = --target=baremetal-x86

# NASMフラグ
NASM_FLAGS = -f elf64

# リンカフラグ
LD_FLAGS = -T linker.ld -nostdlib -static -z noexecstack

# ============================================================
# ファイル設定
# ============================================================

BUILD = ../.tmp/cosmo-linux
ELF64 = $(BUILD)/cosmo-linux64.elf
ELF   = $(BUILD)/cosmo-linux.elf

# テスト用
TEST_ELF64 = $(BUILD)/test64.elf
TEST_ELF   = $(BUILD)/test.elf
TEST_OBJ   = $(BUILD)/test_kernel.o
TEST_SRC   = test/test_entry.cm

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

.PHONY: all build run test clean help

all: $(ELF)

build: clean all

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

$(ELF64): $(BOOT_OBJ) $(KERNEL_OBJ)
	@echo "[LD]   → $@"
	$(LD) $(LD_FLAGS) -o $@ $(BOOT_OBJ) $(KERNEL_OBJ)

$(ELF): $(ELF64)
	@echo "[CONV] elf64 → elf32 (QEMU Multiboot互換)"
	x86_64-elf-objcopy -O elf32-i386 $(ELF64) $(ELF)
	@echo "✓ ビルド完了: $@"

# ============================================================
# テストビルド
# ============================================================

$(TEST_OBJ): $(CM_SOURCES)
	@mkdir -p $(BUILD)
	@echo "[CM]   $(TEST_SRC) (test)"
	$(CM) compile $(CM_FLAGS) -o $@ $(TEST_SRC)

$(TEST_ELF64): $(BOOT_OBJ) $(TEST_OBJ)
	@echo "[LD]   → $@ (test)"
	$(LD) $(LD_FLAGS) -o $@ $(BOOT_OBJ) $(TEST_OBJ)

$(TEST_ELF): $(TEST_ELF64)
	@echo "[CONV] elf64 → elf32 (test)"
	x86_64-elf-objcopy -O elf32-i386 $(TEST_ELF64) $(TEST_ELF)
	@echo "✓ テストビルド完了: $@"

# ============================================================
# QEMU
# ============================================================

run: $(ELF)
	@echo "=== Cosmo Linux 起動 ==="
	@mkdir -p rootfs
	$(QEMU) \
		-kernel $(ELF) \
		-m $(QEMU_MEM) \
		-smp 1 \
		-serial stdio \
		-nic user,model=virtio-net-pci \
		-virtfs local,path=./rootfs,mount_tag=host,security_model=none,id=host0 \
		-no-reboot

# brew install用HTTPサーバ (別端末で実行)
# rootfs/packages/ のバイナリをゲストから HTTP GET で取得可能にする
serve:
	@echo "=== brew パッケージサーバ起動 ==="
	@echo "  http://localhost:8080/packages/<name> でパッケージ配信"
	@echo "  ゲストから: brew install <name>"
	@echo ""
	@lsof -ti :8080 | xargs kill 2>/dev/null || true
	cd rootfs && python3 -m http.server 8080

test: $(TEST_ELF)
	@echo "=== Cosmo Linux テスト ==="
	@rm -f $(BUILD)/serial.log
	@if [ -n "$(TIMEOUT)" ]; then \
		$(TIMEOUT) $(QEMU_TIMEOUT) $(QEMU) \
			-kernel $(TEST_ELF) -m $(QEMU_MEM) -smp 1 \
			-serial file:$(BUILD)/serial.log \
			-display none \
			-device isa-debug-exit,iobase=0xf4,iosize=0x04 \
			-no-reboot 2>/dev/null; \
	else \
		$(QEMU) \
			-kernel $(TEST_ELF) -m $(QEMU_MEM) -smp 1 \
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
	@if grep -q "KTEST_RESULT:PASS" $(BUILD)/serial.log 2>/dev/null; then \
		echo "✓ PASS — 全テスト合格"; \
	elif grep -q "KTEST_RESULT:FAIL" $(BUILD)/serial.log 2>/dev/null; then \
		echo "✗ FAIL — テスト失敗あり"; exit 1; \
	else \
		echo "? UNKNOWN — テスト結果マーカー未検出"; exit 1; \
	fi

clean:
	rm -rf $(BUILD)
	@echo "✓ クリーン完了"
