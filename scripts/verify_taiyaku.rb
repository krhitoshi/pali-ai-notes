# 対訳中のパーリ再掲行を正本と照合するスクリプト
#
# 使い方:
#   ruby scripts/verify_taiyaku.rb <source.txt> <md ファイル...>
#
# 対訳の番号付き行 (例 "3. Tena kho pana samayena ...") はパーリ原文の
# 再掲であり, LLM 生成のためドリフトしうる. 各行が正本の連続部分文字列で
# あることを確認し, 一致しない行を要確認として報告する.
#
# 判定は 4 段階:
#   OK         空白を 1 個に集約した上で正本の部分文字列
#   OK-LOOSE   正本の異読注 [ ... ] と出典略号 ( ... 数字 ... ) を除去し,
#              句読点前の空白を詰めても一致. 出典略号は註釈書の
#              "(dī. ni. 1.190)" のような括弧で, 数字を含む括弧のみ対象
#              (再掲時に異読注・出典を省くのは許容されるドリフト)
#   OK-NOSPACE さらに引用符 (‘ ’ と編集表記の " ') と空白をすべて
#              除いても一致. 文字と語順は保たれており, 引用符の省略・変形・
#              …pe… 前後の空白付加・連声の分かち書きなど再掲時の編集的な
#              揺れだけがある状態. ASCII の " (語句引用) と ' (連声分解の
#              pan' ettha など) は対訳の編集表記として許容する.
#              全角の “ ” は編集表記ではなく生成出力の写し崩れのため
#              許容せず NG で検出する
#   NG         いずれにも一致しない (要確認)
#
# あわせて見出しの検査を行う (NG-HEADING):
#   - 見出しは「# 経題」「## <段落番号>」「## <段落番号> (連番)」
#     「### Meta」「### 対訳」のみ (生成が作った余計な見出しの検出)
#   - 正本に現れる VRI 段落番号がすべて ## 見出しに存在する (欠番の検出.
#     チャンク途中から始まった番号は見出しを持てないため, ここで露見する)
#   - 同一番号の連番 (N) は 1 から始まり連続する

source_path, *md_paths = ARGV
abort "usage: verify_taiyaku.rb <source.txt> <md...>" if md_paths.empty?

def collapse(s)
  s.gsub(/\s+/, " ").strip
end

# 異読注 [ ... ] と出典略号 ( ...数字... ) を除去する緩和変換.
# 除去で生じた空白や句読点前空白も詰める
def loosen(s)
  s.gsub(/\[[^\]]*\]/, "")
   .gsub(/\([^()]*\d[^()]*\)/, "")
   .gsub(/\s+/, " ")
   .gsub(/ ([,.;?!])/, '\1')
   .strip
end

source = collapse(File.read(source_path, encoding: "UTF-8"))
source_loose = loosen(source)
# 引用符と空白をすべて除いた版. 文字化けや脱字は残らず検出できる
source_nospace = source_loose.gsub(/[‘’"']/, "").gsub(/\s/, "")

ng = 0
checked = 0
md_paths.each do |md|
  File.read(md, encoding: "UTF-8").each_line.with_index(1) do |line, lineno|
    # 番号付き行 = パーリ再掲行. 見出しや訳文行 (→, *) は対象外
    next unless line =~ /\A(\d+)\.\s+(.+)\z/m
    pali = collapse($2)
    next if pali.empty?
    checked += 1
    next if source.include?(pali)
    loose = loosen(pali)
    if source_loose.include?(loose)
      puts "OK-LOOSE #{md}:#{lineno}: #{pali[0, 60]}"
    elsif source_nospace.include?(loose.gsub(/[‘’"']/, "").gsub(/\s/, ""))
      puts "OK-NOSPACE #{md}:#{lineno}: #{pali[0, 60]}"
    else
      ng += 1
      puts "NG #{md}:#{lineno}: #{pali}"
    end
  end
end

# 見出しの検査. 正本の段落先頭に現れる VRI 段落番号を期待値とし,
# md の ## 見出しと突き合わせる. 先頭ブロックは経題 ("10. Apaṇṇakasuttaṃ"
# など番号で始まる) のため段落番号の対象から除く
source_raw = File.read(source_path, encoding: "UTF-8")
expected_nums = source_raw.split(/\r?\n\r?\n/)[1..].map { |b| b[/\A(\d+)\./, 1] }.compact
md_paths.each do |md|
  seq = Hash.new(0)
  found_nums = []
  File.read(md, encoding: "UTF-8").each_line.with_index(1) do |line, lineno|
    next unless line =~ /\A\#+ /
    heading = line.chomp
    case heading
    when /\A# ./, /\A### (Meta|対訳)\z/
      # 経題と定型見出しは許可
    when /\A## (\d+)(?: \((\d+)\))?\z/
      n, k = $1, $2
      found_nums << n
      seq[n] += 1
      unless (k ? k.to_i : 1) == seq[n]
        ng += 1
        puts "NG-HEADING #{md}:#{lineno}: 連番が不連続: #{heading}"
      end
    else
      ng += 1
      puts "NG-HEADING #{md}:#{lineno}: 想定外の見出し: #{heading}"
    end
  end
  missing = expected_nums - found_nums
  unless missing.empty?
    ng += 1
    puts "NG-HEADING #{md}: ## 見出しにない段落番号: #{missing.join(', ')}"
  end
end

puts "checked #{checked} lines, NG #{ng}"
exit(ng.zero? ? 0 : 1)
