# usage: mkcases.py <mfa dir> <suspects.json [[file, i, expected, alt], ...]> <out prefix>
import json, sys, os, re, glob, collections
from pypinyin.pinyin_dict import pinyin_dict
from pypinyin.contrib.tone_convert import to_tone3
sys.path.insert(0, os.path.dirname(__file__))
from poly import cnt, common
d, sus, pref = sys.argv[1:4]
exp = json.load(open(os.path.join(d, "expected.json")))
def t3(x): return to_tone3(x, neutral_tone_with_five=True, v_to_u=False)
byr = collections.defaultdict(list)
for cp, r in pinyin_dict.items():
    ch = chr(cp)
    if not ("一" <= ch <= "鿿"): continue
    rs = [t3(x) for x in r.split(",")]
    cm = common(ch)
    # 常用读音只有一种的字才拿来当同音字（词库里出现得越多越靠前，生僻字 TTS 可能不认识）
    if len(cm) == 1 and cm[0] == rs[0]: byr[rs[0]].append((sum(cnt[ch].values()), ch))
def homophone(r, avoid):
    c = sorted(byr.get(r, []), reverse=True)
    c = [ch for n, ch in c if ch not in avoid]
    return c[0] if c else None
def timing(name, i):
    f = glob.glob(os.path.join(d, "out", "**", name + ".json"), recursive=True)[0]
    w = [x for x in json.load(open(f))["tiers"]["words"]["entries"] if re.fullmatch(r"[一-鿿]", x[2])]
    return w[i][0], w[i][1]
jobs = {}; cases = []
for name, i, e, a in json.load(open(sus)):
    sp = exp[name]["speak"]
    pos = [m.start() for m in re.finditer(r"[一-鿿]", sp)][i]
    ch = sp[pos]
    def rep(r):
        h = homophone(r, {ch})
        return (sp[:pos] + h + sp[pos + 1:], h) if h else (None, None)
    t0, t1 = timing(name, i)
    cid = f"{name}_{i}_{a}"
    only_a = os.environ.get("ONLY_A") == "1"      # 普查：只合成"读成另一个音"的那一版
    var = {} if only_a else {"orig": f"{name}_o"}
    if not only_a: jobs[f"{name}_o"] = sp
    info = {}
    for lab, r in ((("A", a),) if only_a else (("E", e), ("A", a))):
        if r.endswith("5"): continue
        txt, h = rep(r)
        if txt: var[lab] = f"{name}_{i}_{r}"; jobs[var[lab]] = txt; info[lab] = h
    cases.append({"id": cid, "file": name, "i": i, "ch": ch, "expected": e, "alt": a, "t0": t0, "t1": t1, "variants": var, "homophones": info,
                  "ctx": sp[max(0, pos - 6):pos] + "【" + ch + "】" + sp[pos + 1:pos + 7]})
json.dump([{"id": k, "text": v} for k, v in jobs.items()], open(pref + "_jobs.json", "w"), ensure_ascii=False, indent=0)
json.dump(cases, open(pref + "_cases.json", "w"), ensure_ascii=False, indent=0)
print(len(cases), "cases,", len(jobs), "synth jobs,", sum(1 for c in cases if "A" not in c["variants"]), "without a homophone for the alt reading")
