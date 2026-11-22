# usage: abcmp.py <cases.json> <audio dir> <orig wav dir>
# 每个 case：{id, file, i(第几个汉字), t0, t1(这个字在原录音里的时间), variants: {label: 合成的 id}}
# 把原录音和每个变体对齐（DTW），只比这个字前后那一小段像不像（声音的形状 + 音高）。
import json, sys, os, numpy as np, warnings
warnings.filterwarnings("ignore")
import librosa
cases = json.load(open(sys.argv[1])); adir, odir = sys.argv[2:4]
F0O, F0V = sys.argv[4:6]
def feat(path):
    y, sr = librosa.load(path, sr=16000)
    m = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13, n_fft=400, hop_length=160)[1:]
    m = (m - m.mean(1, keepdims=True)) / (m.std(1, keepdims=True) + 1e-6)
    # 音高由 f0.py 另外提好（pyin 和 mfcc 放在同一个进程里会崩）
    f0 = np.load(os.path.join(F0O if os.path.dirname(path) == odir else F0V, os.path.basename(path).replace(".wav", ".npy")))
    lf = np.log2(f0); med = np.nanmedian(lf)
    return m, (lf - med) * 12          # 半音，相对这句话的中间音高
def dtw(a, b):
    # 自己写的 DTW（librosa 自带的那个在这个环境里会崩）
    from scipy.spatial.distance import cdist
    C = cdist(a.T, b.T); n, m = C.shape
    D = np.full((n + 1, m + 1), np.inf); D[0, 0] = 0
    for i in range(1, n + 1):
        row = D[i - 1]; cur = D[i]; ci = C[i - 1]
        for j in range(1, m + 1):
            cur[j] = ci[j - 1] + min(row[j], row[j - 1], cur[j - 1])
    i, j = n, m; path = []
    while i > 0 and j > 0:
        path.append((i - 1, j - 1))
        k = int(np.argmin((D[i - 1, j - 1], D[i - 1, j], D[i, j - 1])))
        if k == 0: i, j = i - 1, j - 1
        elif k == 1: i -= 1
        else: j -= 1
    return path[::-1]
cache = {}
def get(p):
    if p not in cache: cache[p] = feat(p)
    return cache[p]
def dist(o, v, t0, t1):
    (mo, fo), (mv, fv) = o, v
    wp = dtw(mo, mv)
    a, b = int(max(0, t0 - 0.03) * 100), int((t1 + 0.03) * 100)
    pairs = [(i, j) for i, j in wp if a <= i <= b]
    if not pairs: return None
    dm = np.mean([np.linalg.norm(mo[:, i] - mv[:, j]) for i, j in pairs])
    df = [abs(fo[i] - fv[j]) for i, j in pairs if i < len(fo) and j < len(fv) and not np.isnan(fo[i]) and not np.isnan(fv[j])]
    return float(dm), (float(np.mean(df)) if df else float("nan"))
def run(c):
    try:
        o = get(os.path.join(odir, c["file"] + ".wav"))
        r = {"id": c["id"]}
        for lab, vid in c["variants"].items():
            p = os.path.join(adir, vid + ".wav")
            r[lab] = dist(o, get(p), c["t0"], c["t1"]) if os.path.exists(p) else None
        return r
    except Exception as e:
        return {"id": c["id"], "error": str(e)}
if __name__ == "__main__":
    from multiprocessing import Pool
    with Pool(8) as pool: res = pool.map(run, cases, chunksize=4)
    json.dump(res, open(sys.argv[1].replace(".json", "_result.json"), "w"), ensure_ascii=False, indent=0)
    if len(res) <= 80:
        for r in res: print(r["id"], " ".join(f"{k}={v[0]:.2f}/{v[1]:.2f}" if v else f"{k}=?" for k, v in r.items() if k != "id"))
    print("compared", len(res), "errors", sum(1 for r in res if "error" in r))
