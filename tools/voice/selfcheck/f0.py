# usage: f0.py <wav dir> <out dir>  — 每个 wav 提一条音高曲线（10 毫秒一帧，没声音的帧是 nan）
# 自相关法，只用 numpy：这套配音是干净的合成声音，用不着更复杂的算法（librosa 的 pyin 在这个环境里会崩）。
import sys, os, glob, numpy as np, soundfile as sf
from multiprocessing import Pool
src, out = sys.argv[1:3]; os.makedirs(out, exist_ok=True)
SR, HOP, WIN, FMIN, FMAX = 16000, 160, 640, 90, 560
def track(y):
    n = 1 + max(0, (len(y) - WIN)) // HOP
    idx = np.arange(WIN)[None, :] + HOP * np.arange(n)[:, None]
    fr = y[idx] * np.hanning(WIN)
    fr = fr - fr.mean(1, keepdims=True)
    spec = np.fft.rfft(fr, 2 * WIN)
    ac = np.fft.irfft(np.abs(spec) ** 2)[:, :WIN]
    wac = np.fft.irfft(np.abs(np.fft.rfft(np.hanning(WIN), 2 * WIN)) ** 2)[:WIN]
    ac = ac / (ac[:, :1] + 1e-9) / (wac / wac[0])[None, :]          # 归一化，去掉窗的影响
    lo, hi = SR // FMAX, SR // FMIN
    seg = ac[:, lo:hi]
    k = seg.argmax(1); peak = seg[np.arange(n), k]
    # 倍频修正：更短的周期要是也差不多一样高，取短的（免得认成低八度）
    for i in range(n):
        for div in (2, 3):
            kk = (k[i] + lo) // div - lo
            if kk > 2 and seg[i, max(0, kk - 2):kk + 3].max() > 0.85 * peak[i]:
                k[i] = max(0, kk - 2) + seg[i, max(0, kk - 2):kk + 3].argmax(); peak[i] = seg[i, k[i]]; break
    lag = (k + lo).astype(float)
    # 抛物线插值
    a, b, c = seg[np.arange(n), np.clip(k - 1, 0, hi - lo - 1)], peak, seg[np.arange(n), np.clip(k + 1, 0, hi - lo - 1)]
    lag += 0.5 * (a - c) / (a - 2 * b + c + 1e-9)
    f0 = SR / lag
    energy = np.sqrt((fr ** 2).mean(1))
    voiced = (peak > 0.5) & (energy > 0.02 * energy.max())
    f0[~voiced] = np.nan
    # 孤立的一两帧跳变（八度错误）抹掉
    lf = np.log2(f0)
    for i in range(1, n - 1):
        nb = [lf[j] for j in (i - 2, i - 1, i + 1, i + 2) if 0 <= j < n and not np.isnan(lf[j])]
        if nb and not np.isnan(lf[i]) and abs(lf[i] - np.median(nb)) > 0.45: f0[i] = np.nan
    pad = np.full(WIN // HOP // 2, np.nan)      # 让第 i 帧对着 i×10 毫秒
    return np.concatenate([pad, f0]).astype(np.float32)
def work(p):
    o = os.path.join(out, os.path.basename(p).replace(".wav", ".npy"))
    y, sr = sf.read(p, dtype="float32")
    assert sr == SR
    np.save(o, track(y)); return 1
if __name__ == "__main__":
    fs = sorted(glob.glob(os.path.join(src, "*.wav")))
    with Pool(8) as pool:
        for i, _ in enumerate(pool.imap_unordered(work, fs, chunksize=16)): pass
    print("DONE", len(fs))
