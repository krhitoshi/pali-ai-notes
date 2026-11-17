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
# <workdir> の名前は <out_md> のファイル名から決まる (issue #59).
#   _tmp/work_<out_md のファイル名から .md を除いたもの>
#   (sn/sn_54_1_10.md -> _tmp/work_sn_54_1_10)
# 対訳 md のファイル名はリポジトリ内で重複しないため, md から workdir を
# 名前だけで引ける. やり直しは同じ workdir で行う. 比較用・試験用の生成は
# out_md を <ファイル名>__<ラベル>.md にし (残さないものは _tmp/ に,
# 残すものは本来の md と同じディレクトリに出す), workdir も同じ規則で
# _tmp/work_<ファイル名>__<ラベル> になる. 規則に合わない組み合わせは abort する.
# 規則を決める前 (2026/11/15 より前) の workdir は名前を変えずに使う.
# run.txt の out_md が <out_md> と同じファイル名なら, 名前が規則と違っても通る.
# そういう workdir がある md に規則どおりの名前の workdir を指定すると,
# 既存の workdir の名前を示して abort する
#
# 例:
#   scripts/taiyaku.sh _tmp/s0305m.mul9.xml "10. Kimilasuttaṃ" "1-3,4,5-6,7-8,9" \
#     _tmp/work_sn_54_1_10 sn/sn_54_1_10.md claude-fable-5-1
#   scripts/taiyaku.sh https://www.tipitaka.org/romn/cscd/s0202m.mul0.xml \
#     "9. Bahuvedanīyasuttaṃ" "1,2,3-5,6-11,12,13-15" _tmp/work_mn_059 mn/mn_059.md \
#     claude-fable-5-1
#   (比較用) TAIYAKU_CTX=none scripts/taiyaku.sh ... _tmp/work_an_05_181-190__ctx-none \
#     _tmp/an_05_181-190__ctx-none.md claude-fable-5-1
#
# <xml|url> に URL を渡すと _tmp/ にダウンロードして使う.
# 既に同名ファイルがあれば再ダウンロードせずそれを正本として使う
#
# 環境変数 TAIYAKU_CTX で参照文脈の付け方を指定する (issue #23).
#   未指定 / none : 従来どおり chunk_NN.txt だけを stdin に流す
#   all           : セクション全体を前後の文脈として付けた prompt_NN.txt を流す
#   <N>           : 前後 N 段落を文脈として付ける
# 文脈は extract_chunks.rb が prompt_NN.txt として組み立てる (訳出対象は
# chunk_NN.txt と同一内容). 短い段落が多いテキストで文脈不足による誤訳を
# 防ぐためのもの. 例:
#   TAIYAKU_CTX=all scripts/taiyaku.sh _tmp/s0403m1.mul18.xml "(19) 4. Araññavaggo" \
#     "1-3,4-5,6-7,8-9,10-11,12-13,14-15,16-17,18-19,20-26" _tmp/work_an_05_181-190 \
#     an/an_05_181-190.md claude-fable-5-1
#
# 環境変数 TAIYAKU_UNTIL でセクションの終了見出しを指定する.
#   未指定 : 従来どおり起点見出しの次の見出しで抽出を止める
#   <見出しテキスト> : その見出しの直前までを 1 セクションとし, 間の
#                      小見出しや結び行を構造ブロックとして取り込む
# ファイル内で最後のセクションは後ろに見出しがないため, セクションの結びの
# 次にある centre 行 (vagga の結び) を指定する.
# セクションの途中に内部の小見出しがある註釈書などで使う. 値はそのまま
# extract_chunks.rb に引き継がれる (詳細は同スクリプトのヘッダコメント参照).
# 段落一覧の表示で指定したのと同じ値を付ける. 例:
#   TAIYAKU_UNTIL="5. Jīvakasuttavaṇṇanā" scripts/taiyaku.sh _tmp/s0202a.att0.xml \
#     "4. Potaliyasuttavaṇṇanā" "<chunkspec>" _tmp/work_mn_attha_054 \
#     mn/mn_attha_054.md claude-fable-5-1
#
# 環境変数 TAIYAKU_AUTH で生成の認証方法を指定する.
#   未指定 / subscription : 従来どおり CLI のログイン (サブスクリプション) で生成する
#   api                   : PALI_AI_NOTES_CLAUDE_API_KEY を ANTHROPIC_API_KEY として
#                           渡し, API の従量課金で生成する
# api でも claude -p の引数は変えず, 認証だけを切り替える.
# api は直接指定せず, TAIYAKU_AUTH=api を付けてこのスクリプトを呼ぶ
# scripts/taiyaku_api.sh を使う (引数は同じ). 例:
#   scripts/taiyaku_api.sh _tmp/s0305m.mul9.xml "10. Kimilasuttaṃ" \
#     "1-3,4,5-6,7-8,9" _tmp/work_sn_54_1_10 sn/sn_54_1_10.md claude-fable-5-1
#
# 環境変数 TAIYAKU_JOBS で生成 (claude -p) の同時実行数の上限を指定する.
#   未指定 : 50
#   <N>    : 同時に N プロセスまで. 空きが出るたびに次のチャンクを起動する
# チャンク数だけ一度に起動すると, 長い註釈書でマシンが高負荷になる
# (2026/11/10 に MN 1 復註の 171 チャンクを同時に起動し, スワップをほぼ
# 使い切った. 同日の 76 チャンク同時起動は問題なく完了している)
#
# 環境変数 TAIYAKU_GEN で生成するチャンクを番号で指定する (分割生成).
#   未指定 : 従来どおり workdir の全チャンクを生成する (生成済みも作り直す)
#   <指定> : チャンク番号か範囲のカンマ区切り. "31-55" は 31 から 55,
#            "31-" は 31 から最後まで, "12,31-55" は 12 と 31 から 55.
#            指定したチャンクだけを生成し, それ以外の out_NN.md には触れない
# 長いテキストを数回に分けて生成するためのもの. 2 回目以降は前回までの
# chunkspec に続きを足した chunkspec を渡し, 新しく増えたチャンクの番号を
# TAIYAKU_GEN に指定する. 組み立てと検証は毎回行い, md にはその時点で
# 生成済みのチャンクがすべて入る. 全体が揃うまで md の frontmatter には
# status: incomplete が付く (assemble_md.rb が判定する).
# 生成済みチャンクの原文 (chunk_NN.txt) が今回の chunkspec で変わる場合は,
# out_NN.md と対応しなくなるため生成前に abort する.
# 失敗したチャンクだけを再生成するときにも使う. 例:
#   TAIYAKU_UNTIL="2. Sabbāsavasuttavaṇṇanā" TAIYAKU_GEN=31- scripts/taiyaku.sh \
#     _tmp/s0201a.att1.xml "1. Mūlapariyāyasuttavaṇṇanā" "<1 回目の chunkspec>,<続き>" \
#     _tmp/work_mn_attha_001 mn/mn_attha_001.md claude-fable-5-1
#
# 環境変数 TAIYAKU_EXCERPT に値 (1 など) を指定すると, セクションの一部だけを
# 対訳する場合 (Dhp-a の vatthu で偈と語句註のみ対訳する等) として扱い,
# chunkspec がセクション全体に届いていなくても status: incomplete を付けない.
# 未指定で一部だけの chunkspec を渡すと, 分割生成の途中とみなして
# status: incomplete が付く
#
# 注意:
# - 生成で 401 が出る場合は claude login で CLI の再ログインが必要
# - 生成の cwd は workdir. リポジトリ内 workdir ではプロジェクト CLAUDE.md が
#   プロンプトに入る (翻訳の方針が伝わるため現状は許容)
# - <out_md> のディレクトリは先に作っておく. ないと抽出の前に abort する
#   (issue #63)
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

# workdir と out_md の名前を規則 (ヘッダコメント参照. issue #59) と照合する.
# workdir は _tmp/ 直下の work_<out_md のファイル名>. _tmp/ に出す md は
# 比較用・試験用に限り, ファイル名を <ファイル名>__<ラベル>.md にする.
# 規則に合わないと md から workdir を名前で引けなくなるため, 抽出の前に abort する.
#
# 規則を決める前の workdir は名前を変えずに使い続ける (チャンクの再生成や
# やり直し). そのため, workdir の run.txt の out_md が今回の out_md と同じ
# ファイル名なら, 名前が規則と違っても通す. 逆に, 規則どおりの名前でも,
# その md を記録した workdir がほかにあれば abort する (規則を決める前の
# workdir がある md に 2 つ目の workdir を作らないため).
# ディレクトリは -ef で比べる (シンボリックリンクや大文字小文字の違う
# パスで呼ばれても同じ場所と判定できる)
md_name=$(basename "$out_md")
md_base=$(basename "$out_md" .md)
# run.txt ($1) に記録された out_md のファイル名を出す. 記録がなければ空
recorded_md() {
  [ -f "$1" ] || return 0
  local rec
  rec=$(sed -n '/^out_md: /{s///p;q;}' "$1")
  [ -z "$rec" ] || basename "$rec"
}
own_md=$(recorded_md "$workdir/run.txt")
if [ ! "$(dirname "$workdir")" -ef "$repo_root/_tmp" ] \
  || { [ "$(basename "$workdir")" != "work_$md_base" ] && [ "$own_md" != "$md_name" ]; }; then
  echo "workdir は _tmp/work_$md_base にしてください (out_md のファイル名から決まる. issue #59). 指定: $workdir" >&2
  exit 1
fi
if [ -n "$own_md" ] && [ "$own_md" != "$md_name" ]; then
  echo "指定の workdir は別の md ($own_md) の生成に使われています (run.txt の out_md). 指定: $workdir $out_md" >&2
  exit 1
fi
if [ -z "$own_md" ]; then
  for f in "$repo_root"/_tmp/work_*/run.txt; do
    if [ "$(recorded_md "$f")" = "$md_name" ]; then
      echo "$md_name の workdir はすでにあります: _tmp/$(basename "$(dirname "$f")") (run.txt の out_md). やり直しや再生成はこの workdir で行ってください. 指定: $workdir" >&2
      exit 1
    fi
  done
fi
if [ "$(dirname "$out_md")" -ef "$repo_root/_tmp" ] && [[ $md_base != *__* ]]; then
  echo "_tmp/ に出す比較用・試験用の md はファイル名を <ファイル名>__<ラベル>.md にしてください. 指定: $out_md" >&2
  exit 1
fi

# out_md のディレクトリがなければ, 抽出の前に abort する (issue #63).
# assemble_md.rb はディレクトリを作らないため, ないまま進むと生成がすべて
# 終わったあとの組み立てで失敗する. ここで作らずに abort するのは,
# ディレクトリ名の打ち間違いに生成の前に気づけるようにするため
md_dir=$(dirname "$out_md")
if [ ! -d "$md_dir" ]; then
  echo "out_md のディレクトリがありません: $md_dir. 新しいディレクトリなら先に作ってください (mkdir -p \"$md_dir\")" >&2
  exit 1
fi

# 生成の同時実行数の上限 (詳細はヘッダコメント参照)
jobs_max=${TAIYAKU_JOBS:-50}
if [[ ! $jobs_max =~ ^[1-9][0-9]*$ ]]; then
  echo "TAIYAKU_JOBS は正の整数を指定. 指定: $jobs_max" >&2
  exit 1
fi

# 生成するチャンクの指定 (詳細はヘッダコメント参照). 未指定なら全チャンク
gen_spec=${TAIYAKU_GEN:-}
if [ -n "$gen_spec" ] && [[ ! $gen_spec =~ ^[0-9]+(-[0-9]*)?(,[0-9]+(-[0-9]*)?)*$ ]]; then
  echo "TAIYAKU_GEN はチャンク番号か範囲のカンマ区切りで指定 (例 31-55, 31-, 12,31-55). 指定: $gen_spec" >&2
  exit 1
fi
# チャンク番号 $1 (chunk_NN.txt の NN) が今回の生成対象かどうか.
# 先頭の 0 で 8 進数と解釈されないよう 10# を付けて比べる
in_gen() {
  [ -z "$gen_spec" ] && return 0
  local n=$((10#$1)) part a b
  local IFS=,
  for part in $gen_spec; do
    a=${part%%-*}
    case "$part" in
      *-) b=999999 ;;
      *-*) b=${part#*-} ;;
      *) b=$a ;;
    esac
    if [ "$n" -ge "$((10#$a))" ] && [ "$n" -le "$((10#$b))" ]; then
      return 0
    fi
  done
  return 1
}

# 認証方法. api では PALI_AI_NOTES_CLAUDE_API_KEY を ANTHROPIC_API_KEY として
# claude -p に渡す
auth=${TAIYAKU_AUTH:-subscription}
case "$auth" in
  subscription) ;;
  api)
    if [ -z "${PALI_AI_NOTES_CLAUDE_API_KEY:-}" ]; then
      echo "TAIYAKU_AUTH=api には環境変数 PALI_AI_NOTES_CLAUDE_API_KEY が必要です" >&2
      exit 1
    fi
    export ANTHROPIC_API_KEY=$PALI_AI_NOTES_CLAUDE_API_KEY
    # デスクトップアプリのセッションから呼ぶと CLAUDE_CODE_ENTRYPOINT=claude-desktop
    # が継承され, ANTHROPIC_API_KEY があってもサブスクリプション側の認証で
    # 生成される (無効なキーでも生成が通り, 出力にサブスクリプションの
    # rate_limit_event が出ることで確認. CLI 2.1.322). 外すとキーが使われる
    unset CLAUDE_CODE_ENTRYPOINT
    ;;
  *)
    echo "TAIYAKU_AUTH は subscription か api を指定. 指定: $auth" >&2
    exit 1
    ;;
esac

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

# 分割生成 (TAIYAKU_GEN) では, 今回生成しないチャンクの out_NN.md を前回の
# まま使う. その原文 chunk_NN.txt が今回の chunkspec で変わると原文と対訳が
# 対応しなくなるため, 生成時に meta_NN.txt へ記録したチェックサム (3 行目) と
# 比べる. 記録のないチャンク (meta_NN.txt 導入前の workdir) は比べない
if [ -n "$gen_spec" ]; then
  changed=""
  for chunk in "$workdir"/chunk_*.txt; do
    n=$(basename "$chunk" .txt); n=${n#chunk_}
    if in_gen "$n" || [ ! -f "$workdir/out_$n.md" ] || [ ! -f "$workdir/meta_$n.txt" ]; then
      continue
    fi
    sum=$(sed -n '3p' "$workdir/meta_$n.txt")
    if [ -n "$sum" ] && [ "$(cksum < "$chunk")" != "$sum" ]; then
      changed+=" $n"
    fi
  done
  if [ -n "$changed" ]; then
    echo "生成済みチャンクの原文が今回の chunkspec で変わっています:$changed" >&2
    echo "前回までの chunkspec を変えずに続きを足すか, 変わったチャンクを TAIYAKU_GEN に含めてください" >&2
    exit 1
  fi
fi

# 実行時の指定を workdir に残す. 分割生成の次の回 (日をまたいで別の
# セッションになることがある) で, 前回までの chunkspec と環境変数を
# 確かめるために使う. 上の検査で abort した実行の chunkspec を残さないよう,
# 検査を通ったあとに書く.
# out_md は workdir からその md をたどるのにも使う (issue #59).
# run.txt は毎回上書きされるため, 同じ内容を run_history.txt に追記して
# 分割生成の各回ややり直しの経過を残す.
# run_history.txt のない workdir (追記を始める前のもの) では, 上書きする前の
# run.txt を最初の記録として写す (後から記録した retro: の行もここに残る)
if [ -f "$workdir/run.txt" ] && [ ! -f "$workdir/run_history.txt" ]; then
  cp "$workdir/run.txt" "$workdir/run_history.txt"
fi
{
  echo "date: $(date '+%Y/%m/%d %H:%M')"
  echo "xml: $(basename "$xml")"
  echo "subhead: $subhead"
  echo "chunkspec: $chunkspec"
  echo "headings: $headings"
  echo "out_md: $out_md"
  echo "model: $model"
  echo "effort: $effort"
  echo "TAIYAKU_UNTIL: ${TAIYAKU_UNTIL:-}"
  echo "TAIYAKU_CTX: ${TAIYAKU_CTX:-none}"
  echo "TAIYAKU_GEN: ${gen_spec:-all}"
  echo "TAIYAKU_EXCERPT: ${TAIYAKU_EXCERPT:-}"
} > "$workdir/run.txt"
{
  [ -s "$workdir/run_history.txt" ] && echo
  cat "$workdir/run.txt"
} >> "$workdir/run_history.txt"

# title 起点セクションでは構造ブロック一覧 struct.txt が書き出される.
# 組み立てと検証で段落番号の検出から除外するために渡す.
# bash 3.2 の set -u は空配列の展開を unbound variable にするため,
# ${arr[@]+...} の形で展開する
struct_args=()
[ -f "$workdir/struct.txt" ] && struct_args=(--struct "$workdir/struct.txt")

# 2. 生成. チャンクごとに claude -p のクリーンな別プロセスを並列で呼ぶ.
# TAIYAKU_CTX 指定時は参照文脈付きの prompt_NN.txt を, 未指定時は
# chunk_NN.txt をそのまま stdin に流す.
# 同時実行数は jobs_max までとし, 実行中のジョブが上限に達している間は
# 空きが出るまで待ってから次のチャンクを起動する (bash 3.2 には wait -n が
# ないため, 実行中ジョブ数を 1 秒ごとに数える)
#
# TAIYAKU_GEN 指定時は該当チャンクだけを生成する. 生成したチャンクには
# 生成日とモデルラベルを meta_NN.txt (1 行目 = 日付, 2 行目 = ラベル,
# 3 行目 = 生成に使った chunk_NN.txt のチェックサム) に記録する.
# assemble_md.rb がチャンクごとの Meta ブロックに使うため, 日をまたいで
# 分割生成しても先に生成したチャンクの日付とラベルが変わらない
#
# --strict-mcp-config で MCP の設定をすべて無視する (--mcp-config は渡さない).
# --tools "" は組み込みツールを外すだけで, CLI 側に登録した MCP サーバと
# claude.ai コネクタのツール定義はリクエストに残る. 対訳の生成はツールを
# 使わないため, 辞書や本文検索を引ける状態にせず, 定義の分の入力も省く
# (issue #57. 2026/11/15 の実測では, パーリの MCP サーバを CLI に登録した
# 状態のチャンクあたりの入力が, サブスクリプションで約 66,000 から約 8,300
# トークン, API キーで約 20,000 から約 7,800 トークンになった).
# 認証の分岐の外にあるため, サブスクリプションと API キーの両方に効く
echo "generate: ctx=${TAIYAKU_CTX:-none} auth=$auth jobs=$jobs_max gen=${gen_spec:-all}"
gen_count=0
for chunk in "$workdir"/chunk_*.txt; do
  n=$(basename "$chunk" .txt); n=${n#chunk_}
  in_gen "$n" || continue
  gen_count=$((gen_count + 1))
  input="chunk_$n.txt"
  [ -f "$workdir/prompt_$n.txt" ] && input="prompt_$n.txt"
  while [ "$(jobs -rp | wc -l)" -ge "$jobs_max" ]; do
    sleep 1
  done
  (
    cd "$workdir"
    claude -p \
      --model "$model" \
      --effort "$effort" \
      --system-prompt "$(cat "$repo_root/system_prompt_no_paraphrase.md")" \
      --disable-slash-commands \
      --tools "" \
      --strict-mcp-config \
      < "$input" > "out_$n.md" 2> "err_$n.log"
    printf '%s\n%s\n%s\n' "$(date +%Y/%m/%d)" "$label" "$(cksum < "chunk_$n.txt")" > "meta_$n.txt"
  ) &
done
wait
if [ "$gen_count" -eq 0 ]; then
  echo "TAIYAKU_GEN=$gen_spec に該当するチャンクがありません" >&2
  exit 1
fi
echo "generated: $gen_count chunks"

# 生成失敗 (空出力や API エラー, 利用上限) の検出.
# 利用上限時は出力が "You've reached your ... limit" のメッセージだけになり
# exit 0 のまま通過するため, 文字列で検出する (2026/08/04 に 17/20 チャンクが
# このメッセージのまま組み立てられた実例あり)
#
# API キー認証 (TAIYAKU_AUTH=api) ではキー無効時に "Invalid API key",
# 残高不足時に "Credit balance is too low" だけが出力になり, これらも
# exit 0 のまま通過するため同様に文字列で検出する
#
# 対訳になっていない出力 (「### 対訳」の行が 1 つもない) も失敗として扱う.
# モデルが訳出用プロンプトに応じず, 挨拶などの短い文だけを返すことがあり,
# これも exit 0 のまま通過する (2026/11/17 に mn_attha_085 のチャンク 8 と
# mn_attha_059 のチャンク 4 で実例あり. リクエストは再生成時と同一で,
# 再生成では通常の対訳になった). 組み立ての WARN は出るが, 検証は対訳が
# 空のセクションを NG にしないため, 組み立ての前にここで止める.
# 冒頭に余計な見出しが付いただけの出力は「### 対訳」の行を持つため, ここでは
# 失敗にせず, 従来どおり組み立ての WARN に任せる
fail=0
auth_fail=0
limit_fail=0
key_fail=0
credit_fail=0
format_fail=0
for out in "$workdir"/out_*.md; do
  if [ ! -s "$out" ] || grep -q "API Error" "$out" || grep -q "You've reached your" "$out" \
    || grep -q "^Invalid API key" "$out" || grep -q "^Credit balance is too low" "$out"; then
    echo "generation failed: $out" >&2
    sed -n '1p' "$out" >&2
    fail=1
    grep -q "401" "$out" && auth_fail=1
    grep -q "You've reached your" "$out" && limit_fail=1
    grep -q "^Invalid API key" "$out" && key_fail=1
    grep -q "^Credit balance is too low" "$out" && credit_fail=1
  elif ! grep -q "^### 対訳" "$out"; then
    echo "generation failed: $out" >&2
    sed -n '1p' "$out" | cut -c1-200 >&2
    fail=1
    format_fail=1
  fi
done
if [ "$auth_fail" -eq 1 ]; then
  echo "CLI の認証トークンが失効しています. claude login で再ログインしてください" >&2
fi
if [ "$key_fail" -eq 1 ]; then
  echo "API キーが無効です. PALI_AI_NOTES_CLAUDE_API_KEY を確認してください" >&2
fi
if [ "$credit_fail" -eq 1 ]; then
  echo "API のクレジット残高が不足しています. 補充後に失敗チャンクのみ再生成してください" >&2
fi
if [ "$limit_fail" -eq 1 ]; then
  echo "モデルの利用上限に達しています. 回復後に失敗チャンクのみ再生成してください" >&2
fi
if [ "$format_fail" -eq 1 ]; then
  echo "対訳になっていない出力があります (「### 対訳」の行がない). 失敗チャンクのみ TAIYAKU_GEN で再生成してください" >&2
fi
[ "$fail" -eq 0 ] || exit 1

# 3. md 組み立て (原文ブロックはチャンクから byte-exact コピー)
ruby "$repo_root/scripts/assemble_md.rb" "$workdir" "$out_md" "$(date +%Y/%m/%d)" "$label" \
  ${headings:+"$headings"} --source "$src_url" ${struct_args[@]+"${struct_args[@]}"} \
  ${TAIYAKU_EXCERPT:+--excerpt}

# 4. 対訳中のパーリ再掲行を正本と照合
ruby "$repo_root/scripts/verify_taiyaku.rb" ${struct_args[@]+"${struct_args[@]}"} \
  "$workdir/source.txt" "$out_md"
