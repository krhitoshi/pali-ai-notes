#!/bin/bash
# 対訳作成パイプライン: 抽出 -> 生成 (claude -p) -> 組み立て -> 検証
#
# 使い方:
#   scripts/taiyaku.sh <xml|url> <subhead> <chunkspec> <workdir> <out_md> \
#     <model> [effort] [headings]
#
# <model> は生成に使うモデルのフル ID (claude-fable-5-1 など). 既定値はなく,
# 未指定やエイリアス (opus 等) は abort する. 呼び出し元セッションと同じ
# モデルで生成するため, 呼び出し元が自分のモデル ID をそのまま渡す.
# Meta ブロックのラベルは model と effort から組み立てる
# (claude-fable-5-1 + high -> "Claude Fable 5.1 High")
#
# [headings] は assemble_md.rb にそのまま渡す見出しラベルの上書き指定
# (例 "1:345-346,4:345-346")
#
# 例:
#   scripts/taiyaku.sh _tmp/s0305m.mul9.xml "10. Kimilasuttaṃ" "1-3,4,5-6,7-8,9" \
#     _tmp/work_kimila sn/sn_54_1_10.md claude-fable-5-1
#   scripts/taiyaku.sh https://www.tipitaka.org/romn/cscd/s0202m.mul0.xml \
#     "9. Bahuvedanīyasuttaṃ" "1,2,3-5,6-11,12,13-15" _tmp/work_mn059 mn/mn_059.md \
#     claude-fable-5-1
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
model=${6:-}
effort=${7:-high}
headings=${8:-}

# モデルは既定値を持たせず必須にする. フル ID 以外 (opus 等のエイリアス) は
# 将来別モデルを指すため受け付けない. 末尾の [1m] は落とす
model=${model%%\[*}
if [[ ! $model =~ ^claude-[a-z]+-[0-9] ]]; then
  echo "usage: taiyaku.sh <xml|url> <subhead> <chunkspec> <workdir> <out_md> <model> [effort] [headings]" >&2
  echo "model はフル ID で必須 (例 claude-fable-5-1). 指定: ${model:-なし}" >&2
  exit 1
fi

# Meta ブロックのラベルを ID と effort から組み立てる.
# claude-fable-5-1 -> "Claude Fable 5.1", claude-opus-4-8 -> "Claude Opus 4.8".
# 末尾の日付サフィックス (claude-haiku-4-5-20251001) は落とす
id=${model#claude-}
family=${id%%-*}
ver=$(printf "%s" "${id#*-}" | sed -E "s/-[0-9]{8}$//; s/-/./g")
label="Claude $(tr a-z A-Z <<<"${family:0:1}")${family:1} $ver $(tr a-z A-Z <<<"${effort:0:1}")${effort:1}"

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

# 原文 URL. ローカル xml 指定でもファイル名は VRI 名のため URL を復元できる
src_url="https://www.tipitaka.org/romn/cscd/$(basename "$xml")"

# 1. 抽出 + チャンク分割 (連結一致 assert 込み)
ruby "$repo_root/scripts/extract_chunks.rb" "$xml" "$subhead" "$workdir" "$chunkspec"

# title 起点セクションでは構造ブロック一覧 struct.txt が書き出される.
# 組み立てと検証で段落番号の検出から除外するために渡す.
# bash 3.2 の set -u は空配列の展開を unbound variable にするため,
# ${arr[@]+...} の形で展開する
struct_args=()
[ -f "$workdir/struct.txt" ] && struct_args=(--struct "$workdir/struct.txt")

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

# 生成失敗 (空出力や API エラー, 利用上限) の検出.
# 利用上限時は出力が "You've reached your ... limit" のメッセージだけになり
# exit 0 のまま通過するため, 文字列で検出する (2026/08/04 に 17/20 チャンクが
# このメッセージのまま組み立てられた実例あり)
fail=0
auth_fail=0
limit_fail=0
for out in "$workdir"/out_*.md; do
  if [ ! -s "$out" ] || grep -q "API Error" "$out" || grep -q "You've reached your" "$out"; then
    echo "generation failed: $out" >&2
    sed -n '1p' "$out" >&2
    fail=1
    grep -q "401" "$out" && auth_fail=1
    grep -q "You've reached your" "$out" && limit_fail=1
  fi
done
if [ "$auth_fail" -eq 1 ]; then
  echo "CLI の認証トークンが失効しています. claude login で再ログインしてください" >&2
fi
if [ "$limit_fail" -eq 1 ]; then
  echo "モデルの利用上限に達しています. 回復後に失敗チャンクのみ再生成してください" >&2
fi
[ "$fail" -eq 0 ] || exit 1

# 3. md 組み立て (原文ブロックはチャンクから byte-exact コピー)
ruby "$repo_root/scripts/assemble_md.rb" "$workdir" "$out_md" "$(date +%Y/%m/%d)" "$label" \
  ${headings:+"$headings"} --source "$src_url" ${struct_args[@]+"${struct_args[@]}"}

# 4. 対訳中のパーリ再掲行を正本と照合
ruby "$repo_root/scripts/verify_taiyaku.rb" ${struct_args[@]+"${struct_args[@]}"} \
  "$workdir/source.txt" "$out_md"
