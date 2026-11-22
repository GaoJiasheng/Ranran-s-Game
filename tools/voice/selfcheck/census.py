# usage: census.py <expected.json> <poly.json> <out census.json> <out groups.json>
# 多音字普查的清单：每个多音字按"前一个字 + 它 + 后一个字"归组，每组挑一句，
# 对它的每个别的读音各出一条 [句子, 第几个字, 按上下文该读的音, 另一个读音]。
import json, sys
exp = json.load(open(sys.argv[1])); poly = json.load(open(sys.argv[2]))
SKIP = set("的了着一个子啦吧呢头儿呀")      # 轻声 / 变调的虚词：靠对齐器和 Whisper 查，不在这里
seen = {}; S = []
for n, e in sorted(exp.items()):
    h = e["han"]
    for i, c in enumerate(h):
        if c not in poly or c in SKIP: continue
        k = c + "|" + "".join(h[max(0, i - 1):i + 2])
        if k in seen: seen[k].append([n, i]); continue
        seen[k] = [[n, i]]
        for a in poly[c]:
            if a != e["py"][i] and not a.endswith("5"): S.append([n, i, e["py"][i], a])
json.dump(S, open(sys.argv[3], "w")); json.dump(seen, open(sys.argv[4], "w"), ensure_ascii=False)
print(len(seen), "groups,", len(S), "alternate readings to test")
