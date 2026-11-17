import math, random, struct, wave, sys
SR = 44100
out = sys.argv[1]
random.seed(7)

def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    k = 0.89 / peak
    with wave.open(f"{out}/{name}.wav", "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))

def silence(sec): return [0.0] * int(SR * sec)

def mix(a, b, offset=0):
    n = max(len(a), offset + len(b)); r = a + [0.0] * (n - len(a))
    for i, s in enumerate(b): r[offset + i] += s
    return r

def clack(base):
    """木头棋盘上落子的"嗒"声：几个快速衰减的共振 + 很短的噪声起音。"""
    n = int(SR * 0.16); s = []
    modes = [(base, 1.0, 38), (base * 2.13, 0.55, 55), (base * 3.4, 0.3, 80), (base * 0.52, 0.45, 26)]
    lp = 0.0
    for i in range(n):
        t = i / SR
        v = sum(a * math.exp(-t * d) * math.sin(2 * math.pi * f * t) for f, a, d in modes)
        noise = random.uniform(-1, 1); lp += 0.35 * (noise - lp)
        v += lp * 1.6 * math.exp(-t * 900)
        s.append(v)
    # 棋子落定的第二声轻响
    settle = [x * 0.22 for x in s[: int(SR * 0.06)]]
    return mix(s, settle, int(SR * 0.028))

def tone(freq, dur, amp=1.0, decay=6.0, harmonics=((1, 1), (2, 0.25), (4, 0.08)), attack=0.004):
    n = int(SR * dur); r = []
    for i in range(n):
        t = i / SR
        env = min(1, t / attack) * math.exp(-t * decay)
        r.append(amp * env * sum(a * math.sin(2 * math.pi * freq * h * t) for h, a in harmonics))
    return r

def glide(f0, f1, dur, amp=1.0):
    n = int(SR * dur); r = []; ph = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        ph += 2 * math.pi * f / SR
        env = math.sin(math.pi * min(1, t * 1.2)) ** 1.5
        r.append(amp * env * math.sin(ph))
    return r

write("stone_a", clack(1180))
write("stone_b", clack(1290))
write("tap", glide(900, 620, 0.07, 0.8))
write("undo", glide(720, 380, 0.12, 0.8))

C5, E5, G5, C6, E6, B6, G4, E4, C4 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1975.5, 392.0, 329.6, 261.6
win = silence(1.6)
for i, f in enumerate([C5, E5, G5, C6]):
    win = mix(win, tone(f, 0.9 if i < 3 else 1.4, decay=4.5 if i < 3 else 2.6), int(SR * 0.11 * i))
win = mix(win, tone(E6, 1.0, 0.35, decay=3), int(SR * 0.44))
write("win", win)

lose = silence(1.4)
for i, f in enumerate([G4, E4, C4]):
    lose = mix(lose, tone(f, 0.9, 0.8, decay=4, harmonics=((1, 1), (2, 0.15))), int(SR * 0.2 * i))
write("lose", lose)

hint = mix(tone(E6, 0.5, 0.6, decay=7, harmonics=((1, 1),)), tone(B6, 0.6, 0.5, decay=6, harmonics=((1, 1),)), int(SR * 0.08))
write("hint", hint)
print("ok")
