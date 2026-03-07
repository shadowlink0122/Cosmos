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

CM ?= Cm/cm
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

BUILD = .tmp/cosmo-linux
ELF64 = $(BUILD)/cosmo-linux64.elf
ELF   = $(BUILD)/cosmo-linux.elf

# テスト用
TEST_ELF64 = $(BUILD)/test64.elf
TEST_ELF   = $(BUILD)/test.elf
TEST_OBJ   = $(BUILD)/test_kernel.o
TEST_SRC   = tests/test_entry.cm

# ソース
BOOT_ASM    = boot/header.S
BOOT_OBJ    = $(BUILD)/header.o
KERNEL_SRC  = boot/entry.cm
KERNEL_OBJ  = $(BUILD)/kernel.o

# 依存関係追跡用
CM_SOURCES = $(shell find . -name '*.cm' 2>/dev/null)

# QEMU設定
QEMU_MEM    ?= 2G
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
# 分割コンパイル（高速インクリメンタルビルド）
# core.o + ui.o を並列コンパイルしてリンク
# 使い方: make fast    (シーケンシャル)
#         make -j2 fast (並列)
# ============================================================

CORE_SRC = boot/entry_core.cm
UI_SRC   = ui/ui_entry.cm
CORE_OBJ = $(BUILD)/core.o
UI_OBJ   = $(BUILD)/ui.o
FAST_ELF64 = $(BUILD)/cosmo-fast64.elf
FAST_ELF   = $(BUILD)/cosmo-fast.elf

# 分割コンパイル用: core/uiそれぞれの依存ソース
CORE_SOURCES = $(shell find arch boot include lib mm sched sys fs exec init drivers net -name '*.cm' 2>/dev/null)
UI_SOURCES   = $(shell find ui pkg -name '*.cm' 2>/dev/null)

.PHONY: fast
fast: $(FAST_ELF)

$(CORE_OBJ): $(CORE_SOURCES)
	@mkdir -p $(BUILD)
	@echo "[CM]   $(CORE_SRC) → core.o"
	$(CM) compile $(CM_FLAGS) -o $@ $(CORE_SRC)

$(UI_OBJ): $(UI_SOURCES) $(CORE_SOURCES)
	@mkdir -p $(BUILD)
	@echo "[CM]   $(UI_SRC) → ui.o"
	$(CM) compile $(CM_FLAGS) -o $@ $(UI_SRC)

$(FAST_ELF64): $(BOOT_OBJ) $(CORE_OBJ) $(UI_OBJ)
	@echo "[LD]   → $@ (分割リンク)"
	$(LD) $(LD_FLAGS) --allow-multiple-definition -o $@ $(BOOT_OBJ) $(CORE_OBJ) $(UI_OBJ)

$(FAST_ELF): $(FAST_ELF64)
	@echo "[CONV] elf64 → elf32 (QEMU Multiboot互換)"
	x86_64-elf-objcopy -O elf32-i386 $(FAST_ELF64) $(FAST_ELF)
	@echo "✓ 分割ビルド完了: $@"

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
		-vga std \
		-serial stdio \
		-nic user,model=virtio-net-pci \
		-virtfs local,path=./rootfs,mount_tag=host,security_model=none,id=host0 \
		-no-reboot

# curlテスト: QEMU起動→自動実行→シリアルログ確認
run-curl: $(ELF)
	@echo "=== curl --version テスト ==="
	@rm -f $(BUILD)/serial_curl.log /tmp/cosmo_qemu_mon.sock
	@$(QEMU) \
		-kernel $(ELF) \
		-m $(QEMU_MEM) \
		-smp 1 \
		-serial file:$(BUILD)/serial_curl.log \
		-nic user,model=virtio-net-pci \
		-virtfs local,path=./rootfs,mount_tag=host,security_model=none,id=host0 \
		-display none \
		-monitor unix:/tmp/cosmo_qemu_mon.sock,server=on,wait=off \
		-no-reboot &
	@sleep 4
	@python3 -c "\
import socket, time; \
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); \
s.connect('/tmp/cosmo_qemu_mon.sock'); \
time.sleep(0.5); s.recv(4096); \
for k in 'curl': \
    s.sendall(('sendkey ' + k + '\n').encode()); time.sleep(0.15); s.recv(4096); \
s.sendall(b'sendkey ret\n'); time.sleep(8); s.recv(4096); \
s.sendall(b'quit\n'); s.close()"
	@echo ""
	@echo "--- シリアルログ (curl) ---"
	@cat $(BUILD)/serial_curl.log 2>/dev/null | tail -40
	@rm -f /tmp/cosmo_qemu_mon.sock

# bashテスト: gen install bash → exec bash --version → シリアルログ確認
run-bash: $(ELF)
	@echo "=== bash --version 統合テスト ==="
	@rm -f $(BUILD)/serial_bash.log /tmp/cosmo_qemu_mon.sock
	@$(QEMU) \
		-kernel $(ELF) \
		-m $(QEMU_MEM) \
		-smp 1 \
		-serial file:$(BUILD)/serial_bash.log \
		-nic user,model=virtio-net-pci \
		-virtfs local,path=./rootfs,mount_tag=host,security_model=none,id=host0 \
		-display none \
		-monitor unix:/tmp/cosmo_qemu_mon.sock,server=on,wait=off \
		-no-reboot &
	@sleep 4
	@python3 scripts/qemu_sendkeys.py "gen install bash:12" "bash --version:5"
	@echo ""
	@echo "--- シリアルログ (bash) ---"
	@cat $(BUILD)/serial_bash.log 2>/dev/null | tail -60
	@echo ""
	@echo "--- 結果 ---"
	@if grep -q "arch_prctl" $(BUILD)/serial_bash.log 2>/dev/null; then \
		echo "✓ arch_prctl呼出し検出 — TLS初期化成功"; \
	else \
		echo "△ arch_prctl未検出"; \
	fi
	@if grep -q "PAGE FAULT" $(BUILD)/serial_bash.log 2>/dev/null; then \
		echo "✗ FAIL — PAGE FAULT検出"; \
		grep "CR2" $(BUILD)/serial_bash.log; exit 1; \
	else \
		echo "✓ PASS — PAGE FAULT なし"; \
	fi
	@rm -f /tmp/cosmo_qemu_mon.sock

# brew install用HTTPサーバ (別端末で実行)
# rootfs/packages/ のバイナリをゲストから HTTP GET で取得可能にする
serve:
	@echo "=== brew パッケージサーバ起動 ==="
	@echo "  http://localhost:8080/packages/<name> でパッケージ配信"
	@echo "  ゲストから: brew install <name>"
	@echo ""
	@lsof -ti :8080 | xargs kill 2>/dev/null || true
	cd rootfs && python3 -m http.server 8080

# Cmプログラムをクロスコンパイルしてrootfs/packages/に配置
# 使い方: make cm-build SRC=programs/hello.cm
# 9p共有でCosmo Linuxから直接実行可能
cm-build:
	@if [ -z "$(SRC)" ]; then \
		echo "Usage: make cm-build SRC=<file.cm>"; \
		echo "  例: make cm-build SRC=programs/hello.cm"; \
		exit 1; \
	fi
	@mkdir -p $(BUILD) rootfs/packages
	@NAME=$$(basename $(SRC) .cm); \
	echo "[CM]   $(SRC) → $$NAME (cosmo-linux)"; \
	$(CM) compile --target=baremetal-x86 -o $(BUILD)/$$NAME.o $(SRC) && \
	$(LD) -T linker-user.ld -nostdlib -static -z noexecstack -o rootfs/packages/$$NAME $(BUILD)/$$NAME.o && \
	echo "✓ rootfs/packages/$$NAME ($$(wc -c < rootfs/packages/$$NAME | tr -d ' ')B)"

# programs/*.cm を一括ビルド
cm-build-all:
	@mkdir -p $(BUILD) rootfs/packages
	@for src in programs/*.cm; do \
		[ -f "$$src" ] || continue; \
		NAME=$$(basename $$src .cm); \
		echo "[CM]   $$src → $$NAME"; \
		$(CM) compile --target=baremetal-x86 -o $(BUILD)/$$NAME.o $$src && \
		$(LD) -T linker-user.ld -nostdlib -static -z noexecstack -o rootfs/packages/$$NAME $(BUILD)/$$NAME.o && \
		echo "✓ rootfs/packages/$$NAME"; \
	done
	@echo "✓ 全プログラムビルド完了"

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

# GCCコンパイル済みバイナリ実行テスト
test-gcc: $(ELF)
	@echo "=== GCC コンパイル済みバイナリ実行テスト ==="
	@rm -f $(BUILD)/serial_gcc_test.log /tmp/cosmo_qemu_mon.sock
	@$(QEMU) -kernel $(ELF) -m $(QEMU_MEM) -smp 1 \
		-serial file:$(BUILD)/serial_gcc_test.log \
		-nic user,model=virtio-net-pci \
		-virtfs local,path=./rootfs,mount_tag=host,security_model=none,id=host0 \
		-display none \
		-monitor unix:/tmp/cosmo_qemu_mon.sock,server=on,wait=off \
		-no-reboot & sleep 20 && \
	python3 scripts/qemu_sendkeys.py "hellogcc:10" && \
	rm -f /tmp/cosmo_qemu_mon.sock
	@echo ""
	@echo "--- 結果 ---"
	@if grep -q "Hello from GCC!" $(BUILD)/serial_gcc_test.log 2>/dev/null; then \
		echo "✓ PASS — hellogcc: Hello from GCC! 出力確認"; \
	else \
		echo "✗ FAIL — hellogcc: 期待出力なし"; exit 1; \
	fi

clean:
	rm -rf $(BUILD)
	@echo "✓ クリーン完了"

# ============================================================
# Homebrew依存ツール: Dockerビルド (x86_64 musl静的リンク)
# ============================================================

DOCKER_PLATFORM = --platform linux/amd64

# bash 5.2.37
brew-bash:
	docker build $(DOCKER_PLATFORM) -f Dockerfile.bash -t cosmo-bash .
	docker run --rm $(DOCKER_PLATFORM) cosmo-bash > rootfs/packages/bash
	chmod +x rootfs/packages/bash
	@file rootfs/packages/bash
	@ls -lh rootfs/packages/bash

# Git 2.47.1
brew-git:
	docker build $(DOCKER_PLATFORM) -f Dockerfile.git -t cosmo-git .
	docker run --rm $(DOCKER_PLATFORM) cosmo-git > rootfs/packages/git
	chmod +x rootfs/packages/git
	@file rootfs/packages/git
	@ls -lh rootfs/packages/git

# Ruby 3.4.2
brew-ruby:
	docker build $(DOCKER_PLATFORM) -f Dockerfile.ruby -t cosmo-ruby .
	docker run --rm $(DOCKER_PLATFORM) cosmo-ruby > rootfs/packages/ruby
	chmod +x rootfs/packages/ruby
	@file rootfs/packages/ruby
	@ls -lh rootfs/packages/ruby

# 全ツール一括ビルド
brew-tools: brew-bash brew-git brew-ruby
	@echo "✓ Homebrew依存ツール全ビルド完了"
	@echo "  bash: $$(ls -lh rootfs/packages/bash | awk '{print $$5}')"
	@echo "  git:  $$(ls -lh rootfs/packages/git | awk '{print $$5}')"
	@echo "  ruby: $$(ls -lh rootfs/packages/ruby | awk '{print $$5}')"
