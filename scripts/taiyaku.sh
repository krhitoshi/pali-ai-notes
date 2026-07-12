#!/bin/bash
# 対訳作成パイプライン: 抽出 -> 生成 (claude -p) -> 組み立て -> 検証
#
# 使い方:
#   scripts/taiyaku.sh <xml|url> <subhead> <chunkspec> <workdir> <out_md> [model] [effort] [label]
#
# 例:
#   scripts/taiyaku.sh _tmp/s0305m.mul9.xml "10. Kimilasuttaṃ" "1-3,4,5-6,7-8,9" \
#     _tmp/work_kimila sn/sn_54_1_10_fable5.md
#   scripts/taiyaku.sh https://www.tipitaka.org/romn/cscd/s0202m.mul0.xml \
#     "9. Bahuvedanīyasuttaṃ" "1,2,3-5,6-11,12,13-15" _tmp/work_mn059 mn/mn_059_fable5.md
#
# <xml|url> に URL を渡すと _tmp/ にダウンロードして使う.
# 既に同名ファイルがあれば再ダウンロードせずそれを正本として使う
#
# 注意:
# - 生成で 401 が出る場合は claude login で CLI の再ログインが必要
# - 生成の cwd は workdir. リポジトリ内 workdir ではプロジェクト CLAUDE.md が
#   プロンプトに入る (翻訳の方針が伝わるため現状は許容)
set -euo pipefail

xml=$1; subhead=$2; chunkspec=$3; workdir=$4; out_md=$5
model=${6:-claude-fable-5}
effort=${7:-high}
label=${8:-"Claude Fable 5 High"}

repo_root=$(cd "$(dirname "$0")/.." && pwd)

# 0. URL なら _tmp/ にダウンロードする. 既存ファイルは正本として再利用する
case "$xml" in
  http://*|https://*)
    dest="$repo_root/_tmp/$(basename "$xml")"
    if [ -f "$dest" ]; then
      echo "reuse: $dest"
    else
      curl -sS -o "$dest" "$xml"
      echo "downloaded: $dest ($(wc -c < "$dest" | tr -d ' ') bytes)"
    fi
    xml=$dest
    ;;
esac

# 1. 抽出 + チャンク分割 (連結一致 assert 込み)
ruby "$repo_root/scripts/extract_chunks.rb" "$xml" "$subhead" "$workdir" "$chunkspec"

# 2. 生成. チャンクごとに claude -p のクリーンな別プロセスを並列で呼ぶ
for chunk in "$workdir"/chunk_*.txt; do
  n=$(basename "$chunk" .txt); n=${n#chunk_}
  (
    cd "$workdir"
    claude -p \
      --model "$model" \
      --effort "$effort" \
      --system-prompt "$(cat "$repo_root/system_prompt_no_paraphrase.md")" \
      --disable-slash-commands \
      --tools "" \
      < "chunk_$n.txt" > "out_$n.md" 2> "err_$n.log"
  ) &
done
wait

# 生成失敗 (空出力や API エラー) の検出
fail=0
auth_fail=0
for out in "$workdir"/out_*.md; do
  if [ ! -s "$out" ] || grep -q "API Error" "$out"; then
    echo "generation failed: $out" >&2
    sed -n '1p' "$out" >&2
    fail=1
    grep -q "401" "$out" && auth_fail=1
  fi
done
if [ "$auth_fail" -eq 1 ]; then
  echo "CLI の認証トークンが失効しています. claude login で再ログインしてください" >&2
fi
[ "$fail" -eq 0 ] || exit 1

# 3. md 組み立て (原文ブロックはチャンクから byte-exact コピー)
ruby "$repo_root/scripts/assemble_md.rb" "$workdir" "$out_md" "$(date +%Y/%m/%d)" "$label"

# 4. 対訳中のパーリ再掲行を正本と照合
ruby "$repo_root/scripts/verify_taiyaku.rb" "$workdir/source.txt" "$out_md"
