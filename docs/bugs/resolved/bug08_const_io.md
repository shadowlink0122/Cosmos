# Bug #8: const式でのI/Oポート計算

**修正**: Cm v0.14.1

## 症状（修正前）

`const`定数を使った加算式が関数引数で正しく評価されない場合があった。

```cm
const ulong COM1_PORT = 0x3F8;
const ulong REG_IER = 1;
outb(COM1_PORT + REG_IER, 0x00);  // 期待: 0x3F9、実際: 不定
```

## 検証結果

Cm v0.14.1 で `BASE + OFFSET = 1017 (0x3F9)` が正常に出力されることを確認。
