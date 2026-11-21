#!/usr/bin/env python3
"""从 gen.sh 生成的候选里，按每一组的步数目标挑出关卡，写成 levels.txt 的草稿。

用法：python3 tools/klotski/pick.py <候选文件夹> > 草稿
候选文件夹里是 out_easy_*.txt / out_mid_*.txt / out_hard_*.txt / out_master_*.txt（每行：最少步数 整齐分 木块数 盘面）。
挑选规矩：每个目标步数里选整齐分最高的；和已经选了的局面不能重复（左右镜像算重复），
也不能"差一块"（木块差不多都在同一个位置）；木块组成（竖块 / 横块 / 小方块各几块）尽量和已选的不一样。
挑完以后要人看一遍，改好的结果放在 levels.txt（那才是正式的关卡表，tools/klotski/emit.sh 读它）。
"""
import glob
import os
import sys

PACKS = [
    # id, 文件前缀, 目标步数（从易到难）, 最多几块木块
    ("intro", "easy", [2, 2, 3, 3, 4, 4, 5, 6, 7, 8, 9, 10], 6),
    ("grow", "mid", [10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22, 24, 25], 9),
    ("pro", "hard", [26, 27, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50], 11),
    ("classic", "master", [60, 64, 68, 72, 76, 80, 84, 100, 108], 11),
]
FIXED = {"classic": [(90, "VBBV/VBBV/VHHV/VSSV/S..S", "横刀立马")]}


def mirror(layout):
    return "/".join(r[::-1] for r in layout.split("/"))


def pieces(layout):
    """盘面 → 木块集合 {(种类, x, y)}"""
    rows = layout.split("/")
    used = set()
    out = set()
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "." or (x, y) in used:
                continue
            w, h = {"B": (2, 2), "V": (1, 2), "H": (2, 1), "S": (1, 1)}[c]
            for dy in range(h):
                for dx in range(w):
                    used.add((x + dx, y + dy))
            out.add((c, x, y))
    return out


def composition(layout):
    p = pieces(layout)
    return (sum(1 for k in p if k[0] == "V"), sum(1 for k in p if k[0] == "H"), sum(1 for k in p if k[0] == "S"))


def similar(a, b):
    pa, pb = pieces(a), pieces(b)
    for other in (pb, pieces(mirror(b))):
        if len(pa & other) >= len(pa) - 1:
            return True
    return False


def main(folder):
    for pack, prefix, targets, max_pieces in PACKS:
        cands = {}
        for path in glob.glob(os.path.join(folder, f"out_{prefix}_*.txt")):
            for line in open(path):
                d, score, n, layout = line.split()
                if int(n) > max_pieces:
                    continue
                cands.setdefault(int(d), []).append((float(score), layout))
        chosen = []
        comps = []
        fixed = {d: (l, name) for d, l, name in FIXED.get(pack, [])}
        for i, target in enumerate(targets, 1):
            if target in fixed and not any(c[0] == target for c in chosen):
                pass
            best = None
            for score, layout in sorted(cands.get(target, []), reverse=True)[:400]:
                if any(similar(layout, c[1]) for c in chosen):
                    continue
                s = score - 1.5 * comps.count(composition(layout))
                if best is None or s > best[0]:
                    best = (s, layout)
            if best is None:
                print(f"# {pack}: 没有 {target} 步的候选", file=sys.stderr)
                continue
            chosen.append((target, best[1]))
            comps.append(composition(best[1]))
        for d, (layout, name) in fixed.items():
            chosen.append((d, layout))
        chosen.sort(key=lambda c: c[0])
        for i, (d, layout) in enumerate(chosen, 1):
            print(f"{pack} {pack[0]}{i:02d} {layout}  # {d}")


if __name__ == "__main__":
    main(sys.argv[1])
