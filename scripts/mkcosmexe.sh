#!/bin/sh
# mkcosmexe.sh - フラットバイナリにCosmEXEヘッダを付与する
#
# 使い方:
#   ./scripts/mkcosmexe.sh input.bin output.cosmexe [entry_offset]
#   ./scripts/mkcosmexe.sh input.bin output.cosmexe --efi=app.efi
#
# --efi=FILE を指定すると、PE/COFFからエントリオフセットを自動取得。
#
# CosmEXEフォーマット (32バイトヘッダ):
#   [0x00] magic:     8B = "CosmEXE\0"
#   [0x08] entry:     8B = エントリポイントオフセット
#   [0x10] code_size: 8B = コードサイズ
#   [0x18] flags:     8B = 予約(0)
#   [0x20] code:      ... = 実行コード

set -e

LLVM_READOBJ="${LLVM_READOBJ:-/opt/homebrew/opt/llvm@17/bin/llvm-readobj}"

if [ $# -lt 2 ]; then
    echo "使い方: $0 input.bin output.cosmexe [entry_offset|--efi=app.efi]"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"
ENTRY=0

# 第3引数の処理
if [ $# -ge 3 ]; then
    case "$3" in
        --efi=*)
            # PE/COFFからエントリオフセットを自動取得
            # NOTE: objcopy -O binary が PE ヘッダを再配置する場合があるため
            #       実際に埋め込む入力バイナリ ($INPUT) のヘッダを読み取る
            ENTRY_RVA=$("$LLVM_READOBJ" --headers "$INPUT" 2>/dev/null \
                | grep "AddressOfEntryPoint" | awk '{print $2}')
            SECTION_VA=$("$LLVM_READOBJ" --sections "$INPUT" 2>/dev/null \
                | grep -A3 ".text" | grep "VirtualAddress" | awk '{print $2}')
            RAW_DATA_OFF=$("$LLVM_READOBJ" --sections "$INPUT" 2>/dev/null \
                | grep -A5 ".text" | grep "PointerToRawData" | awk '{print $2}')
            # 16進→10進変換してファイルオフセット計算
            # ENTRY = PointerToRawData + (AddressOfEntryPoint - VirtualAddress)
            ENTRY_RVA_DEC=$(printf '%d' "$ENTRY_RVA")
            SECTION_VA_DEC=$(printf '%d' "$SECTION_VA")
            RAW_DATA_DEC=$(printf '%d' "$RAW_DATA_OFF")
            ENTRY=$((RAW_DATA_DEC + ENTRY_RVA_DEC - SECTION_VA_DEC))
            ;;
        *)
            ENTRY=$(printf '%d' "$3")
            ;;
    esac
fi

CODE_SIZE=$(wc -c < "$INPUT" | tr -d ' ')

# リトルエンディアンu64をバイト列で出力する関数
write_le64() {
    val=$1
    i=0
    while [ $i -lt 8 ]; do
        byte=$((val & 0xFF))
        printf "\\$(printf '%03o' "$byte")"
        val=$((val >> 8))
        i=$((i + 1))
    done
}

# ヘッダ出力（32バイト）
{
    printf 'CosmEXE\0'          # magic: "CosmEXE\0" (8バイト)
    write_le64 "$ENTRY"          # entry offset (8バイト)
    write_le64 "$CODE_SIZE"      # code_size (8バイト)
    write_le64 0                 # flags (8バイト、予約)
} > "$OUTPUT"

# コード本体を追記
cat "$INPUT" >> "$OUTPUT"

TOTAL=$(wc -c < "$OUTPUT" | tr -d ' ')
echo "CosmEXE: $TOTAL bytes (code=$CODE_SIZE, entry=0x$(printf '%x' $ENTRY))"
