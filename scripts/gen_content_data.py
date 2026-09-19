#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""用南怀瑾《白话易经》译文 + 维基文库原文生成 HexagramContentData.swift。"""
import json

DIV_PATH = "/tmp/divination.json"

def esc(s: str) -> str:
    s = s.replace('\\', '\\\\')
    s = s.replace('\n', '\\n')
    s = s.replace('"', '\\"')
    return s

def main():
    content = json.load(open('/Users/liuzixiang/Projects/yijing64/scripts/hexagram_content.json'))
    content.sort(key=lambda r: r['number'])
    div = json.load(open(DIV_PATH))

    recs = []
    for r in content:
        j = esc(r['judgementText'].strip())
        lits = ['"' + esc(x.strip()) + '"' for x in r['lineTexts']]
        d = div[str(r['number'])].strip()
        if not d:
            d = "[白话译文待补充]"
        extra = esc(r.get('extraLine') or '').strip()
        extra_lit = '"' + extra + '"' if extra else 'nil'
        recs.append(
            f'        HexagramContent(judgementText: "{j}", lineTexts: [{", ".join(lits)}], '
            f'divinationText: "{esc(d)}", extraLine: {extra_lit}),'
        )
    body = "\n".join(recs)
    out = (
        "import Foundation\n\n"
        "/// 六十四卦《周易》经文与白话译文静态数据。\n"
        "/// 经文部分为公有领域（中文维基文库，转简体并核对）；\n"
        "/// 白话译文整理自南怀瑾著《白话易经》（周易今注今译），以\"【白话】\"列示。\n"
        "/// 与 HexagramData 按文王卦序 1-64 对齐。\n"
        "enum HexagramContentData {\n"
        "    static let items: [HexagramContent] = [\n"
        + body + "\n"
        "    ]\n"
        "}\n"
    )
    open('/Users/liuzixiang/Projects/yijing64/YijingCore/Sources/YijingCore/Models/HexagramContentData.swift', 'w').write(out)
    print('records:', out.count('HexagramContent('))

if __name__ == '__main__':
    main()