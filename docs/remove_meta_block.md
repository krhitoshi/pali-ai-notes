# 対訳ファイルの生成メタブロック削除手順

対訳ファイル (例 patisambhidamagga/patis_1_03.md) の各セクションには, 生成元
(モデル) と生成日を記したメタブロックが付いている. 見出しは `### Meta` で
統一している (以前は Claude / Gemini など生成元の名前だったが 2026/07 に統一).
完成後は不要なので削除する.

```
### Meta

- 2026/06/26
- Claude Opus 4.8 High

```

生成元が変わってもモデル行が変わるだけで見出しは同じ (例: Gemini):

```
### Meta

- 2026/06/20
- gemini-3.1-pro-preview

```

## バリエーション

- 日付は節ごとに異なる (例 2026/06/22, 06/23, 06/24, 06/26)
- モデル文字列は生成元・バージョンで変わる (例 Claude Opus 4.8 High,
  gemini-3.1-pro-preview)

→ 日付・モデルを固定文字列で決め打ちにせず, **パターン**で照合する.

## 削除の方針 (重要: 貪欲削除をしない)

「`### Meta` 以降, 空行と `- ` 行を全部消す」という貪欲な方式は**危険**.
モデル行の後に, `- ※…` のような**内容の箇条書き**が直接続くセクションがあり
(例: patis_1_03 の §164 「- ※upaṭṭhāna は本段で二義に…」), 巻き込んで消してしまう.

そこで **厳密な 5 行パターンに一致するブロックだけ**を削除する:

1. `### Meta` (見出し行. 旧形式のファイルでは Claude / Gemini などの
   生成元名のこともある)
2. 空行
3. `- ` + 日付 (正規表現 `^- \d{4}/\d{2}/\d{2}$`)
4. `- ` で始まる行 (モデル. 直前が見出し+空行+日付なので構造的に確定する)
5. 空行

この 5 行が揃ったブロックのみ削除する. 直前の空行 (ブロックの前にある区切り) は
残るので, 削除後は前の内容と次の見出しの間が空行 1 つになる.

## スクリプト

```python
import re, sys
src = "patisambhidamagga/patis_1_03.md"   # 対象ファイル
# 見出しは Meta (旧形式では Claude / Gemini など ASCII の生成元名).
# 日本語の内容見出しは除外される
HEAD = re.compile(r'^### [A-Za-z][\w.\-]*$')
lines = open(src, encoding="utf-8").read().split("\n")
drop = set()
removed = 0
for i, l in enumerate(lines):
    if HEAD.match(l.strip()):
        blk = lines[i:i+5]
        if (len(blk) == 5 and blk[1].strip() == ""
                and re.match(r'^- \d{4}/\d{2}/\d{2}$', blk[2].strip())
                and re.match(r'^- \S', blk[3].strip())
                and blk[4].strip() == ""):
            for k in range(i, i+5):
                drop.add(k)
            removed += 1
out = [l for j, l in enumerate(lines) if j not in drop]
open(src + ".tmp", "w", encoding="utf-8").write("\n".join(out))
print(f"削除ブロック: {removed} / 削除行: {len(drop)}")
```

一時ファイル (`.tmp`) に出力して検証してから本体へ反映する.

## 検証

1. 適用前に, モデル行の直後 (空行を挟んだ次の行) が必ずしも `### 対訳` でない
   ことを確認する (※注記・content bullet が続く節がある). 上記の厳密パターンなら
   これらは巻き込まない
2. 削除後に残存ゼロを確認: `grep -cE '^### Meta'` と モデル文字列の grep
3. **git diff で削除内容を確認**: 挿入 0, 削除は `### Meta` / 日付 / モデル / 空行
   のみであること. 他の行が削除/挿入されていれば貪欲削除の事故
   ```sh
   git --no-pager diff --no-color <file> | grep '^+' | grep -v '^+++'   # 空であるべき
   ```
4. 数の整合: 削除行数 = ブロック数 × 5

## 適用実績

- 2026/06/29 patis_1_03.md: 72 ブロック × 5 = 360 行削除. 挿入 0. content bullet
  (§164 の ※upaṭṭhāna 注) は保持を確認
