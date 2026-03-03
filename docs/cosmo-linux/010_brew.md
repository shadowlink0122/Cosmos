# Cosmo Linux — Homebrew パッケージマネージャ (brew)

## 概要

ホスト側 `rootfs/packages/` に配置した静的リンクELFバイナリを
シェルからインストール・実行するパッケージマネージャ。

## コマンド

| コマンド | 内容 |
|---------|------|
| `brew install <pkg>` | ホストからRamFSにコピー |
| `brew list` | インストール済みパッケージ一覧 |
| `brew search` | ホスト側の利用可能パッケージ |
| `brew run <pkg>` | パッケージを実行 |
| `brew help` | ヘルプ表示 |

## アーキテクチャ

```
ホスト: rootfs/packages/<name> (ELF64静的リンク)
         ↓ 9pfs (virtio-9p)
brew install <name>
         ↓ 9pfs read → RamFS create + write
exec <name>
         ↓ RamFS read → ELF load → プロセス作成
プログラム実行
```

## パッケージ作成方法

```bash
# x86_64クロスコンパイラでアセンブリ or Cから静的リンクELFを作成
x86_64-elf-as -o hello.o hello.S
x86_64-elf-ld -o rootfs/packages/hello hello.o
```
