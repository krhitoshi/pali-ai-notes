# VRI XML から経を抽出しチャンクに分割するスクリプト
#
# 使い方:
#   ruby scripts/extract_chunks.rb <xml> <subhead> <outdir> <chunkspec>
#
# 例:
#   ruby scripts/extract_chunks.rb _tmp/s0305m.mul9.xml "10. Kimilasuttaṃ" work "1-3,4,5-6,7-8,9"
#
# - <subhead> は <p rend="subhead"> の見出しテキストと完全一致させる
# - <chunkspec> は段落番号 (1 始まり) のグループ指定. 例 "1-3,4,5-9"
# - 出力: <outdir>/source.txt (正本, read-only) と <outdir>/chunk_NN.txt
# - チャンク先頭 (chunk_01) には経題行を含める
# - 全チャンクを連結すると source.txt と一致することを assert する

# ARGV はロケールによって binary になるため UTF-8 を強制する
xml_path, subhead, outdir, chunkspec = ARGV.map { |a| a.dup.force_encoding("UTF-8") }
abort "usage: extract_chunks.rb <xml> <subhead> <outdir> <chunkspec>" unless chunkspec

# VRI XML は UTF-16LE (BOM 付き)
raw = File.read(xml_path, mode: "rb", encoding: "UTF-16LE:UTF-8")
raw.sub!(/\A﻿/, "")

# 対象経の subhead から次の subhead/title/centre までの bodytext 段落を集める
lines = raw.split(/\r?\n/)
start = lines.index { |l| l =~ %r{<p rend="subhead">#{Regexp.escape(subhead)}</p>} }
abort "subhead not found: #{subhead}" unless start

paras = []
lines[(start + 1)..].each do |line|
  line = line.strip
  next if line.empty?
  break unless line.start_with?('<p rend="bodytext"')
  paras << line
end
abort "no bodytext paragraphs found" if paras.empty?

# タグ処理: LLM を通さず決定論的に平文へ変換する
# - 段落番号 <hi rend="paranum">986</hi><hi rend="dot">.</hi> -> "986."
# - 異読 <note>X</note> -> "[X]"
# - 頁番号 <pb ... /> -> 削除
# - 連続スペースは 1 個に集約 (pb 除去に伴う "bhāsati ," 型の空白は残る)
def to_plain(p)
  s = p.dup
  s.sub!(/\A<p[^>]*>/, "")
  s.sub!(%r{</p>\z}, "")
  s.gsub!(%r{<hi rend="paranum">([^<]*)</hi><hi rend="dot">\.</hi>}, '\1.')
  s.gsub!(%r{<note>([^<]*)</note>}, '[\1]')
  s.gsub!(%r{<pb [^>]*/>}, "")
  s.gsub!(/ {2,}/, " ")
  s.strip
end

blocks = [subhead] + paras.map { |p| to_plain(p) }

# 正本を書き出し read-only にする
require "fileutils"
FileUtils.mkdir_p(outdir)
source_path = File.join(outdir, "source.txt")
File.chmod(0644, source_path) if File.exist?(source_path)
source = blocks.join("\n\n") + "\n"
File.write(source_path, source)
File.chmod(0444, source_path)

# chunkspec を解釈してチャンクを書き出す
# 段落番号は経題を除いた bodytext 段落の 1 始まり
groups = chunkspec.split(",").map do |spec|
  a, b = spec.split("-").map(&:to_i)
  (a..(b || a)).to_a
end
covered = groups.flatten
expected = (1..paras.size).to_a
abort "chunkspec mismatch: covers #{covered.inspect}, expected #{expected.inspect}" unless covered == expected

chunk_paths = []
groups.each_with_index do |nums, i|
  body = nums.map { |n| blocks[n] }
  # 先頭チャンクには経題行を含める
  body.unshift(blocks[0]) if i.zero?
  path = File.join(outdir, format("chunk_%02d.txt", i + 1))
  File.write(path, body.join("\n\n") + "\n")
  chunk_paths << path
end

# 連結一致 assert: 全チャンク連結 == 正本
# ロケールが C でも比較が壊れないよう UTF-8 を明示して読み込む
joined = chunk_paths.map { |p| File.read(p, encoding: "UTF-8").chomp }.join("\n\n") + "\n"
if joined == source
  puts "OK: #{chunk_paths.size} chunks, concat == source (#{source.bytesize} bytes)"
  chunk_paths.each { |p| puts "  #{p} (#{File.read(p).bytesize} bytes)" }
else
  abort "ASSERT FAILED: concatenated chunks differ from source"
end
