# AN の vagga ごとの分量

AN の対訳では参照文脈として vagga 全体をプロンプトに入れる (`TAIYAKU_CTX=all`).
そのため vagga の長さがプロンプトの大きさを決める. 対訳済みの vagga を基準にして,
AN 全 11 集の vagga 186 個の分量を VRI 原文の語数で比べる.

## 数え方

- 原文は VRI (CST4) の `s0401m.mul*.xml` から `s0404m4.mul*.xml` まで
  (AN 1 から AN 11 まで, 186 ファイル). `<p rend="chapter">` を vagga の
  区切りとした. 1 ファイルが 1 vagga に対応する
- 語数は bodytext と偈 (gathalast など) の段落にある語の数. 異読注
  (`<note>`), 見出し, 段落番号は数えない
- 文字数は同じ範囲の空白を除いた文字数
- `pe` で省略された部分は省略されたままの長さで数える. peyyāla の vagga は
  段落番号の範囲が広くても語数は小さい
- 「Upāsaka 比」は AN 5 (18) Upāsakavagga の語数 2,451 を 1 としたときの比
- 調査日は 2026/11/07. 基準の 2 vagga はこの時点で対訳済みだったもの

## 基準にした vagga

| vagga | 語数 | 分布上の位置 |
|---|--:|---|
| AN 5 (18) Upāsakavagga (171-180) | 2,451 | 上位 4 分の 1 の境目あたり. これより長い vagga は 45 個 |
| AN 5 (19) Araññavagga (181-190) | 341 | 下位 4 分の 1 の境目あたり. これ以下の vagga は 48 個 |

Araññavagga は 182 以降が `pe` による省略形のため短い.

## 全体の分布

186 vagga, 合計 約 29.5 万語. 中央値 1,056 語, 平均 1,588 語,
四分位は 333 / 1,056 / 2,361 語.

| 語数 | vagga 数 |
|---|--:|
| 500 未満 | 65 |
| 500-1,000 | 27 |
| 1,000-2,000 | 38 |
| 2,000-3,000 | 26 |
| 3,000-4,000 | 15 |
| 4,000-6,000 | 10 |
| 6,000 以上 | 5 |

Upāsakavagga 以下の長さに約 4 分の 3 (141 個) が収まる.
残る 45 個はそれより長く, 最大で約 3.3 倍になる.

## Upāsakavagga の 2 倍以上の vagga

| vagga | 語数 | Upāsaka 比 |
|---|--:|--:|
| AN 3 (7) Mahāvagga | 8,146 | 3.3 |
| AN 6 Mahāvagga | 7,537 | 3.1 |
| AN 4 (20) Mahāvagga | 6,966 | 2.8 |
| AN 9 Mahāvagga | 6,726 | 2.7 |
| AN 7 Mahāvagga | 6,242 | 2.5 |
| AN 10 Mahāvagga | 5,688 | 2.3 |
| AN 8 Mahāvagga | 5,661 | 2.3 |
| AN 10 (10) Upālivagga | 5,538 | 2.3 |
| AN 11 Anussativagga | 5,184 | 2.1 |

各集の Mahāvagga が最長の部類に集中している.

## 集ごとの傾向

| 集 | vagga 数 | 合計語数 | 中央値 | 最大 |
|---|--:|--:|--:|--:|
| AN 1 | 20 | 7,441 | 302 | 1,512 |
| AN 2 | 19 | 9,408 | 330 | 1,491 |
| AN 3 | 18 | 37,353 | 1,742 | 8,146 |
| AN 4 | 28 | 47,207 | 1,524 | 6,966 |
| AN 5 | 29 | 42,829 | 1,258 | 4,471 |
| AN 6 | 13 | 26,886 | 1,234 | 7,537 |
| AN 7 | 11 | 21,473 | 984 | 6,242 |
| AN 8 | 11 | 29,803 | 3,103 | 5,661 |
| AN 9 | 10 | 17,505 | 732 | 6,726 |
| AN 10 | 23 | 47,196 | 2,003 | 5,688 |
| AN 11 | 4 | 8,180 | 1,453 | 5,184 |

- AN 1, AN 2 はすべて 1,500 語程度以下で, vagga 全体を文脈に入れても負担は小さい
- AN 8 は中央値が 3,103 語で, Upāsakavagga より長い vagga が多い
- AN 5 の中では (8) Yodhājīvavagga の 4,471 語 (Upāsaka 比 1.8) が最大
- 各集末尾の peyyāla (Rāgapeyyāla など) は本文が 100-400 語程度

## プロンプト量への影響

`TAIYAKU_CTX=all` では各チャンクのプロンプトに vagga 全体が付くため,
入力の総量はおおよそ「vagga の長さ x チャンク数」になる. 長い vagga は
チャンク数も多くなりやすいため, 入力量の差は語数の差より大きく開く.

## vagga 一覧

### AN 1 Ekakanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Rūpādivaggo | 1-10 | 246 | 2,072 | 0.1 | s0401m.mul0.xml |
| 2. Nīvaraṇappahānavaggo | 11-20 | 330 | 2,910 | 0.1 | s0401m.mul1.xml |
| 3. Akammaniyavaggo | 21-30 | 224 | 1,857 | 0.1 | s0401m.mul2.xml |
| 4. Adantavaggo | 31-40 | 232 | 1,865 | 0.1 | s0401m.mul3.xml |
| 5. Paṇihitaacchavaggo | 41-50 | 386 | 2,970 | 0.2 | s0401m.mul4.xml |
| 6. Accharāsaṅghātavaggo | 51-60 | 261 | 2,110 | 0.1 | s0401m.mul5.xml |
| 7. Vīriyārambhādivaggo | 61-70 | 334 | 2,586 | 0.1 | s0401m.mul6.xml |
| 8. Kalyāṇamittādivaggo | 71-80 | 277 | 2,311 | 0.1 | s0401m.mul7.xml |
| 9. Pamādādivaggo | 81-97 | 366 | 3,139 | 0.1 | s0401m.mul8.xml |
| 10. Dutiyapamādādivaggo | 98-139 | 528 | 4,719 | 0.2 | s0401m.mul9.xml |
| 11. Adhammavaggo | 140-149 | 137 | 1,077 | 0.1 | s0401m.mul10.xml |
| 12. Anāpattivaggo | 150-169 | 267 | 2,103 | 0.1 | s0401m.mul11.xml |
| 13. Ekapuggalavaggo | 170-187 | 237 | 2,283 | 0.1 | s0401m.mul12.xml |
| 14. Etadaggavaggo | 188-267 | 326 | 3,365 | 0.1 | s0401m.mul13.xml |
| 15. Aṭṭhānapāḷi | 268-295 | 651 | 5,042 | 0.3 | s0401m.mul14.xml |
| 16. Ekadhammapāḷi | 296-365 | 1,512 | 11,754 | 0.6 | s0401m.mul15.xml |
| 17. Pasādakaradhammavaggo | 366-381 | 22 | 275 | 0.0 | s0401m.mul16.xml |
| 18. Aparaaccharāsaṅghātavaggo | 382-562 | 529 | 5,059 | 0.2 | s0401m.mul17.xml |
| 19. Kāyagatāsativaggo | 563-599 | 385 | 3,871 | 0.2 | s0401m.mul18.xml |
| 20. Amatavaggo | 600-611 | 191 | 1,562 | 0.1 | s0401m.mul19.xml |

### AN 2 Dukanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Kammakaraṇavaggo | 1-10 | 842 | 6,793 | 0.3 | s0402m1.mul0.xml |
| 2. Adhikaraṇavaggo | 11-21 | 1,453 | 11,334 | 0.6 | s0402m1.mul1.xml |
| 3. Bālavaggo | 22-32 | 330 | 2,482 | 0.1 | s0402m1.mul2.xml |
| 4. Samacittavaggo | 33-42 | 1,491 | 12,128 | 0.6 | s0402m1.mul3.xml |
| 5. Parisavaggo | 43-52 | 1,060 | 8,346 | 0.4 | s0402m1.mul4.xml |
| (6) 1. Puggalavaggo | 53-64 | 609 | 4,409 | 0.2 | s0402m1.mul5.xml |
| (7) 2. Sukhavaggo | 65-77 | 278 | 2,254 | 0.1 | s0402m1.mul6.xml |
| (8) 3. Sanimittavaggo | 78-87 | 190 | 1,228 | 0.1 | s0402m1.mul7.xml |
| (9) 4. Dhammavaggo | 88-98 | 160 | 1,010 | 0.1 | s0402m1.mul8.xml |
| (10) 5. Bālavaggo | 99-118 | 420 | 2,666 | 0.2 | s0402m1.mul9.xml |
| (11) 1. Āsāduppajahavaggo | 119-130 | 237 | 1,511 | 0.1 | s0402m1.mul10.xml |
| (12) 2. Āyācanavaggo | 131-141 | 574 | 4,174 | 0.2 | s0402m1.mul11.xml |
| (13) 3. Dānavaggo | 142-151 | 218 | 1,609 | 0.1 | s0402m1.mul12.xml |
| (14) 4. Santhāravaggo | 152-163 | 258 | 2,027 | 0.1 | s0402m1.mul13.xml |
| (15) 5. Samāpattivaggo | 164-180 | 236 | 1,630 | 0.1 | s0402m1.mul14.xml |
| 1. Kodhapeyyālaṃ | 181-190 | 377 | 2,515 | 0.2 | s0402m1.mul15.xml |
| 2. Akusalapeyyālaṃ | 191-200 | 66 | 476 | 0.0 | s0402m1.mul16.xml |
| 3. Vinayapeyyālaṃ | 201-230 | 202 | 2,182 | 0.1 | s0402m1.mul17.xml |
| 4. Rāgapeyyālaṃ | 231-246 | 407 | 2,793 | 0.2 | s0402m1.mul18.xml |

### AN 3 Tikanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Bālavaggo | 1-10 | 836 | 6,446 | 0.3 | s0402m2.mul0.xml |
| 2. Rathakāravaggo | 11-20 | 2,254 | 17,864 | 0.9 | s0402m2.mul1.xml |
| 3. Puggalavaggo | 21-30 | 2,683 | 20,940 | 1.1 | s0402m2.mul2.xml |
| 4. Devadūtavaggo | 31-40 | 3,121 | 23,837 | 1.3 | s0402m2.mul3.xml |
| 5. Cūḷavaggo | 41-51 | 763 | 5,957 | 0.3 | s0402m2.mul4.xml |
| (6) 1. Brāhmaṇavaggo | 52-61 | 3,659 | 27,817 | 1.5 | s0402m2.mul5.xml |
| (7) 2. Mahāvaggo | 62-71 | 8,146 | 63,740 | 3.3 | s0402m2.mul6.xml |
| (8) 3. Ānandavaggo | 72-81 | 2,584 | 20,274 | 1.1 | s0402m2.mul7.xml |
| (9) 4. Samaṇavaggo | 82-92 | 2,070 | 16,440 | 0.8 | s0402m2.mul8.xml |
| (10) 5. Loṇakapallavaggo | 93-103 | 3,555 | 29,128 | 1.5 | s0402m2.mul9.xml |
| (11) 1. Sambodhavaggo | 104-113 | 1,451 | 12,387 | 0.6 | s0402m2.mul10.xml |
| (12) 2. Āpāyikavaggo | 114-123 | 1,607 | 12,799 | 0.7 | s0402m2.mul11.xml |
| (13) 3. Kusināravaggo | 124-133 | 1,876 | 14,718 | 0.8 | s0402m2.mul12.xml |
| (14) 4. Yodhājīvavaggo | 134-146 | 1,498 | 11,943 | 0.6 | s0402m2.mul13.xml |
| (15) 5. Maṅgalavaggo | 147-156 | 427 | 3,322 | 0.2 | s0402m2.mul14.xml |
| (16) 6. Acelakavaggo | 157-163 | 434 | 3,764 | 0.2 | s0402m2.mul15.xml |
| (17) 7. Kammapathapeyyālaṃ | 164-183 | 297 | 2,276 | 0.1 | s0402m2.mul16.xml |
| (18) 8. Rāgapeyyālaṃ | 184 | 92 | 815 | 0.0 | s0402m2.mul17.xml |

### AN 4 Catukkanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Bhaṇḍagāmavaggo | 1-10 | 1,746 | 14,389 | 0.7 | s0402m3.mul0.xml |
| 2. Caravaggo | 11-20 | 1,121 | 9,444 | 0.5 | s0402m3.mul1.xml |
| 3. Uruvelavaggo | 21-30 | 2,080 | 16,445 | 0.8 | s0402m3.mul2.xml |
| 4. Cakkavaggo | 31-40 | 1,932 | 14,719 | 0.8 | s0402m3.mul3.xml |
| 5. Rohitassavaggo | 41-50 | 1,522 | 12,363 | 0.6 | s0402m3.mul4.xml |
| (6) 1. Puññābhisandavaggo | 51-60 | 1,571 | 13,842 | 0.6 | s0402m3.mul5.xml |
| (7) 2. Pattakammavaggo | 61-70 | 1,707 | 14,435 | 0.7 | s0402m3.mul6.xml |
| (8) 3. Apaṇṇakavaggo | 71-80 | 1,321 | 9,505 | 0.5 | s0402m3.mul7.xml |
| (9) 4. Macalavaggo | 81-90 | 1,510 | 12,158 | 0.6 | s0402m3.mul8.xml |
| (10) 5. Asuravaggo | 91-100 | 2,166 | 16,495 | 0.9 | s0402m3.mul9.xml |
| (11) 1. Valāhakavaggo | 101-110 | 2,236 | 16,772 | 0.9 | s0402m3.mul10.xml |
| (12) 2. Kesivaggo | 111-120 | 1,913 | 14,063 | 0.8 | s0402m3.mul11.xml |
| (13) 3. Bhayavaggo | 121-130 | 2,718 | 22,000 | 1.1 | s0402m3.mul12.xml |
| (14) 4. Puggalavaggo | 131-140 | 902 | 7,905 | 0.4 | s0402m3.mul13.xml |
| (15) 5. Ābhāvaggo | 141-150 | 281 | 2,332 | 0.1 | s0402m3.mul14.xml |
| (16) 1. Indriyavaggo | 151-160 | 1,376 | 11,244 | 0.6 | s0402m3.mul15.xml |
| (17) 2. Paṭipadāvaggo | 161-170 | 1,778 | 14,811 | 0.7 | s0402m3.mul16.xml |
| (18) 3. Sañcetaniyavaggo | 171-180 | 2,740 | 21,340 | 1.1 | s0402m3.mul17.xml |
| (19) 4. Brāhmaṇavaggo | 181-190 | 2,953 | 22,378 | 1.2 | s0402m3.mul18.xml |
| (20) 5. Mahāvaggo | 191-200 | 6,966 | 53,302 | 2.8 | s0402m3.mul19.xml |
| (21) 1. Sappurisavaggo | 201-210 | 1,527 | 12,418 | 0.6 | s0402m3.mul20.xml |
| (22) 2. Parisāvaggo | 211-220 | 362 | 2,944 | 0.1 | s0402m3.mul21.xml |
| (23) 3. Duccaritavaggo | 221-231 | 362 | 2,814 | 0.1 | s0402m3.mul22.xml |
| (24) 4. Kammavaggo | 232-242 | 1,444 | 13,129 | 0.6 | s0402m3.mul23.xml |
| (25) 5. Āpattibhayavaggo | 243-253 | 1,282 | 10,253 | 0.5 | s0402m3.mul24.xml |
| (26) 6. Abhiññāvaggo | 254-263 | 1,052 | 8,624 | 0.4 | s0402m3.mul25.xml |
| (27) 7. Kammapathavaggo | 264-273 | 456 | 3,293 | 0.2 | s0402m3.mul26.xml |
| (28) 8. Rāgapeyyālaṃ | 274-783 | 183 | 1,598 | 0.1 | s0402m3.mul27.xml |

### AN 5 Pañcakanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Sekhabalavaggo | 1-10 | 1,339 | 10,419 | 0.5 | s0403m1.mul0.xml |
| 2. Balavaggo | 11-20 | 719 | 6,122 | 0.3 | s0403m1.mul1.xml |
| 3. Pañcaṅgikavaggo | 21-30 | 2,718 | 22,578 | 1.1 | s0403m1.mul2.xml |
| 4. Sumanavaggo | 31-40 | 1,777 | 13,128 | 0.7 | s0403m1.mul3.xml |
| 5. Muṇḍarājavaggo | 41-50 | 2,885 | 22,171 | 1.2 | s0403m1.mul4.xml |
| (6) 1. Nīvaraṇavaggo | 51-60 | 2,605 | 20,335 | 1.1 | s0403m1.mul5.xml |
| (7) 2. Saññāvaggo | 61-70 | 582 | 4,745 | 0.2 | s0403m1.mul6.xml |
| (8) 3. Yodhājīvavaggo | 71-80 | 4,471 | 37,540 | 1.8 | s0403m1.mul7.xml |
| (9) 4. Theravaggo | 81-90 | 1,258 | 10,048 | 0.5 | s0403m1.mul8.xml |
| (10) 5. Kakudhavaggo | 91-100 | 1,269 | 10,602 | 0.5 | s0403m1.mul9.xml |
| (11) 1. Phāsuvihāravaggo | 101-110 | 1,418 | 11,357 | 0.6 | s0403m1.mul10.xml |
| (12) 2. Andhakavindavaggo | 111-120 | 890 | 7,343 | 0.4 | s0403m1.mul11.xml |
| (13) 3. Gilānavaggo | 121-130 | 804 | 6,417 | 0.3 | s0403m1.mul12.xml |
| (14) 4. Rājavaggo | 131-140 | 2,941 | 22,614 | 1.2 | s0403m1.mul13.xml |
| (15) 5. Tikaṇḍakīvaggo | 141-150 | 1,497 | 11,768 | 0.6 | s0403m1.mul14.xml |
| (16) 1. Saddhammavaggo | 151-160 | 1,686 | 13,952 | 0.7 | s0403m1.mul15.xml |
| (17) 2. Āghātavaggo | 161-170 | 2,783 | 22,318 | 1.1 | s0403m1.mul16.xml |
| (18) 3. Upāsakavaggo (基準) | 171-180 | 2,451 | 19,903 | 1.0 | s0403m1.mul17.xml |
| (19) 4. Araññavaggo (基準) | 181-190 | 341 | 2,779 | 0.1 | s0403m1.mul18.xml |
| (20) 5. Brāhmaṇavaggo | 191-200 | 3,847 | 31,186 | 1.6 | s0403m1.mul19.xml |
| (21) 1. Kimilavaggo | 201-210 | 690 | 5,340 | 0.3 | s0403m1.mul20.xml |
| (22) 2. Akkosakavaggo | 211-220 | 681 | 5,386 | 0.3 | s0403m1.mul21.xml |
| (23) 3. Dīghacārikavaggo | 221-230 | 609 | 4,894 | 0.2 | s0403m1.mul22.xml |
| (24) 4. Āvāsikavaggo | 231-240 | 817 | 6,746 | 0.3 | s0403m1.mul23.xml |
| (25) 5. Duccaritavaggo | 241-250 | 598 | 4,655 | 0.2 | s0403m1.mul24.xml |
| (26) 6. Upasampadāvaggo | 251-271 | 429 | 4,048 | 0.2 | s0403m1.mul25.xml |
| 1. Sammutipeyyālaṃ | 272-285 | 325 | 2,773 | 0.1 | s0403m1.mul26.xml |
| 2. Sikkhāpadapeyyālaṃ | 286-302 | 222 | 1,894 | 0.1 | s0403m1.mul27.xml |
| 3. Rāgapeyyālaṃ | 303-1151 | 177 | 1,587 | 0.1 | s0403m1.mul28.xml |

### AN 6 Chakkanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Āhuneyyavaggo | 1-10 | 1,498 | 12,020 | 0.6 | s0403m2.mul0.xml |
| 2. Sāraṇīyavaggo | 11-20 | 3,521 | 25,913 | 1.4 | s0403m2.mul1.xml |
| 3. Anuttariyavaggo | 21-30 | 3,350 | 27,495 | 1.4 | s0403m2.mul2.xml |
| 4. Devatāvaggo | 31-42 | 2,249 | 18,275 | 0.9 | s0403m2.mul3.xml |
| 5. Dhammikavaggo | 43-54 | 4,535 | 34,796 | 1.9 | s0403m2.mul4.xml |
| 6. Mahāvaggo | 55-64 | 7,537 | 59,997 | 3.1 | s0403m2.mul5.xml |
| 7. Devatāvaggo | 65-74 | 1,234 | 9,665 | 0.5 | s0403m2.mul6.xml |
| 8. Arahattavaggo | 75-84 | 779 | 6,134 | 0.3 | s0403m2.mul7.xml |
| 9. Sītivaggo | 85-95 | 769 | 6,359 | 0.3 | s0403m2.mul8.xml |
| 10. Ānisaṃsavaggo | 96-106 | 554 | 4,500 | 0.2 | s0403m2.mul9.xml |
| 11. Tikavaggo | 107-116 | 488 | 3,881 | 0.2 | s0403m2.mul10.xml |
| 12. Sāmaññavaggo | 117-139 | 248 | 2,066 | 0.1 | s0403m2.mul11.xml |
| 13. Rāgapeyyālaṃ | 140-649 | 124 | 1,095 | 0.1 | s0403m2.mul12.xml |

### AN 7 Sattakanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Dhanavaggo | 1-10 | 948 | 7,802 | 0.4 | s0403m3.mul0.xml |
| 2. Anusayavaggo | 11-20 | 984 | 8,037 | 0.4 | s0403m3.mul1.xml |
| 3. Vajjisattakavaggo | 21-31 | 1,812 | 14,539 | 0.7 | s0403m3.mul2.xml |
| 4. Devatāvaggo | 32-43 | 1,618 | 13,185 | 0.7 | s0403m3.mul3.xml |
| 5. Mahāyaññavaggo | 44-53 | 4,117 | 32,076 | 1.7 | s0403m3.mul4.xml |
| 6. Abyākatavaggo | 54-64 | 4,562 | 33,698 | 1.9 | s0403m3.mul5.xml |
| 7. Mahāvaggo | 65-74 | 6,242 | 50,167 | 2.5 | s0403m3.mul6.xml |
| 8. Vinayavaggo | 75-84 | 573 | 4,761 | 0.2 | s0403m3.mul7.xml |
| 9. Samaṇavaggo | 85-94 | 167 | 1,147 | 0.1 | s0403m3.mul8.xml |
| 10. Āhuneyyavaggo | 95-622 | 322 | 3,008 | 0.1 | s0403m3.mul9.xml |
| 11. Rāgapeyyālaṃ | 623-1132 | 128 | 1,094 | 0.1 | s0403m3.mul10.xml |

### AN 8 Aṭṭhakanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Mettāvaggo | 1-10 | 3,103 | 24,739 | 1.3 | s0404m1.mul0.xml |
| 2. Mahāvaggo | 11-20 | 5,661 | 43,485 | 2.3 | s0404m1.mul1.xml |
| 3. Gahapativaggo | 21-30 | 4,178 | 32,406 | 1.7 | s0404m1.mul2.xml |
| 4. Dānavaggo | 31-40 | 1,670 | 14,211 | 0.7 | s0404m1.mul3.xml |
| 5. Uposathavaggo | 41-50 | 3,431 | 27,690 | 1.4 | s0404m1.mul4.xml |
| (6) 1. Gotamīvaggo | 51-60 | 2,783 | 23,155 | 1.1 | s0404m1.mul5.xml |
| (7) 2. Bhūmicālavaggo | 61-70 | 3,355 | 25,650 | 1.4 | s0404m1.mul6.xml |
| (8) 3. Yamakavaggo | 71-80 | 3,755 | 26,529 | 1.5 | s0404m1.mul7.xml |
| (9) 4. Sativaggo | 81-90 | 1,589 | 13,797 | 0.6 | s0404m1.mul8.xml |
| (10) 5. Sāmaññavaggo | 91-116 | 37 | 272 | 0.0 | s0404m1.mul9.xml |
| (11). Rāgapeyyālaṃ | 117-626 | 241 | 2,105 | 0.1 | s0404m1.mul10.xml |

### AN 9 Navakanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Sambodhivaggo | 1-10 | 3,284 | 27,154 | 1.3 | s0404m2.mul0.xml |
| 2. Sīhanādavaggo | 11-20 | 3,308 | 25,880 | 1.3 | s0404m2.mul1.xml |
| 3. Sattāvāsavaggo | 21-31 | 2,096 | 17,130 | 0.9 | s0404m2.mul2.xml |
| 4. Mahāvaggo | 32-41 | 6,726 | 52,856 | 2.7 | s0404m2.mul3.xml |
| 5. Sāmaññavaggo | 42-51 | 858 | 6,933 | 0.4 | s0404m2.mul4.xml |
| (6) 1. Khemavaggo | 52-62 | 222 | 1,752 | 0.1 | s0404m2.mul5.xml |
| (7) 2. Satipaṭṭhānavaggo | 63-72 | 605 | 5,085 | 0.2 | s0404m2.mul6.xml |
| (8) 3. Sammappadhānavaggo | 73-82 | 181 | 1,591 | 0.1 | s0404m2.mul7.xml |
| (9) 4. Iddhipādavaggo | 83-92 | 109 | 1,094 | 0.0 | s0404m2.mul8.xml |
| (10) 5. Rāgapeyyālaṃ | 93-432 | 116 | 981 | 0.0 | s0404m2.mul9.xml |

### AN 10 Dasakanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Ānisaṃsavaggo | 1-10 | 2,003 | 16,572 | 0.8 | s0404m3.mul0.xml |
| 2. Nāthavaggo | 11-20 | 2,622 | 21,673 | 1.1 | s0404m3.mul1.xml |
| 3. Mahāvaggo | 21-30 | 5,688 | 45,790 | 2.3 | s0404m3.mul2.xml |
| 4. Upālivaggo | 31-40 | 936 | 7,639 | 0.4 | s0404m3.mul3.xml |
| 5. Akkosavaggo | 41-50 | 2,331 | 18,371 | 1.0 | s0404m3.mul4.xml |
| (6) 1. Sacittavaggo | 51-60 | 3,552 | 26,850 | 1.4 | s0404m3.mul5.xml |
| (7) 2. Yamakavaggo | 61-70 | 2,804 | 23,875 | 1.1 | s0404m3.mul6.xml |
| (8) 3. Ākaṅkhavaggo | 71-80 | 2,963 | 23,179 | 1.2 | s0404m3.mul7.xml |
| (9) 4. Theravaggo | 81-90 | 3,891 | 31,241 | 1.6 | s0404m3.mul8.xml |
| (10) 5. Upālivaggo | 91-100 | 5,538 | 42,896 | 2.3 | s0404m3.mul9.xml |
| (11) 1. Samaṇasaññāvaggo | 101-112 | 1,743 | 15,088 | 0.7 | s0404m3.mul10.xml |
| (12) 2. Paccorohaṇivaggo | 113-122 | 2,318 | 18,037 | 0.9 | s0404m3.mul11.xml |
| (13) 3. Parisuddhavaggo | 123-133 | 316 | 2,827 | 0.1 | s0404m3.mul12.xml |
| (14) 4. Sādhuvaggo | 134-144 | 410 | 3,255 | 0.2 | s0404m3.mul13.xml |
| (15) 5. Ariyavaggo | 145-154 | 375 | 2,956 | 0.2 | s0404m3.mul14.xml |
| (16) 1. Puggalavaggo | 155-166 | 171 | 1,253 | 0.1 | s0404m3.mul15.xml |
| (17) 2. Jāṇussoṇivaggo | 167-177 | 4,126 | 31,120 | 1.7 | s0404m3.mul16.xml |
| (18) 3. Sādhuvaggo | 178-188 | 431 | 3,355 | 0.2 | s0404m3.mul17.xml |
| (19) 4. Ariyamaggavaggo | 189-198 | 380 | 2,979 | 0.2 | s0404m3.mul18.xml |
| (20) 5. Aparapuggalavaggo | 199-210 | 184 | 1,426 | 0.1 | s0404m3.mul19.xml |
| (21) 1. Karajakāyavaggo | 211-220 | 3,195 | 25,775 | 1.3 | s0404m3.mul20.xml |
| (22) 2. Sāmaññavaggo | 221-236 | 1,085 | 8,244 | 0.4 | s0404m3.mul21.xml |
| 23. Rāgapeyyālaṃ | 237-746 | 134 | 1,203 | 0.1 | s0404m3.mul22.xml |

### AN 11 Ekādasakanipāta

| vagga | 段落 | 語数 | 文字数 | Upāsaka 比 | XML |
|---|---|--:|--:|--:|---|
| 1. Nissayavaggo | 1-10 | 2,714 | 22,861 | 1.1 | s0404m4.mul0.xml |
| 2. Anussativaggo | 11-21 | 5,184 | 41,177 | 2.1 | s0404m4.mul1.xml |
| 3. Sāmaññavaggo | 22-501 | 192 | 1,908 | 0.1 | s0404m4.mul2.xml |
| 4. Rāgapeyyālaṃ | 502-671 | 90 | 836 | 0.0 | s0404m4.mul3.xml |
