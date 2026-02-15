# Cosmos OS Makefile
# 使い方:
#   make          - カーネルコンパイル＆リンク
#   make compile  - コンパイルのみ
#   make run      - QEMUで実行（OVMFを自動ダウンロード）
#   make clean    - 生成ファイル削除

# Cmコンパイラ（サブモジュール内）
CM ?= Cm/cm
LLD ?= lld-link
QEMU ?= qemu-system-x86_64

# OVMFファームウェアの配置先
OVMF_DIR ?= .tmp/ovmf
OVMF_FW ?= $(OVMF_DIR)/OVMF.fd

# OVMF ダウンロードURL (Arch: x86_64, Release build)
OVMF_URL ?= https://retrage.github.io/edk2-nightly/bin/RELEASEX64_OVMF.fd

# カーネルソース
KERNEL_SRC = kernel/boot/efi_main.cm
KERNEL_OBJ = .tmp/build/kernel.o
EFI = .tmp/build/BOOTX64.EFI
ESP_DIR = .tmp/esp
ESP_BOOT = $(ESP_DIR)/EFI/BOOT

.PHONY: all compile link run clean setup-esp download-ovmf

all: $(EFI)

# Cmソースをコンパイル（uefiターゲット）
compile: $(KERNEL_OBJ)
$(KERNEL_OBJ): $(KERNEL_SRC) $(CM)
	@mkdir -p .tmp/build
	$(CM) compile --target=uefi -o $(KERNEL_OBJ) $(KERNEL_SRC)

# PE/COFF EFIアプリケーションにリンク
link: $(EFI)
$(EFI): $(KERNEL_OBJ)
	$(LLD) /subsystem:efi_application /entry:efi_main /out:$(EFI) $(KERNEL_OBJ)

# ESP (EFI System Partition) ディレクトリ構造を作成
setup-esp: $(EFI)
	mkdir -p $(ESP_BOOT)
	cp $(EFI) $(ESP_BOOT)/BOOTX64.EFI

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

# QEMUでUEFIアプリケーションを実行
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

clean:
	rm -rf .tmp/build .tmp/esp
