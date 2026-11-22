# 多音字清单：一个字有哪几种"常用"读音（按 pypinyin 词库里各读音出现的次数算，去掉生僻的）
import json, collections, sys
from pypinyin.phrases_dict import phrases_dict
from pypinyin.pinyin_dict import pinyin_dict
from pypinyin.contrib.tone_convert import to_tone3
def t3(x): return to_tone3(x, neutral_tone_with_five=True, v_to_u=False)
cnt = collections.defaultdict(collections.Counter)
for ph, py in phrases_dict.items():
    if len(ph) != len(py): continue
    for ch, p in zip(ph, py): cnt[ch][t3(p[0])] += 1
def common(ch):
    c = cnt.get(ch)
    first = [t3(x) for x in pinyin_dict.get(ord(ch), "").split(",") if x][:1]
    if not c: return first
    tot = sum(c.values())
    rs = [r for r, n in c.most_common() if n >= 3 and n / tot >= 0.04]
    for f in first:
        if f not in rs: rs.append(f)
    return rs
if __name__ == "__main__":
    exp = json.load(open(sys.argv[1]))
    occ = collections.Counter()
    for e in exp.values():
        for ch in e["han"]: occ[ch] += 1
    poly = {ch: common(ch) for ch in occ if len(common(ch)) > 1}
    json.dump(poly, open(sys.argv[2], "w"), ensure_ascii=False)
    seg = {c: r for c, r in poly.items() if len({x[:-1] for x in r}) > 1}
    tone = {c: r for c, r in poly.items() if c not in seg}
    print("多音字", len(poly), "出现", sum(occ[c] for c in poly), "| 声母韵母不同", len(seg), "出现", sum(occ[c] for c in seg), "| 只差声调", len(tone), "出现", sum(occ[c] for c in tone))
    print(" ".join(f"{c}{occ[c]}:{'/'.join(r)}" for c, r in sorted(seg.items(), key=lambda x: -occ[x[0]])))
    print(" ".join(f"{c}{occ[c]}:{'/'.join(r)}" for c, r in sorted(tone.items(), key=lambda x: -occ[x[0]])))
