# usage: tone.py <mfa dir> <f0 dir> <poly.json> <out.json>
# 声调分类器：用这套配音里"只有一种读音的字"的音高曲线当训练数据，再去判多音字实际读的是第几声。
import json, sys, os, glob, re, numpy as np, collections, warnings
warnings.filterwarnings("ignore")
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.model_selection import GroupKFold, cross_val_predict
d, f0dir, polyf, outf = sys.argv[1:5]
exp = json.load(open(os.path.join(d, "expected.json"))); poly = json.load(open(polyf))
NEUTRAL = set("的了着子们吗呢吧啊么个呀啦嘛哦")
def contour(f, a, b, n=6):
    seg = f[a:b]; ok = ~np.isnan(seg)
    if ok.sum() < 4: return None
    x = np.where(ok)[0]; y = seg[ok]
    return np.interp(np.linspace(x[0], x[-1], n), x, y), ok.mean(), x[0] / max(1, b - a)
rows = []
for name, e in exp.items():
    fs = glob.glob(os.path.join(d, "out", "**", name + ".json"), recursive=True)
    if not fs: continue
    words = [w for w in json.load(open(fs[0]))["tiers"]["words"]["entries"] if re.fullmatch(r"[一-鿿]", w[2])]
    if len(words) != len(e["han"]): continue
    f = np.load(os.path.join(f0dir, name + ".npy")); lf = 12 * np.log2(f)
    med = np.nanmedian(lf); lf = lf - med
    cs = []
    for w in words:
        a, b = int(round(w[0] * 100)), int(round(w[1] * 100))
        cs.append(contour(lf, a, min(b, len(lf))))
    total = words[-1][1]
    for i, (w, ch, py) in enumerate(zip(words, e["han"], e["py"])):
        c = cs[i]
        if c is None: continue
        prev = cs[i - 1][0][-1] if i > 0 and cs[i - 1] is not None and words[i][0] - words[i - 1][1] < 0.08 else np.nan
        nxt = cs[i + 1][0][0] if i + 1 < len(cs) and cs[i + 1] is not None and words[i + 1][0] - words[i][1] < 0.08 else np.nan
        k = c[0]
        feat = list(k) + [k[-1] - k[0], k.max() - k.min(), k.mean(), int(np.argmin(k)), int(np.argmax(k)), c[1], c[2], w[1] - w[0], w[0] / total, prev, nxt,
                          (k[0] - prev) if not np.isnan(prev) else np.nan, (nxt - k[-1]) if not np.isnan(nxt) else np.nan]
        nxt_py = e["py"][i + 1] if i + 1 < len(e["py"]) else ""
        rows.append({"name": name, "i": i, "ch": ch, "py": py, "next": nxt_py, "feat": feat})
X = np.array([r["feat"] for r in rows], dtype=float)
def surface(r):
    t = r["py"][-1]
    if t == "3" and r["next"].endswith("3"): return "2"     # 上声连读变调
    return t
train = [k for k, r in enumerate(rows) if r["ch"] not in poly and r["ch"] not in NEUTRAL and r["ch"] not in "一不" and r["py"][-1] in "1234"]
y = np.array([surface(rows[k]) for k in train]); g = np.array([rows[k]["name"] for k in train])
clf = HistGradientBoostingClassifier(max_iter=300, learning_rate=0.08)
pred = cross_val_predict(clf, X[train], y, groups=g, cv=GroupKFold(5), method="predict_proba")
classes = sorted(set(y)); hard = np.array(classes)[pred.argmax(1)]
print("训练用的字", len(train), "五折交叉验证的正确率 %.1f%%" % (100 * (hard == y).mean()))
conf = collections.Counter(zip(y, hard))
print("真实\\判成  " + "  ".join(classes))
for a in classes: print("   ", a, "   ", "  ".join(f"{conf[(a, b)]:5d}" for b in classes))
# 两两之间分得开吗（只在两种声调里二选一）
for a in classes:
    for b in classes:
        if a < b:
            m = (y == a) | (y == b); ia, ib = classes.index(a), classes.index(b)
            pick = np.where(pred[m, ia] > pred[m, ib], a, b)
            print(f"  {a} 对 {b} 二选一：{100 * (pick == y[m]).mean():.1f}%", end="")
print()
clf.fit(X[train], y)
P = clf.predict_proba(X)
out = []
for k, r in enumerate(rows):
    if r["ch"] in poly: out.append({"name": r["name"], "i": r["i"], "ch": r["ch"], "py": r["py"], "next": r["next"], "p": {c: round(float(p), 4) for c, p in zip(clf.classes_, P[k])}})
json.dump(out, open(outf, "w"), ensure_ascii=False)
print("多音字实例", len(out))
