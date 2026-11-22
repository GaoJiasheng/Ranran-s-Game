# usage: census_judge.py <census_cases.json> <census_cases_result.json> <census_groups.json>
# 每种上下文：原录音和"换成另一个读音的同音字"那一版在这个字上像不像。像 = 实际读的是另一个读音。
import json, sys, collections
cases = {c["id"]: c for c in json.load(open(sys.argv[1]))}
res = json.load(open(sys.argv[2])); groups = json.load(open(sys.argv[3]))
MF, F0 = float(sys.argv[4]) if len(sys.argv) > 4 else 1.75, float(sys.argv[5]) if len(sys.argv) > 5 else 0.6
rows = []
for r in res:
    c = cases[r["id"]]; a = r.get("A")
    if not a: continue
    rows.append((a[0], a[1], c))
import math
like = [(m, f, c) for m, f, c in rows if m < MF and (math.isnan(f) or f < F0)]
print(len(rows), "判过；听起来像另一个读音的", len(like), f"（门槛：声音形状 < {MF}，音高差 < {F0} 个半音）")
hist = collections.Counter(min(9, int(m / 0.5)) for m, f, c in rows)
print("声音形状距离分布（每 0.5 一档）:", [hist[i] for i in range(10)])
for m, f, c in sorted(like, key=lambda x: (x[2]["ch"], x[2]["alt"])):
    n = len(groups.get(c["ch"] + "|" + c["ctx"].split("【")[0][-1:] + c["ch"] + c["ctx"].split("】")[1][:1], [])) or "?"
    print(f"{c['ch']} 按上下文该读 {c['expected']}，听着像 {c['alt']}（{c['homophones'].get('A')}） {m:.2f}/{f:.2f} ×{n}  {c['ctx']}  [{c['file']}]")
json.dump([{"file": c["file"], "i": c["i"], "ch": c["ch"], "expected": c["expected"], "alt": c["alt"], "ctx": c["ctx"], "m": m, "f": f} for m, f, c in like], open(sys.argv[2].replace("_result.json", "_like.json"), "w"), ensure_ascii=False, indent=0)
