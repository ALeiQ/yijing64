#!/usr/bin/env python3
"""抓取维基文库《周易》64 卦的卦辞与爻辞，转为简体并存为 JSON。

数据源：https://zh.wikisource.org（公有领域，PD-old）
用法：python3 fetch_yijing.py
输出：./hexagram_content.json（本脚本目录）
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from opencc import OpenCC

API = "https://zh.wikisource.org/w/api.php"
UA = "Yijing64App/1.0 (research; PD classical text)"

NAMES = [
    "乾","坤","屯","蒙","需","讼","师","比","小畜","履",
    "泰","否","同人","大有","谦","豫","随","蛊","临","观",
    "噬嗑","贲","剥","复","无妄","大畜","颐","大过","坎","离",
    "咸","恒","遁","大壮","晋","明夷","家人","睽","蹇","解",
    "损","益","夬","姤","萃","升","困","井","革","鼎",
    "震","艮","渐","归妹","丰","旅","巽","兑","涣","节",
    "中孚","小过","既济","未济",
]
SLUGS = [
    "乾","坤","屯","蒙","需","訟","師","比","小畜","履",
    "泰","否","同人","大有","謙","豫","隨","蠱","臨","觀",
    "噬嗑","賁","剝","復","无妄","大畜","頤","大過","坎","離",
    "咸","恒","遯","大壯","晉","明夷","家人","睽","蹇","解",
    "損","益","夬","姤","萃","升","困","井","革","鼎",
    "震","艮","漸","歸妹","豐","旅","巽","兌","渙","節",
    "中孚","小過","既濟","未濟",
]
assert len(NAMES) == len(SLUGS) == 64

cc = OpenCC("t2s")


def to_simplified(text: str) -> str:
    """opencc t2s 的特例修正：周易专名不应被误转。"""
    s = cc.convert(text)
    s = s.replace("干干", "乾乾")  # 乾乾（君子终日乾乾）不可作干干
    s = s.replace("遯", "遁")      # 遯 -> 遁（天山遁/遁卦）
    return s

LINE_RE = re.compile(r"^(初九|初六|九二|六二|九三|六三|九四|六四|九五|六五|上九|上六|用九|用六)[：:,，]")
ORDER = ["初九", "初六", "九二", "六二", "九三", "六三",
         "九四", "六四", "九五", "六五", "上九", "上六"]


def fetch_wikitext(title: str) -> str | None:
    params = {
        "action": "query", "prop": "revisions", "rvprop": "content",
        "rvslots": "main", "format": "json", "formatversion": "2",
        "titles": title, "redirects": "1",
    }
    url = API + "?" + urllib.parse.urlencode(params)
    for attempt in range(8):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            pages = data.get("query", {}).get("pages", [])
            if not pages or "missing" in pages[0]:
                return None
            revs = pages[0].get("revisions", [])
            if not revs:
                return None
            return revs[0].get("slots", {}).get("main", {}).get("content", "")
        except urllib.error.HTTPError as exc:
            backoff = 15 * (attempt + 1)
            print(f"[429/limit] {title} -> sleep {backoff}s", file=sys.stderr)
            time.sleep(backoff)
        except Exception as exc:
            print(f"[retry {attempt}] {title}: {exc}", file=sys.stderr)
            time.sleep(6)
    return None


def strip_markup(line: str) -> str:
    s = line
    s = re.sub(r"<ref[^>]*>.*?</ref>", "", s, flags=re.S)
    s = re.sub(r"<[^>]+>", "", s)
    s = re.sub(r"''''*", "", s)
    s = re.sub(r"\[\[File:[^\]]*\]\]", "", s)
    s = re.sub(r"\[\[[^\]|]*\|([^\]]*)\]\]", r"\1", s)
    s = re.sub(r"\[\[[^\]]*\]\]", "", s)
    s = re.sub(r"-[{]([^}]*)[}]-", r"\1", s)          # -{乾}- -> 乾
    s = re.sub(r"\{\{[^}]*\}\}", "", s)               # {{*|一作太和}} -> ""
    s = re.sub(r"^[*#;:]+", "", s)                    # 行首列表/段落标记
    return s.strip()


def parse_hexagram(text: str, name: str) -> dict | None:
    text = re.sub(r"\{\{.*?\}\}", "", text, flags=re.S)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    text = re.sub(r"<noinclude>.*?</noinclude>", "", text, flags=re.S)

    judgement = None
    line_dict: dict[str, str] = {}

    for raw in text.splitlines():
        line = strip_markup(raw)
        if not line:
            continue
        m = LINE_RE.match(line)
        if m:
            key = m.group(1)
            if key not in line_dict:
                line_dict[key] = to_simplified(line[m.end():].strip().lstrip("：:,，").strip())
            continue
        if judgement is not None:
            continue
        if line.startswith("彖") or line.startswith("象") or line.startswith("文言"):
            continue
        # 卦辞：行形如「乾：元亨。」（冒号即剥名）或「同人于野，亨。」（无冒号则整行即卦辞）
        m_colon = re.match(r"^" + re.escape(name) + r"[：:]", line)
        if m_colon:
            judgement = to_simplified(line[m_colon.end():].strip().rstrip("。；；"))
            continue
        m_plain = re.match(r"^" + re.escape(name) + r"(?=[\u4e00-\u9fff])", line)
        if m_plain and len(line) > len(name):
            judgement = to_simplified(line.strip().rstrip("。；；"))
            continue
        # 兜底：含元亨/利貞且以卦名或「易經：」开头
        probe2 = re.sub(r"^易經?[：:]", "", line).strip()
        if probe2 and ("元亨" in probe2 or "利貞" in probe2):
            probe2 = re.sub(r"^" + re.escape(name) + r"[：:]", "", probe2).strip()
            if probe2:
                judgement = to_simplified(probe2.rstrip("。；；"))

    if not judgement:
        return None

    # 六爻按位置归位：ORDER 每两个对应一个爻位（初九|初六，…，上九|上六）
    lineTexts: list[str] = []
    for pair_start in range(0, len(ORDER), 2):
        content1 = to_simplified(line_dict.get(ORDER[pair_start], ""))
        content2 = to_simplified(line_dict.get(ORDER[pair_start + 1], ""))
        lineTexts.append(content1 or content2)
    if not any(lineTexts):
        return None

    extra = to_simplified(line_dict.get("用九") or line_dict.get("用六") or "")
    return {"name": name, "judgementText": judgement,
            "lineTexts": lineTexts, "extraLine": extra or None}


def main():
    out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hexagram_content.json")
    out = []
    if os.path.exists(out_path):
        out = json.load(open(out_path, encoding="utf-8"))
        assert len(out) == 64, f"已有文件卦数 {len(out)} != 64，先重置"
    ok = sum(1 for r in out if r.get("ok"))
    for i, (name, slug) in enumerate(zip(NAMES, SLUGS), start=1):
        record = out[i - 1]
        if record.get("ok"):
            continue
        page = "周易/{}".format(slug)
        text = fetch_wikitext(page)
        if text is None:
            print(f"[ERROR] 抓取失败 {page}", file=sys.stderr)
            continue
        parsed = parse_hexagram(text, slug)
        if parsed is None:
            print(f"[ERROR] 解析失败 {page}", file=sys.stderr)
            continue
        parsed["number"] = i
        parsed["name"] = to_simplified(name)
        parsed["ok"] = True
        out[i - 1] = parsed
        ok += 1
        print(f"[OK] {i:02d} {to_simplified(name)} ({ok}/64)", file=sys.stderr, flush=True)
        with open(out_path, "w", encoding="utf-8") as f:  # 每成功一个就落盘
            json.dump(out, f, ensure_ascii=False, indent=2)
        time.sleep(2.0)  # 友好限速

    print(f"\n成功 {ok}/64，输出 {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()