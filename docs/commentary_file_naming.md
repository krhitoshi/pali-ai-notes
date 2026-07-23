# 註釈・復註ファイルの命名規則 (attha / tika 方式)

対訳ファイルのうち註釈 (aṭṭhakathā) と復註 (ṭīkā) のファイル名に使う識別子を
`attha` / `tika` に統一する規則. 採用の背景と適用記録をまとめる.

## 背景

- 従来は `mn_061.md` (経) に対して註釈を `mna_061.md`, 復註を `mnt_067.md` と
  1 文字追加で表していた
- `mna_` は `mn_` と字面が似ており見間違えやすい
- patisambhidamagga では `patis_a_1_03.md` とアンダースコア区切りにしていたが,
  `patis_` との見間違いは解消しなかった. 原因は区切り文字ではなく識別子の
  文字数の少なさにある
- VRI 版 (CST4) はファイル名を `.mul` / `.att` / `.tik` の 3 区分で表し, サイト
  表示では Aṭṭhakathā の略称として attha を使う. これに倣い綴りを省略しない
  識別子を採用する
- visuddhimagga では `vism_attha_08.md` が先にこの方式を使っており,
  既存の命名とも整合する

## 規則

- 註釈: `<経典略号>_attha_<番号>.md` (例 `mn_attha_061.md`)
- 復註: `<経典略号>_tika_<番号>.md` (例 `mn_tika_067.md`)
- 識別子は番号の前に置く. 「どのテキストか」は接頭辞側,
  `_check` `_reviewed` `_history` `_v1` などの作業工程は接尾辞側と役割を分離する
- `mn_061_attha.md` のような後置は経と註が隣接ソートされる利点があるが,
  `mn_061_attha_history.md` のように工程接尾辞と連結したとき識別子の役割が
  混ざるため採用しない

## 適用状況

- patisambhidamagga/: 適用済み (2026/07/23). `patis_a_1_03*.md` 4 ファイル
  (`_gemini` `_history` `_v1` 含む) を `patis_attha_1_03*.md` に改名し,
  リポジトリ内の旧名参照 (patis_1_03.md, 各 _history.md, scripts/,
  docs/ の計 8 ファイル) も更新した
- mn/: 適用済み (2026/07/23). `mna_*.md` 17 ファイル → `mn_attha_*.md`,
  `mnt_067.md` `mnt_073.md` → `mn_tika_067.md` `mn_tika_073.md`.
  旧名参照は docs/unify_list_indent.md の 1 箇所のみで, 更新済み

## 改名時の注意

- 改名は内容変更と混ぜず, 旧名の削除と新名の追加を同時にステージして
  rename (R100) として記録されることを確認する
- 各 `_history.md` 内の旧ファイル名への自己参照も合わせて更新する
- 公開済み docs の過去記録にある旧名言及 (unify_list_indent.md の
  `mna_061_with_paraphrase` 等) も, 参照切れ回避を優先して新名に更新した
