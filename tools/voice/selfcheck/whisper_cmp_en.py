# usage: whisper_cmp_en.py <manifest_en.json> <whisper_en.json>  — 英文：把数字、符号都换成词再比
import json, re, sys
items = json.load(open(sys.argv[1])); w = json.load(open(sys.argv[2]))
ONES = "zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen".split()
TENS = "x x twenty thirty forty fifty sixty seventy eighty ninety".split()
def words(n):
    if n < 20: return ONES[n]
    if n < 100: return TENS[n // 10] + ("" if n % 10 == 0 else " " + ONES[n % 10])
    if n < 1000: return ONES[n // 100] + " hundred" + ("" if n % 100 == 0 else " " + words(n % 100))
    return " ".join(ONES[int(c)] for c in str(n))
SYM = {"+": " plus ", "−": " minus ", "×": " times ", "÷": " divided by ", "=": " equals ", "&": " and ", "%": " percent "}
SAME = {"ok": "okay", "ranran": "ranran", "alright": "all right", "centre": "center", "colour": "color", "metres": "meters", "metre": "meter", "litres": "liters", "litre": "liter", "favourite": "favorite", "grey": "gray"}
def norm(t):
    t = t.lower()
    for k, v in SYM.items(): t = t.replace(k, v)
    t = re.sub(r"\$(\d+)", r"\1 dollars", t)
    t = re.sub(r"\d+", lambda m: " " + words(int(m.group(0))) + " ", t)
    t = t.replace("-", " ").replace("’", "'")
    t = re.sub(r"[^a-z' ]", " ", t)
    ws = [SAME.get(x, x) for x in t.split()]
    return " ".join(ws).replace("all right", "alright").split()
def ed(a, b):
    d = list(range(len(b) + 1))
    for i, x in enumerate(a, 1):
        p = d[0]; d[0] = i
        for j, y in enumerate(b, 1):
            c = d[j]; d[j] = min(d[j] + 1, d[j - 1] + 1, p + (x != y)); p = c
    return d[-1]
import difflib, collections
bad = []; subs = collections.Counter()
for it in items:
    if it["file"] not in w: continue
    a = norm(it.get("speak", it["text"])); b = norm(w[it["file"]])
    if a == b: continue
    sm = difflib.SequenceMatcher(None, a, b); parts = []
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op != "equal":
            parts.append(f"[{' '.join(a[i1:i2])}→{' '.join(b[j1:j2])}]"); subs[(' '.join(a[i1:i2]), ' '.join(b[j1:j2]))] += 1
    bad.append((it["file"], it.get("speak", it["text"]), w[it["file"]], parts))
print(len(w), "transcribed;", len(bad), "lines differ;", len(subs), "kinds of difference")
for (x, y), n in subs.most_common(): print(f"{n:4d}  [{x}] → [{y}]")
json.dump(bad, open(sys.argv[2].replace(".json", "_diff.json"), "w"), ensure_ascii=False, indent=0)
