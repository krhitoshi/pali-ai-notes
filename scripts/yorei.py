#!/usr/bin/env python3
# VRI XML からパーリ語句の用例 (出典 + 文) を抽出するスクリプト
#
# 使い方:
#   python3 scripts/yorei.py [options] <pattern>
#
# 例:
#   python3 scripts/yorei.py --code s0202m.mul 'appāṭihīrakataṃ bhāsitaṃ sampajjat'
#   python3 scripts/yorei.py --code s0101m.mul --code s0202m.mul 'bhāsitaṃ sampajjat'
#   python3 scripts/yorei.py --xml _tmp/e0101n.mul8.xml 'bhāvanā sampajjati'
#   python3 scripts/yorei.py --all-cached 'nānubhonti'
#
# - <pattern> は正規表現 (大文字小文字を区別する. -i で無視)
# - --code は tipitaka.org の分割前ファイル名 (cscd-text MCP の検索結果に出る
#   "s0202m.mul.xml" の形. .xml はあってもなくてもよい). 分割ファイル
#   (s0202m.mul0.xml, s0202m.mul1.xml, ...) を 404 になるまで順に取得し,
#   _tmp/ にキャッシュする. 既にあるファイルはそのまま使う
# - --xml はローカルの XML ファイルを直接指定する (複数可)
# - --all-cached は _tmp/*.xml をすべて検索する (ダウンロードしない)
# - 出力は一致ごとに 2 行: 出典行 (略号 + VRI 段落番号 + ファイル / 見出し /
#   PTS 頁) と, 一致を含む文. --para で文の代わりに段落全体を出す
# - 異読注 <note> は既定で落とす. --keep-notes で [..] として残す
# - 出典略号は DN / MN / SN / AN / Dhp-a / Vism とその註・復註に対応し,
#   それ以外はファイル名と見出し連鎖をそのまま出す (引用形は利用者が組む)
# - PTS 頁は XML の <pb ed="P"> から取るが行番号は得られない.
#   一致位置の直前にあるマーカーを採るので, 頁境界付近では前後 1 頁ずれうる

import argparse
import glob
import os
import re
import sys
import urllib.error
import urllib.request

BASE_URL = "https://www.tipitaka.org/romn/cscd/"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CACHE = os.path.join(REPO_ROOT, "_tmp")

# ファイル名の先頭 (s0101 など) -> (本文略号, 註略号, 復註略号, PTS 略号 本文, PTS 略号 註)
# PTS 略号は <pb ed="P"> の巻.頁に付ける
BOOK_TABLE = {
    "s0101": ("DN", "Sv", "Sv-pṭ", "D", "Sv"),
    "s0102": ("DN", "Sv", "Sv-pṭ", "D", "Sv"),
    "s0103": ("DN", "Sv", "Sv-pṭ", "D", "Sv"),
    "s0201": ("MN", "Ps", "Ps-pṭ", "M", "Ps"),
    "s0202": ("MN", "Ps", "Ps-pṭ", "M", "Ps"),
    "s0203": ("MN", "Ps", "Ps-pṭ", "M", "Ps"),
    "s0301": ("SN", "Spk", "Spk-pṭ", "S", "Spk"),
    "s0302": ("SN", "Spk", "Spk-pṭ", "S", "Spk"),
    "s0303": ("SN", "Spk", "Spk-pṭ", "S", "Spk"),
    "s0304": ("SN", "Spk", "Spk-pṭ", "S", "Spk"),
    "s0305": ("SN", "Spk", "Spk-pṭ", "S", "Spk"),
    "s0401": ("AN", "Mp", "Mp-ṭ", "A", "Mp"),
    "s0402": ("AN", "Mp", "Mp-ṭ", "A", "Mp"),
    "s0403": ("AN", "Mp", "Mp-ṭ", "A", "Mp"),
    "s0404": ("AN", "Mp", "Mp-ṭ", "A", "Mp"),
    "s0502": ("Dhp", "Dhp-a", "Dhp-a-ṭ", "Dhp", "Dhp-a"),
    "e0101": ("Vism", "Vism-mhṭ", "", "Vism", "Vism-mhṭ"),
    "e0102": ("Vism", "Vism-mhṭ", "", "Vism", "Vism-mhṭ"),
    "e0103": ("Vism-mhṭ", "", "", "Vism-mhṭ", ""),
    "e0104": ("Vism-mhṭ", "", "", "Vism-mhṭ", ""),
}

# DN: 巻ファイルごとの経番号オフセット (chapter の "9. Poṭṭhapādasuttaṃ" に足す)
DN_OFFSET = {"s0101": 0, "s0102": 13, "s0103": 23}
# MN: 巻ファイルごとの経番号ベース. 経番号 = base + 10*(vagga-1) + sutta
MN_BASE = {"s0201": 0, "s0202": 50, "s0203": 100}
# SN: 巻ファイルごとの相応番号オフセット (chapter の "1. Devatāsaṃyuttaṃ" に足す)
SN_OFFSET = {"s0301": 0, "s0302": 11, "s0303": 21, "s0304": 34, "s0305": 44}
# AN: book 名 -> 集番号
AN_NIPATA = [
    ("ekādasaka", 11), ("dasaka", 10), ("navaka", 9), ("aṭṭhaka", 8),
    ("sattaka", 7), ("chakka", 6), ("pañcaka", 5), ("catukka", 4),
    ("tika", 3), ("duka", 2), ("ekaka", 1),
]

# AN 本文: ファイル名の接頭辞 -> 集番号 (book 見出しが取れないときのフォールバック)
AN_CODE_NIPATA = {
    "s0401m": 1, "s0402m1": 2, "s0402m2": 3, "s0402m3": 4,
    "s0403m1": 5, "s0403m2": 6, "s0403m3": 7,
    "s0404m1": 8, "s0404m2": 9, "s0404m3": 10, "s0404m4": 11,
}

# PTS 頁が巻通しの文献 (巻番号を付けずに頁だけで引く)
CONTINUOUS_PTS = {"Sv"}

ROMAN = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
         "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX",
         "XX", "XXI", "XXII", "XXIII"]


def roman(n):
    return ROMAN[n] if 0 < n < len(ROMAN) else str(n)


def fetch(url, dest):
    """URL を dest に保存する. 404 なら False"""
    try:
        with urllib.request.urlopen(url, timeout=60) as r:
            data = r.read()
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        raise
    with open(dest, "wb") as f:
        f.write(data)
    return True


def resolve_code(code, cache, max_parts):
    """--code の指定を分割ファイルのパス一覧に解決する"""
    code = os.path.basename(code)
    code = re.sub(r"\.xml$", "", code)
    paths = []
    # 既に分割番号付き (e0101n.mul8 など) なら単一ファイル
    if re.search(r"\.(mul|att|tik|nrf)\d+$", code):
        candidates = [code]
    else:
        candidates = [f"{code}{i}" for i in range(max_parts)]
    for c in candidates:
        dest = os.path.join(cache, c + ".xml")
        if not os.path.exists(dest):
            ok = fetch(BASE_URL + c + ".xml", dest)
            if not ok:
                if paths:
                    break
                # 先頭が 404 のときは分割なしの可能性もあるが, tipitaka.org の
                # romn/cscd は分割ファイルのみなのでここで打ち切る
                print(f"not found: {BASE_URL}{c}.xml", file=sys.stderr)
                break
            print(f"downloaded: {dest}", file=sys.stderr)
        paths.append(dest)
    return paths


def read_xml(path):
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        text = raw.decode("utf-16")
    else:
        text = raw.decode("utf-8", errors="replace")
    return text.lstrip("﻿")


P_RE = re.compile(r'<p rend="([^"]+)"((?:\s+[a-z]+="[^"]*")*)\s*>(.*?)</p>', re.S)
N_ATTR_RE = re.compile(r'\sn="(\d+)"')
PARANUM_RE = re.compile(r'<hi rend="paranum">(\d+)</hi>')
PB_RE = re.compile(r'<pb ed="([A-Z])" n="([0-9.]+)"\s*/>')
NOTE_RE = re.compile(r"<note>(.*?)</note>", re.S)
TAG_RE = re.compile(r"<[^>]+>")
HEAD_RENDS = ("nikaya", "book", "chapter", "title", "subhead")


def clean(fragment, keep_notes):
    if keep_notes:
        fragment = NOTE_RE.sub(lambda m: " [" + m.group(1).strip() + "]", fragment)
    else:
        fragment = NOTE_RE.sub("", fragment)
    fragment = TAG_RE.sub("", fragment)
    fragment = re.sub(r"\s+", " ", fragment)
    fragment = re.sub(r"\s+([,.;:?!’])", r"\1", fragment)
    return fragment.strip()


SENT_SPLIT_RE = re.compile(r"(?<=[.?!])\s+(?=[‘\"A-ZĀĪŪṬḌṆÑṂṄḶ\d\[])")


ABBREV_RE = re.compile(r"(^|[\s(])[a-zāīūṭḍṇñṃṅḷ]{1,4}\.$")


def sentence_at(text, pos):
    """text 中の位置 pos を含む文を返す. 略号 (dha. sa. など) の後では切らない"""
    start = 0
    for m in SENT_SPLIT_RE.finditer(text):
        if ABBREV_RE.search(text[:m.start()]):
            continue
        if m.end() <= pos:
            start = m.end()
        else:
            return text[start:m.start()].strip()
    return text[start:].strip()


def pts_at(fragment_raw, pos_raw, last_pts):
    """生の段落文字列中, 位置 pos_raw より前の最後の PTS マーカーを返す"""
    pts = last_pts
    for m in PB_RE.finditer(fragment_raw):
        if m.start() >= pos_raw:
            break
        if m.group(1) == "P":
            pts = m.group(2)
    return pts


def leading_num(s):
    m = re.match(r"\s*(\d+)\.", s or "")
    return int(m.group(1)) if m else None


def pts_label(code5, kind, pts):
    """"1.0339" -> "D I 339" の形にする"""
    if not pts:
        return ""
    entry = BOOK_TABLE.get(code5)
    vol, page = pts.split(".") if "." in pts else ("", pts)
    page = str(int(page)) if page.isdigit() else page
    vol_s = roman(int(vol)) if vol.isdigit() else vol
    if entry:
        abbr = entry[3] if kind == "mul" else entry[4]
        if abbr in CONTINUOUS_PTS:
            return f"{abbr} {page}"
        if abbr:
            return f"{abbr} {vol_s} {page}".replace("  ", " ")
    return f"PTS {vol_s} {page}"


def citation(path, heads, n, n_next, own_n=None):
    """出典の引用形を組む. 対応外のときは None"""
    fname = os.path.basename(path)
    code5 = fname[:5]
    kind_m = re.search(r"\.(mul|att|tik|nrf)\d+\.xml$", fname)
    kind = kind_m.group(1) if kind_m else "mul"
    entry = BOOK_TABLE.get(code5)
    if not entry:
        return None, code5, kind
    mul_abbr, att_abbr, tik_abbr = entry[0], entry[1], entry[2]
    sec = f"VRI §{n}" if n else "VRI §?"

    if mul_abbr in ("DN", "MN", "SN", "AN"):
        sutta = None
        if mul_abbr == "DN":
            k = leading_num(heads.get("chapter"))
            if k is not None:
                sutta = f"DN {k + DN_OFFSET[code5]}"
        elif mul_abbr == "MN":
            vagga = leading_num(heads.get("chapter"))
            s = leading_num(heads.get("subhead"))
            if vagga is not None and s is not None:
                if code5 == "s0203" and vagga == 5:
                    num = 142 + s
                else:
                    num = MN_BASE[code5] + 10 * (vagga - 1) + s
                sutta = f"MN {num}"
        elif mul_abbr == "SN":
            # VRI の段落番号は巻 (Sagāthāvagga など) 通しの番号で経番号ではない.
            # 経番号は title (相応内の vagga) x 10 + subhead の番号で推定する.
            # vagga が 10 経でない相応 (SN 35 など) ではずれるので要確認
            k = leading_num(heads.get("chapter"))
            v = leading_num(heads.get("title"))
            s = leading_num(heads.get("subhead"))
            if k is not None:
                samy = k + SN_OFFSET[code5]
                if v is not None and s is not None:
                    sutta = f"SN {samy}.{10 * (v - 1) + s}"
                else:
                    sutta = f"SN {samy}"
        elif mul_abbr == "AN":
            # book 見出し "Catukkanipātapāḷi" / "Catukkanipāta-aṭṭhakathā" から
            # nipāta 直前の語を取る ("aṭṭhakathā" に "aṭṭhaka" が含まれるため
            # 単純な部分一致は使わない)
            book = (heads.get("book") or "").lower()
            bm = re.search(r"([a-zāīūṭḍṇñṃṅḷ]+)nipāta", book)
            nip = dict((k, v) for k, v in AN_NIPATA).get(bm.group(1)) if bm else None
            if nip is None:
                prefix = re.sub(r"\.(mul|att|tik|nrf)\d+\.xml$", "", fname)
                nip = AN_CODE_NIPATA.get(prefix)
            if nip is not None:
                sutta = f"AN {nip}.{n}" if n else f"AN {nip}"
        if sutta is None:
            return None, code5, kind
        if kind == "mul":
            if mul_abbr == "AN":
                # AN の段落番号は集内の経番号と一致する
                return sutta, code5, kind
            return f"{sutta} ({sec})", code5, kind
        abbr = att_abbr if kind == "att" else tik_abbr
        # 註・復註では経番号が見出しから取れるが, SN/AN の段落番号は経番号と
        # 一致しないことがあるので VRI § を併記する
        return f"{abbr} (ad {sutta}, {sec})", code5, kind

    if mul_abbr == "Dhp":
        # Dhp / Dhp-a: 段落番号は偈番号. 番号付き段落 (偈) はその番号を,
        # 番号なし段落 (物語) は同節内の次の偈番号を, なければ直前の偈番号を使う
        if kind == "mul":
            verse = n
        else:
            verse = own_n if own_n is not None else (n_next or n)
        vatthu = re.sub(r"^\s*\d+\.\s*", "", heads.get("subhead") or "")
        abbr = att_abbr if kind == "att" else (tik_abbr if kind == "tik" else mul_abbr)
        if kind == "mul":
            return f"Dhp {verse}", code5, kind
        return f"{abbr} (ad Dhp {verse}, {vatthu})", code5, kind

    if mul_abbr.startswith("Vism"):
        ch = leading_num(heads.get("chapter"))
        abbr = mul_abbr if kind == "mul" or code5 in ("e0103", "e0104") else att_abbr
        if ch is None:
            return f"{abbr} ({sec})", code5, kind
        return f"{abbr} {roman(ch)} ({sec})", code5, kind

    return None, code5, kind


def scan_file(path, pattern, args, heads=None):
    """1 ファイルを走査して一致を返す. heads は前の分割ファイルから引き継ぐ見出し"""
    text = read_xml(path)
    heads = dict(heads or {})
    last_n = None
    last_pts = None
    paras = []
    # 1 周目: 段落と見出し, 番号を集める (Dhp-a の "次の偈番号" のため)
    for m in P_RE.finditer(text):
        rend, attrs, body = m.group(1), m.group(2), m.group(3)
        if rend in HEAD_RENDS:
            heads[rend] = clean(body, False)
            if rend in ("chapter", "title"):
                heads.pop("subhead", None)
            if rend == "chapter":
                heads.pop("title", None)
            paras.append(None)
            continue
        nm = N_ATTR_RE.search(attrs) or PARANUM_RE.search(body)
        if nm:
            last_n = int(nm.group(1))
        pts_before = last_pts
        for pm in PB_RE.finditer(body):
            if pm.group(1) == "P":
                last_pts = pm.group(2)
        paras.append({
            "heads": dict(heads),
            "n": last_n,
            "own_n": int(nm.group(1)) if nm else None,
            "pts_before": pts_before,
            "raw": body,
            "subhead": heads.get("subhead"),
        })
    # 同一 subhead 内で次に現れる番号付き段落の番号
    next_n = None
    cur_sub = object()
    for p in reversed(paras):
        if p is None:
            continue
        if p["subhead"] != cur_sub:
            cur_sub = p["subhead"]
            next_n = None
        p["n_next"] = next_n
        if p["own_n"] is not None:
            next_n = p["own_n"]

    hits = []
    for p in paras:
        if p is None:
            continue
        cleaned = clean(p["raw"], args.keep_notes)
        seen = set()
        for mm in pattern.finditer(cleaned):
            sent = cleaned if args.para else sentence_at(cleaned, mm.start())
            if sent in seen:
                continue
            seen.add(sent)
            # PTS 頁: 生文字列中の一致位置を推定する (タグ除去前後で位置が
            # 変わるため, 一致文字列の最初の出現位置で代用する)
            raw_pos = p["raw"].find(mm.group(0))
            pts = pts_at(p["raw"], raw_pos if raw_pos >= 0 else len(p["raw"]), p["pts_before"])
            cite, code5, kind = citation(path, p["heads"], p["n"], p.get("n_next"), p["own_n"])
            hits.append({
                "cite": cite,
                "file": os.path.basename(path),
                "heads": " > ".join(p["heads"][k] for k in HEAD_RENDS if k in p["heads"]),
                "n": p["n"],
                "pts": pts_label(code5, kind, pts),
                "text": sent,
            })
    return hits, heads


def main():
    ap = argparse.ArgumentParser(description="VRI XML からパーリ語句の用例を抽出する")
    ap.add_argument("pattern", help="検索する正規表現")
    ap.add_argument("--code", action="append", default=[],
                    help="tipitaka.org のファイル名 (例 s0202m.mul). 複数可")
    ap.add_argument("--xml", action="append", default=[], help="ローカル XML. 複数可")
    ap.add_argument("--all-cached", action="store_true", help="キャッシュ内の全 XML を検索")
    ap.add_argument("--cache", default=DEFAULT_CACHE, help="キャッシュディレクトリ (既定 _tmp)")
    ap.add_argument("--max-parts", type=int, default=80, help="分割ファイルの最大数")
    ap.add_argument("-i", "--ignore-case", action="store_true")
    ap.add_argument("--para", action="store_true", help="文でなく段落全体を出す")
    ap.add_argument("--keep-notes", action="store_true", help="異読注を [..] で残す")
    args = ap.parse_args()

    os.makedirs(args.cache, exist_ok=True)
    paths = []
    for c in args.code:
        paths += resolve_code(c, args.cache, args.max_parts)
    paths += args.xml
    if args.all_cached:
        paths += sorted(glob.glob(os.path.join(args.cache, "*.xml")))
    if not paths:
        ap.error("--code, --xml, --all-cached のいずれかを指定する")

    flags = re.IGNORECASE if args.ignore_case else 0
    pattern = re.compile(args.pattern, flags)

    total = 0
    # 同じコードの分割ファイルは番号順に処理し, nikaya / book などの見出しを
    # 引き継ぐ (book 見出しは先頭の分割ファイルにしか現れない)
    carried = {}
    for path in paths:
        if not os.path.exists(path):
            print(f"missing: {path}", file=sys.stderr)
            continue
        prefix = re.sub(r"\d+\.xml$", "", os.path.basename(path))
        hits, heads = scan_file(path, pattern, args, carried.get(prefix))
        carried[prefix] = heads
        for h in hits:
            total += 1
            cite = h["cite"] or f"{h['file']} (VRI §{h['n']})"
            extra = f"{h['file']} | {h['heads']} | §{h['n']}"
            if h["pts"]:
                extra += f" | {h['pts']}"
            print(f"{cite}  [{extra}]")
            print(f"  {h['text']}")
    if total == 0:
        print("no match", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
