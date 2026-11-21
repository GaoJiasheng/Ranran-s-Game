#!/usr/bin/env python3
"""作图帮手：给一个影子的轮廓，找出七块板子怎么拼（只用"整数朝向"：大三角、小三角斜边横竖，中三角直角边横竖，正方形是菱形）。

把每个 1×1 的格子用两条对角线切成 4 个小三角，影子 = 一堆小三角；每块板子盖住一堆小三角，找一种恰好盖满的摆法。

  python3 tools/tangram/solve.py           解 OUTLINES 里的全部轮廓，打印成 figures.py 的写法
  python3 tools/tangram/solve.py NAME ...  只解这几个

找到的摆法抄进 figures.py（摆法定下来就不随着这个脚本变了）。
"""
import sys
from fractions import Fraction as Fr

CANON = {
    "L": [(0, 0), (4, 0), (2, 2)],
    "M": [(0, 0), (2, 0), (0, 2)],
    "S": [(0, 0), (2, 0), (1, 1)],
    "Q": [(0, 1), (1, 0), (2, 1), (1, 2)],
    "P": [(0, 0), (2, 0), (3, 1), (1, 1)],
}
COUNT = {"L": 2, "M": 1, "S": 2, "Q": 1, "P": 1}
ORDER = ["L", "M", "Q", "P", "S"]


def rot90(p, k):
    x, y = p
    for _ in range(k % 4):
        x, y = -y, x
    return (x, y)


def inside(pt, poly):
    """点在多边形里（射线法；点不会落在边上，因为用的是小三角的重心）"""
    x, y = pt
    c = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            xi = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
            if x < xi:
                c = not c
    return c


CENTROIDS = [(Fr(1, 2), Fr(1, 6)), (Fr(5, 6), Fr(1, 2)), (Fr(1, 2), Fr(5, 6)), (Fr(1, 6), Fr(1, 2))]


def tiles(poly):
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    out = set()
    for i in range(int(min(xs)) - 1, int(max(xs)) + 1):
        for j in range(int(min(ys)) - 1, int(max(ys)) + 1):
            for q, (cx, cy) in enumerate(CENTROIDS):
                if inside((i + cx, j + cy), poly):
                    out.add((i, j, q))
    return out


def orientations(kind):
    out = []
    flips = (0, 1) if kind == "P" else (0,)
    seen = set()
    for f in flips:
        for k in range(4):
            vs = [rot90((-x if f else x, y), k) for x, y in CANON[kind]]
            mx = min(v[0] for v in vs)
            my = min(v[1] for v in vs)
            vs = [(Fr(x - mx), Fr(y - my)) for x, y in vs]
            key = frozenset(vs)
            if key in seen:
                continue
            seen.add(key)
            out.append(vs)
    return out


def solve(target_polys, limit=1):
    target = set()
    for p in target_polys:
        target |= tiles([(Fr(x), Fr(y)) for x, y in p])
    if len(target) != 64:
        return None, f"area {len(target) / 4} (need 16)"
    xs = [t[0] for t in target]
    ys = [t[1] for t in target]
    placements = {k: [] for k in COUNT}
    for kind in COUNT:
        offsets = [(Fr(0), Fr(0))] + ([(Fr(1, 2), Fr(1, 2))] if kind == "Q" else [])
        for vs in orientations(kind):
            for ox, oy in offsets:
                for tx in range(min(xs) - 4, max(xs) + 2):
                    for ty in range(min(ys) - 4, max(ys) + 2):
                        poly = [(x + tx + ox, y + ty + oy) for x, y in vs]
                        cov = tiles(poly)
                        if cov <= target:
                            placements[kind].append((frozenset(cov), poly))
    by_tile = {}
    for kind, ps in placements.items():
        for cov, poly in ps:
            for t in cov:
                by_tile.setdefault(t, []).append((kind, cov, poly))
    order = sorted(target, key=lambda t: (-t[1], t[0], t[2]))
    sols = []
    left = dict(COUNT)
    chosen = []

    def rec(covered):
        if len(sols) >= limit:
            return
        first = next((t for t in order if t not in covered), None)
        if first is None:
            sols.append(list(chosen))
            return
        for kind, cov, poly in by_tile.get(first, []):
            if left[kind] == 0 or cov & covered:
                continue
            left[kind] -= 1
            chosen.append((kind, poly))
            rec(covered | cov)
            chosen.pop()
            left[kind] += 1

    rec(frozenset())
    return sols, None


def fmt(v):
    if v.denominator == 1:
        return str(v.numerator)
    return f'"{v.numerator}/{v.denominator}"'


def show(name, sols):
    if not sols:
        print(f"# {name}: no tiling")
        return
    kinds_order = {"L": 0, "M": 1, "S": 2, "Q": 3, "P": 4}
    sol = sorted(sols[0], key=lambda kp: kinds_order[kp[0]])
    print(f"    # {name}")
    for kind, poly in sol:
        print("        [" + ", ".join(f"({fmt(x)}, {fmt(y)})" for x, y in poly) + "],")


if __name__ == "__main__":
    import outlines
    names = sys.argv[1:] or list(outlines.OUTLINES)
    for n in names:
        sols, err = solve(outlines.OUTLINES[n])
        if err:
            print(f"# {n}: {err}")
        else:
            show(n, sols)
