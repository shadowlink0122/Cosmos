# Bug #17: ___chkstk_ms 未定義シンボル

## 状態: 解決済み

## 現象

`make run`（リンク）時に以下のエラー:

```
lld-link: error: undefined symbol: ___chkstk_ms
>>> referenced by .tmp/build/kernel.o:(cosmfs_op)
>>> referenced by .tmp/build/kernel.o:(aria_op)
```

## 原因

LLVM/Windowsターゲットは**4KB以上のスタックフレーム**を持つ関数に
`___chkstk_ms`呼び出しを自動挿入する（スタックページのプローブ用）。

`cosmfs_op()`と`aria_op()`は多数のローカル変数を持つ大きな関数のため、
4KBを超えるスタックフレームとなり、LLVMがプローブを挿入した。

## ワークアラウンド

`kernel/lib/chkstk.c` にno-opスタブを提供:
```c
void ___chkstk_ms(void) { /* no-op */ }
```

clangで`-target x86_64-unknown-windows-msvc`としてCOFFオブジェクトに
コンパイルし、`lld-link`時に含める。

## 根本原因

ベアメタル環境ではページフォールトによるスタック拡張がないため
スタックプローブは不要。ただしLLVMはターゲット設定に基づき
機械的に挿入するため、シンボル定義が必要。

## 影響ファイル

- `kernel/lib/chkstk.c` — スタブ実装
- `Makefile` — CLANG変数、chkstk.oコンパイル+リンクステップ
