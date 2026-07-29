# チャンクと生成結果から対訳 md を組み立てるスクリプト
#
# 使い方:
#   ruby scripts/assemble_md.rb <workdir> <out_md> <date> <model_label> [headings] \
#     [--source <url>] [--struct <file>]
#
# 例:
#   ruby scripts/assemble_md.rb work sn/sn_54_1_10_fable5.md 2026/07/12 "Claude Fable 5 High"
#   ruby scripts/assemble_md.rb work dhammapada/dhp_attha_345-346.md 2026/07/26 \
#     "Claude Fable 5 High" "1:345-346,4:345-346,5:345-346"
#
# - <workdir> には extract_chunks.rb の chunk_NN.txt と生成結果 out_NN.md を置く
# - 原文ブロックは chunk_NN.txt から byte-exact でコピーする (LLM 出力を使わない)
# - out_NN.md はコードブロックのフェンスを外して「### 対訳」以下を取り込む
# - 見出しは "## <段落番号>". 段落番号はチャンク先頭の本文段落から取り,
#   番号のないチャンクは直前の番号を引き継ぐ. 同じ番号が複数チャンクに
#   またがる場合のみ "## <段落番号> (N)" と連番を付ける
# - 先頭チャンクに段落番号がない場合 (Dhp-a の vatthu 導入部など, 最初の
#   番号より前に本文がある形) は後続で最初に現れる番号を引き継ぐ
# - [headings] は "チャンク番号:ラベル" のカンマ区切りで見出しラベルを
#   上書きする (例 "1:345-346,4:345-346"). 番号規則で決まらない編集判断
#   (物語導入部や複数偈にまたがる語句註を偈の範囲でラベル付けする等) を
#   組み立て段階で明示するためのもの. 省略時は完全に従来動作
# - --source は原文 XML の URL. 出力 md 先頭の frontmatter
#   (source, generated, updated) に書く. 省略時は source 行なし
# - --struct は extract_chunks.rb が書き出した構造ブロック一覧 (struct.txt).
#   一致するブロック (数字で始まる subhead "1. Gaṇanavāra" など) を
#   見出し用の段落番号の検出から除外する

args = ARGV.map { |a| a&.dup&.force_encoding("UTF-8") }
source_url = nil
if (i = args.index("--source"))
  args.delete_at(i)
  source_url = args.delete_at(i)
  abort "usage: assemble_md.rb ... --source <url>" unless source_url
end
struct_blocks = []
if (i = args.index("--struct"))
  args.delete_at(i)
  struct_path = args.delete_at(i)
  abort "usage: assemble_md.rb ... --struct <file>" unless struct_path
  struct_blocks = File.read(struct_path, encoding: "UTF-8").split("\n").reject(&:empty?)
end
workdir, out_md, date, model_label, headings_spec = args
abort "usage: assemble_md.rb <workdir> <out_md> <date> <model_label> [headings] [--source <url>] [--struct <file>]" unless model_label

overrides = {}
if headings_spec
  headings_spec.split(",").each do |pair|
    i, label = pair.split(":", 2)
    abort "invalid headings spec: #{pair}" unless label && !label.empty? && i =~ /\A\d+\z/
    overrides[i.to_i] = label
  end
end

chunk_paths = Dir[File.join(workdir, "chunk_*.txt")].sort
gen_paths = chunk_paths.map { |p| p.sub(/chunk_(\d+)\.txt\z/, 'out_\1.md') }
# 生成結果が揃っていないチャンクはスキップして部分組み立てにする
# (長いテキストを数回に分けて生成する運用のため). 欠けを警告する
missing = gen_paths.reject { |p| File.exist?(p) }
abort "no generation outputs in #{workdir}" if missing.size == chunk_paths.size
unless missing.empty?
  warn "WARN: partial assembly, missing #{missing.size}/#{chunk_paths.size}: " +
       missing.map { |p| File.basename(p) }.join(", ")
end

# 先頭チャンクの 1 行目は経題
first = File.read(chunk_paths[0], encoding: "UTF-8")
title, _, = first.partition(/\n\n/)

# チャンクごとの原文ブロック (先頭チャンクは経題行を除く)
bodies = chunk_paths.each_with_index.map do |path, i|
  body = File.read(path, encoding: "UTF-8").chomp
  i.zero? ? body.partition(/\n\n/).last : body
end

# 見出し用の段落番号: チャンク先頭の段落から取り, なければ直前チャンクまでに
# 最後に現れた番号を引き継ぐ (チャンク途中で番号が進む場合があるため,
# チャンク先頭の番号ではなく本文中の最後の番号を引き継ぎ元にする).
# 同じ番号が複数チャンクにまたがる場合のみ連番 (N) を付ける.
# 構造ブロック (--struct) は番号の検出から除外する. チャンク先頭が
# subhead の場合は直後の本文段落から番号を取る
last = nil
paranums = bodies.map do |body|
  paras = body.split(/\n\n/).reject { |b| struct_blocks.include?(b) }
  n = paras.first&.[](/\A(\d+)\./, 1) || last
  nums = paras.map { |b| b[/\A(\d+)\./, 1] }.compact
  last = nums.last || last
  n
end
# 見出しラベルの上書きを適用する (番号の引き継ぎ計算には影響しない)
bad = overrides.keys.reject { |i| (1..paranums.size).cover?(i) }
abort "headings spec: chunk #{bad.join(', ')} not found" unless bad.empty?
paranums = paranums.each_with_index.map { |n, i| overrides[i + 1] || n }

# 先頭チャンクに番号がない場合は後続で最初に現れる番号を引き継ぐ
first_num = paranums.compact.first
abort "paranum not found in any chunk" unless first_num
paranums = paranums.map { |n| n || first_num }
counts = paranums.tally
seen = Hash.new(0)
headings = paranums.map do |n|
  seen[n] += 1
  counts[n] > 1 ? "#{n} (#{seen[n]})" : n
end

# 生成結果からコードブロックのフェンスと前後の空行を外す
def unfence(s)
  s = s.strip
  if s.start_with?("```")
    lines = s.lines
    lines.shift
    lines.pop while lines.any? && lines.last.strip == "```"
    s = lines.join.strip
  end
  s
end

# 先頭にファイル単位のメタ情報 (frontmatter) を置く. updated は改訂時に手動更新する
out = +"---\n"
out << "source: #{source_url}\n" if source_url
out << "generated: #{date}\n"
out << "updated: #{date}\n"
out << "---\n"
out << "\n# #{title}\n"
assembled = 0
bodies.each_with_index do |body, i|
  next unless File.exist?(gen_paths[i])
  gen = unfence(File.read(gen_paths[i], encoding: "UTF-8"))
  warn "WARN: #{gen_paths[i]} does not start with '### 対訳'" unless gen.start_with?("### 対訳")
  out << "\n## #{headings[i]}\n\n"
  out << body << "\n\n"
  out << "### Meta\n\n- #{date}\n- #{model_label}\n\n"
  out << gen << "\n"
  assembled += 1
end

File.write(out_md, out)
puts "wrote #{out_md} (#{out.bytesize} bytes, #{assembled}/#{chunk_paths.size} chunks)"
