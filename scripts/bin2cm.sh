#!/bin/sh
# bin2cm.sh - バイナリファイルをCm言語の埋め込みデータ関数に変換する
#
# movq命令でu64単位にメモリ書き込み。NULバイト安全。
# Cmパーサーのブロック反復上限を回避するため1関数あたり最大30チャンクに分割。
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

# ヘッダ出力
cat > "$OUTPUT" << 'HEADER'
//! platform: uefi
// 自動生成ファイル — 手動で編集しないでください

/// 8バイト書き込みヘルパー
HEADER
echo "export void ${FUNC}_w8(ulong addr, ulong val) {" >> "$OUTPUT"
# Cm inline asmのエスケープ: ${r:val}をそのまま出力
printf '    __asm__(` movq ${r:val}, %%rax; movq ${r:addr}, %%rdi; movq %%rax, (%%rdi) `);\n' >> "$OUTPUT"
echo "}" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# メイン処理: 一時ファイルから読み取り
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
        echo "export void ${FUNC}_p${sub}(ulong dst) {" >> "$OUTPUT"
        in_func=1
        sub=$((sub + 1))
    fi

    offset=$((n * 8))
    echo "    ${FUNC}_w8(dst + ${offset}, ${val});" >> "$OUTPUT"
    n=$((n + 1))
done < "$TMPFILE"

# 最後のサブ関数を閉じる
if [ $in_func -eq 1 ]; then
    echo "}" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
fi

# メイン関数
echo "/// 埋め込みバイナリをdstにコピー" >> "$OUTPUT"
echo "/// 戻り値: バイト数" >> "$OUTPUT"
echo "export ulong ${FUNC}(ulong dst) {" >> "$OUTPUT"

i=0
while [ $i -lt $sub ]; do
    echo "    ${FUNC}_p${i}(dst);" >> "$OUTPUT"
    i=$((i + 1))
done

echo "    return ${SIZE};" >> "$OUTPUT"
echo "}" >> "$OUTPUT"

echo "生成: $OUTPUT ($SIZE bytes, $n u64s, $sub subs)"
