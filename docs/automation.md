# 対訳作成の自動化メモ

Claude Code を使って対訳作成プロセスを自動化する際の設計方針をまとめる.
実装ステップ 1-3 (分割・生成・検証) は `scripts/` に実装済み.
スキル化 (ステップ 4) は未着手.

## 実行手順

```bash
# URL 指定 (未取得なら _tmp/ にダウンロード, 取得済みならそれを正本に再利用)
scripts/taiyaku.sh https://www.tipitaka.org/romn/cscd/s0202m.mul0.xml \
  "9. Bahuvedanīyasuttaṃ" "1,2,3-5,6-11,12,13-15" _tmp/work_mn059 mn/mn_059.md

# ローカルの XML を直接指定してもよい
scripts/taiyaku.sh _tmp/s0305m.mul9.xml "10. Kimilasuttaṃ" "1-3,4,5-6,7-8,9" \
  _tmp/work_kimila sn/sn_54_1_10.md
```

- 第 3 引数はチャンク分割の指定. bodytext 段落番号 (1 始まり) のグループを
  カンマ区切りで書く. 境界は編集判断のため人が決める
- workdir (`_tmp/work_kimila`) に source.txt (read-only の正本), chunk_NN.txt,
  生成結果 out_NN.md, err_NN.log が残る
- 個別ステップは scripts/extract_chunks.rb (分割 + 連結一致 assert),
  scripts/assemble_md.rb (md 組み立て), scripts/verify_taiyaku.rb (再掲行照合)

## 背景: 現状の手動プロセス

1. VRI 版 (Chattha Sangayana Tipitaka) のテキストを適度なチャンクに分割する
2. 分割したチャンクを Claude Web 版のプロジェクトに貼り付けて実行する
3. 出力結果をコピペして md ファイルにまとめる

Gemini では API を使い, モデル固定で安定した出力を得ていた.
Claude については API を使わず, サブスクリプション (Claude Web / Claude Code) で運用する方針.

## 自動化の全体方針: orchestration と生成を分離する

対話セッション (Claude Code 本体) には, ハーネスの system prompt,
`~/.claude/CLAUDE.md`, auto-memory, MCP 説明などが必ず読み込まれる.
このため対訳生成を対話セッションや subagent で行うと, 対訳に不要な
プロンプトが影響する.

そこで役割を分ける.

- orchestrator (Claude Code 本体): 原文取得, チャンク分割, ファイル書き込み, 検証
- 生成: `claude -p` のクリーンな別プロセス呼び出し

これは Web 版の「まっさらなプロジェクト + 自前の system prompt」を
CLI で再現する構成になる.

## 設計原則: 原文のバイト列は LLM を一切通さない

最大の懸念は, チャンク分割時に LLM がテキストを再出力することで
ディアクリティカル (ā, ṃ, ñ, ṭ など) の正規化や脱字が起きること.

原則として, 原文バイト列は次の経路だけを通す.

```
原文ファイル (read-only) -> スクリプトで切り出し -> パイプ (stdin) -> 生成呼び出し
```

チャンク分割は LLM にテキストを再生成させる工程にせず,
スクリプトによる決定論的な文字列操作で行う.

## チャンク分割の手順

1. 原文を read-only のファイルに保存し, 唯一の正本 (source of truth) とする
   - 原文取得自体は別途 (cscd-text MCP など). ただし検索スニペットではなく
     完全な本文を取得すること
2. 分割は機械的に行う. VRI テキストは段落・節構造があるので, 空行や
   daṇḍa (`.`) 区切りでスクリプト分割できる. LLM に分割を委ねない
   - 境界は編集判断のため, 節範囲を引数で渡す形が安全
3. 分割直後に整合性を assert する. 全チャンクを連結したら原文と一致する
   ことをスクリプトで検査する (`連結 == 原文`)

### VRI XML の扱い (実装知見)

- `_tmp/s0305m.mul9.xml` などの VRI XML は UTF-16LE (BOM 付き, CRLF).
  Ruby では `File.read(path, mode: "rb", encoding: "UTF-16LE:UTF-8")` で読む.
  シェルで直接 sed/cat すると壊れて見えるが grep は透過的に扱える
- タグからテキストへの変換は既存の手動対訳 (sn/sn_54_1_09.md) の表記に合わせ
  決定論的に行う
  - `<hi rend="paranum">986</hi><hi rend="dot">.</hi>` -> `986.`
  - `<note>X</note>` -> `[X]` (異読注)
  - `<pb ... />` (頁番号) -> 削除. 除去痕の `bhāsati ,` のような
    句読点前空白は手動版と同じくそのまま残る
  - 連続スペースは 1 個に集約
- 経の範囲は `<p rend="subhead">` から次の非 bodytext 段落までの bodytext 段落.
  経題行は先頭チャンクにのみ含める (経名も対訳対象のため)
- 経の結び: MN などでは "...suttaṃ niṭṭhitaṃ navamaṃ." が rend="centre" の
  独立段落になっている. 直後の centre 段落が `niṭṭhitaṃ` を含む場合のみ
  段落として取り込む (既存 mn_061.md 等がこの行を訳出しているため).
  SN の vagga 結び ("Ekadhammavaggo paṭhamo.") は niṭṭhitaṃ を含まず除外される
- 見出し "## <段落番号>" はチャンク先頭の段落番号から取り, 番号のない
  チャンクは直前を引き継ぐ. 同じ番号が複数チャンクにまたがる場合のみ
  "(N)" の連番を付ける (MN 59 のように 1 経に複数の段落番号がある場合に対応)
- 制限: 経の途中に内部 subhead がある場合 (MN 54 Potaliya の
  "Kāmādīnavakathā" など) はそこで抽出が止まる. 対象が sutta 以外
  (vagga 全体, 註釈書など) の場合も未対応. 必要になったら範囲指定の
  方法を拡張する
- ロケールが C のシェルから Ruby を呼ぶと `File.read` が ASCII-8BIT に
  なり文字列比較が壊れる. 読み込み時に encoding を明示する
- ブラウザからの手動コピペには NBSP (U+00A0) が混入する. tipitaka.org の
  HTML が `&nbsp;` を使っているためで, 段落番号の直後や異読注ブラケットの
  前後など要素境界に現れる. スクリプト抽出では同じ位置が通常スペースになる.
  MN 71 での比較では差はこの空白の種類のみで, 文字・語順は完全に一致した

## 生成ステップ (サブスクリプション運用)

API を使わない方針のため `--bare` は使えない.
サブスクリプション認証で以下のように呼び出す.

```bash
cat chunk.txt | claude -p \
  --model claude-fable-5 \
  --effort high \
  --system-prompt "$(cat system_prompt_no_paraphrase.md)" \
  --disable-slash-commands \
  --tools "" \
  > out.md
```

- `--model claude-fable-5`: 利用できる最高モデルをフル ID で固定する. Fable が
  使えない環境では claude-opus-4-8 を使う. エイリアス (`opus` 等) は将来
  別モデルを指す可能性があるため避ける
- `--effort high`: 品質を上げる. さらに上は `xhigh` / `max`
- `--system-prompt`: 既定の Claude Code システムプロンプトを自前のファイルで
  完全置換する
- `--disable-slash-commands`: スキルを無効化する
- `--tools ""`: ツールを無効化する. 生成はテキスト変換のみでツールは不要

これにより, Gemini API で得ていた「固定モデルで安定」と同じ効果が出る.

### 生成ステップの実行環境 (実装知見)

- `API Error: 401 Invalid authentication credentials` が出る場合は
  CLI の OAuth トークンが失効している. `claude login` で再ログインすると
  解消する (セッション由来の環境変数は無関係だった.
  再ログイン後は Claude Code セッション内からのネスト実行も通る)
- `--exclude-dynamic-system-prompt-sections` は `--system-prompt` 併用時は
  無視されるため不要

### プロンプトに含まれる Claude 関連の内容 (実測)

`--system-prompt` + `--disable-slash-commands` + `--tools ""` の構成で,
モデル自身にコンテキストを報告させて確認した結果.

- system prompt: system_prompt_no_paraphrase.md で完全置換される.
  Claude Code 既定のハーネス指示は入らない
- ツール定義・MCP ツール説明: なし (`--tools ""` で消える)
- スキル: なし (`--disable-slash-commands` で消える)
- 最初のユーザーメッセージに system-reminder として以下が注入される
  - `~/.claude/CLAUDE.md` (グローバル個人設定). cwd に関係なく常に入る
  - userEmail と currentDate
  - cwd がリポジトリ内の場合のみ追加: プロジェクト CLAUDE.md と
    auto-memory の MEMORY.md (インデックス)

`--bare` との違いは上記の system-reminder 注入が残る点だけで,
生成の実体 (system prompt とチャンク本文) は同等になる.

### workdir の位置と CLAUDE.md の混入

- workdir をリポジトリ内 (`_tmp/work_...`) にすると, プロジェクト
  CLAUDE.md (翻訳の方針: assāsa = 出息 の規定を含む) と MEMORY.md が
  プロンプトに入る
- workdir をリポジトリ外にすると, グローバル CLAUDE.md だけになる
- 現状はリポジトリ内 workdir を採用する. 「翻訳の方針」が生成に伝わるのは
  むしろ望ましく (system_prompt_no_paraphrase.md には出入息の方向の規定が
  ない), 影響は確認済みの範囲にとどまるため. 完全な分離が必要になったら
  方針を system prompt 側へ移してリポジトリ外 workdir に切り替える
- チャンクごとに独立したプロセスで生成するため, 箇条書きの空行の有無や
  括弧の全角/半角など軽微な体裁がチャンク間で揺れる (Web 版の手動運用と
  同じ性質). 仕組み上しかたないので許容する
- 生成が経題を `#`/`##` の見出しにしたり, 経題行に和訳を同居させることが
  ある (特に短い経). 参照形式は「N. 経題 (純パーリ行)」+「→ 訳」なので,
  組み立て後に見出し検査で拾って手直しする.
  検査例: `grep -nE "^#{1,4} " <md>` で `# 経題` `## 段落番号` `### Meta`
  `### 対訳` 以外の見出しが出ないこと

## md への書き込みと検証

1. md の各節冒頭の原文ブロックは, スクリプトが正本から byte-exact でコピーして
   書き込む. LLM が触るのは対訳セクションだけにする
   - 既存の `vism_08_gemini.md` の構造 (原文段落 -> `### 対訳`) を踏襲する
2. 生成後の diff チェック. 対訳の各行はパーリ語を再掲するため, LLM 生成で
   ドリフトしうる. 対訳中のパーリ行を抽出して byte-exact の原文ブロックと
   diff を取り, 不一致を要確認として出す
   - 実装 (scripts/verify_taiyaku.rb) は番号付き行を対象に, 正本の連続
     部分文字列かどうかで判定する. 判定は 4 段階
     - OK: 空白集約のみで一致
     - OK-LOOSE: 異読注 `[ ... ]` の除去と句読点前空白の詰めで一致
       (再掲時に異読注を省く・空白痕を直すのは許容されるドリフト)
     - OK-NOSPACE: さらに引用符 (‘ ’) と空白をすべて除いて一致.
       引用符の省略, `…pe…` 前後の空白付加, 連声の分かち書き
       (pajānātī’’ti -> pajānātī ti) など再掲時の編集的な揺れ.
       文字と語順は保たれるので脱字・文字化けは検出できる
     - NG: 一致しない. 要確認として行番号付きで報告する
   - 生成出力はコードブロックで返るため, 組み立て時にフェンスを外す
     (scripts/assemble_md.rb). 冒頭が `### 対訳` でない場合は警告を出す

## モデル / プロンプト汚染に関する注意

- `--bare` は CLAUDE.md auto-discovery, hooks, auto-memory などを切れるが,
  認証が `ANTHROPIC_API_KEY` または apiKeyHelper に限定される.
  サブスクリプション運用では使えない
- このため `--bare` なしの運用では `~/.claude/CLAUDE.md` (グローバル) が
  読み込まれ続ける. これは生成ステップのスタイルに影響しうるが,
  原文バイト列の改変とは無関係 (原文は stdin で素通しのため)
- グローバル設定のルールが訳文に漏れるのが気になる場合は出力を確認して
  判断する. 汚染を完全にゼロにするには API キー + `--bare` が必要だが,
  現状は採用しない

## やらないこと

- Task / subagent での生成. ハーネスと CLAUDE.md が乗り, モデル固定も
  保証されないため, 両方の懸念が再発する

## 今後の実装ステップ

1. [済] 分割スクリプト (原文 -> チャンク + 連結一致 assert) を作り, 文字が
   保たれることを確認する -> scripts/extract_chunks.rb
2. [済] `claude -p` 生成を繋ぐ -> scripts/taiyaku.sh
3. [済] 生成後の diff 検証を加える -> scripts/verify_taiyaku.rb
4. 一連の処理を `.claude/commands/` のスキルにまとめる
