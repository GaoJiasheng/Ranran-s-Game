# 给强制对齐做一本"一个字一个词、每种读音一条"的词典，并把每句话写成一个字一个字的文本。
# usage: build_dict.py <manifest.json> <mandarin_china_mfa.dict> <out dir>
import json, sys, re, os, collections
from pypinyin import lazy_pinyin, Style
from pypinyin.pinyin_dict import pinyin_dict
from pypinyin.contrib.tone_convert import to_tone3
man, mfadict, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
TONES = ["˥˩", "˨˩˦", "˧˥", "˥"]          # 4, 3, 2, 1（长的先匹配）
TNUM = {"˥˩": "4", "˨˩˦": "3", "˧˥": "2", "˥": "1"}
def tone_of(phones):
    for p in phones.split():
        for t in TONES:
            if t in p: return TNUM[t]
    return "5"
def strip(phones):
    s = phones
    for t in TONES: s = s.replace(t, "")
    return s
def retone(phones, t):
    mark = {v: k for k, v in TNUM.items()}[t]
    outp = []
    for p in phones.split():
        q = p
        for x in TONES:
            if x in q: q = q.replace(x, mark); break
        outp.append(q)
    return " ".join(outp)
def readings(ch):
    r = pinyin_dict.get(ord(ch))
    if not r: return []
    return [to_tone3(x, neutral_tone_with_five=True, v_to_u=False) for x in r.split(",")]
# MFA 词典里单字的读法
prons = collections.defaultdict(list)   # char -> [(prob, phones)]
for line in open(mfadict, encoding="utf8"):
    f = line.rstrip("\n").split("\t")
    if len(f[0]) != 1 or not ("一" <= f[0] <= "鿿"): continue
    try: prob = float(f[1]); ph = f[-1]
    except ValueError: prob = 1.0; ph = f[-1]
    prons[f[0]].append((prob, ph))
# 只有一种读音的字投票：拼音音节 -> 音素
vote = collections.defaultdict(collections.Counter)
for ch, ps in prons.items():
    rs = readings(ch)
    if len(rs) != 1: continue
    best = max(ps)[1]
    if tone_of(best) == rs[0][-1]: vote[rs[0]][best] += 1
syl = {k: c.most_common(1)[0][0] for k, c in vote.items()}
# 第二轮：有些音节只出现在多音字上（能、打、给、大）。拿这些字在 MFA 词典里声调对得上、
# 又不是它别的读音的那条读法来投票。
vote2 = collections.defaultdict(collections.Counter)
for ch, ps in prons.items():
    rs = readings(ch)
    if len(rs) < 2: continue
    other = {syl[r] for r in rs if r in syl}
    for r in rs:
        if r in syl or r[-1] == "5": continue
        cands = [(prob, ph) for prob, ph in ps if tone_of(ph) == r[-1] and ph not in other]
        same_tone = [x for x in rs if x[-1] == r[-1] and x not in syl]
        if cands and len(same_tone) == 1: vote2[r][max(cands)[1]] += max(cands)[0]
for k, c in vote2.items(): syl[k] = c.most_common(1)[0][0]
# 两轮都没学到的（这个字有两种同声调的生僻读音），照 MFA 词典里的常用读法手写
syl.setdefault("neng2", "n o˧˥ ŋ"); syl.setdefault("shei2", "ʂ ej˧˥"); syl.setdefault("fou3", "f ow˨˩˦")
base = collections.defaultdict(collections.Counter)   # 不带调的音节 -> 不带调的音素
for k, v in syl.items(): base[k[:-1]][strip(v)] += 1
def phones_for(r):
    if r in syl: return syl[r]
    b = base.get(r[:-1])
    if not b or r[-1] == "5": return None
    # 这个声调没见过：拿别的声调的音素换调
    for t in "1234":
        if r[:-1] + t in syl: return retone(syl[r[:-1] + t], r[-1])
    return None
items = json.load(open(man))
chars = set()
for it in items: chars |= set(re.findall(r"[一-鿿]", it["speak"]))
lex = collections.defaultdict(dict)      # char -> phones -> set(labels)
missing = collections.Counter()
for ch in sorted(chars):
    rs = readings(ch)
    for r in rs:
        if r[-1] == "5":
            # 轻声：用 MFA 词典里这个字不带调的读法
            for prob, ph in prons.get(ch, []):
                if tone_of(ph) == "5": lex[ch].setdefault(ph, set()).add(r)
            continue
        ph = phones_for(r)
        if not ph: missing[r] += 1; continue
        lex[ch].setdefault(ph, set()).add(r)
        if r[-1] == "3": lex[ch].setdefault(retone(ph, "2"), set()).add(r + "~sandhi")
    # 一、不 的变调
    if ch == "一":
        for t in "24": lex[ch].setdefault(retone(phones_for("yi1"), t), set()).add("yi1~sandhi")
    if ch == "不": lex[ch].setdefault(retone(phones_for("bu4"), "2"), set()).add("bu4~sandhi")
    # 念轻了（石头的头、时候的候）：MFA 词典里这个字不带调的读法，都算"轻读"
    for prob, ph in prons.get(ch, []):
        if tone_of(ph) == "5": lex[ch].setdefault(ph, set()).add("~light")
    if not lex[ch]: missing["CHAR " + ch] += 1
with open(os.path.join(out, "chars.dict"), "w", encoding="utf8") as f:
    for ch in sorted(lex):
        for ph in lex[ch]: f.write(f"{ch}\t{ph}\n")
json.dump({ch: {ph: sorted(l) for ph, l in d.items()} for ch, d in lex.items()}, open(os.path.join(out, "lex.json"), "w"), ensure_ascii=False)
corp = os.path.join(out, "corpus", "xiaoxiao"); os.makedirs(corp, exist_ok=True)
exp = {}
odd = []
for it in items:
    name = it["file"].replace(".mp3", "")
    sp = it["speak"]
    han = re.findall(r"[一-鿿]", sp)
    if re.search(r"[0-9A-Za-z]", sp): odd.append(sp)
    toks = re.findall("[\u4e00-\u9fff]|[0-9A-Za-z]+", sp)   # 字母数字留着当词典外的词，占住那段声音
    open(os.path.join(corp, name + ".lab"), "w", encoding="utf8").write(" ".join(toks))
    py = lazy_pinyin("".join(han), style=Style.TONE3, neutral_tone_with_five=True)
    exp[name] = {"text": it["text"], "speak": sp, "han": han, "py": py}
json.dump(exp, open(os.path.join(out, "expected.json"), "w"), ensure_ascii=False)
print("chars", len(chars), "syllables learned", len(syl), "missing", dict(missing))
print("lines with digits/latin:", len(odd)); print("\n".join(odd[:15]))
for ch in "能打给大答谁这否":
    print(ch, {ph: sorted(l) for ph, l in lex.get(ch, {}).items()})
