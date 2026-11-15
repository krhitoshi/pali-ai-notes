# 対訳生成 (claude -p) のトークン消費量と費用を, 生成の前に見積もるスクリプト
#
# 使い方 (数値を直接渡す場合):
#   ruby scripts/taiyaku_estimate.rb --xml <xml> --model <model> --chars <字数> \
#     [--chunks <チャンク数>] [--auth subscription|api] [--kind mul|att|tik] \
#     [--effort <effort>]
#
# 例:
#   ruby scripts/taiyaku_estimate.rb --xml s0201a.att1.xml --model claude-fable-5-2 \
#     --chars 39800
#
# チャンク案に対する見積もりは scripts/extract_chunks.rb の --estimate で出す
# (チャンク数と参照文脈の分の入力を XML から数える). このファイルは見積もりの
# 計算と表示を持ち, extract_chunks.rb からも読み込まれる. 数値を直接渡す形は,
# 分割生成の回ごとの見積もりのように字数だけがわかっている場合に使う
#
# 見積もりの式:
#   出力 = 原文字数 × 係数 (テキスト種別 × モデル. thinking を含む)
#   入力 = チャンク数 × 固定分 + 入力の字数 × 0.68
#   費用 = 各トークン × API の定価 (scripts/taiyaku_prices.rb)
#
# - テキスト種別は XML のファイル名 (.mul / .att / .tik) で決める. 経蔵・律蔵
#   以外 (Visuddhimagga など) はファイル名の区分と内容が合わないことがあり,
#   実績もないため, --kind で近い種別を指定する
# - 係数と固定分は scripts/taiyaku_usage.rb で集計した実績から決めた値.
#   実績が増えたときや, system prompt と CLAUDE.md を大きく変えたときは
#   測り直して更新する
# - 実績のないモデル, 種別, effort は, 実績のあるものの係数で代用する.
#   モデルが変わると出力の量も変わるため, 代用したことと見積もりが実際と
#   離れうることを「注意」の行に出し, 幅を広く取る. 実績が 5 件に満たない
#   組み合わせも, 幅が仮の値であることを「注意」に出す
# - 見積もれるのは作業全体や分割生成の 1 回分の合計. チャンク 1 個ごとの
#   出力は同じ種別でも 1.4 - 2.2 倍ばらつくため当たらない
# - 作り直しの分は含まない (実績では生成 991 回のうち 29 回)
# - サブスクリプションの利用上限に対する割合は出せない. 費用は API の定価に
#   換算した参考値になる

require_relative "taiyaku_prices"

module TaiyakuEstimate
  KIND_LABELS = { mul: "経・律 (mūla)", att: "註", tik: "復註" }.freeze
  AUTH_LABELS = { subscription: "サブスクリプション", api: "API キー" }.freeze

  # 出力トークンの係数 (原文 1 字あたり. thinking を含む. effort high).
  # 2026/11/15 までの実績のうち, 最終の対訳に使われた生成を workdir ごとに
  # 合算して求めた. coef は workdir ごとの値の中央値, n は workdir の数.
  # low / high は実績の最小と最大で, n が 5 以上のときだけ書く
  OUTPUT_PER_CHAR = {
    "claude-fable-5-2" => {
      mul: { coef: 5.3, n: 3 },
      att: { coef: 6.4, n: 1 },
      tik: { coef: 6.9, n: 1 }
    },
    "claude-fable-5-1" => {
      mul: { coef: 3.6, low: 2.8, high: 4.8, n: 19 },
      att: { coef: 5.3, low: 3.9, high: 5.8, n: 10 },
      tik: { coef: 7.0, low: 6.5, high: 9.3, n: 7 }
    },
    "claude-fable-5" => {
      mul: { coef: 4.7, low: 3.7, high: 5.7, n: 18 },
      att: { coef: 7.0, n: 1 }
    }
  }.freeze
  # 実績が 5 件に満たない組み合わせの幅. 実績の多い組み合わせで, 最小と最大が
  # 中央値の 0.74 - 0.93 倍と 1.10 - 1.32 倍だったことから決めた
  SPREAD = [0.75, 1.35].freeze
  # 係数のないモデルは, このモデルの係数で代用する
  FALLBACK_MODEL = "claude-fable-5-2"
  # 別のモデル, 種別, effort の係数で代用したときの幅. モデルが変わると出力の
  # 量も変わり (経の係数は Fable 5.1 の 3.6 に対して Fable 5.2 が 5.3 で
  # 約 1.5 倍), SPREAD では足りないため広げる
  FALLBACK_SPREAD = [0.6, 1.6].freeze

  # 入力トークン. 1 回の生成の入力は「固定分 + 入力の字数 × 係数」にほぼ乗る
  # (MN 85 の 29 回で誤差 1% 未満. 2026/11/15). 固定分は system prompt と
  # プロジェクトの CLAUDE.md などで, MCP のツール定義を読み込まなくなった
  # あとの値. 入力の字数は claude -p の stdin (chunk_NN.txt か, 参照文脈付きの
  # prompt_NN.txt) の字数
  INPUT_FIXED = { subscription: 8_300, api: 7_800 }.freeze
  INPUT_PER_CHAR = 0.68
  # 入力のうちキャッシュ書き込みになる割合. 残りはキャッシュ読み出し.
  # 並列で起動するタイミングで変わるため実績の値を使う. 書き込みの単価は
  # サブスクリプションが 1 時間, API キーが 5 分のキャッシュ
  WRITE_SHARE = { subscription: 0.87, api: 0.67 }.freeze
  WRITE_KEY = { subscription: :write_1h, api: :write_5m }.freeze
  # チャンク数が決まっていないときの概算に使う, 1 チャンクの平均字数
  AVG_CHUNK_CHARS = 1_400

  # XML のファイル名からテキスト種別を決める. 判定できなければ nil
  def self.kind_of(xml_path)
    File.basename(xml_path.to_s)[/\.(mul|att|tik)\d*\.xml\z/, 1]&.to_sym
  end

  def self.approx_chunks(chars)
    [(chars.to_f / AVG_CHUNK_CHARS).ceil, 1].max
  end

  # 見積もりを計算する.
  #   chars       : 訳出対象の原文の字数
  #   chunks      : チャンク数. nil なら字数から概算する
  #   input_chars : claude -p の stdin の字数の合計. nil なら chars と同じ
  #                 (参照文脈なし) とみなす
  def self.estimate(kind:, model:, auth:, chars:, chunks: nil, input_chars: nil, effort: "high")
    model = model.to_s.sub(/\[.*\z/, "")
    notes = []
    coef_model = OUTPUT_PER_CHAR.key?(model) ? model : FALLBACK_MODEL
    unless coef_model == model
      notes << "#{model} の実績がないため #{coef_model} の係数で代用した. " \
               "モデルによって出力の量が変わるため, 見積もりは実際と離れることがある"
    end
    table = OUTPUT_PER_CHAR[coef_model]
    coef_kind = table.key?(kind) ? kind : table.keys.last
    unless coef_kind == kind
      notes << "#{KIND_LABELS[kind] || '種別不明'} の実績がないため #{KIND_LABELS[coef_kind]} の係数で代用した. " \
               "種別によって出力の量が変わるため, 見積もりは実際と離れることがある"
    end
    cell = table[coef_kind]
    unless effort.to_s == "high"
      notes << "effort #{effort} の実績がないため high の係数で代用した. " \
               "effort によって出力の量が変わるため, 見積もりは実際と離れることがある"
    end
    # 幅は, 代用したときは広く取り, 実績が 5 件以上あればその最小と最大,
    # それ以外は SPREAD を使う
    if notes.any?
      low, high = FALLBACK_SPREAD.map { |rate| cell[:coef] * rate }
      notes << "代用のため幅を広く取っている"
    elsif cell[:low]
      low, high = cell[:low], cell[:high]
    else
      low, high = SPREAD.map { |rate| cell[:coef] * rate }
      notes << "実績が #{cell[:n]} 件と少ないため, 幅は実績の多い組み合わせのばらつきから仮に置いている"
    end

    chunks_exact = !chunks.nil?
    chunks ||= approx_chunks(chars)
    input = chunks * INPUT_FIXED.fetch(auth) + (input_chars || chars) * INPUT_PER_CHAR
    result = { kind: kind, model: model, effort: effort.to_s, auth: auth, chars: chars, chunks: chunks,
               chunks_exact: chunks_exact, coef: cell[:coef], coef_n: cell[:n], coef_model: coef_model,
               coef_kind: coef_kind, output: chars * cell[:coef], output_low: chars * low,
               output_high: chars * high, input: input, notes: notes }
    if (price = TaiyakuPrices.for(model))
      share = WRITE_SHARE.fetch(auth)
      input_cost = input * (share * price[WRITE_KEY.fetch(auth)] + (1 - share) * price[:read]) / 1e6
      %i[output output_low output_high].each do |key|
        result[key.to_s.sub("output", "cost").to_sym] = input_cost + result[key] * price[:output] / 1e6
      end
    else
      notes << "#{model} の単価が scripts/taiyaku_prices.rb にないため費用は出せない"
    end
    result
  end

  def self.commas(n)
    n.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
  end

  def self.tokens(n)
    if n >= 995_000 then "#{(n / 10_000.0).round} 万"
    elsif n >= 10_000 then "#{format('%.1f', n / 10_000.0)} 万"
    else commas(n)
    end
  end

  def self.dollars(n)
    n >= 10 ? n.round.to_s : format("%.1f", n)
  end

  # 見積もりを表示用の行にする. ユーザへの確認ではこの行をそのまま示す
  def self.lines(est)
    out = []
    out << "見積もり: #{est[:model]} #{est[:effort]} | #{KIND_LABELS[est[:kind]] || '種別不明'} | #{AUTH_LABELS[est[:auth]]}"
    out << "  チャンク #{est[:chunks_exact] ? '' : '約 '}#{commas(est[:chunks])} 個 | 原文 #{commas(est[:chars])} 字"
    out << "  出力 約 #{tokens(est[:output])} トークン (幅 #{tokens(est[:output_low])} - #{tokens(est[:output_high])})"
    out << "  入力 約 #{tokens(est[:input])} トークン"
    if est[:cost]
      meaning = est[:auth] == :api ? "API キーでの生成の請求の目安" : "API の定価に換算した参考値 (サブスクリプションでは課金されない)"
      out << "  費用 約 #{dollars(est[:cost])} ドル (幅 #{dollars(est[:cost_low])} - #{dollars(est[:cost_high])} ドル). #{meaning}"
    end
    out << "  根拠: 出力は原文 1 字あたり #{est[:coef]} トークン " \
           "(#{KIND_LABELS[est[:coef_kind]]} × #{est[:coef_model]} の実績 #{est[:coef_n]} 件). 作り直しの分は含まない"
    est[:notes].each { |note| out << "  注意: #{note}" }
    out
  end

  # --auth の値を検査してシンボルにする
  def self.parse_auth(value)
    auth = (value || "subscription").to_sym
    abort "--auth は subscription か api を指定する: #{value.inspect}" unless AUTH_LABELS.key?(auth)
    auth
  end

  # --kind の値か XML のファイル名から種別を決める
  def self.parse_kind(value, xml_path)
    return kind_of(xml_path) unless value

    kind = value.to_sym
    abort "--kind は mul / att / tik のいずれかを指定する: #{value.inspect}" unless KIND_LABELS.key?(kind)
    kind
  end
end

if $PROGRAM_NAME == __FILE__
  args = ARGV.map { |a| a.dup.force_encoding("UTF-8") }
  opts = {}
  %w[--xml --model --chars --chunks --auth --kind --effort].each do |name|
    i = args.index(name) or next
    args.delete_at(i)
    opts[name] = args.delete_at(i)
  end
  usage = "usage: taiyaku_estimate.rb --xml <xml> --model <model> --chars <字数> " \
          "[--chunks <チャンク数>] [--auth subscription|api] [--kind mul|att|tik] [--effort <effort>]"
  abort usage unless args.empty? && opts["--model"] && opts["--chars"] =~ /\A[1-9]\d*\z/ &&
                     (opts["--xml"] || opts["--kind"]) && (opts["--chunks"].nil? || opts["--chunks"] =~ /\A[1-9]\d*\z/)
  est = TaiyakuEstimate.estimate(kind: TaiyakuEstimate.parse_kind(opts["--kind"], opts["--xml"]),
                                 model: opts["--model"], auth: TaiyakuEstimate.parse_auth(opts["--auth"]),
                                 chars: opts["--chars"].to_i, chunks: opts["--chunks"]&.to_i,
                                 effort: opts["--effort"] || "high")
  puts TaiyakuEstimate.lines(est)
end
