#!/usr/bin/env python3
"""七巧板图形：校验、画总览图、导出给 App 用的数据。

  python3 tools/tangram/figures_tool.py check            校验全部图形（七块各用一次、不重叠、连成一片、坐标在格子上）
  python3 tools/tangram/figures_tool.py sheet OUT.png [ID ...]  画总览图：每个图形左边彩色、右边黑影，下面写名字（给了 ID 就按这个顺序只画这些）
  python3 tools/tangram/figures_tool.py alternatives      用 solve.py 给整数朝向的图形找几种别的拼法，写进 alternatives.json（测试用）
  python3 tools/tangram/figures_tool.py export           写 RanranGame/Games/Tangram/Logic/TangramFigureData.swift
  python3 tools/tangram/figures_tool.py one ID OUT.png   只画一个（大一点，看细节）

图形写在 figures.py 里（每块板子写出它的顶点），这里认出每块是哪块板、怎么转、放在哪。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geom import (AREA, COUNT, Q2, edge_touch, farea, fpoly, identify, overlap, placed, pt, q2, rot, mirror,
                  touch)
import figures

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SWIFT_OUT = os.path.join(ROOT, "RanranGame", "Games", "Tangram", "Logic", "TangramFigureData.swift")

COLORS = {"L0": (0xEE, 0x7B, 0x6B), "L1": (0x8E, 0xC5, 0xE8), "M0": (0xE9, 0xB8, 0x72), "S0": (0x8D, 0xB5, 0x96),
          "S1": (0xB7, 0xA6, 0xE0), "Q0": (0xF4, 0xB6, 0xB0), "P0": (0x7C, 0xC4, 0xBC)}


class Figure:
    def __init__(self, fid, name, polys, rot45=0, flip=False):
        self.id = fid
        self.name = name
        self.problems = []
        pieces = []
        for vs in polys:
            ps = [pt(x, y) for x, y in vs]
            if flip:
                ps = [mirror(p) for p in ps][::-1]
            ps = [rot(p, rot45) for p in ps]
            pieces.append(ps)
        # 挪到第一象限：左下角在 (0,0)
        if pieces:
            mx = min((p[0] for vs in pieces for p in vs), key=float)
            my = min((p[1] for vs in pieces for p in vs), key=float)
            pieces = [[(x - mx, y - my) for x, y in vs] for vs in pieces]
        self.polys = pieces
        self.placements = []
        for vs in pieces:
            r = identify(vs)
            if r is None:
                self.problems.append(f"not a tangram piece: {vs}")
            else:
                self.placements.append(r)

    def validate(self):
        p = list(self.problems)
        kinds = [k for k, *_ in self.placements]
        for k, n in COUNT.items():
            if kinds.count(k) != n:
                p.append(f"piece {k} used {kinds.count(k)} times (need {n})")
        if len(self.placements) != 7:
            p.append(f"{len(self.placements)} pieces")
        for vs in self.polys:
            for x, y in vs:
                if not (x.on_lattice() and y.on_lattice()):
                    p.append(f"vertex off lattice: {x}, {y}")
        fp = [fpoly(vs) for vs in self.polys]
        tot = sum(farea(q) for q in fp)
        if abs(tot - 16) > 1e-9:
            p.append(f"area {tot}")
        for i in range(len(fp)):
            for j in range(i + 1, len(fp)):
                o = overlap(fp[i], fp[j])
                if o > 1e-9:
                    p.append(f"pieces {i + 1} ({kinds[i]}) and {j + 1} ({kinds[j]}) overlap by {o:.4f}")
        # 连成一片：挨着（共边或共点）的板子连起来
        seen = {0}
        stack = [0]
        while stack:
            i = stack.pop()
            for j in range(len(fp)):
                if j not in seen and touch(fp[i], fp[j]):
                    seen.add(j)
                    stack.append(j)
        if len(seen) != len(fp):
            p.append("not connected")
        return p

    def point_only_joins(self):
        """只靠一个点挨着别的板子的板子（允许，但列出来看看）"""
        fp = [fpoly(vs) for vs in self.polys]
        out = []
        for i in range(len(fp)):
            if not any(edge_touch(fp[i], fp[j]) for j in range(len(fp)) if j != i):
                out.append(i)
        return out

    def size(self):
        xs = [float(x) for vs in self.polys for x, _ in vs]
        ys = [float(y) for vs in self.polys for _, y in vs]
        return max(xs), max(ys)


def load():
    out = []
    for spec in figures.FIGURES:
        fid, name, polys = spec[:3]
        opts = spec[3] if len(spec) > 3 else {}
        out.append(Figure(fid, name, polys, rot45=opts.get("rot", 0), flip=opts.get("flip", False)))
    return out


def check(figs):
    bad = 0
    ids = set()
    for f in figs:
        probs = f.validate()
        if f.id in ids:
            probs.append("duplicate id")
        ids.add(f.id)
        if probs:
            bad += 1
            print(f"❌ {f.id} {f.name}")
            for p in probs:
                print("    " + p)
    print(f"{len(figs)} figures, {bad} with problems")
    return bad


# ---------------------------------------------------------------- 画图

def font(size):
    from PIL import ImageFont
    for path in ["/System/Library/Fonts/Hiragino Sans GB.ttc", "/System/Library/Fonts/STHeiti Medium.ttc"]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def draw_figure(draw, f, box, colored, outline=True):
    x0, y0, x1, y1 = box
    w, h = f.size()
    scale = min((x1 - x0) / w, (y1 - y0) / h)
    ox = x0 + ((x1 - x0) - w * scale) / 2
    oy = y1 - ((y1 - y0) - h * scale) / 2
    counts = {}
    for (kind, *_), vs in zip(f.placements, f.polys):
        n = counts.get(kind, 0)
        counts[kind] = n + 1
        pts = [(ox + float(x) * scale, oy - float(y) * scale) for x, y in vs]
        if colored:
            draw.polygon(pts, fill=COLORS[f"{kind}{n}"], outline=(60, 50, 60) if outline else None)
        else:
            draw.polygon(pts, fill=(46, 42, 53), outline=(46, 42, 53))


def sheet(figs, out, cols=6, cell=(380, 250)):
    from PIL import Image, ImageDraw
    rows = (len(figs) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell[0], rows * cell[1]), (0xF7, 0xF1, 0xE8))
    d = ImageDraw.Draw(img)
    fnt = font(24)
    for i, f in enumerate(figs):
        cx, cy = (i % cols) * cell[0], (i // cols) * cell[1]
        d.rectangle([cx + 4, cy + 4, cx + cell[0] - 4, cy + cell[1] - 4], outline=(220, 210, 200))
        half = (cell[0] - 30) / 2
        draw_figure(d, f, (cx + 10, cy + 12, cx + 10 + half, cy + cell[1] - 46), True)
        draw_figure(d, f, (cx + 20 + half, cy + 12, cx + 20 + 2 * half, cy + cell[1] - 46), False)
        label = f"{i + 1}. {f.name}  ({f.id})"
        d.text((cx + 12, cy + cell[1] - 40), label, fill=(46, 42, 53), font=fnt)
    img.save(out)
    print("wrote", out)


# ---------------------------------------------------------------- 导出 Swift

def lat(v):
    m, n = v.lattice()
    return f"TangramNum({m}, {n})"


def export(figs):
    lines = [
        "import Foundation",
        "",
        "// 自动生成：python3 tools/tangram/figures_tool.py export（图形写在 tools/tangram/figures.py 里）。不要手改。",
        "// 每个图形是七块板子的一种摆法；坐标是 (m + n√2) / 2，见 TangramGeometry.swift。",
        "",
        "extension TangramFigure {",
        "    static let all: [TangramFigure] = [",
    ]
    names = {"L": "large", "M": "medium", "S": "small", "Q": "square", "P": "parallelogram"}
    for f in figs:
        lines.append(f'        TangramFigure(id: "{f.id}", name: "{f.name}", pieces: [')
        for kind, k, fl, t in f.placements:
            lines.append(f"            TangramPlacement(kind: .{names[kind]}, rotation: {k}, flipped: {'true' if fl else 'false'}, "
                         f"x: {lat(t[0])}, y: {lat(t[1])}),")
        lines.append("        ]),")
    lines += ["    ]", "}", ""]
    with open(SWIFT_OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print("wrote", SWIFT_OUT, len(figs), "figures")


def encode(placement):
    kind, k, f, t = placement
    (mx, nx), (my, ny) = t[0].lattice(), t[1].lattice()
    return f"{kind}.{k}.{1 if f else 0}.{mx}.{nx}.{my}.{ny}"


ALT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "alternatives.json")


def alternatives(figs, per=3):
    """整数朝向的图形：用 solve.py 再找几种盖满同一个影子的拼法，给测试用（判断要认得别的拼法）"""
    import json
    import solve
    out = {}
    for f in figs:
        if any(x.b != 0 or y.b != 0 for vs in f.polys for x, y in vs):
            continue
        ref = {frozenset((x.a, y.a) for x, y in vs) for vs in f.polys}
        sols, err = solve.solve([[(x.a, y.a) for x, y in vs] for vs in f.polys], limit=40)
        if err or not sols:
            continue
        alts = []
        for sol in sols:
            key = {frozenset((x, y) for x, y in poly) for _, poly in sol}
            if key == ref:
                continue
            alts.append([encode(identify([pt(x, y) for x, y in poly])) for _, poly in sol])
            if len(alts) >= per:
                break
        if alts:
            out[f.id] = alts
    with open(ALT_OUT, "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
    print("wrote", ALT_OUT, sum(len(v) for v in out.values()), "alternatives for", len(out), "figures")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    figs = load()
    if cmd == "check":
        sys.exit(1 if check(figs) else 0)
    elif cmd == "sheet":
        check(figs)
        only = sys.argv[3:] if len(sys.argv) > 3 else None
        by_id = {f.id: f for f in figs}
        sel = [by_id[i] for i in only] if only else figs
        sheet(sel, sys.argv[2])
    elif cmd == "one":
        from PIL import Image, ImageDraw
        f = next(f for f in figs if f.id == sys.argv[2])
        print(f.validate())
        img = Image.new("RGB", (900, 450), (0xF7, 0xF1, 0xE8))
        d = ImageDraw.Draw(img)
        draw_figure(d, f, (10, 10, 440, 440), True)
        draw_figure(d, f, (460, 10, 890, 440), False)
        img.save(sys.argv[3])
    elif cmd == "alternatives":
        alternatives(figs)
    elif cmd == "export":
        if check(figs):
            sys.exit(1)
        export(figs)
