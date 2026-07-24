# VRI XML から経を抽出しチャンクに分割するスクリプト
#
# 使い方:
#   ruby scripts/extract_chunks.rb <xml> <subhead> [<outdir> <chunkspec>]
#
# 例:
#   ruby scripts/extract_chunks.rb _tmp/s0305m.mul9.xml "10. Kimilasuttaṃ" work "1-3,4,5-6,7-8,9"
#   ruby scripts/extract_chunks.rb _tmp/s0305m.mul9.xml "10. Kimilasuttaṃ"   # 段落一覧のみ
#
# - <subhead> は <p rend="subhead"> の見出しテキストと完全一致させる
# - <chunkspec> は段落番号 (1 始まり) のグループ指定. 例 "1-3,4,5-9"
# - <outdir> と <chunkspec> を省略すると, チャンク境界を決めるための
#   段落一覧 (連番, VRI 段落番号, 文字数, 冒頭) を表示して終了する
# - 出力: <outdir>/source.txt (正本, read-only) と <outdir>/chunk_NN.txt
# - チャンク先頭 (chunk_01) には経題行を含める
# - 全チャンクを連結すると source.txt と一致することを assert する

# ARGV はロケールによって binary になるため UTF-8 を強制する
xml_path, subhead, outdir, chunkspec = ARGV.map { |a| a.dup.force_encoding("UTF-8") }
abort "usage: extract_chunks.rb <xml> <subhead> [<outdir> <chunkspec>]" unless subhead
abort "usage: extract_chunks.rb <xml> <subhead> [<outdir> <chunkspec>]" if outdir && !chunkspec

# VRI XML は UTF-16LE (BOM 付き)
raw = File.read(xml_path, mode: "rb", encoding: "UTF-16LE:UTF-8")
raw.sub!(/\A﻿/, "")

# 対象経の subhead から次の subhead/title/centre までの bodytext 段落を集める
lines = raw.split(/\r?\n/)
start = lines.index { |l| l =~ %r{<p rend="subhead">#{Regexp.escape(subhead)}</p>} }
abort "subhead not found: #{subhead}" unless start

# 本文段落として取り込む rend. bodytext のほか, 註釈書に現れる
# unindented (続き段落), indent, 偈 (gatha1..gathalast) を含める.
# hangnum は偈の前に段落番号だけが独立段落になる形 (Vism 8 章 §223 など)
BODY_RENDS = %w[bodytext unindented indent gatha1 gatha2 gatha3 gathalast hangnum].freeze

paras = []
lines[(start + 1)..].each do |line|
  line = line.strip
  next if line.empty?
  rend = line[/\A<p rend="([^"]+)"/, 1]
  unless BODY_RENDS.include?(rend)
    # 経の結び (MN などの "... niṭṭhitaṃ ..." centre 段落) は含める.
    # vagga の結び ("...vaggo paṭhamo." など) は niṭṭhitaṃ を含まないので除外される
    paras << line if rend == "centre" && line.include?("niṭṭhitaṃ")
    break
  end
  paras << line
end
abort "no bodytext paragraphs found" if paras.empty?

# タグ処理: LLM を通さず決定論的に平文へ変換する
# - 段落番号 <hi rend="paranum">986</hi><hi rend="dot">.</hi> -> "986."
#   (直後に空白がなければ 1 個補う. 既存の手動対訳の表記に合わせる)
# - 太字 <hi rend="bold">X</hi> -> "X". 註釈書の語句引用の強調は平文化する
#   (既存の手動対訳 patis_attha_1_03.md, vism_08.md が太字マーカーを使わない
#   表記のため)
# - 異読 <note>X</note> -> "[X]"
# - 頁番号 <pb ... /> -> 削除
# - 連続スペースは 1 個に集約 (pb 除去に伴う "bhāsati ," 型の空白は残る)
def to_plain(p)
  s = p.dup
  s.sub!(/\A<p[^>]*>/, "")
  s.sub!(%r{</p>\z}, "")
  s.gsub!(%r{<hi rend="paranum">([^<]*)</hi><hi rend="dot">\.</hi>}, '\1.')
  s.gsub!(%r{<hi rend="bold">([^<]*)</hi>}, '\1')
  s.gsub!(%r{<note>([^<]*)</note>}, '[\1]')
  s.gsub!(%r{<pb [^>]*/>}, "")
  s.gsub!(/ {2,}/, " ")
  s.strip!
  s.sub!(/\A(\d+)\.(?=\S)/, '\1. ')
  s
end

blocks = [subhead] + paras.map { |p| to_plain(p) }

# chunkspec 省略時は段落一覧を表示して終了する (チャンク境界の検討用)
unless chunkspec
  puts subhead
  blocks[1..].each_with_index do |b, i|
    num = b[/\A(\d+)\./, 1]
    puts format("%3d | para %-4s | %5d chars | %s", i + 1, num.to_s, b.size, b[0, 60])
  end
  exit
end

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
  # チャンク途中から始まる VRI 段落番号は組み立て時に自分のセクション
  # 見出しを持てず, 後続チャンクの見出しラベルも誤解を招くため警告する
  nums[1..].each do |n|
    pn = blocks[n][/\A(\d+)\./, 1]
    warn "WARN: chunk #{i + 1}: 段落 #{n} (VRI #{pn}) がチャンク途中にある. " \
         "番号の先頭で新チャンクを始めることを検討" if pn
  end
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
