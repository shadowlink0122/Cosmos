/* kernel/lib/chkstk.c - ___chkstk_ms スタブ（UEFI用）
 *
 * LLVM/Windows ターゲットは4KB以上のスタックフレームで自動挿入する。
 * ベアメタル環境ではスタックは既にマップ済みなのでno-op。
 */
void ___chkstk_ms(void) {
    /* no-op: ベアメタルではスタックプローブ不要 */
}
