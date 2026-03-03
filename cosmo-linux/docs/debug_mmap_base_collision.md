# musl mallocng exit #PF デバッグ記録

## 問題

`busybox echo hello world`がexit時に#PF(CR2=0x10)でcrash。  
musl-libcの`free()`→`__bin_chunk()`がNULLポインタ(prev=0)参照。

## 根本原因

`MMAP_BASE=0x10000000`がboot identity map(0-1GB, 512×2MBページ)と衝突。

### メカニズム

```
1. boot header.S: PD[0-511]に2MBページ = 0x00000000-0x3FFFFFFF identity map
2. mmap(0, 0x1000, PROT_RW) → find_free_region → VA=0x10000000
3. PMM→物理ページ確保(例: PA=0x1234000)
4. map_page(VA=0x10000000, PA=0x1234000, flags=7):
   → PD[128]にすでに2MB entry (PA=0x10000000 | PS=1 | P=1 | W=1)
   → entry_present(pd_entry) → true (PS bitを無視！)
   → entry_addr(pd_entry) → 0x10000000 を "PTアドレス" と誤認
   → write_entry(0x10000000, 0, 0x1234007) → phys 0x10000000[0]に書込
5. VA=0x10000000は依然2MB identity map → phys 0x10000000に解決
6. memzero(PA=0x1234000)で正しい物理ページをゼロクリア → VA経由でアクセス不可
```

## 修正

| 項目 | Before | After |
|------|--------|-------|
| MMAP_BASE | 0x10000000 (identity map内) | 0x40000000 (1GB超、identity map外) |
| mmap MAP_FIXED | VMA登録のみ | 既存ページスキップ + 未マッピング時新規割当 |
| syscall stub | RDI/RSI/RDX/R10/R8/R9未復帰 | 全レジスタ保存・復帰 |

## デバッグ手法

1. **syscallトレース強化**: brk/mmap引数+返り値出力
2. **DEADBEEF test write**: mmapハンドラ内でtest valueを書込
   - brk(0x714000)は保持 → identity map内の通常4KB mapping(0x714000はloader設定済み)
   - mmap(0x10000000)は消失 → 物理ページとVAマッピングの不一致を証明
3. **boot header.S解析**: 512×2MB=1GB identity mapを確認
4. **objdump**: `__bin_chunk`の逆アセンブリでcrash箇所の完全再現

## 教訓

- `map_page`は2MBページ(PD entry PS bit)を検知しない → 将来的に4KB splitting対応が必要
- MMAP_BASEはidentity map外に配置する必要がある
- musl mallocngはmmap領域にメタデータを書き込むため、mmapが正しくページを割り当てないとfree()でcrashする
