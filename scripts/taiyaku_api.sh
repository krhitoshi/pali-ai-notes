#!/bin/bash
# 対訳作成パイプラインの API キー版. 引数は taiyaku.sh と同じ
#
# 使い方:
#   scripts/taiyaku_api.sh <xml|url> <subhead> <chunkspec> <workdir> <out_md> \
#     <model> [effort] [headings]
#
# CLI のログイン (サブスクリプション) ではなく, 環境変数
# PALI_AI_NOTES_CLAUDE_API_KEY のキーを使った API の従量課金で生成する.
# 処理本体は taiyaku.sh で, このスクリプトは TAIYAKU_AUTH=api を付けて
# 呼ぶだけ. TAIYAKU_CTX などの環境変数もそのまま引き継がれる
set -euo pipefail

TAIYAKU_AUTH=api exec "$(dirname "$0")/taiyaku.sh" "$@"
