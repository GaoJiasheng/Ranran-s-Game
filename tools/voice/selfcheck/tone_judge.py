# usage: tone_judge.py <tone_pred.json> <poly.json> <expected.json>  — 按"字 + 前后各一个字"归组，看声调分类器更信哪个读音
import json, sys, collections, math
pred = json.load(open(sys.argv[1])); poly = json.load(open(sys.argv[2])); exp = json.load(open(sys.argv[3]))
SKIP = set("的了着一个子啦吧呢头儿呀")
def surf(r, nxt): return "2" if r[-1] == "3" and nxt.endswith("3") else r[-1]
groups = collections.defaultdict(list)
for x in pred:
    ch = x["ch"]
    if ch in SKIP: continue
    alts = [r for r in poly[ch] if r[:-1] == x["py"][:-1] and r != x["py"] and r[-1] != "5"]
    if not alts or x["py"][-1] == "5": continue
    h = exp[x["name"]]["han"]; i = x["i"]
    pe = x["p"].get(surf(x["py"], x["next"]), 0)
    for a in alts:
        pa = x["p"].get(surf(a, x["next"]), 0)
        if surf(a, x["next"]) == surf(x["py"], x["next"]): continue
        groups[(ch, x["py"], a, "".join(h[max(0, i - 1):i + 2]))].append((pa / (pa + pe + 1e-9), x["name"], i))
rows = []
for (ch, py, a, tri), v in groups.items():
    m = sum(p for p, _, _ in v) / len(v)
    rows.append((m, len(v), ch, py, a, tri, v[0][1], v[0][2]))
print(len(rows), "组；分类器更信另一个读音（平均 > 0.7）的：")
out = []
for m, n, ch, py, a, tri, name, i in sorted(rows, key=lambda r: (r[2], -r[0])):
    if m > 0.7:
        h = exp[name]["han"]
        print(f"{ch} 参考 {py} → 更像 {a}  {m:.2f} ×{n}  {''.join(h[max(0,i-5):i])}【{ch}】{''.join(h[i+1:i+6])}")
        out.append([name, i, py, a, m, n])
json.dump(out, open(sys.argv[1].replace("_pred.json", "_flag.json"), "w"), ensure_ascii=False)
