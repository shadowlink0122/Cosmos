#!/usr/bin/env python3
"""PE/COFFファイルからCosmEXEバイナリを生成する。

objcopy -O binary はPE/COFFのセクションをVAオフセットに正しく配置しない場合がある。
このスクリプトはPEヘッダを解析し、各セクションをVAオフセットに従って
フラットバイナリとして配置し、CosmEXEヘッダを付与する。

CosmEXEフォーマット (32バイトヘッダ):
  [0x00] magic:     8B = "CosmEXE\0"
  [0x08] entry:     8B = エントリポイントオフセット（コード先頭からの相対）
  [0x10] code_size: 8B = コードサイズ
  [0x18] flags:     8B = 予約(0)
  [0x20] code:      ... = フラットバイナリ（セクションがVA配置済み）

使い方: python3 pe2cosmexe.py input.efi output.cosmexe
"""
import struct
import sys
import os


def read_pe_sections(data: bytes):
    """PE/COFFのセクション情報を解析する。"""
    # MZスタブの検出
    if data[:2] != b'MZ':
        raise ValueError("MZシグネチャが見つかりません")

    # PEシグネチャオフセット (MZ header offset 0x3C)
    pe_offset = struct.unpack_from('<I', data, 0x3C)[0]
    if data[pe_offset:pe_offset + 4] != b'PE\0\0':
        raise ValueError("PEシグネチャが見つかりません")

    # COFFヘッダ (PEシグネチャの直後)
    coff_offset = pe_offset + 4
    num_sections = struct.unpack_from('<H', data, coff_offset + 2)[0]
    opt_header_size = struct.unpack_from('<H', data, coff_offset + 16)[0]

    # Optionalヘッダからエントリポイントを取得
    opt_offset = coff_offset + 20
    # PE32+のマジック確認 (0x20B)
    opt_magic = struct.unpack_from('<H', data, opt_offset)[0]
    if opt_magic != 0x20B:
        raise ValueError(f"PE32+以外はサポートしていません (magic=0x{opt_magic:04X})")

    entry_rva = struct.unpack_from('<I', data, opt_offset + 16)[0]

    # セクションテーブル
    section_table_offset = opt_offset + opt_header_size
    sections = []
    for i in range(num_sections):
        s_off = section_table_offset + i * 40
        name = data[s_off:s_off + 8].rstrip(b'\x00').decode('ascii', errors='replace')
        virt_size = struct.unpack_from('<I', data, s_off + 8)[0]
        virt_addr = struct.unpack_from('<I', data, s_off + 12)[0]
        raw_size = struct.unpack_from('<I', data, s_off + 16)[0]
        raw_offset = struct.unpack_from('<I', data, s_off + 20)[0]
        sections.append({
            'name': name,
            'virt_addr': virt_addr,
            'virt_size': virt_size,
            'raw_size': raw_size,
            'raw_offset': raw_offset,
        })

    return entry_rva, sections


def create_flat_binary(data: bytes, entry_rva: int, sections: list):
    """セクションをVAオフセットに配置したフラットバイナリを生成する。"""
    if not sections:
        raise ValueError("セクションが見つかりません")

    # 最小VA（ベースオフセット）
    min_va = min(s['virt_addr'] for s in sections)
    # 最大VA + サイズ（バッファサイズ）
    max_end = max(s['virt_addr'] + max(s['virt_size'], s['raw_size']) for s in sections)
    flat_size = max_end - min_va

    # フラットバイナリ作成
    flat = bytearray(flat_size)

    for s in sections:
        dst_offset = s['virt_addr'] - min_va
        src_offset = s['raw_offset']
        copy_size = min(s['raw_size'], len(data) - src_offset)
        if copy_size > 0:
            flat[dst_offset:dst_offset + copy_size] = data[src_offset:src_offset + copy_size]

    # エントリポイント（フラットバイナリ内のオフセット）
    entry_offset = entry_rva - min_va

    return bytes(flat), entry_offset


def create_cosmexe(flat_binary: bytes, entry_offset: int):
    """CosmEXEヘッダを付与する。"""
    header = bytearray(32)
    # magic: "CosmEXE\0"
    header[0:8] = b'CosmEXE\0'
    # entry offset (LE u64)
    struct.pack_into('<Q', header, 8, entry_offset)
    # code_size (LE u64)
    struct.pack_into('<Q', header, 16, len(flat_binary))
    # flags (LE u64) = 0
    struct.pack_into('<Q', header, 24, 0)

    return bytes(header) + flat_binary


def main():
    if len(sys.argv) < 3:
        print(f"使い方: {sys.argv[0]} input.efi output.cosmexe", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    with open(input_path, 'rb') as f:
        data = f.read()

    entry_rva, sections = read_pe_sections(data)

    # セクション情報を表示
    min_va = min(s['virt_addr'] for s in sections)
    for s in sections:
        print(f"  {s['name']:8s}  VA=0x{s['virt_addr']:04X}  "
              f"RawOff=0x{s['raw_offset']:04X}  "
              f"VSize=0x{s['virt_size']:04X}  RSize=0x{s['raw_size']:04X}")

    flat_binary, entry_offset = create_flat_binary(data, entry_rva, sections)
    cosmexe = create_cosmexe(flat_binary, entry_offset)

    with open(output_path, 'wb') as f:
        f.write(cosmexe)

    total_size = len(cosmexe)
    print(f"CosmEXE: {total_size} bytes "
          f"(code={len(flat_binary)}, entry=0x{entry_offset:x})")


if __name__ == '__main__':
    main()
