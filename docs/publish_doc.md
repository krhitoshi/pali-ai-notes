# docs/ のファイルを公開 (追跡対象) にする手順

`docs/` は作業メモ置き場として既定で gitignore されている. 内容が確定し, 公開して
問題ないと判断したファイルだけを個別に追跡解除して公開する. その手順をまとめる.

## 前提: opt-in 方式の gitignore

`.gitignore` で `docs/` の中身を既定 ignore にし, 確定ファイルだけをネゲートで
追跡解除する.

```
/docs/*
!/docs/plain_terms.md
!/docs/<確定したファイル名>
```

- `docs/` 内の新規ファイルは自動的に ignore される. 未確定・私的情報を含みうる
  ファイルを誤ってコミットする事故が起きない (安全な既定)
- 公開するファイルだけを `!` 行で明示的に opt-in する
- ネゲートを効かせるにはディレクトリ自体ではなく中身を ignore する必要がある.
  `/docs/` ではなく `/docs/*` と書く (`/docs/` だとディレクトリ除外でネゲート不可)

## 手順

1. **全文確認** — 対象ファイルを通読する
2. **私的情報チェック** — 公開リポジトリの規約 (CLAUDE.md) に反する情報がないか.
   - 絶対パス (`/Users/<user>/...` 等), メールアドレス, グローバル個人設定
     (`~/.claude/CLAUDE.md` など) の中身への言及
   - 確認コマンド: `grep -nE "/Users/|/home/|@|<公開済み以外の固有名>" docs/<file>`
3. **冒頭の一般化** — 「YYYY/MM/DD に xxx で実施した記録」のように特定日・特定
   ファイルの一回限りの記録調になっている場合は, 汎用的な参照説明に書き換える.
   日付つきの適用実績は別セクション (`## 適用実績` 等) に残してよい
4. **参照切れの確認** — 本文が他の docs ファイルや未追跡ファイルを参照していないか.
   - 確認: `grep -noE "[a-z_]+\.md" docs/<file> | sort -u`
   - 参照先が未追跡なら次のいずれかで参照切れを解消する:
     - (a) 参照先も同時に公式化する (連鎖する場合は閉包を確認する)
     - (b) 参照を本文内の説明に展開し, ファイル名参照を除去する
   - 参照先が追跡済みファイル (例 `mn/mn_NNN.md`) なら問題ない
5. **ファイル名の一般化** — ファイル名が特定の対象に固定されている場合
   (例 `remove_claude_meta.md`) は, 内容に合う汎用名に変更する
   (例 `remove_meta_block.md`)
6. **.gitignore に追跡解除を追加** — `!/docs/<file>` を追記する
7. **ステージして確認** — `git add .gitignore docs/<file>` の後,
   - 対象ファイルのみ trackable, 他の docs は ignored のままであること
   - ステージされたのが対象ファイルだけであること
   を確認する
8. **コミット** — ユーザの明示的な指示と動作確認を待ってから実行する
   (CLAUDE.md「コミットはユーザが動作確認をした後に行う」). 確定するまでは
   ステージまでで止める

## 確認コマンド例

```sh
# docs/ 各ファイルの追跡状況
for f in docs/*.md; do
  printf "%-26s " "$(basename "$f")"
  git check-ignore -q "$f" && echo "ignored" || echo "trackable"
done

# ステージ内容 (対象ファイルのみであること)
git diff --cached --name-only -- docs/
```

## 公開済みファイル

- `plain_terms.md` — 漢語・古語の平易化リスト
- `breath_direction.md` — assāsa / passāsa の方向改訂の手順
- `check_version.md` — 校閲 (指摘方式) の作り方
- `remove_meta_block.md` — 生成メタブロックの削除手順
- `publish_doc.md` — 本書 (公開手順)
- `translation_terms.md` — 改訂で置換した訳語リスト
- `yathattha_term.md` — yathattha の訳語「真実の目的」の根拠
- `automation.md` — 対訳作成の自動化の設計方針と運用手順
- `insert_blank_lines.md` — 空行スタイル改訂 (リスト前・訳文行前の空行挿入) の手順
- `unify_list_indent.md` — 対訳リストのインデント正書法と統一改訂の記録
