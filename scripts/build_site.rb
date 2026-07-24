# frozen_string_literal: true

# 対訳 md を静的 HTML としてビルドするスクリプト
# 使い方: bundle exec ruby scripts/build_site.rb
#
# - 対象は本体 + 註 (attha) + 復註 (tika) のみ. 派生ファイル (_check, _v1 など) は
#   ファイル名のホワイトリスト正規表現で除外する
# - ソース md は変更せず, 変換時にメモリ上で前処理する
#   - Meta ブロックの除去
#   - 二重番号行 (例 "3. 107. Evaṃ...") の内側番号のピリオドをエスケープして
#     CommonMark の入れ子リスト解釈を防ぐ (issue #1)
# - 出力は public/ にソースと同じ階層でミラーし, リンクはすべて相対パス
# - public/ 配下は全消し再生成するが .gitkeep は残す

require "commonmarker"
require "cgi"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
OUT_DIR = File.join(ROOT, "public")

# セクション定義. トップページと一覧の表示順もこの順
SECTIONS = [
  { dir: "mn", name: "中部 (Majjhimanikāya)" },
  { dir: "sn", name: "相応部 (Saṃyuttanikāya)" },
  { dir: "dhammapada", name: "ダンマパダ (Dhammapada)" },
  { dir: "patisambhidamagga", name: "無礙解道 (Paṭisambhidāmagga)" },
  { dir: "visuddhimagga", name: "清浄道論 (Visuddhimagga)" },
].freeze

# 本体 + 註 + 復註だけを通すホワイトリスト
# 数字以外の接尾辞 (_check, _opus, _v1 など) はここで弾かれる
TARGET_RE = /\A(mn|sn|vism|patis|dhp)(_attha|_tika)?(_[\d-]+)+\z/

KIND_LABELS = { main: "本文", attha: "註", tika: "復註" }.freeze

# 生成メタデータの見出しテキスト
# "Meta" のほか, 旧形式 (dhammapada) ではモデル名が直接見出しになっている
META_TITLE_RE = /\A(Meta|GPT( .+)?|gpt-\S+|Gemini( .+)?|Claude( .+)?)\z/

CSS = <<~CSS
  html { background: #fdfcf7; }
  body {
    max-width: 46rem;
    margin: 0 auto;
    padding: 0 1rem 4rem;
    font-family: "Hiragino Kaku Gothic ProN", "Yu Gothic", sans-serif;
    line-height: 1.8;
    color: #222;
    background: #fdfcf7;
  }
  h1, h2, h3 {
    font-family: "Hiragino Kaku Gothic ProN", "Yu Gothic", sans-serif;
    line-height: 1.4;
  }
  h1 { font-size: 1.4rem; border-bottom: 2px solid #8a7b5c; padding-bottom: 0.3rem; }
  h2 { font-size: 1.15rem; border-bottom: 1px solid #ccc; padding-bottom: 0.2rem; }
  h3 { font-size: 1rem; }
  a { color: #1a5276; }
  nav.site-nav {
    font-family: "Hiragino Kaku Gothic ProN", "Yu Gothic", sans-serif;
    font-size: 0.9rem;
    background: #f4f1ea;
    padding: 0.5rem 0.8rem;
    margin: 1rem 0;
    border-radius: 4px;
  }
  nav.site-nav span.sep { color: #999; margin: 0 0.4rem; }
  ol, ul { padding-left: 1.6rem; }
  li { margin: 0.2rem 0; }
  table { border-collapse: collapse; width: 100%; font-size: 0.95rem; }
  th, td { border: 1px solid #ccc; padding: 0.3rem 0.6rem; text-align: left; }
  th {
    font-family: "Hiragino Kaku Gothic ProN", "Yu Gothic", sans-serif;
    background: #f4f1ea;
  }
  ul.page-list { list-style: none; padding-left: 0; }
CSS

Page = Struct.new(:dir, :stem, :kind, :number_key, :titles, :md_path, keyword_init: true) do
  def html_name
    "#{stem}.html"
  end

  # 番号表示用にコーパス接頭辞を除いた部分を返す
  def display_number
    number_key.sub(/\A(mn|sn|vism|patis|dhp)_/, "")
  end
end

# ファイル名から数字部分を数値として比較する自然順ソートキー
def sort_key(stem)
  stem.split(/(\d+)/).map { |part| part.match?(/\A\d+\z/) ? [1, part.to_i] : [0, part] }
end

def collect_pages(section)
  dir_path = File.join(ROOT, section[:dir])
  Dir.glob(File.join(dir_path, "*.md")).filter_map do |path|
    stem = File.basename(path, ".md")
    next unless stem.match?(TARGET_RE)

    kind =
      case stem
      when /_attha_/ then :attha
      when /_tika_/ then :tika
      else :main
      end
    Page.new(
      dir: section[:dir],
      stem: stem,
      kind: kind,
      number_key: stem.sub(/_(attha|tika)_/, "_"),
      titles: extract_titles(path),
      md_path: path
    )
  end.sort_by { |page| [sort_key(page.number_key), KIND_LABELS.keys.index(page.kind)] }
end

# H1 見出しをタイトルとして抽出する
# mn では段落番号も H1 のため, 数字だけの見出しは除外する
def extract_titles(path)
  titles = File.readlines(path, encoding: "UTF-8").filter_map do |line|
    text = line[/\A# (.+?)\s*\z/, 1]
    next unless text
    next if text.match?(/\A\d+( \(\d+\))?\z/)
    next if text.match?(META_TITLE_RE)

    text
  end
  titles.uniq.join(" / ")
end

# md テキストの前処理. ソースファイルは変更しない
def preprocess(md)
  lines = md.lines
  result = []
  in_meta = false
  lines.each do |line|
    heading_text = line[/\A#+ (.+?)\s*\z/, 1]
    if heading_text&.match?(META_TITLE_RE)
      in_meta = true
      next
    end
    if in_meta
      next unless line.start_with?("#")

      in_meta = false
    end
    # 二重番号行の内側番号のピリオドをエスケープする
    result << line.sub(/\A(\d+\. \d+)\./) { "#{$1}\\." }
  end
  result.join
end

def to_html(md)
  Commonmarker.to_html(md, options: { extension: { autolink: true } })
end

def render_layout(title:, css_href:, nav:, body:)
  <<~HTML
    <!DOCTYPE html>
    <html lang="ja">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>#{CGI.escapeHTML(title)}</title>
    <link rel="stylesheet" href="#{css_href}">
    </head>
    <body>
    #{nav}
    <main>
    #{body}
    </main>
    #{nav}
    </body>
    </html>
  HTML
end

def nav_html(items)
  links = items.map do |label, href|
    if href
      %(<a href="#{href}">#{CGI.escapeHTML(label)}</a>)
    else
      CGI.escapeHTML(label)
    end
  end
  %(<nav class="site-nav">#{links.join('<span class="sep">|</span>')}</nav>)
end

def write_page(page, section, pages)
  # 前後は同じ種別の中で番号順に張る
  same_kind = pages.select { |p| p.kind == page.kind }
  index = same_kind.index(page)
  prev_page = index > 0 ? same_kind[index - 1] : nil
  next_page = same_kind[index + 1]

  items = []
  items << ["トップ", "../index.html"]
  items << ["#{section[:name]} 一覧", "index.html"]
  items << ["← #{prev_page.stem}", prev_page.html_name] if prev_page
  items << ["#{next_page.stem} →", next_page.html_name] if next_page
  # 同じ番号の本文 / 註 / 復註への相互リンク
  pages.each do |other|
    next if other == page || other.number_key != page.number_key

    items << [KIND_LABELS[other.kind], other.html_name]
  end

  md = preprocess(File.read(page.md_path, encoding: "UTF-8"))
  title = page.titles.empty? ? page.stem : page.titles
  html = render_layout(
    title: "#{title} - #{section[:name]}",
    css_href: "../style.css",
    nav: nav_html(items),
    body: to_html(md)
  )
  File.write(File.join(OUT_DIR, page.dir, page.html_name), html)
end

def index_body(section, pages)
  grouped = pages.group_by(&:number_key)
  # 註や復註を持つセクションは表, 本文だけのセクションは単純なリスト
  if pages.any? { |p| p.kind != :main }
    rows = grouped.map do |_key, group|
      title_page = group.min_by { |p| KIND_LABELS.keys.index(p.kind) }
      links = KIND_LABELS.keys.map do |kind|
        page = group.find { |p| p.kind == kind }
        page ? %(<a href="#{page.html_name}">#{KIND_LABELS[kind]}</a>) : ""
      end
      <<~ROW
        <tr>
        <td>#{CGI.escapeHTML(title_page.display_number)}</td>
        <td>#{CGI.escapeHTML(title_page.titles)}</td>
        <td>#{links[0]}</td><td>#{links[1]}</td><td>#{links[2]}</td>
        </tr>
      ROW
    end
    <<~HTML
      <h1>#{CGI.escapeHTML(section[:name])}</h1>
      <table>
      <tr><th>番号</th><th>タイトル</th><th>本文</th><th>註</th><th>復註</th></tr>
      #{rows.join}
      </table>
    HTML
  else
    items = pages.map do |page|
      %(<li><a href="#{page.html_name}">#{CGI.escapeHTML(page.display_number)}</a> #{CGI.escapeHTML(page.titles)}</li>)
    end
    <<~HTML
      <h1>#{CGI.escapeHTML(section[:name])}</h1>
      <ul class="page-list">
      #{items.join("\n")}
      </ul>
    HTML
  end
end

def write_index(section, pages)
  items = [["トップ", "../index.html"], ["#{section[:name]} 一覧", nil]]
  html = render_layout(
    title: "#{section[:name]} 一覧",
    css_href: "../style.css",
    nav: nav_html(items),
    body: index_body(section, pages)
  )
  File.write(File.join(OUT_DIR, section[:dir], "index.html"), html)
end

def write_top(section_pages)
  readme_html = to_html(File.read(File.join(ROOT, "README.md"), encoding: "UTF-8"))
  list_items = section_pages.map do |section, pages|
    %(<li><a href="#{section[:dir]}/index.html">#{CGI.escapeHTML(section[:name])}</a> (#{pages.size} 件)</li>)
  end
  body = <<~HTML
    #{readme_html}
    <h2>対訳一覧</h2>
    <ul class="page-list">
    #{list_items.join("\n")}
    </ul>
  HTML
  html = render_layout(
    title: "パーリ仏典 多読用 AI ノート",
    css_href: "style.css",
    nav: nav_html([["トップ", nil]]),
    body: body
  )
  File.write(File.join(OUT_DIR, "index.html"), html)
end

# public/ 配下を全消し再生成する. Dir.glob は既定でドットファイルを含まないため
# .gitkeep は残る
FileUtils.rm_rf(Dir.glob(File.join(OUT_DIR, "*")))
FileUtils.mkdir_p(OUT_DIR)

total_md = 0
total_html = 0
section_pages = SECTIONS.map do |section|
  pages = collect_pages(section)
  FileUtils.mkdir_p(File.join(OUT_DIR, section[:dir]))
  pages.each { |page| write_page(page, section, pages) }
  write_index(section, pages)
  generated = Dir.glob(File.join(OUT_DIR, section[:dir], "*.html")).size - 1
  puts "#{section[:dir]}: #{pages.size} md -> #{generated} html"
  total_md += pages.size
  total_html += generated
  [section, pages]
end

write_top(section_pages)
File.write(File.join(OUT_DIR, "style.css"), CSS)

raise "md と html の件数が一致しません (md=#{total_md} html=#{total_html})" if total_md != total_html

puts "計 #{total_md} ページ + 一覧 #{SECTIONS.size} + トップ 1"
