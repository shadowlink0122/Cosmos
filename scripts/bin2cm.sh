#!/bin/sh
# bin2cm.sh - バイナリファイルをCm言語の埋め込みデータに変換する
#
# データ配列+ループ方式: 固定メモリにデータを書き込み、ループでdstにコピー。
# Cmパーサーのブロック反復上限を回避するため1サブ関数あたり最大30チャンクに分割。
#
# 使い方: ./scripts/bin2cm.sh input.cosmexe output.cm func_name

set -e

if [ $# -lt 3 ]; then
    echo "使い方: $0 input.cosmexe output.cm func_name"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"
FUNC="$3"
CPF=30  # 1サブ関数あたりの最大チャンク数

SIZE=$(wc -c < "$INPUT" | tr -d ' ')

# u64 hexダンプを一時ファイルに保存
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
xxd -p -c 8 "$INPUT" > "$TMPFILE"

TOTAL_LINES=$(wc -l < "$TMPFILE" | tr -d ' ')

# 8バイト境界にパディング
PADDED_SIZE=$(( (SIZE + 7) / 8 * 8 ))
TOTAL_U64=$TOTAL_LINES

# ヘッダ出力
cat > "$OUTPUT" << 'HEADER'
//! platform: uefi
// 自動生成ファイル — 手動で編集しないでください
//
// データ配列+ループ方式:
//   1. サブ関数がスクラッチ領域にデータを書き込む
//   2. embed_help() がループでdstにコピー

HEADER

echo "/// 8バイト書き込みヘルパー" >> "$OUTPUT"
echo "export void ${FUNC}_w8(ulong addr, ulong val) {" >> "$OUTPUT"
printf '    __asm__(` movq ${r:val}, %%rax; movq ${r:addr}, %%rdi; movq %%rax, (%%rdi) `);\n' >> "$OUTPUT"
echo "}" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# スクラッチ領域アドレス (高位の未使用領域)
SCRATCH="0x20000"
echo "// スクラッチ領域: ${SCRATCH} (${PADDED_SIZE} bytes)" >> "$OUTPUT"
echo "const ulong EMBED_SCRATCH = ${SCRATCH};" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# サブ関数生成: スクラッチ領域にデータを直接書き込む
n=0
sub=0
in_func=0

while IFS= read -r hex; do
    # 16文字にパディング
    while [ ${#hex} -lt 16 ]; do
        hex="${hex}0"
    done

    # リトルエンディアンu64変換
    val="0x$(echo "$hex" | sed 's/\(..\)/\1 /g' | awk '{for(i=NF;i>=1;i--) printf "%s",$i}')"

    # サブ関数開始
    if [ $((n % CPF)) -eq 0 ]; then
        if [ $in_func -eq 1 ]; then
            echo "}" >> "$OUTPUT"
            echo "" >> "$OUTPUT"
        fi
        echo "export void ${FUNC}_p${sub}() {" >> "$OUTPUT"
        in_func=1
        sub=$((sub + 1))
    fi

    offset=$((n * 8))
    echo "    ${FUNC}_w8(EMBED_SCRATCH + ${offset}, ${val});" >> "$OUTPUT"
    n=$((n + 1))
done < "$TMPFILE"

# 最後のサブ関数を閉じる
if [ $in_func -eq 1 ]; then
    echo "}" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
fi

# メイン関数: サブ関数でスクラッチ領域にデータを配置 → ループでdstにコピー
echo "/// 埋め込みバイナリをdstにコピー" >> "$OUTPUT"
echo "/// 戻り値: バイト数" >> "$OUTPUT"
echo "export ulong ${FUNC}(ulong dst) {" >> "$OUTPUT"
echo "    // スクラッチ領域にデータを配置" >> "$OUTPUT"

i=0
while [ $i -lt $sub ]; do
    echo "    ${FUNC}_p${i}();" >> "$OUTPUT"
    i=$((i + 1))
done

echo "" >> "$OUTPUT"
echo "    // ループでdstにコピー" >> "$OUTPUT"
echo "    ulong i = 0;" >> "$OUTPUT"
echo "    ulong count = ${TOTAL_U64};" >> "$OUTPUT"
echo "    while (i < count) {" >> "$OUTPUT"
echo "        ulong offset = i * 8;" >> "$OUTPUT"
echo "        ulong src_addr = EMBED_SCRATCH + offset;" >> "$OUTPUT"
echo "        ulong* src = src_addr as ulong*;" >> "$OUTPUT"
echo "        ulong val = *src;" >> "$OUTPUT"
echo "        ${FUNC}_w8(dst + offset, val);" >> "$OUTPUT"
echo "        i = i + 1;" >> "$OUTPUT"
echo "    }" >> "$OUTPUT"
echo "    return ${SIZE};" >> "$OUTPUT"
echo "}" >> "$OUTPUT"

echo "生成: $OUTPUT ($SIZE bytes, $n u64s, $sub subs)"
