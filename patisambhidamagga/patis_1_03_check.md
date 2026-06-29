# patis_1_03 校訂チェック (指摘方式)

patis_1_03.md (Paṭisambhidāmagga 大品 出入息念論 §152-§183) のうち, 訳の正確性に
検討を要する箇所だけを指摘する. docs/check_version.md の方式による.

- 対象: patisambhidamagga/patis_1_03.md (訳語統一・方向 assāsa=出息・平易化・古語の
  各バッチを適用済みの状態)
- チェック: Claude Opus 4.8 + 並列サブエージェント (opus 5 区間) + MCP
  (pali-dict / dop / cscd-text の aṭṭhakathā)
- 日付: 2026/06/29
- 優先度: 高 (要修正/要検討) / 中 (註記推奨) / 低 (語の精度, 任意)
- 除外: yathattha (如実義, §161(2)) は別途 docs/yathattha_term.md で検討中
- 主エージェントが高の指摘を cscd / 本文 grep で裏取り済み
- 箇所参照は **§ + Pali 語** で示す (行番号は patis_1_03.md の編集でずれるため使わない).
  対象は grep で Pali 語を引いて特定する

## チェック範囲

- 重点確認: 教理語・比喩・定型句・格数態が密集する段
  (§152 計数門, §154-157 随煩悩, §159 鋸喩, §160 upaṭṭhāna 構文, §162 buddha 語義列挙,
  §166-171 vivattati/samodhāneti/比喩, §172-177 paṭividita/samattha 定型, §178-183 の
  viññāṇaṃ-cittaṃ 定型と縁起八相・数目総括)
- 流し読み: 各 catukka の定型反復・…pe… 省略・三学反復 (前段と同型で差分のみ照合)
- 原文照合: cscd の aṭṭhakathā を高・中の判断で随時引用

## 指摘

### 高 (要修正/要検討)

**1. §162(1) visavitā ― 語源の取り違え (毒 → 開敷)**
- 箇所: §162(1) 7番 Visavitāya buddho (grep: `Visavitāya`)
- 現訳:「(煩悩という)毒を除き去っていることによって、仏である」/ gloss「visa(毒)を離れた状態」
- 指摘: visavitā を visa「毒」と解しているが誤り. 註は visavati / vikasati「開く・咲き開く」と取る
- 根拠: Paṭisambhidāmagga-aṭṭhakathā §162 ほか Vism-mahāṭīkā・Mahāniddesa-a・Itivuttaka-a の
  4-5 註が一致して「Visavitāya buddhoti **nānāguṇavisavanato padumamiva vikasanaṭṭhena** buddho」
  (= 種々の功徳をもって蓮華のごとく開敷する義によって仏). Mahāniddesa-a は nānāguṇa**vikasana**to
  と明示. 異読 vikasitāya (咲き開いた) も同義. いずれにも「毒」の解釈なし (主エージェント cscd 確認)
- 提案:「(蓮華のごとく)種々の功徳をもって開敷していることによって、仏である」

**2. paṭividita ― 「洞察」と「明らかに知られる」の不統一 (paṭivijjhati との語根混同)**
- 箇所: §170 (te kāyā paṭividitā honti), §173-177 (sukhā/cittasaṅkhārā/dhammā paṭividitā honti)
  は「洞察」/ §172 (sā pīti paṭividitā hoti) は「明らかに知られる」(grep: `paṭividitā`)
- 現訳:「洞察された(ものとなる)」と「明らかに知られたものとなる」が混在
- 指摘: paṭividita は paṭi-√vid「知られた・確知された」の過去分詞 (§170 の gloss も
  「vindati の過去分詞」と認識). 一方 paṭivijjhati は paṭi-√vyadh「貫通・洞察」で別語.
  paṭividita を「洞察」と訳すと同一段の samatthañca paṭivijjhati「洞察する」と衝突し語根を取り違える
- 根拠: 辞書 (Main/Concise/PTS) paṭividita=known/ascertained, paṭivijjhati=penetrate.
  §172 自身が「明らかに知られる」と正訳 (本文 grep で不整合を確認)
- 提案: §170/§173-177 も「明らかに知られる/明らかに知られたものとなる」に統一 (§172 に揃える)

**3. §179(2)-6 viññāṇaṃ cittaṃ の係り受けの崩れ**
- 箇所: §179(2)-6 (Vimocayaṃ cittaṃ … viññāṇaṃ cittaṃ upaṭṭhānaṃ sati. grep: `viññāṇaṃ cittaṃ upaṭṭhānaṃ`)
- 現訳:「出入息によって〔生ずるものが〕識であり、心が現前〔の対象〕であり、念が…」
- 指摘: 定型 viññāṇaṃ cittaṃ | upaṭṭhānaṃ sati | anupassanā ñāṇaṃ は (識=心)(現前=念)(随観=智)
  の三対. 現訳は viññāṇaṃ を単独述語にし cittaṃ を upaṭṭhānaṃ の主語へ繰り上げており構造が崩れる
- 根拠: 同一文書 §178(1)-7 は同じ Pali を「識は心であり、現前は念であり、随観は智である」と
  正訳 (本文で確認). kāya 定型 (assāsapassāsā kāyo, upaṭṭhānaṃ sati…) も viññāṇaṃ と cittaṃ を一対とする
- 提案:「出入息によって〔生ずる〕識が心であり、現前が念であり〔、随観が智である〕…」(§178-7 に統一)

### 中 (註記推奨)

**4. abhitunna ― 「圧倒された」と「悩まされた」の不統一**
- 箇所: §154 (assāsena/passāsena abhitunnassa)「圧倒された」/ §157 (同 abhitunnassa)「悩まされた」(grep: `abhitunna`)
- 指摘: 同一語 abhitunna が同じ呼吸瞑想の構文で割れている (本文で確認)
- 根拠: 辞書 Main「制圧された」, PTS「overwhelmed」(Paṭis I 129,164 を挙例). 註 abhitunna=viddha「突かれた」
- 提案: どちらかに統一. 辞書の overwhelmed に近い「圧倒された」を推奨

**5. §177 samatthañca paṭivijjhati ― 訳ゆれ + sama=「平等」の再考**
- 箇所: §172-177 各末尾 samatthañca paṭivijjhati (grep: `samatthañca paṭivijjhati`. 訳が § ごとに「義をも/平等の意義を/等しき意義を」と動揺)
- 指摘: (1) 同一定型句の訳が不統一. (2) gloss で sama を「平等」と断定するが, 註は
  sama=samatha/vodāna (寂止・浄化, ひいては涅槃) と取り, samañca samatthañca の ekasesa とする
- 根拠: Paṭis-a (s0517a)「…samassa atthoti samattho, paramaṭṭho pana samameva atthoti vā
  nibbānapayojanattā… samañca samatthañca ekadesasarūpekasesaṃ katvā…」
- 提案: 訳語を全 § で統一し,「平等」断定を緩める. 例「義をも洞察する」+ 註で「sama=samatha/涅槃」を補う

**6. §170 nimitta + upanibandhana ― 註の一体解釈との微差**
- 箇所: §170(1) rūpakāya の列挙「…相と繋縛(処)と…」(grep: `upanibandhanā`)
- 指摘: 註は nimittañca upanibandhana を一括し「念を繋ぎとめる相となる出入息の触点(鼻端・上唇)」
  と一体解釈. 現訳は2独立項として並列
- 根拠: Paṭis-a §170「Nimittañca upanibandhanāti satiupanibandhanāya nimittabhūtaṃ
  assāsapassāsānaṃ phusanaṭṭhānaṃ」
- 提案: 並列訳は残しても可だが, gloss に註の一体解釈 (念を繋ぎとめる相=呼吸の触点) を明示

**7. §177 pīti 同義語列の訳ゆれ (vs §172)**
- 箇所: §177「愉悦・歓悦・大喜笑・満悦」/ §172「欣喜・歓喜・喜笑・極喜・満足・踊躍・適意性」(grep: `āmodanā`)
- 指摘: 同一の pīti 同義語定型 (āmodanā pamodanā hāso pahāso vitti odagyaṃ attamanatā) が § で別語
- 提案: §172 の訳語に統一

**8. §174 「念が現前したものとなる」 vs 「念が現前する」**
- 箇所: §174「念が現前したものとなる」/ 他 §は「念が現前する」(grep: `sati upaṭṭhitā hoti`)
- 指摘: 同一定型句 sati upaṭṭhitā hoti の訳が §174 だけ過去分詞を強調. 表現の不統一 (意味上の誤りではない)
- 提案:「念が現前する」に統一

### 低 (語の精度, 任意)

**9. §157 sāraddha「緊張」**
- 箇所: §157 (sāraddhā ca honti). 辞書はより強い「躁暴・激情/violent」, 註 sāraddha=sadaratha (daratha を伴う),
  passaddha-kāya の対義. 誤訳ではないが「ざわつき・ほてり立ち」等が原意に近い

**10. §179 gloss の省略定型句の引用ミス**
- 箇所: §179(2)-6 gloss「省略される定型句『sati upaṭṭhānañ ceva ñāṇañ ca…』」
- 指摘: 正しくは「sati upaṭṭhānañceva sati ca」(§178(1)-8 で確認).「ñāṇañ ca」は誤記. gloss のみ

**11. §183(3) samadhika の語源**
- 箇所: §183(3)-9 gloss「samadhika = saha + adhika」(grep: `samadhika`)
- 指摘: PTS は samadhika = sama + adhika「excessive, abundant」. 訳語「二百有余」は適切で本文訳に影響なし

## 確認したが問題なし (字義による誤修正を防ぐ記録)

- assāsa=出息 / passāsa=入息 の内外対応: 註「ajjhattaṃ vikkhepaṃ… bahi…」で出息=内・入息=外を確認.
  律註方針と整合し正しい
- §153 uducita「積み調えられた」: 註 uddhaṃ ucitaṃ… uparūpari kataparicayaṃ と一致
- satokārī, parapattiya, nikanti, adhimoceti (旧 勝解→向け定める), vivaṭṭanā (§158): 辞書・註と整合
- §162 anaññaneyya「他に導かれず自ら覚った」, vimokkhantika, bodhetā (使役), abuddhivihata: 註と一致
- §166 vivattati「対象から転じ離れる」(PTS sense 2), samatthañca の ekasesa 解釈, pabhāvanā「成立」,
  cittapaṭibaddhā cittasaṅkhārā を「心所…心行」とする読み: 註と整合
- §178/§182 sati upaṭṭhānañceva sati ca「念は現前でもあり念でもある」: ṭīkā「saraṇaṭṭhena,
  upatiṭṭhanaṭṭhena ca」両義で正しい
- §183 paṭisaṅkhā santiṭṭhanā paññā「簡択して安住する慧」(saṅkhārupekkhā 定型), bhayatupaṭṭhāne,
  abbhatthaṃ gacchanti「滅没に至る」: 辞書・cscd 並行例で確認
- §181 縁起各支の滅の八相定型, §183 数目総括 (24定+72観+8×3+21=二百有余): 整合

## 語解釈の精査記録 (§162 buddha 語義 全項照合)

visavitā のような語源系の誤りが出たため, 語義解説が密集する §162(1) の buddha 18 エピテットを
Paṭisambhidāmagga-aṭṭhakathā §162 (+ Vism-mahāṭīkā 等の並行註) と一項ずつ照合した. 結果:

- **誤りは visavitā (7番) の 1 件のみ** (上記 [高]1)
- 他の 17 項は註・辞書と整合し正しい:
  bujjhitā saccāni (覚知者, 註: avagantā→avagato の喩), bodhetā pajāya (覚らせる者, 註:
  paṇṇasosā→paṇṇasusā の喩), sabbaññutā/sabbadassāvitā, anaññaneyya (aññena abodhanīyato
  sayameva buddhattā), khīṇāsava-saṅkhāta, nirupalepa-saṅkhāta, ekantavītarāga/dosa/moha/
  nikkilesa, ekāyanamagga gato (一行道), eko… abhisambuddho, abuddhivihatattā buddhipaṭilābhā,
  「この名は母…神々が作ったのでない」, vimokkhantikā paññatti (解脱を究極とする施設)
- → 語義・語源・格数態のレベルで個別に検証済み. 訳ゆれだけでなく語解釈も照合している

## メモ

- 確度の高い要修正は **[高] 3 件** (visavitā 語源誤り / paṭividita の語根混同・訳ゆれ /
  §179 の係り受け崩れ). うち paṭividita と §179 は内部不整合で, 同一文書内の正訳箇所へ揃えれば足りる
- [中] は大半が定型句の訳ゆれ (abhitunna, samattha, pīti 語列, 現前) と註との微差. 統一が望ましい
- 誤訳・語解釈も MCP の aṭṭhakathā・辞書で照合した (visavitā 語源誤り, §179 係り受け, sama=平等
  の再解釈, ekasesa・anaññaneyya・vivattati 等の「問題なし」判定はいずれも註と突き合わせた結果).
  訳ゆれが多いのは, 既に複数バッチ校訂済み + 第一稿が高精度で, 残る誤訳が少ないため
- narrative・数目の反復部は精度が高く, 指摘は教理語と定型句に集中した
- 反映する場合は各バッチを別コミットにし, patis_1_03_history.md に追記する
