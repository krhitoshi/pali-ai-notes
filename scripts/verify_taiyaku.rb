# 対訳中のパーリ再掲行を正本と照合するスクリプト
#
# 使い方:
#   ruby scripts/verify_taiyaku.rb <source.txt> <md ファイル...>
#
# 対訳の番号付き行 (例 "3. Tena kho pana samayena ...") はパーリ原文の
# 再掲であり, LLM 生成のためドリフトしうる. 各行が正本の連続部分文字列で
# あることを確認し, 一致しない行を要確認として報告する.
#
# 判定は 3 段階:
#   OK       空白を 1 個に集約した上で正本の部分文字列
#   OK-LOOSE 正本の異読注 [ ... ] を除去し, 句読点前の空白を詰めても一致
#   NG       いずれにも一致しない (要確認)

source_path, *md_paths = ARGV
abort "usage: verify_taiyaku.rb <source.txt> <md...>" if md_paths.empty?

def collapse(s)
  s.gsub(/\s+/, " ").strip
end

source = collapse(File.read(source_path, encoding: "UTF-8"))
# 異読注を除去した緩和版. 注の除去で生じた空白や句読点前空白も詰める
source_loose = collapse(source.gsub(/\[[^\]]*\]/, "")).gsub(/ ([,.;?!])/, '\1')

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
    loose = pali.gsub(/\[[^\]]*\]/, "").gsub(/\s+/, " ").gsub(/ ([,.;?!])/, '\1').strip
    if source_loose.include?(loose)
      puts "OK-LOOSE #{md}:#{lineno}: #{pali[0, 60]}"
    else
      ng += 1
      puts "NG #{md}:#{lineno}: #{pali}"
    end
  end
end

puts "checked #{checked} lines, NG #{ng}"
exit(ng.zero? ? 0 : 1)
