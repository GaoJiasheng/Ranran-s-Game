# usage: judge3.py <cases.json> <result.json>  — 三方对照：原录音更像"读音甲"那一版还是"读音乙"那一版
import json, sys, math
cases = {c["id"]: c for c in json.load(open(sys.argv[1]))}; res = json.load(open(sys.argv[2]))
def sc(v): return None if not v else v[0] + 0.5 * (0 if math.isnan(v[1]) else min(v[1], 6))
out = []
for r in res:
    c = cases[r["id"]]; o, e, a = sc(r.get("orig")), sc(r.get("E")), sc(r.get("A"))
    if e is not None and a is not None:
        v = c["expected"] if e < a - 0.35 else c["alt"] if a < e - 0.35 else "?"
    elif a is not None:      # 参考读音是轻声，没有同音字：只看像不像另一个读音（和重新合成原句的那一版比）
        v = c["alt"] if a < (o or 1.2) + 0.45 else c["expected"]
    elif e is not None:
        v = c["expected"] if e < (o or 1.2) + 0.45 else c["alt"]
    else: v = "?"
    out.append({"file": c["file"], "i": c["i"], "ch": c["ch"], "ctx": c["ctx"], "ref": c["expected"], "alt": c["alt"], "actual": v, "o": o, "e": e, "a": a})
json.dump(out, open(sys.argv[2].replace("_result.json", "_verdict.json"), "w"), ensure_ascii=False, indent=0)
f = lambda x: "  - " if x is None else f"{x:4.1f}"
for x in sorted(out, key=lambda x: (x["ch"], x["actual"], x["ctx"])):
    mark = "≠" if x["actual"] != x["ref"] else " "
    print(f"{mark}{x['ch']} 实际 {x['actual']:7s}(参考 {x['ref']} / 另 {x['alt']}) {f(x['o'])}{f(x['e'])}{f(x['a'])} {x['ctx']}")
