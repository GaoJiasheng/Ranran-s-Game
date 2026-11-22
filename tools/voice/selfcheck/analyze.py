# usage: analyze.py <mfa dir (lex.json, expected.json, out/)>  — 对齐器给每个字挑的读音，和按上下文该读的音比
import json, sys, os, re, glob, collections
d = sys.argv[1]
lex = json.load(open(os.path.join(d, "lex.json"))); exp = json.load(open(os.path.join(d, "expected.json")))
TONES = ["˥˩", "˨˩˦", "˧˥", "˥"]
def strip(p):
    for t in TONES: p = p.replace(t, "")
    return p
rows = []; nofile = []; badcount = []; total = 0
stats = collections.defaultdict(collections.Counter)   # (char, expected) -> chosen -> n
for name, e in exp.items():
    fs = glob.glob(os.path.join(d, "out", "**", name + ".json"), recursive=True)
    if not fs: nofile.append(name); continue
    j = json.load(open(fs[0]))
    words = [w for w in j["tiers"]["words"]["entries"] if re.fullmatch(r"[一-鿿]", w[2])]
    phones = j["tiers"]["phones"]["entries"]
    if len(words) != len(e["han"]): badcount.append((name, len(words), len(e["han"]))); continue
    for i, (w, ch, py) in enumerate(zip(words, e["han"], e["py"])):
        ph = " ".join(p[2] for p in phones if p[0] >= w[0] - 1e-6 and p[1] <= w[1] + 1e-6)
        labels = lex.get(ch, {}).get(ph)
        total += 1
        if labels is None: rows.append((name, i, ch, py, "?" + ph, "unknown")); continue
        if py in labels or py + "~sandhi" in labels: stats[(ch, py)][py] += 1; continue
        mine = [p for p, l in lex[ch].items() if py in l]
        real = [l for l in labels if not l.startswith("~")]
        if "~light" in labels and any(strip(m) == ph for m in mine): stats[(ch, py)][py] += 1; continue
        if not real: real = ["(轻读)"]
        chosen = real[0].replace("~sandhi", "")
        if py[-1] == "5" and not mine:
            kind = "light"       # 该读轻声，可是词典里这个字没有轻声读法：比不了
        elif chosen[:-1] == py[:-1]:
            kind = "light" if "5" in (py[-1], chosen[-1]) else "tone"
        else: kind = "segment"
        stats[(ch, py)][chosen] += 1
        rows.append((name, i, ch, py, chosen, kind))
print("字数", total, "对不上", len(rows), "没有对齐结果的句子", len(nofile), "字数不一致的句子", len(badcount))
json.dump({"rows": rows, "nofile": nofile, "badcount": badcount}, open(os.path.join(d, "mismatch.json"), "w"), ensure_ascii=False)
by = collections.defaultdict(list)
for r in rows: by[(r[5], r[2], r[3], r[4])].append(r)
for kind in ("segment", "tone", "light", "unknown"):
    ks = sorted([k for k in by if k[0] == kind], key=lambda k: -len(by[k]))
    print(f"\n===== {kind}: {sum(len(by[k]) for k in ks)} 处，{len(ks)} 种")
    for k in ks:
        _, ch, py, chosen = k
        n = len(by[k]); tot = sum(stats[(ch, py)].values())
        ex = by[k][0]; e = exp[ex[0]]
        s = "".join(e["han"]); i = ex[1]
        print(f"{ch} 该读 {py} 挑了 {chosen}: {n}/{tot}  例: {s[max(0,i-6):i]}【{ch}】{s[i+1:i+7]}  ({ex[0]})")
