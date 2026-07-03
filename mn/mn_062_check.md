Mahārāhulovāda-sutta (MN 62) 校閲

- 第一稿: mn_062.md (Gemini gemini-3.1-pro-preview)
- チェック: Claude claude-opus-4-8 + MCP (pali-dict / dop / cscd-text)
- 2026/06/28

本書は全文校閲版ではなく, 第一稿のうち改訂が必要そうな箇所のみを指摘する.
優先度は 高 (要修正/要検討) / 中 (註記推奨) / 低 (語の精度, 任意) で示す.

## チェック範囲

- 重点確認: 五大の比喩 (#119), 四梵住・不浄・無常 (#120), 安那般那念 16 階梯 (#121)
- 流し読み: 序 (#113), 五大の定義と無常観 (#114-#118)
- 原文の byte 照合は本書では未実施 (訳語の指摘に限定)

## 指摘

### 高

1. sabbakāyappaṭisaṃvedī (#121 対訳 8)
   - 第一稿: 「全身を経験しながら（覚知しながら）」
   - 指摘: 註釈は「身体全体」でなく「息の全体」と解す
   - 根拠: Paṭisambhidāmagga-aṭṭh. 「Sabbakāyapaṭisaṃvedīti sabbassa
     **assāsapassāsakāyassa** paṭisaṃvedī」(= 出入息の全体を覚知する者)。
     Vism-mahāṭīkā も同趣旨で, 息の初・中・後を覚知する意とする
   - 提案: 「(息の) 全体を覚知しながら」とし, 註で「sabbakāya = 出入息の全体
     (初・中・後), 身体全体ではない」と補う。少なくとも両義がある旨を註記する

### 中

2. assāsa / passāsa の方向 (#121 対訳 5 ほか) ※方針決定により 高 に格上げ
   - 第一稿: assasati = 息を吸う, passasati = 息を吐く (assasati = 入)
   - 方針 (2026-06-28 決定): assasati / assāsa = 出息 (外), passasati / passāsa =
     入息 (内) に統一 (CLAUDE.md「翻訳の方針」, 律註の定義)
   - 指摘: 第一稿は assasati = 吸う (入) で方針と逆。安那般那念の段 (#121) の
     assasati / passasati をすべて反転する必要がある (assasati = 吐く/出息,
     passasati = 吸う/入息)
   - 提案: #121 の dīgha/rassa, 各 sikkhati 句などで出入を統一して修正する

3. kāyasaṅkhāra / cittasaṅkhāra (#121 対訳 9, 12)
   - 第一稿: kāyasaṅkhāra =「身行(身体の形成作用, 呼吸)」, cittasaṅkhāra =
     「心行(心の形成作用, 受と想)」
   - 指摘: 註釈と整合 (kāyasaṅkhāra = assāsapassāsa = 息, cittasaṅkhāra =
     saññā + vedanā)。第一稿は両義を併記しており妥当。確認のみ
   - 提案: 修正不要。括弧内の「呼吸」「受と想」が註釈の定義である旨を明記すると堅い

### 低

4. arati (#120 対訳 6)
   - 第一稿: 「不満（不快）」(muditā が断つもの)
   - 指摘: 辞書は a+rati =「不楽, 倦怠」(ukkaṇṭhita)。修行・遠離に対する
     「不楽・倦怠」の含意が出にくい
   - 根拠: PTS arati = dislike, discontent; Dhp-a/Thig-a が ukkaṇṭhita と注
   - 提案: 「(修行への) 不楽・倦怠」とすると含意が明確。任意

## 問題を確認できなかった箇所 (参考)

- 五大の比喩 (#119): pathavī/āpo/tejo/vāyo/ākāsa と aṭṭīyati/harāyati/jigucchati,
  pariyādāya の訳は妥当
- 四梵住の対治 (#120): mettā→byāpāda, karuṇā→vihesā, muditā→arati,
  upekkhā→paṭigha, asubha→rāga, aniccasaññā→asmimāna は定型どおり
- carimaka assāsa (#121 対訳 23): 「最後の呼吸」で可 (PTS が本経 M I 426 を引用)

## メモ

- 高 1 件 (sabbakāya), 中 2 件 (方向, saṅkhāra 確認), 低 1 件 (arati)
- 全文校閲版 (mn_NNN_reviewed.md) に比べ, 確認済み箇所の冗長な再掲を避け,
  判断が要る箇所だけを集約できる
