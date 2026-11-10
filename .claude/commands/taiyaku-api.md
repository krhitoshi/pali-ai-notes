---
description: taiyaku スキルと同じ手順で対訳 md を新規生成する. 生成だけをサブスクリプションではなく API キー (PALI_AI_NOTES_CLAUDE_API_KEY) の従量課金で行う
argument-hint: 対訳する経・註釈書 (例 "MN 43") [チャンクや文脈範囲の指示]
disable-model-invocation: true
---

# 対訳作成 (API キー版)

対象: $ARGUMENTS

taiyaku スキル (`.claude/skills/taiyaku/SKILL.md`) を読み込み, 手順 1 から
手順 6 までをそのまま実行する. 違いは次の 1 点だけ.

- 手順 3 のパイプライン実行で `scripts/taiyaku.sh` の代わりに
  `scripts/taiyaku_api.sh` を使う (引数と `TAIYAKU_CTX` などの環境変数は
  同じ). 生成の `claude -p` が CLI のログイン (サブスクリプション) ではなく
  環境変数 `PALI_AI_NOTES_CLAUDE_API_KEY` のキーで実行される

途中で `scripts/taiyaku.sh` に切り替えない. API キー側の失敗 (キー無効,
クレジット残高不足) や失敗チャンクの再生成は, スキルの手順 4 にある
`taiyaku_api.sh` 向けの記述に従う. サブスクリプションでの生成に
切り替えるかどうかはユーザに確認する.
