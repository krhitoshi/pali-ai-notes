# 対訳生成の費用計算に使う API の定価
#
# scripts/taiyaku_usage.rb (実績の集計) と scripts/taiyaku_estimate.rb
# (事前の見積もり) が読み込む.
#
# 単位は米ドル / 100 万トークン. 2026/11 時点.
# キャッシュ書き込みは入力の 1.25 倍 (5 分) と 2 倍 (1 時間).
# 新しいモデルで生成するときや料金が変わったときは更新する
module TaiyakuPrices
  TABLE = {
    "claude-fable-5-2" => { input: 8.0, write_5m: 10.0, write_1h: 16.0, read: 0.20, output: 40.0 },
    "claude-fable-5-1" => { input: 10.0, write_5m: 12.5, write_1h: 20.0, read: 0.25, output: 50.0 },
    "claude-fable-5" => { input: 10.0, write_5m: 12.5, write_1h: 20.0, read: 1.00, output: 50.0 },
    "claude-opus-5-5" => { input: 4.0, write_5m: 5.0, write_1h: 8.0, read: 0.20, output: 20.0 },
    "claude-sonnet-5-5" => { input: 2.0, write_5m: 2.5, write_1h: 4.0, read: 0.10, output: 10.0 }
  }.freeze

  # モデル ID の単価. 末尾の日付サフィックスと [1m] は落として引く. 表にない
  # モデルは nil
  def self.for(model)
    TABLE[model.to_s.sub(/\[.*\z/, "").sub(/-\d{8}\z/, "")]
  end
end
