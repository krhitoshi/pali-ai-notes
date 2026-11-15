# 対訳生成 (claude -p) のトークン消費量と費用を workdir ごとに集計するスクリプト
#
# 使い方:
#   ruby scripts/taiyaku_usage.rb [--detail] [--tsv] <workdir>...
#
# 例:
#   ruby scripts/taiyaku_usage.rb _tmp/work_mn085
#   ruby scripts/taiyaku_usage.rb --detail _tmp/work_mn085
#   ruby scripts/taiyaku_usage.rb --tsv _tmp/work_mn083 _tmp/work_mn_attha_083
#
# - taiyaku.sh は workdir を cwd にして claude -p を呼ぶため, CLI のセッション
#   記録が workdir ごとのディレクトリ (~/.claude/projects/<workdir の絶対パスの
#   英数字以外を - に置き換えた名前>/*.jsonl) に残る. claude -p の 1 回が
#   1 ファイルで, 応答ごとの usage (入力, キャッシュ書き込み, キャッシュ読み出し,
#   出力) が入っている. このスクリプトはそれを読んで合算する
# - 記録は CLI が管理するもので, 古いものは残っていないことがある
#   (2026/11/15 時点で 2026/08/03 より前の生成分はない). 記録のない workdir は
#   「記録なし」と表示する
# - 対象は生成 (claude -p) だけ. チャンク境界の検討や検証後の手直しをした
#   呼び出し元セッションの消費は含まない
#
# 表示する項目:
# - 入力は 4 区分 (キャッシュなしの入力, 5 分キャッシュ書き込み, 1 時間
#   キャッシュ書き込み, キャッシュ読み出し). 出力は thinking を含む.
#   thinking の内訳は新しい版の CLI の記録にだけあり, ない場合は - と表示する
# - 生成のうち, 応答の本文が workdir の out_NN.md と一致するものを「最終の
#   対訳に使われた」生成とする. 一致しないものは作り直す前の生成や失敗した
#   生成で, 「使われなかった」分として別に数える
# - 認証 (サブスクリプション / API キー) は記録に直接の項目がないため推定する.
#   taiyaku.sh は TAIYAKU_AUTH=api のとき CLAUDE_CODE_ENTRYPOINT を外して
#   claude -p を呼ぶので, 記録の entrypoint が sdk-cli になる. 1 時間キャッシュ
#   書き込みはサブスクリプションの生成にだけ現れる. この 2 点から
#   「entrypoint が sdk-cli で 1 時間キャッシュ書き込みがない」生成を API,
#   それ以外をサブスクリプションとみなす. ターミナルから taiyaku.sh を実行した
#   場合も entrypoint は sdk-cli になりうるため, 確実な判定ではない
# - 費用は米ドル. CLI が記録した額 (cost-state の totalCostUSD) があれば
#   それを使い, なければ下の料金表から計算する. どちらもトークン数に API の
#   定価を掛けた値で, API キーでの生成なら請求に近い額, サブスクリプションでの
#   生成なら定価に換算した参考値になる
#
# --detail は生成 1 回ごとの行を追加で表示する.
# --tsv は workdir ごとに 1 行のタブ区切りで出力する (見出し行つき)

require "json"
require "time"

# API の定価 (米ドル / 100 万トークン). 2026/11 時点.
# キャッシュ書き込みは入力の 1.25 倍 (5 分) と 2 倍 (1 時間).
# 新しいモデルで生成したときや料金が変わったときは更新する.
# 表にないモデルは CLI が記録した額だけを使い, それもなければ費用を - とする
PRICES = {
  "claude-fable-5-2" => { input: 8.0, write_5m: 10.0, write_1h: 16.0, read: 0.20, output: 40.0 },
  "claude-fable-5-1" => { input: 10.0, write_5m: 12.5, write_1h: 20.0, read: 0.25, output: 50.0 },
  "claude-fable-5" => { input: 10.0, write_5m: 12.5, write_1h: 20.0, read: 1.00, output: 50.0 },
  "claude-opus-5-5" => { input: 4.0, write_5m: 5.0, write_1h: 8.0, read: 0.20, output: 20.0 },
  "claude-sonnet-5-5" => { input: 2.0, write_5m: 2.5, write_1h: 4.0, read: 0.10, output: 10.0 }
}.freeze

TOKEN_KEYS = %i[input write_5m write_1h read output].freeze
AUTH_LABELS = { api: "API (推定)", subscription: "サブスクリプション (推定)" }.freeze

# 生成 1 回 (claude -p の 1 セッション) の記録
Gen = Struct.new(:time, :model, :entrypoint, :input, :write_5m, :write_1h, :read, :output,
                 :thinking, :cli_cost, :text, :chunk, keyword_init: true) do
  def auth
    entrypoint == "sdk-cli" && write_1h.zero? ? :api : :subscription
  end

  # 料金表から計算した費用. 表にないモデルは nil
  def list_cost
    price = PRICES[model.to_s.sub(/-\d{8}\z/, "")] or return nil
    TOKEN_KEYS.sum { |k| self[k] * price[k] } / 1_000_000.0
  end

  def cost
    cli_cost || list_cost
  end
end

# セッション記録 1 ファイルを読む. 応答のない記録は nil, cwd が workdir と
# 違う記録 (ディレクトリ名の変換が衝突した別の場所のもの) は :other を返す
def read_session(path, workdir_abs)
  msgs = {}
  cli_cost = nil
  File.foreach(path, encoding: "UTF-8") do |line|
    rec = begin
      JSON.parse(line)
    rescue JSON::ParserError
      next
    end
    case rec["type"]
    when "assistant"
      msg = rec["message"] or next
      # <synthetic> は API エラーなどを CLI が応答の形にしたもので, 消費がない
      next if msg["model"] == "<synthetic>" || !msg["usage"]
      return :other if rec["cwd"] && rec["cwd"] != workdir_abs
      # 同じ応答が内容ブロックごとに複数行に分かれる. usage は後の行を使う
      entry = (msgs[msg["id"]] ||= { texts: [] })
      entry.update(usage: msg["usage"], model: msg["model"], entrypoint: rec["entrypoint"], time: rec["timestamp"])
      Array(msg["content"]).each { |b| entry[:texts] << b["text"] if b["type"] == "text" }
    when "cost-state"
      cli_cost = rec["totalCostUSD"]
    end
  end
  return nil if msgs.empty?

  gen = Gen.new(input: 0, write_5m: 0, write_1h: 0, read: 0, output: 0, cli_cost: cli_cost, text: +"")
  msgs.each_value do |entry|
    usage = entry[:usage]
    gen.model = entry[:model]
    gen.entrypoint = entry[:entrypoint]
    gen.time = Time.parse(entry[:time]).localtime if entry[:time]
    gen.input += usage["input_tokens"].to_i
    gen.read += usage["cache_read_input_tokens"].to_i
    gen.output += usage["output_tokens"].to_i
    if (creation = usage["cache_creation"])
      gen.write_5m += creation["ephemeral_5m_input_tokens"].to_i
      gen.write_1h += creation["ephemeral_1h_input_tokens"].to_i
    else
      # 内訳のない記録は 5 分キャッシュとして扱う
      gen.write_5m += usage["cache_creation_input_tokens"].to_i
    end
    if (thinking = usage.dig("output_tokens_details", "thinking_tokens"))
      gen.thinking = gen.thinking.to_i + thinking
    end
    gen.text << entry[:texts].join
  end
  gen
end

# 複数の生成を合算した結果
class Tally
  attr_reader :count, :tokens, :thinking, :thinking_missing, :cost, :cost_missing, :cli_cost_count

  def initialize
    @count = 0
    @tokens = Hash.new(0)
    @thinking = 0
    @thinking_missing = 0
    @cost = 0.0
    @cost_missing = 0
    @cli_cost_count = 0
  end

  def add(gen)
    @count += 1
    TOKEN_KEYS.each { |k| @tokens[k] += gen[k] }
    gen.thinking ? @thinking += gen.thinking : @thinking_missing += 1
    if gen.cost
      @cost += gen.cost
      @cli_cost_count += 1 if gen.cli_cost
    else
      @cost_missing += 1
    end
    self
  end

  # thinking と費用は, 記録や単価のない生成が混ざっていれば nil にする
  def thinking_total
    @thinking_missing.zero? ? @thinking : nil
  end

  def cost_total
    @cost_missing.zero? ? @cost : nil
  end
end

def tally(gens)
  gens.each_with_object(Tally.new) { |g, t| t.add(g) }
end

# workdir 1 つ分の集計
Report = Struct.new(:workdir, :log_dir, :gens, :chunk_count, :source_chars, :out_count, :other_cwd, keyword_init: true) do
  def used
    gens.select(&:chunk)
  end

  def unused
    gens.reject(&:chunk)
  end
end

def projects_dir
  File.join(ENV["CLAUDE_CONFIG_DIR"] || File.join(Dir.home, ".claude"), "projects")
end

def build_report(workdir)
  abs = File.expand_path(workdir)
  log_dir = File.join(projects_dir, abs.gsub(/[^A-Za-z0-9]/, "-"))
  other_cwd = 0
  gens = Dir[File.join(log_dir, "*.jsonl")].filter_map do |path|
    gen = read_session(path, abs)
    other_cwd += 1 if gen == :other
    gen.is_a?(Gen) ? gen : nil
  end
  gens.sort_by! { |g| g.time || Time.at(0) }

  # 応答の本文が out_NN.md と一致する生成を, 最終の対訳に使われたものとする.
  # 同じ本文の生成が複数あれば新しいものを採る.
  # 作り直しの前の版を残した out_NN.prev.md などは対象にしない
  outs = Dir[File.join(abs, "out_*.md")].grep(/out_\d+\.md\z/).to_h do |path|
    [File.read(path, encoding: "UTF-8").strip, path[/out_(\d+)\.md\z/, 1]]
  end
  taken = {}
  gens.reverse_each do |gen|
    chunk = outs[gen.text.strip] or next
    next if taken[chunk]
    taken[chunk] = true
    gen.chunk = chunk
  end

  # 原文の字数は訳出対象のチャンクの合計 (source.txt はセクション一部だけを
  # 対訳する場合もセクション全体のため使わない)
  chunks = Dir[File.join(abs, "chunk_*.txt")].grep(/chunk_\d+\.txt\z/)
  source_chars = chunks.sum { |path| File.read(path, encoding: "UTF-8").strip.size }
  Report.new(workdir: workdir, log_dir: log_dir, gens: gens, chunk_count: chunks.size,
             source_chars: source_chars, out_count: outs.size, other_cwd: other_cwd)
end

def commas(n)
  n.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
end

def tokens_or_dash(n)
  n ? commas(n) : "-"
end

def usd(cost)
  cost ? format("%.2f", cost) : "-"
end

# 全角文字を 2 桁と数えた表示幅で桁をそろえる
def display_width(str)
  str.each_char.sum { |c| c.ord > 0x2E7F ? 2 : 1 }
end

def pad(str, width, left: false)
  space = " " * [width - display_width(str), 0].max
  left ? str + space : space + str
end

def print_table(rows)
  widths = rows.transpose.map { |col| col.map { |c| display_width(c) }.max }
  rows.each do |row|
    puts "  " + row.each_with_index.map { |c, i| pad(c, widths[i], left: i.zero?) }.join("  ")
  end
end

TABLE_HEADER = ["", "回数", "入力", "5 分書込", "1 時間書込", "読出", "出力", "うち thinking", "費用 (USD)"].freeze

def table_row(label, tal)
  [label, commas(tal.count), *TOKEN_KEYS.map { |k| commas(tal.tokens[k]) },
   tokens_or_dash(tal.thinking_total), usd(tal.cost_total)]
end

def auth_rows(gens)
  AUTH_LABELS.filter_map do |auth, label|
    part = gens.select { |g| g.auth == auth }
    table_row(label, tally(part)) unless part.empty?
  end
end

def date_range(gens)
  dates = gens.filter_map { |g| g.time&.strftime("%Y/%m/%d") }.uniq
  dates.size > 1 ? "#{dates.first} - #{dates.last}" : dates.first.to_s
end

def cost_note(gens)
  all = tally(gens)
  notes = []
  notes << "CLI の記録値 #{all.cli_cost_count} 回" if all.cli_cost_count.positive?
  listed = all.count - all.cli_cost_count - all.cost_missing
  notes << "料金表から計算 #{listed} 回" if listed.positive?
  notes << "単価なし #{all.cost_missing} 回" if all.cost_missing.positive?
  "費用の出どころ: #{notes.join(', ')}"
end

def print_report(report, detail:)
  puts report.workdir
  if report.gens.empty?
    puts "  記録なし (#{report.log_dir.sub(Dir.home, '~')})"
    return
  end
  gens = report.gens
  puts "  生成日    #{date_range(gens)}"
  puts "  モデル    #{gens.map(&:model).uniq.join(', ')}"
  puts "  チャンク  #{report.chunk_count} 個, 原文 #{commas(report.source_chars)} 字"
  if report.out_count.zero?
    puts "  生成      #{gens.size} 回 (out_NN.md がないため, 最終の対訳に使われたかは判定できない)"
  else
    puts "  生成      #{gens.size} 回 (最終の対訳に使われた #{report.used.size} 回, 使われなかった #{report.unused.size} 回)"
  end
  puts
  rows = [TABLE_HEADER.dup] + auth_rows(gens)
  rows << table_row("合計", tally(gens)) if rows.size > 2
  rows << table_row("うち使われなかった分", tally(report.unused)) if report.out_count.positive? && report.unused.any?
  print_table(rows)
  puts
  used = tally(report.out_count.zero? ? gens : report.used)
  if report.source_chars.positive? && used.count.positive?
    per_char = format("出力 %.2f トークン", used.tokens[:output].to_f / report.source_chars)
    per_char += format(", 費用 %.2f ドル / 1,000 字", used.cost_total / report.source_chars * 1000) if used.cost_total
    puts "  原文 1 字あたり#{report.out_count.zero? ? '' : ' (使われた分)'}: #{per_char}"
  end
  puts "  #{cost_note(gens)}"
  if report.out_count.positive? && report.used.size < report.out_count
    puts "  記録と一致しない out_NN.md が #{report.out_count - report.used.size} 個ある (記録が残っていないか, 生成後に書き換えられている)"
  end
  puts "  cwd が違うため除いた記録: #{report.other_cwd} 個" if report.other_cwd.positive?
  # CLI の記録値と料金表の計算がずれていれば, 料金表が古くなっている
  both = gens.select { |g| g.cli_cost && g.list_cost }
  cli_sum = both.sum(&:cli_cost)
  list_sum = both.sum(&:list_cost)
  if cli_sum.positive? && ((list_sum - cli_sum).abs / cli_sum) > 0.01
    puts format("  注意: CLI の記録値 %.2f と料金表の計算 %.2f が 1%% 以上ずれている. PRICES を確認する", cli_sum, list_sum)
  end
  print_detail(gens) if detail
end

def print_detail(gens)
  puts
  rows = [["日時", "チャンク", "モデル", "認証", "入力", "5 分書込", "1 時間書込", "読出", "出力", "うち thinking", "費用 (USD)"]]
  gens.each do |g|
    rows << [g.time ? g.time.strftime("%m/%d %H:%M") : "-", g.chunk || "-", g.model.to_s,
             g.auth == :api ? "API" : "サブスク", *TOKEN_KEYS.map { |k| commas(g[k]) },
             tokens_or_dash(g.thinking), usd(g.cost)]
  end
  print_table(rows)
end

def print_tsv(reports)
  puts %w[workdir first_date last_date models chunks source_chars generations used unused
          api_generations subscription_generations input write_5m write_1h read output thinking
          cost_usd api_cost_usd subscription_cost_usd unused_cost_usd].join("\t")
  reports.each do |r|
    all = tally(r.gens)
    api = tally(r.gens.select { |g| g.auth == :api })
    sub = tally(r.gens.select { |g| g.auth == :subscription })
    dates = r.gens.filter_map { |g| g.time&.strftime("%Y/%m/%d") }
    puts [r.workdir, dates.first, dates.last, r.gens.map(&:model).uniq.join(","), r.chunk_count,
          r.source_chars, r.gens.size, r.used.size, r.unused.size, api.count, sub.count,
          *TOKEN_KEYS.map { |k| all.tokens[k] }, all.thinking_total,
          *[all, api, sub, tally(r.unused)].map { |t| t.cost_total&.round(4) }].join("\t")
  end
end

args = ARGV.map { |a| a.dup.force_encoding("UTF-8") }
detail = !args.delete("--detail").nil?
tsv = !args.delete("--tsv").nil?
abort "usage: taiyaku_usage.rb [--detail] [--tsv] <workdir>..." if args.empty? || args.any? { |a| a.start_with?("--") }
missing = args.reject { |a| File.directory?(a) }
abort "workdir が見つからない: #{missing.join(', ')}" unless missing.empty?

reports = args.map { |workdir| build_report(workdir.chomp("/")) }
if tsv
  print_tsv(reports)
else
  reports.each_with_index do |report, i|
    puts if i.positive?
    print_report(report, detail: detail)
  end
  with_gens = reports.reject { |r| r.gens.empty? }
  if with_gens.size > 1
    gens = with_gens.flat_map(&:gens)
    puts
    puts "総計 (#{with_gens.size} 個の workdir)"
    rows = [TABLE_HEADER.dup] + auth_rows(gens)
    rows << table_row("合計", tally(gens)) if rows.size > 2
    print_table(rows)
  end
  puts
  puts "費用はトークン数に API の定価を掛けた値. API キーでの生成は請求に近い額, " \
       "サブスクリプションでの生成は定価に換算した参考値"
end
