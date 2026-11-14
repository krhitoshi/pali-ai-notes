# frozen_string_literal: true

# 対訳 md を静的 HTML としてビルドするスクリプト
# 使い方: bundle exec ruby scripts/build_site.rb
#
# - 対象は本体 + 註 (attha) + 復註 (tika) のみ. 派生ファイル (_check, _v1 など) は
#   ファイル名のホワイトリスト正規表現で除外する
# - ソース md は変更せず, 変換時にメモリ上で前処理する
#   - 先頭の frontmatter (source, generated, updated) は本文から外し,
#     ページ冒頭に原文リンクと日付の行として表示する.
#     分割生成の途中の対訳 (status: incomplete) には「未完」を添える
#   - Meta ブロックの除去
#   - 二重番号行 (例 "3. 107. Evaṃ...") の内側番号のピリオドをエスケープして
#     CommonMark の入れ子リスト解釈を防ぐ (issue #1)
# - 出力は public/ にソースと同じ階層でミラーし, リンクはすべて相対パス
#   (vinaya/mahavagga のような 2 階層のセクションもある)
# - notes/ の調査ノートは対訳とは別扱いで, 全ファイルを対象にし,
#   ノート間の相対 .md リンクを .html に張り替える
# - public/ 配下は全消し再生成するが .gitkeep は残す

require "commonmarker"
require "cgi"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
OUT_DIR = File.join(ROOT, "public")
# 公開先の URL. ここを指すリンクはサイト内のリンクとして扱う
SITE_URL = "https://krhitoshi.github.io/pali-ai-notes/"

# セクション定義. トップページと一覧の表示順もこの順
# prefix は対訳ファイル名の接頭辞. notes: true のセクションは調査ノート
SECTIONS = [
  { dir: "vinaya/mahavagga", name: "律 大品 (Vinaya Mahāvagga)", prefix: "vin_mahavagga" },
  { dir: "dn", name: "長部 (Dīghanikāya)", prefix: "dn" },
  { dir: "mn", name: "中部 (Majjhimanikāya)", prefix: "mn" },
  { dir: "sn", name: "相応部 (Saṃyuttanikāya)", prefix: "sn" },
  { dir: "an", name: "増支部 (Aṅguttaranikāya)", prefix: "an" },
  { dir: "dhammapada", name: "ダンマパダ (Dhammapada)", prefix: "dhp" },
  { dir: "jataka", name: "ジャータカ (Jātaka)", prefix: "ja" },
  { dir: "patisambhidamagga", name: "無礙解道 (Paṭisambhidāmagga)", prefix: "patis" },
  { dir: "visuddhimagga", name: "清浄道論 (Visuddhimagga)", prefix: "vism" },
  { dir: "notes", name: "調査ノート", notes: true },
].freeze

PREFIX_RE = Regexp.union(SECTIONS.filter_map { |s| s[:prefix] })

# 本体 + 註 + 復註だけを通すホワイトリスト
# 数字以外の接尾辞 (_check, _opus, _v1 など) はここで弾かれる
TARGET_RE = /\A(#{PREFIX_RE})(_attha|_tika)?(_[\d-]+)+\z/

KIND_LABELS = { main: "本文", attha: "註", tika: "復註" }.freeze

# 生成メタデータの見出しテキスト. 全コーパスで "Meta" に統一済み
META_HEADING = "Meta"

# 欧文は OS 標準の欧文フォントで描画する (外部のフォントは読み込まない).
# ヒラギノ角ゴは ā は持つが ṃ ṅ ṭ ḍ ṇ ḷ を持たず, 文字ごとに別フォントへ
# フォールバックしてガタガタに見えるため, ダイアクリティカル付き文字を
# 揃って持つ欧文フォントを先に置く (macOS: SF / Helvetica Neue,
# Windows: Segoe UI, Android: Roboto). 和文は欧文フォントに含まれないので,
# 後続のヒラギノ / 游ゴシック / メイリオで描画される
FONT_FAMILY = %(-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Noto Sans", "Helvetica Neue", Arial, ) +
              %("Hiragino Kaku Gothic ProN", "Hiragino Sans", "Yu Gothic", Meiryo, sans-serif)

CSS = <<~CSS
  html { background: #fdfcf7; }
  body {
    max-width: 46rem;
    margin: 0 auto;
    padding: 0 1rem 4rem;
    font-family: #{FONT_FAMILY};
    line-height: 1.8;
    color: #222;
    background: #fdfcf7;
  }
  h1, h2, h3 {
    font-family: #{FONT_FAMILY};
    line-height: 1.4;
  }
  h1 { font-size: 1.4rem; border-bottom: 2px solid #8a7b5c; padding-bottom: 0.3rem; }
  h2 { font-size: 1.15rem; border-bottom: 1px solid #ccc; padding-bottom: 0.2rem; }
  h3 { font-size: 1rem; }
  a { color: #1a5276; }
  nav.site-nav {
    font-family: #{FONT_FAMILY};
    font-size: 0.9rem;
    background: #f4f1ea;
    padding: 0.5rem 0.8rem;
    margin: 1rem 0;
    border-radius: 4px;
  }
  nav.site-nav span.sep { color: #999; margin: 0 0.4rem; }
  p.page-meta {
    font-family: #{FONT_FAMILY};
    font-size: 0.85rem;
    color: #666;
  }
  p.page-meta span.sep { color: #bbb; margin: 0 0.4rem; }
  /* コードブロックのパーリ文は 1 行が長いので, 横にはみ出さず折り返す */
  pre {
    white-space: pre-wrap;
    overflow-wrap: break-word;
    padding: 0.6rem 0.8rem;
    border-radius: 4px;
  }
  /* コードの記法で囲んだパーリ文も等幅にせず本文と同じフォントで描画する */
  pre, code { font-family: #{FONT_FAMILY}; font-size: 0.95em; }
  ol, ul { padding-left: 1.6rem; }
  li { margin: 0.2rem 0; }
  table { border-collapse: collapse; width: 100%; font-size: 0.95rem; }
  th, td { border: 1px solid #ccc; padding: 0.3rem 0.6rem; text-align: left; }
  th {
    font-family: #{FONT_FAMILY};
    background: #f4f1ea;
  }
  ul.page-list { list-style: none; padding-left: 0; }
  /* 調査ノート一覧の作成日 */
  ul.note-list li { margin: 0.4rem 0; }
  ul.note-list span.note-date { color: #666; font-variant-numeric: tabular-nums; }
CSS

Page = Struct.new(:dir, :stem, :kind, :number_key, :titles, :md_path, keyword_init: true) do
  def html_name
    "#{stem}.html"
  end

  # 番号表示用にコーパス接頭辞を除いた部分を返す
  def display_number
    number_key.sub(/\A(#{PREFIX_RE})_/, "")
  end
end

# セクションのディレクトリから public/ ルートへの相対パス (例 "../../")
def root_rel(section)
  "../" * (section[:dir].count("/") + 1)
end

# ファイル名から数字部分を数値として比較する自然順ソートキー
def sort_key(stem)
  stem.split(/(\d+)/).map { |part| part.match?(/\A\d+\z/) ? [1, part.to_i] : [0, part] }
end

def collect_pages(section)
  dir_path = File.join(ROOT, section[:dir])
  Dir.glob(File.join(dir_path, "*.md")).filter_map do |path|
    stem = File.basename(path, ".md")
    next unless section[:notes] || stem.match?(TARGET_RE)

    kind =
      case stem
      when ->(_) { section[:notes] } then :main
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
    next if text == META_HEADING

    text
  end
  titles.uniq.join(" / ")
end

# タイトル (見出しの md テキスト) のインライン記法を HTML にする
# Commonmarker の出力から外側の <p> を外して使う. 段落 1 つにならない場合
# (行頭の "1." がリストと解釈されるなど) は記法を解釈せずエスケープだけする
def title_html(md_text)
  # H1 のないページは空文字 (US-ASCII の "" になり Commonmarker が受け付けない)
  return "" if md_text.empty?

  html =Commonmarker.to_html(md_text, options: { render: { hardbreaks: false } }).strip
  html[%r{\A<p>(.*)</p>\z}m, 1] || CGI.escapeHTML(md_text)
end

# <title> 用に, タイトルの記法を外したテキストにする
def title_text(md_text)
  CGI.unescapeHTML(title_html(md_text).gsub(/<[^>]*>/, ""))
end

# 先頭の frontmatter (--- で囲まれた key: value 行) を分離する
# 戻り値: [メタ情報の Hash, frontmatter を除いた本文]
def split_front_matter(md)
  m = md.match(/\A---\n(.*?)\n---\n/m)
  return [{}, md] unless m

  meta = {}
  m[1].each_line do |line|
    key, value = line.chomp.split(/:\s+/, 2)
    meta[key] = value if value && !value.empty?
  end
  [meta, m.post_match]
end

# frontmatter の内容をページ冒頭の一行として表示する
def front_matter_html(meta)
  parts = []
  if meta["source"]
    href = CGI.escapeHTML(meta["source"])
    name = CGI.escapeHTML(File.basename(meta["source"]))
    parts << %(原文: <a href="#{href}">#{name}</a>)
  end
  parts << "作成: #{CGI.escapeHTML(meta['generated'])}" if meta["generated"]
  parts << "更新: #{CGI.escapeHTML(meta['updated'])}" if meta["updated"]
  # 分割生成の途中の対訳 (assemble_md.rb が status: incomplete を書く)
  parts << "未完 (生成途中)" if meta["status"] == "incomplete"
  # 調査ノートだけが持つ項目
  parts << "モデル: #{CGI.escapeHTML(meta['models'])}" if meta["models"]
  parts << "レビュー: #{CGI.escapeHTML(meta['reviewed'])}" if meta["reviewed"]
  return "" if parts.empty?

  %(<p class="page-meta">#{parts.join('<span class="sep">|</span>')}</p>\n)
end

# md テキストの前処理. ソースファイルは変更しない
def preprocess(md)
  lines = md.lines
  result = []
  in_meta = false
  lines.each do |line|
    heading_text = line[/\A#+ (.+?)\s*\z/, 1]
    if heading_text == META_HEADING
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

# Commonmarker は既定で改行を <br> にする (hardbreaks). 対訳はこの挙動に合わせて
# 書かれているが, 調査ノートは 1 段落を 1 行で書く通常の markdown なので false で呼ぶ
def to_html(md, hardbreaks: true)
  Commonmarker.to_html(md, options: { extension: { autolink: true }, render: { hardbreaks: hardbreaks } })
end

# 同じディレクトリ内の相対 .md リンク (例 "](foo.md)" "](foo.md#sec)") を .html に張り替える
# URL スキームやパス区切りを含むリンクは対象外
def rewrite_md_links(md)
  md.gsub(/\]\(([\w.-]+)\.md(#[^)]*)?\)/) { "](#{$1}.html#{$2})" }
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
  items << ["トップ", "#{root_rel(section)}index.html"]
  items << ["#{section[:name]} 一覧", "index.html"]
  # 調査ノートは番号順の並びに意味がないので前後リンクを張らない
  unless section[:notes]
    items << ["← #{prev_page.stem}", prev_page.html_name] if prev_page
    items << ["#{next_page.stem} →", next_page.html_name] if next_page
  end
  # 同じ番号の本文 / 註 / 復註への相互リンク
  pages.each do |other|
    next if other == page || other.number_key != page.number_key

    items << [KIND_LABELS[other.kind], other.html_name]
  end

  meta, body_md = split_front_matter(File.read(page.md_path, encoding: "UTF-8"))
  md = preprocess(body_md)
  md = rewrite_md_links(md) if section[:notes]
  title = page.titles.empty? ? page.stem : title_text(page.titles)
  html = render_layout(
    title: "#{title} - #{section[:name]}",
    css_href: "#{root_rel(section)}style.css",
    nav: nav_html(items),
    body: front_matter_html(meta) + to_html(md, hardbreaks: !section[:notes])
  )
  File.write(File.join(OUT_DIR, page.dir, page.html_name), html)
end

def index_body(section, pages)
  grouped = pages.group_by(&:number_key)
  # 調査ノートはタイトルのリスト, 註や復註を持つセクションは表,
  # 本文だけのセクションは番号付きの単純なリスト
  if section[:notes]
    # 作成日 (frontmatter の generated) の新しい順. 同じ日付どうしはファイル名順
    # generated のないノートは末尾に置く
    notes = pages.map do |page|
      meta, = split_front_matter(File.read(page.md_path, encoding: "UTF-8"))
      [page, meta]
    end
    notes.sort! do |(a, a_meta), (b, b_meta)|
      [b_meta["generated"].to_s, sort_key(a.stem)] <=> [a_meta["generated"].to_s, sort_key(b.stem)]
    end
    items = notes.map do |page, meta|
      title = page.titles.empty? ? CGI.escapeHTML(page.stem) : title_html(page.titles)
      date = meta["generated"] ? %(<span class="note-date">#{CGI.escapeHTML(meta['generated'])}</span> ) : ""
      # reviewed が none のノートだけをレビュー待ちとする. reviewed の行がない
      # ノートはレビューの有無の記録がない (未レビューとは限らない) ので何も付けない
      pending = meta["reviewed"] == "none" ? " (レビュー待ち)" : ""
      %(<li>#{date}<a href="#{page.html_name}">#{title}</a>#{pending}</li>)
    end
    <<~HTML
      <h1>#{CGI.escapeHTML(section[:name])}</h1>
      <ul class="page-list note-list">
      #{items.join("\n")}
      </ul>
    HTML
  elsif pages.any? { |p| p.kind != :main }
    rows = grouped.map do |_key, group|
      title_page = group.min_by { |p| KIND_LABELS.keys.index(p.kind) }
      links = KIND_LABELS.keys.map do |kind|
        page = group.find { |p| p.kind == kind }
        page ? %(<a href="#{page.html_name}">#{KIND_LABELS[kind]}</a>) : ""
      end
      <<~ROW
        <tr>
        <td>#{CGI.escapeHTML(title_page.display_number)}</td>
        <td>#{title_html(title_page.titles)}</td>
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
      %(<li><a href="#{page.html_name}">#{CGI.escapeHTML(page.display_number)}</a> #{title_html(page.titles)}</li>)
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
  items = [["トップ", "#{root_rel(section)}index.html"], ["#{section[:name]} 一覧", nil]]
  html = render_layout(
    title: "#{section[:name]} 一覧",
    css_href: "#{root_rel(section)}style.css",
    nav: nav_html(items),
    body: index_body(section, pages)
  )
  File.write(File.join(OUT_DIR, section[:dir], "index.html"), html)
end

# 外部リンクを新しいタブで開くようにする. サイト自身 (SITE_URL) を指すリンクは除く
# md には target を書けない (GitHub も取り除く) ため, ビルド時に HTML へ足す
def open_external_links_in_new_tab(html)
  html.gsub(%r{<a href="(https?://[^"]*)"}) do
    href = Regexp.last_match(1)
    href.start_with?(SITE_URL) ? $& : %(<a href="#{href}" target="_blank" rel="noopener")
  end
end

def write_top(section_pages)
  readme_html = to_html(File.read(File.join(ROOT, "README.md"), encoding: "UTF-8"))
  readme_html = open_external_links_in_new_tab(readme_html)
  list_item = lambda do |section, pages|
    %(<li><a href="#{section[:dir]}/index.html">#{CGI.escapeHTML(section[:name])}</a> (#{pages.size} 件)</li>)
  end
  corpus, notes = section_pages.partition { |section, _pages| !section[:notes] }
  lists_html = <<~HTML
    <h2>対訳一覧</h2>
    <ul class="page-list">
    #{corpus.map { |s, p| list_item.call(s, p) }.join("\n")}
    </ul>
    <h2>調査ノート</h2>
    <ul class="page-list">
    #{notes.map { |s, p| list_item.call(s, p) }.join("\n")}
    </ul>
  HTML
  # 一覧は README の「データソース」見出しの直前に差し込む. 見出しがなければ末尾に置く
  insert_at = readme_html.index(/<h2[^>]*>データソース/) || readme_html.size
  body = readme_html.dup.insert(insert_at, lists_html)
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
