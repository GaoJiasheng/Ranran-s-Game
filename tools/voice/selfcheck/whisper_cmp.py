# usage: whisper_cmp.py <manifest.json> <whisper.json>  — 中文：把识别出来的字和要读的字按不带调的拼音比
import json, re, sys
from pypinyin import lazy_pinyin
items = json.load(open(sys.argv[1])); w = json.load(open(sys.argv[2]))
D = "零一二三四五六七八九"
def num(m):
    n = int(m.group(0))
    if n < 10: return D[n]
    if n < 100:
        t, o = divmod(n, 10)
        return ("" if t == 1 else D[t]) + "十" + (D[o] if o else "")
    if n < 1000:
        h, r = divmod(n, 100)
        return D[h] + "百" + ("" if r == 0 else ("零" + D[r] if r < 10 else num(re.match(r"\d+", str(r))).replace("十", "一十", 1) if r < 20 else num(re.match(r"\d+", str(r)))))
    return "".join(D[int(c)] for c in m.group(0))
LOOSE = {"la": "le", "lou": "le", "ma": "ma", "ne": "ne", "ya": "a", "na": "a", "wa": "a", "nei": "na", "zhei": "zhe", "shei": "shui"}
def norm(t):
    t = re.sub(r"\d+", num, t)
    t = re.sub(r"[^一-鿿A-Za-z]", "", t)
    return [LOOSE.get(x, x).lower() for x in lazy_pinyin(t)]
def ed(a, b):
    d = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        p = d[0]; d[0] = i
        for j, y in enumerate(b, 1):
            c = d[j]; d[j] = min(d[j] + 1, d[j - 1] + 1, p + (x != y)); p = c
    return d[-1]
bad = []
for it in items:
    if it["file"] not in w: continue
    a = norm(it["speak"]); b = norm(w[it["file"]])
    e = ed(a, b)
    if e: bad.append((e, len(a), it["file"], it["text"], it["speak"], w[it["file"]]))
bad.sort(key=lambda x: (-x[0] / max(1, x[1]), x[2]))
print(len(w), "transcribed;", len(bad), "lines differ")
json.dump(bad, open(sys.argv[2].replace(".json", "_diff.json"), "w"), ensure_ascii=False, indent=0)
for e, n, f, t, s, g in bad: print(f"{e:2d}/{n:<3d} {f} | {s}\n{'':22s}{g}")
