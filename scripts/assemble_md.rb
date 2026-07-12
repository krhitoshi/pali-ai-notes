# チャンクと生成結果から対訳 md を組み立てるスクリプト
#
# 使い方:
#   ruby scripts/assemble_md.rb <workdir> <out_md> <date> <model_label>
#
# 例:
#   ruby scripts/assemble_md.rb work sn/sn_54_1_10_fable5.md 2026/07/12 "Claude Fable 5 High"
#
# - <workdir> には extract_chunks.rb の chunk_NN.txt と生成結果 out_NN.md を置く
# - 原文ブロックは chunk_NN.txt から byte-exact でコピーする (LLM 出力を使わない)
# - out_NN.md はコードブロックのフェンスを外して「### 対訳」以下を取り込む
# - 見出しは "## <段落番号>". 段落番号はチャンク先頭の本文段落から取り,
#   番号のないチャンクは直前の番号を引き継ぐ. 同じ番号が複数チャンクに
#   またがる場合のみ "## <段落番号> (N)" と連番を付ける

workdir, out_md, date, model_label = ARGV.map { |a| a&.dup&.force_encoding("UTF-8") }
abort "usage: assemble_md.rb <workdir> <out_md> <date> <model_label>" unless model_label

chunk_paths = Dir[File.join(workdir, "chunk_*.txt")].sort
gen_paths = Dir[File.join(workdir, "out_*.md")].sort
abort "chunk/out count mismatch (#{chunk_paths.size}/#{gen_paths.size})" if chunk_paths.size != gen_paths.size

# 先頭チャンクの 1 行目は経題
first = File.read(chunk_paths[0], encoding: "UTF-8")
title, _, = first.partition(/\n\n/)

# チャンクごとの原文ブロック (先頭チャンクは経題行を除く)
bodies = chunk_paths.each_with_index.map do |path, i|
  body = File.read(path, encoding: "UTF-8").chomp
  i.zero? ? body.partition(/\n\n/).last : body
end

# 見出し用の段落番号: チャンク先頭の段落から取り, なければ直前を引き継ぐ.
# 同じ番号が複数チャンクにまたがる場合のみ連番 (N) を付ける
last = nil
paranums = bodies.map do |body|
  n = body[/\A(\d+)\./, 1]
  last = n if n
  last or abort "paranum not found in first chunk"
end
# tally は Ruby 2.7+ のため手動で数える
counts = Hash.new(0)
paranums.each { |n| counts[n] += 1 }
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

out = +"\n# #{title}\n"
bodies.each_with_index do |body, i|
  gen = unfence(File.read(gen_paths[i], encoding: "UTF-8"))
  warn "WARN: #{gen_paths[i]} does not start with '### 対訳'" unless gen.start_with?("### 対訳")
  out << "\n## #{headings[i]}\n\n"
  out << body << "\n\n"
  out << "### Meta\n\n- #{date}\n- #{model_label}\n\n"
  out << gen << "\n"
end

File.write(out_md, out)
puts "wrote #{out_md} (#{out.bytesize} bytes, #{chunk_paths.size} chunks)"
