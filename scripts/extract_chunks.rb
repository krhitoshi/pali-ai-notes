# VRI XML から経を抽出しチャンクに分割するスクリプト
#
# 使い方:
#   ruby scripts/extract_chunks.rb <xml> <subhead> [<outdir> <chunkspec>]
#
# 例:
#   ruby scripts/extract_chunks.rb _tmp/s0305m.mul9.xml "10. Kimilasuttaṃ" work "1-3,4,5-6,7-8,9"
#   ruby scripts/extract_chunks.rb _tmp/s0305m.mul9.xml "10. Kimilasuttaṃ"   # 段落一覧のみ
#
# - <subhead> は <p rend="subhead"> / <p rend="title"> / <p rend="chapter"> /
#   <p rend="subsubhead"> の見出しテキストと完全一致させる.
#   title 起点の場合 (Patis の kathā など) は
#   次の title までを 1 セクションとし, 内部の subhead / centre 段落も
#   本文ブロックとして含める. chapter 起点の場合 (Patis-a の kathā 註など) は
#   次の chapter までとし, 内部の title / subhead / centre を含める.
#   見出し rend で見つからない場合は bodytext 段落の完全一致 (前後空白を無視)
#   も探す (Jātaka-a の各話見出し " [20] 10. Naḷapānajātakavaṇṇanā" のように
#   見出しが bodytext で書かれている形に対応). bodytext 起点の場合は次の
#   centre (各話の結び "...vaṇṇanā dasamā." など) までを 1 セクションとし,
#   結びの centre も本文ブロックとして含める.
#   subsubhead 起点の場合 (MN 註の冒頭 s0201a.att0.xml の "Ganthārambhakathā"
#   など) は次の上位見出し (subhead / title / chapter) かファイル末尾までを
#   1 セクションとし, 続く同位の subsubhead ("Nidānakathā") も構造ブロック
#   として含める. 註釈書冒頭の序偈と nidāna を 1 ファイルにまとめるための形で,
#   MN 註の冒頭以外の構造 (DN 註や復註の冒頭など) は未確認.
#   その構造ブロックの一覧を <outdir>/struct.txt に書き出す (assemble_md.rb と
#   verify_taiyaku.rb が段落番号の検出・欠番検査から除外するために使う)
# - 環境変数 TAIYAKU_UNTIL に見出しテキスト (例 "8. Mārakathā") を指定すると,
#   起点見出しから TAIYAKU_UNTIL の見出しの直前までを 1 セクションとし,
#   間にある subhead / centre / title を構造ブロックとして取り込む. subhead 起点の
#   セクションが内部に centre 区切りや番号なし subhead を持つ形 (Vinaya
#   khandhaka の各 kathā など) や, 内部に title 見出しを持つ形 (MN 1 復註の
#   Nettinayavaṇṇanā など) に対応する. 結び行 ("...kathā niṭṭhitā." 等)
#   も構造ブロックとして含まれる. 未指定時の挙動は従来どおり
#   (最初の centre で終了. 連続する centre のうち niṭṭhitaṃ / niṭṭhitā を含む
#   段落までを結びとして本文に含める)
# - <chunkspec> は段落番号 (1 始まり) のグループ指定. 例 "1-3,4,5-9"
#   セクション一部だけを対訳する用途のため "6-11" のような途中範囲も
#   指定できる. ただし連続した昇順であること (歯抜けや逆順は誤指定として弾く)
# - <outdir> と <chunkspec> を省略すると, チャンク境界を決めるための
#   段落一覧 (連番, VRI 段落番号, 文字数, 冒頭) を表示して終了する.
#   一覧の末尾には抽出の終了位置 (どの行で抽出が止まったか) を表示する.
#   一覧の前にはセクション全体の行数, 字数, 出力トークンの見積もりを表示する.
#   字数が分割の目安 (SPLIT_THRESHOLD) を超える場合は段落一覧を省略し,
#   区切りごとの行範囲と字数だけを表示する. このとき段落一覧は
#   --rows A-B で行範囲を指定して表示する (例 --rows 1-62)
# - 出力: <outdir>/source.txt (正本, read-only) と <outdir>/chunk_NN.txt
#   source.txt は chunkspec の範囲によらず常にセクション全体を書く
#   (verify_taiyaku.rb は正本の部分文字列照合のため広い分には問題ない)
# - チャンク先頭 (chunk_01) には経題行を含める
# - 全チャンクを連結すると正本の該当範囲 (経題 + 指定段落) と一致することを
#   assert する. 全段落指定なら正本全体との一致になる

# ARGV はロケールによって binary になるため UTF-8 を強制する
argv = ARGV.map { |a| a.dup.force_encoding("UTF-8") }
# --rows A-B: 段落一覧に表示する行範囲 (段落一覧の表示時のみ有効)
rows_spec = nil
if (i = argv.index("--rows"))
  argv.delete_at(i)
  rows_spec = argv.delete_at(i)
  abort "--rows は A-B の形で指定する (例 --rows 1-62): #{rows_spec.inspect}" unless rows_spec =~ /\A[1-9]\d*-[1-9]\d*\z/
end
xml_path, subhead, outdir, chunkspec = argv
abort "usage: extract_chunks.rb <xml> <subhead> [<outdir> <chunkspec>]" unless subhead
abort "usage: extract_chunks.rb <xml> <subhead> [<outdir> <chunkspec>]" if outdir && !chunkspec
abort "--rows は段落一覧の表示 (<outdir> <chunkspec> の省略時) にだけ指定できる" if rows_spec && chunkspec

# 分割生成の目安. 原文がこの字数を超えるセクションは, 段落一覧を出さずに
# 規模の要約だけを表示する. 段落一覧とそれを基にしたチャンク表が大きくなり,
# 生成前の確認だけでセッションのトークンを使うため. 生成も数回に分ける
# ことを検討する. 値は MN 註の実績から決めた (2026/11/12). 1 回で生成した
# MN 77 註 (35,623 字) と MN 43 註 (37,982 字) は下回り, MN 3 註 (40,085 字)
# 以上が該当する
SPLIT_THRESHOLD = 40_000
# 出力トークンの見積もり係数 (原文 1 字あたり). 2026/11 に生成した MN 1 註
# (6.4), MN 1 復註 (6.9), MN 83 註 (6.4) の実績から決めた. それ以前の生成は
# 4.2-5.7 で, モデルや effort によって変わるため目安として扱う
TOKENS_PER_CHAR = 6.5
# 参照文脈の指定 (詳細は末尾の prompt_NN.txt 書き出し部を参照). 書き出し前に検査する
ctx = ENV["TAIYAKU_CTX"].to_s.strip
ctx = "none" if ctx.empty?
abort "TAIYAKU_CTX は none / all / 正の整数のいずれか: #{ctx.inspect}" unless ctx =~ /\A(none|all|[1-9]\d*)\z/

# VRI XML は UTF-16LE (BOM 付き)
raw = File.read(xml_path, mode: "rb", encoding: "UTF-16LE:UTF-8")
raw.sub!(/\A﻿/, "")

# 対象経の subhead から次の subhead/title/centre までの bodytext 段落を集める.
# title 起点の場合は次の title までを 1 セクションとし, 内部の subhead / centre
# も構造ブロックとして取り込む (Patis の kathā が title 直下に複数の subhead を
# 持つ形に対応). chapter 起点の場合は次の chapter までとし, 内部の title /
# subhead / centre を取り込む (Patis-a の kathā 註が chapter 直下に複数の
# title を持つ形に対応)
lines = raw.split(/\r?\n/)
start_rend = nil
start = lines.index do |l|
  if l =~ %r{<p rend="(subhead|title|chapter|subsubhead)">#{Regexp.escape(subhead)}</p>}
    start_rend = $1
    true
  end
end
# Jātaka-a の各話見出しは rend="bodytext" (先頭空白付き) のため,
# 見出し rend で見つからない場合は bodytext の完全一致 (strip 後) を探す
start ||= lines.index do |l|
  if l =~ %r{<p rend="bodytext">\s*#{Regexp.escape(subhead)}\s*</p>}
    start_rend = "bodytext"
    true
  end
end
abort "subhead not found: #{subhead}" unless start
# 起点見出しの階層より下位の見出し rend を構造ブロックとして取り込む.
# subsubhead 起点だけは同位の subsubhead を取り込む (註釈書冒頭の
# Ganthārambhakathā と Nidānakathā を 1 セクションにするため)
struct_rends = { "chapter" => %w[title subhead centre],
                 "title" => %w[subhead centre],
                 "subhead" => [],
                 "subsubhead" => %w[subsubhead],
                 "bodytext" => [] }.fetch(start_rend)

# 本文段落として取り込む rend. bodytext のほか, 註釈書に現れる
# unindented (続き段落), indent, 偈 (gatha1..gathalast) を含める.
# hangnum は偈の前に段落番号だけが独立段落になる形 (Vism 8 章 §223 など)
BODY_RENDS = %w[bodytext unindented indent gatha1 gatha2 gatha3 gathalast hangnum].freeze

# TAIYAKU_UNTIL: 終了見出しの明示指定 (詳細はヘッダコメント参照)
until_text = ENV["TAIYAKU_UNTIL"]
until_text = until_text.dup.force_encoding("UTF-8") if until_text && !until_text.empty?
until_text = nil if until_text && until_text.empty?

paras = []
# 構造ブロック (title 起点セクション内の subhead / centre) の paras 内での
# 位置. 段落番号の検出から除外するために使う
struct_flags = []
until_reached = false
# 抽出が止まった位置の行 (段落一覧の末尾に終了位置として表示する).
# nil のままならファイル末尾まで読んだことを表す
stop_line = nil
rest = lines[(start + 1)..]
rest.each_with_index do |line, idx|
  line = line.strip
  next if line.empty?
  rend = line[/\A<p rend="([^"]+)"/, 1]
  if until_text
    if line =~ %r{<p rend="(subhead|title|chapter)">#{Regexp.escape(until_text)}</p>}
      until_reached = true
      stop_line = line
      break
    end
    unless BODY_RENDS.include?(rend)
      # 終了見出しまでの間の subhead / centre は構造ブロックとして取り込む.
      # title も同様に取り込む (MN 1 復註の Nettinayavaṇṇanā のように subhead
      # 起点のセクション内に title 見出しが現れる形に対応)
      if %w[subhead centre title].include?(rend)
        paras << line
        struct_flags << true
        next
      end
      abort "TAIYAKU_UNTIL #{until_text.inspect} に到達する前に想定外の行: #{line[0, 80]}"
    end
    paras << line
    struct_flags << false
    next
  end
  unless BODY_RENDS.include?(rend)
    # title / chapter 起点では下位の見出し rend を構造ブロックとして含め,
    # 同位以上の見出し rend で終了する
    if struct_rends.include?(rend)
      paras << line
      struct_flags << true
      next
    end
    # 結びとして取り込んだ centre 段落の数 (終了位置はその次の行になる)
    closing = 0
    if struct_rends.empty?
      # 経の結び (MN などの "... niṭṭhitaṃ ..." centre 段落) は含める.
      # vagga の結び ("...vaggo paṭhamo." "...vaggo niṭṭhito ..." など) は
      # niṭṭhitaṃ / niṭṭhitā を含まないので除外される.
      # MN 註のように結びが複数の centre 段落 ("Papañcasūdaniyā
      # majjhimanikāyaṭṭhakathāya" + "...suttavaṇṇanā niṭṭhitā.") に分かれる
      # 場合があるため, 連続する centre を先読みし, 最初に niṭṭhitaṃ /
      # niṭṭhitā を含む段落までを結びとして含める. それ以降の vagga 結びや
      # uddāna は含めない (issue #16).
      # 復註 (ṭīkā) の結びは "...suttavaṇṇanāya līnatthappakāsanā samattā."
      # の形で niṭṭhitā を含まないため samattā も結びとして扱う
      # bodytext 起点 (Jātaka-a の各話) では直後の centre が各話の結び
      # ("...vaṇṇanā dasamā." など) のため niṭṭhitaṃ がなくても含める
      if rend == "centre"
        if start_rend == "bodytext"
          paras << line
          struct_flags << false
          closing = 1
        else
          run = rest[idx..].map(&:strip)
                           .take_while { |l| l.empty? || l.start_with?('<p rend="centre">') }
                           .reject(&:empty?)
          close = run.index { |l| l =~ /niṭṭhit(aṃ|ā)\b|samattā\b/ }
          run[..close].each { |l| paras << l; struct_flags << false } if close
          closing = close + 1 if close
        end
      end
    end
    stop_line = rest[idx..].map(&:strip).reject(&:empty?)[closing]
    break
  end
  paras << line
  struct_flags << false
end
abort "TAIYAKU_UNTIL の見出しが見つからない: #{until_text}" if until_text && !until_reached
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
  # pb と note は太字の内側に入れ子になることがある (MN 78 註 §261 の
  # "<hi rend="bold">Na <pb .../> karotī</hi>" など) ため, 太字より先に処理する
  s.gsub!(%r{<pb [^>]*/>}, "")
  s.gsub!(%r{<note>([^<]*)</note>}, '[\1]')
  s.gsub!(%r{<hi rend="paranum">([^<]*)</hi><hi rend="dot">\.</hi>}, '\1.')
  s.gsub!(%r{<hi rend="bold">([^<]*)</hi>}, '\1')
  s.gsub!(/ {2,}/, " ")
  s.strip!
  s.sub!(/\A(\d+)\.(?=\S)/, '\1. ')
  s
end

blocks = [subhead] + paras.map { |p| to_plain(p) }

# chunkspec 省略時は段落一覧を表示して終了する (チャンク境界の検討用).
# 構造ブロック (subhead / centre) は para 欄に "strt" と表示する
#
# 一覧の前にセクション全体の規模 (行数, 字数, 出力トークンの見積もり) を
# 表示する. 字数が SPLIT_THRESHOLD を超える場合は段落一覧を省略し, 代わりに
# 区切り (小見出しと VRI 段落番号) ごとの行範囲と字数を表示する. 分割生成の
# 各回の範囲はこの内訳から決め, その回の範囲だけを --rows で一覧表示する
def commas(n)
  n.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
end

def token_estimate(chars)
  t = chars * TOKENS_PER_CHAR
  t >= 10_000 ? "約 #{(t / 10_000.0).round} 万トークン" : "約 #{(t / 1000.0).round} 千トークン"
end

unless chunkspec
  rows = blocks[1..]
  total = rows.sum(&:size)
  puts subhead
  puts "合計: #{rows.size} 行 | #{commas(total)} 字 | 出力見積もり #{token_estimate(total)}"
  if rows_spec
    first, last = rows_spec.split("-").map(&:to_i)
    abort "--rows が段落範囲 1..#{rows.size} を超えているか逆順: #{rows_spec}" unless first <= last && last <= rows.size
  else
    first, last = 1, rows.size
  end
  if total > SPLIT_THRESHOLD && !rows_spec
    puts "分割の目安 (#{commas(SPLIT_THRESHOLD)} 字) を超えているため段落一覧は省略する. " \
         "生成を数回に分けることを検討する"
    puts "区切りごとの内訳 (行範囲 | 字数 | 累計 | 小見出し / VRI 段落番号):"
    # 区切りは小見出し (構造ブロックのうち結びの centre 以外) と VRI 段落番号の
    # 行で始める. 見出しが続く場合と見出し直後の番号段落は 1 つの区切りにまとめる
    para_rends = paras.map { |p| p[/\A<p rend="([^"]+)"/, 1] }
    groups = []
    rows.each_with_index do |b, i|
      heading = struct_flags[i] && para_rends[i] != "centre"
      num = struct_flags[i] ? nil : b[/\A(\d+)\./, 1]
      if heading
        if groups.last && groups.last[:open]
          groups.last[:label] += " / #{b[0, 40]}"
        else
          groups << { first: i + 1, label: b[0, 40], open: true }
        end
        next
      end
      if groups.empty?
        groups << { first: 1, label: num ? "para #{num}" : "(冒頭)" }
      elsif num && groups.last[:open]
        groups.last[:label] += " / para #{num}"
      elsif num
        groups << { first: i + 1, label: "para #{num}" }
      end
      groups.last[:open] = false
    end
    cum = 0
    groups.each_with_index do |g, gi|
      g_last = gi + 1 < groups.size ? groups[gi + 1][:first] - 1 : rows.size
      chars = rows[(g[:first] - 1)..(g_last - 1)].sum(&:size)
      cum += chars
      puts format("%4d-%-4d | %7s 字 | 累計 %8s | %s", g[:first], g_last, commas(chars), commas(cum), g[:label])
    end
    puts "段落一覧は行範囲を指定して表示する (例 --rows 1-#{groups.size > 1 ? groups[1][:first] - 1 : rows.size})"
  else
    rows.each_with_index do |b, i|
      next unless (first..last).cover?(i + 1)
      num = struct_flags[i] ? "strt" : b[/\A(\d+)\./, 1]
      puts format("%3d | para %-4s | %5d chars | %s", i + 1, num.to_s, b.size, b[0, 60])
    end
  end
  # 抽出の終了位置を表示する. subhead 起点のセクションは次の見出しで抽出が
  # 止まるため, セクション内部の小見出し (MN 54 註の "Kāmādīnavakathāvaṇṇanā"
  # など) で止まると一覧が途中までになる. 一覧だけでは気づけないので,
  # どの行で止まったかを示す
  stop_rend = stop_line && stop_line[/\A<p rend="([^"]+)"/, 1]
  if stop_rend
    stop_text = to_plain(stop_line)
    puts "終了位置: #{stop_rend} | #{stop_text[0, 60]}"
    if start_rend == "subhead" && stop_rend == "subhead" && !until_text &&
       subhead =~ /\A\d+\./ && stop_text !~ /\A\d+\./
      puts "注意: 番号のない subhead で終了している. セクション内部の小見出しであれば, " \
           "TAIYAKU_UNTIL に次のセクションの見出しを指定して全体を抽出する"
    end
  else
    puts "終了位置: 本文の終わり"
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

# 構造ブロック (subhead / centre) の一覧を書き出す. assemble_md.rb と
# verify_taiyaku.rb が段落番号の検出・欠番検査から除外するために使う
# (数字で始まる subhead "1. Gaṇanavāra" が VRI 段落番号と誤認されるのを防ぐ)
struct_blocks = blocks[1..].each_with_index.select { |_, i| struct_flags[i] }.map(&:first)
struct_path = File.join(outdir, "struct.txt")
if struct_blocks.empty?
  File.delete(struct_path) if File.exist?(struct_path)
else
  File.write(struct_path, struct_blocks.join("\n") + "\n")
end

# chunkspec を解釈してチャンクを書き出す
# 段落番号は経題を除いた bodytext 段落の 1 始まり.
# セクション一部だけを対訳する用途のため 1 から始まらない範囲も許可する
groups = chunkspec.split(",").map do |spec|
  a, b = spec.split("-").map(&:to_i)
  (a..(b || a)).to_a
end
covered = groups.flatten
abort "chunkspec が空か逆順: #{chunkspec.inspect}" if covered.empty?
abort "chunkspec が連続した昇順でない: #{covered.inspect}" unless covered == (covered.first..covered.last).to_a
abort "chunkspec が段落範囲 1..#{paras.size} を超えている: #{covered.inspect}" unless covered.first >= 1 && covered.last <= paras.size

chunk_paths = []
groups.each_with_index do |nums, i|
  # チャンク途中から始まる VRI 段落番号は組み立て時に自分のセクション
  # 見出しを持てず, 後続チャンクの見出しラベルも誤解を招くため警告する.
  # 構造ブロック (subhead / centre) の先頭数字は段落番号でないため対象外.
  # チャンク先頭の構造ブロック直後の番号段落は見出しの取得元になるため
  # 対象外 (先頭の構造ブロックをスキップした位置を実質の先頭とみなす)
  head = nums.index { |n| !struct_flags[n - 1] } || nums.size
  nums[(head + 1)..].to_a.each do |n|
    next if struct_flags[n - 1]
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

# 連結一致 assert: 全チャンク連結 == 正本の該当範囲 (経題 + 指定段落).
# 全段落指定なら正本全体との一致になる.
# ロケールが C でも比較が壊れないよう UTF-8 を明示して読み込む
expected = ([blocks[0]] + covered.map { |n| blocks[n] }).join("\n\n") + "\n"
joined = chunk_paths.map { |p| File.read(p, encoding: "UTF-8").chomp }.join("\n\n") + "\n"
if joined == expected
  label = covered.size == paras.size ? "source" : "source slice (para #{covered.first}-#{covered.last})"
  puts "OK: #{chunk_paths.size} chunks, concat == #{label} (#{expected.bytesize} bytes)"
  chunk_paths.each { |p| puts "  #{p} (#{File.read(p).bytesize} bytes)" }
else
  abort "ASSERT FAILED: concatenated chunks differ from source"
end

# 参照文脈付きプロンプトの書き出し (issue #23). 環境変数 TAIYAKU_CTX で指定する.
#   未指定 / none : 書き出さない. taiyaku.sh の stdin は chunk_NN.txt だけになり,
#                   参照範囲 = 訳出範囲の従来どおりの生成になる
#   all           : セクション全体を前後の文脈として付ける
#   <N>           : 前後 N 段落 (段落一覧の行単位) を文脈として付ける.
#                   切れた側には "(中略)" を置く
# チャンクごとに prompt_NN.txt を書き出す. 「前の文脈」「訳出対象」「後の文脈」の
# 順に並べ, 訳出対象は chunk_NN.txt と同一内容にする (連結一致 assert の対象は
# 引き続き chunk_NN.txt). 文脈は語義・指示語・…pe… 省略の判断材料で, 訳出も
# 再掲もさせない. 経題行は先頭チャンク以外では前の文脈の先頭に置き, vagga 名や
# 経名を全チャンクに見せる.
# 古い prompt_*.txt が残って意図せず使われないよう, none のときは削除する
Dir[File.join(outdir, "prompt_*.txt")].each { |p| File.delete(p) }
exit if ctx == "none"

PROMPT_HEADER = <<~TEXT
  以下は 1 つのセクションの原文を「前の文脈」「訳出対象」「後の文脈」の順に並べたものです。対訳を作るのは「訳出対象」の部分だけです。前後の文脈は、語義・指示語・省略 (…pe…) の内容を判断するために参照するもので、訳出・再掲の対象にしません。文脈を参照して判断したことを語釈に書く場合は、「前の文脈」「後の文脈」という言い方をせず、経名や段落番号で示します (例: 「第 1 経と同じ定型」「§181 と同じ構造」)。対訳の通し番号は訳出対象の先頭を 1 とします。訳出対象の先頭が経題行の場合は、経題を項目 1 として扱います。
TEXT

groups.each_with_index do |nums, i|
  before = blocks[1...nums.first]
  after = blocks[(nums.last + 1)..] || []
  unless ctx == "all"
    n = ctx.to_i
    before = ["(中略)"] + before.last(n) if before.size > n
    after = after.first(n) + ["(中略)"] if after.size > n
  end
  before.unshift(blocks[0]) unless i.zero?
  target = File.read(chunk_paths[i], encoding: "UTF-8").chomp
  prompt = +PROMPT_HEADER
  prompt << "\n===== 前の文脈 (訳出しない) =====\n\n"
  prompt << (before.empty? ? "(なし)" : before.join("\n\n")) << "\n\n"
  prompt << "===== 訳出対象 (この部分だけ対訳する) =====\n\n"
  prompt << target << "\n\n"
  prompt << "===== 後の文脈 (訳出しない) =====\n\n"
  prompt << (after.empty? ? "(なし)" : after.join("\n\n")) << "\n"
  path = File.join(outdir, format("prompt_%02d.txt", i + 1))
  File.write(path, prompt)
  puts "  #{path} (ctx=#{ctx}, #{prompt.bytesize} bytes)"
end
