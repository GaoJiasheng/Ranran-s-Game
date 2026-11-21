#!/usr/bin/env python3
"""生成数独教学：RanranGame/Tutorials/sudoku.json。

改了这里以后：
  1. python3 tools/tutorials/build_sudoku.py
  2. zsh tools/sudoku/test.sh（每道题都按 SudokuLessonLogic 判一遍，练习的每种变换也查）
  3. python3 tools/voice/build_manifest.py，再重新生成配音

盘面写法 "<边长>[f]:<格子>"："." 是空格，f 表示用水果显示（1 苹果 2 草莓 3 胡萝卜 4 气球）。
格子 "r3c4" = 第 3 行第 4 列；行列宫 "row:3"、"col:4"、"box:5"，都从 1 数起，宫按从左到右、从上到下数。
题目和标记的写法见 RanranGame/Games/Sudoku/Logic/SudokuLessonLogic.swift。

课的 id（s1…s18）是存档的钥匙，不能改、不能复用。课程规划见 docs/tutorial-sudoku.md。
这里也带了一个很小的解题器（和 App 里的规则一样），只用来挑局面、在生成时自查；真正的检查在 tools/sudoku/test.sh。
"""
import json
import os
import random

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "RanranGame", "Tutorials", "sudoku.json")

FRUIT = {1: "苹果", 2: "草莓", 3: "胡萝卜", 4: "气球"}


# ----------------------------------------------------------------------------- 小解题器

def shape(n):
    return {4: (2, 2), 6: (2, 3), 9: (3, 3)}[n]


class G:
    def __init__(self, n, cells, fruit=False):
        self.n, self.cells, self.fruit = n, list(cells), fruit
        self.br, self.bc = shape(n)

    @staticmethod
    def rows(rows, fruit=False):
        n = len(rows)
        cells = [0 if ch == "." else int(ch) for r in rows for ch in r]
        assert len(cells) == n * n, rows
        return G(n, cells, fruit)

    def copy(self):
        return G(self.n, self.cells, self.fruit)

    @property
    def spec(self):
        return f"{self.n}{'f' if self.fruit else ''}:" + "".join("." if v == 0 else str(v) for v in self.cells)

    def unit_cells(self, kind, i):
        n = self.n
        if kind == "row":
            return [i * n + c for c in range(n)]
        if kind == "col":
            return [r * n + i for r in range(n)]
        across = n // self.bc
        r0, c0 = (i // across) * self.br, (i % across) * self.bc
        return [r * n + c for r in range(r0, r0 + self.br) for c in range(c0, c0 + self.bc)]

    def unit_of(self, kind, cell):
        r, c = divmod(cell, self.n)
        if kind == "row":
            return r
        if kind == "col":
            return c
        return (r // self.br) * (self.n // self.bc) + c // self.bc

    def units(self):
        return [(k, i) for k in ("row", "col", "box") for i in range(self.n)]

    def peers(self, cell):
        out = set()
        for k in ("row", "col", "box"):
            out |= set(self.unit_cells(k, self.unit_of(k, cell)))
        out.discard(cell)
        return out

    def cands(self, cell):
        if self.cells[cell]:
            return []
        used = {self.cells[j] for j in self.peers(cell)}
        return [v for v in range(1, self.n + 1) if v not in used]

    def blanks(self, k, i):
        return [c for c in self.unit_cells(k, i) if self.cells[c] == 0]

    def missing(self, k, i):
        have = {self.cells[c] for c in self.unit_cells(k, i)}
        return [v for v in range(1, self.n + 1) if v not in have]

    def moves(self, every=False):
        """(rank, cell, value, via)：和 SudokuSolver.moves 一样的三招。every：同一格同一个数的几种想法都留着"""
        out = {}

        def add(rank, cell, v, via):
            key = (cell, v, via) if every else (cell, v)
            if key not in out or out[key][0] > rank:
                out[key] = (rank, cell, v, via)
        for k, i in self.units():
            b = self.blanks(k, i)
            if len(b) == 1:
                m = self.missing(k, i)
                if len(m) == 1 and m[0] in self.cands(b[0]):
                    add(1, b[0], m[0], "full:" + k)
            for v in self.missing(k, i):
                spots = [c for c in b if v in self.cands(c)]
                if len(spots) == 1:
                    add(2 if k == "box" else 3, spots[0], v, "hidden:" + k)
        for c in range(self.n * self.n):
            cs = self.cands(c)
            if len(cs) == 1:
                add(4, c, cs[0], "naked")
        return sorted(out.values())

    def name(self, cell):
        r, c = divmod(cell, self.n)
        return f"r{r + 1}c{c + 1}"

    def solve_count(self, limit=2):
        cells = self.cells

        def rec():
            best, bc = None, None
            for i in range(self.n * self.n):
                if cells[i] == 0:
                    cs = self.cands(i)
                    if not cs:
                        return 0
                    if best is None or len(cs) < len(bc):
                        best, bc = i, cs
            if best is None:
                return 1
            total = 0
            for v in bc:
                cells[best] = v
                total += rec()
                if total >= limit:
                    break
            cells[best] = 0
            return total
        saved = list(cells)
        r = rec()
        self.cells = saved
        return r


def base(n):
    br, bc = shape(n)
    return [(bc * (r % br) + r // br + c) % n + 1 for r in range(n) for c in range(n)]


def shuffled(n, rows, cols, digits):
    b = base(n)
    return [digits[b[rows[r] * n + cols[c]] - 1] for r in range(n) for c in range(n)]


# 四宫格的答案（水果和数字共用）
A4 = G.rows(["1234", "3412", "2143", "4321"])
# 六宫格、九宫格的答案：标准盘面换一换行、列、数字，看起来不那么整齐
P6 = G(6, shuffled(6, [1, 0, 3, 2, 4, 5], [2, 0, 1, 4, 5, 3], [3, 5, 1, 6, 2, 4]))
P9 = G(9, shuffled(9, [2, 0, 1, 4, 5, 3, 7, 6, 8], [1, 2, 0, 5, 3, 4, 8, 7, 6], [5, 3, 8, 1, 9, 2, 7, 4, 6]))


def holes(sol, names, fruit=False):
    """答案盘面挖掉这些格子"""
    g = sol.copy()
    g.fruit = fruit
    for nm in names.split():
        r, c = nm[1:].split("c")
        g.cells[(int(r) - 1) * g.n + int(c) - 1] = 0
    return g


def only(sol, names, fruit=False):
    """答案盘面里只留下这些格子"""
    g = G(sol.n, [0] * (sol.n * sol.n), fruit)
    for nm in names.split():
        r, c = nm[1:].split("c")
        i = (int(r) - 1) * g.n + int(c) - 1
        g.cells[i] = sol.cells[i]
    return g


def carve(sol, blanks, seed, check=None):
    """按固定种子挖 blanks 个空格（只用三招就能解完）；check(g) 为真才要"""
    rng = random.Random(seed)
    for _ in range(4000):
        g = sol.copy()
        order = list(range(sol.n * sol.n))
        rng.shuffle(order)
        for i in order:
            if sum(1 for v in g.cells if v == 0) >= blanks:
                break
            keep = g.cells[i]
            g.cells[i] = 0
            if not logic_solvable(g):
                g.cells[i] = keep
        if sum(1 for v in g.cells if v == 0) == blanks and (check is None or check(g)):
            return g
    raise SystemExit(f"carve failed (seed {seed})")


def logic_solvable(g):
    g = g.copy()
    while 0 in g.cells:
        ms = g.moves()
        if not ms:
            return False
        g.cells[ms[0][1]] = ms[0][2]
    return True


def find_move(g, via_prefix, cond=lambda m: True):
    for m in g.moves(every=True):
        if m[3].startswith(via_prefix) and cond(m):
            return m
    return None


# ----------------------------------------------------------------------------- 写课的小工具

def step(say, board=None, marks=None, task=None, hint=None, ok=None, drill=None):
    s = {"say": say}
    if drill:
        s["drill"] = drill
    if board is not None:
        s["board"] = board.spec if isinstance(board, G) else board
    if marks:
        s["marks"] = marks
    if task:
        s["task"] = task
    if hint:
        s["hint"] = hint
    if ok:
        s["ok"] = ok
    return s


def task(kind, rule, via=None):
    t = {"type": kind, "rule": rule}
    if via:
        t["extra"] = {"via": via}
    return t


def fill(rule, via=None):
    return task("fill", rule, via)


def pick(rule, via=None):
    return task("pick", rule, via)


def value(rule):
    return task("value", rule)


def cands(rule):
    return task("cands", rule)


def lesson(id, title, icon, learned, steps):
    return {"id": id, "title": title, "icon": icon, "learned": learned, "steps": steps}


# ----------------------------------------------------------------------------- 第一组 · 基础规则（四宫格，水果）

FULL4 = A4.copy()
FULL4.fruit = True

S1 = lesson("s1", "认识数独", "square.grid.2x2.fill", "数独的行、列和宫", [
    step("这是一个小数独。里面有四种水果：苹果、草莓、胡萝卜和气球。", board=FULL4),
    step("横着的一排格子，叫『一行』。看，第一行亮起来了。", marks=["row:1"]),
    step("点一下第三行里的任意一个格子。", task=pick("inUnit:row:3"),
         hint="从上往下的第三排横着的格子，就是第三行。", ok="对，这就是第三行！"),
    step("竖着的一排格子，叫『一列』。这是第一列。", marks=["col:1"]),
    step("点一下第二列里的任意一个格子。", task=pick("inUnit:col:2"),
         hint="从左往右的第二排竖着的格子，就是第二列。", ok="对，这就是第二列！"),
    step("粗线围起来的四个格子，叫『一宫』。四宫格一共有四个宫。", marks=["box:1"]),
    step("点一下右下角那一宫里的格子。", task=pick("inUnit:box:4"),
         hint="看粗线：右下角围起来的四个格子是一宫。", ok="对，这就是一宫！"),
])

S2 = lesson("s2", "每一行都不重复", "line.3.horizontal", "每一行里水果都不重复", [
    step("数独的规则：每一行里，四种水果各有一个，不能重复。", board=FULL4, marks=["row:2"]),
    step("这一行有两个一样的水果，挤在一起了。点一下其中一个！",
         board=G.rows(["1231", "....", "....", "...."], True), task=pick("clash"),
         hint="一个一个看过去，哪两个格子里的水果一样？", ok="找到了！两个苹果在同一行，这样不可以。"),
    step("这一行还空着一个格子。缺的是哪一种水果？点下面的按钮选。",
         board=G.rows(["12.4", "....", "....", "...."], True), marks=["row:1"], task=value("missing:row:1"),
         hint="这一行已经有苹果、草莓和气球了，还缺谁？", ok="对，缺的是胡萝卜！"),
    step("把胡萝卜放进去：先点空格子，再点胡萝卜。", task=fill("cell:r1c3", "full:row"),
         hint="这一行只缺胡萝卜。点那个空格子，再点胡萝卜按钮。", ok="放好了！这一行四种水果都有了。"),
    step("再来一行！把空着的格子填好。", board=G.rows(["....", "3.12", "....", "...."], True),
         marks=["row:2"], task=fill("cell:r2c2", "full:row"),
         hint="这一行已经有胡萝卜、苹果和草莓了，还缺气球。", ok="填对了！"),
])

S3 = lesson("s3", "每一列、每一宫也不重复", "square.grid.3x3", "每一列、每一宫也都不能重复", [
    step("不光是行：每一列、每一宫里，四种水果也都各有一个。", board=FULL4, marks=["col:3", "box:1"]),
    step("这一列里有两个一样的，找出来点一下！", board=G.rows([".2..", ".4..", ".2..", "...."], True),
         marks=["col:2"], task=pick("clash"),
         hint="这一列竖着看下来，哪两个格子里的水果一样？", ok="对！两个草莓在同一列。"),
    step("这一宫里也有两个一样的，找出来！", board=G.rows(["....", "....", "..13", "...1"], True),
         marks=["box:4"], task=pick("clash"),
         hint="看粗线围起来的这一宫，哪两个水果一样？", ok="对！两个苹果在同一宫。"),
    step("这一列只空着一个格子。缺的是哪一种？", board=G.rows(["...4", "...2", "....", "...1"], True),
         marks=["col:4"], task=value("missing:col:4"),
         hint="这一列已经有气球、草莓和苹果，还缺谁？", ok="对，缺胡萝卜！"),
    step("把它放进空格子里吧。", task=fill("cell:r3c4", "full:col"),
         hint="这一列只缺胡萝卜。点空格子，再点胡萝卜。", ok="放好了！"),
    step("这一宫只空着一个格子，把它填好！", board=G.rows(["12..", "3...", "....", "...."], True),
         marks=["box:1"], task=fill("cell:r2c2", "full:box"),
         hint="这一宫已经有苹果、草莓和胡萝卜，还缺气球。", ok="这一宫也齐了！"),
])

S4_BOARD = holes(A4, "r1c1 r1c2 r2c1 r3c4", fruit=True)
S4 = lesson("s4", "只剩一个空格", "1.square.fill", "哪里只剩一个空格，就填它缺的那一个", [
    step("填数独的第一个办法：找只剩一个空格的地方。那里缺谁，就填谁。", board=S4_BOARD),
    step("找出只剩一个空格的那一行，点一下这一行。", task=pick("oneBlank:row"),
         hint="一行一行看，哪一行只空着一个格子？", ok="对！这一行只空着一个格子。"),
    step("现在把它填好！", task=fill("single"),
         hint="这一行已经有三种水果了，缺哪一种就填哪一种。", ok="填对了！"),
    step("再找只剩一个空格的那一列！", task=pick("oneBlank:col"),
         hint="竖着看，哪一列只空着一个格子？", ok="找到了！"),
    step("把它也填好。", task=fill("single"),
         hint="这一列缺哪一种水果？", ok="对啦！"),
    step("剩下的格子，你也能填好吗？", task=fill("single"),
         hint="看看哪一行、哪一列、哪一宫只剩一个空格。", ok="真棒！"),
    step("最后一个！", task=fill("single"),
         hint="只剩一个空格了，它这一行缺谁？", ok="全部填好啦！"),
])

S5_BOARD = holes(A4, "r1c3 r2c1 r3c4 r4c2 r4c3", fruit=True)
S5 = lesson("s5", "第一个四宫格", "star.fill", "自己填完一整个四宫格", [
    step("现在你来填一整个四宫格！每个空格都找一找：它这一行、这一列、这一宫，哪里只剩一个空格？",
         board=S5_BOARD),
    step("填一个你能确定的格子。", task=fill("single"),
         hint="先找只空着一个格子的行。", ok="对啦！"),
    step("再找一个。", task=fill("single"), hint="再看看别的行，或者竖着看列。", ok="填对了！"),
    step("继续！", task=fill("single"), hint="哪一行、哪一列、哪一宫只剩一个空格？", ok="真棒！"),
    step("快好了！", task=fill("single"), hint="还剩两个空格，先看它们的列。", ok="就剩一个了！"),
    step("最后一个！", task=fill("single"), hint="这一行只缺一种水果了。", ok="全部填好啦！"),
    step("你自己填完了一整个数独！每一行、每一列、每一宫，四种水果都不重复。"),
])

BASIC = {"id": "basic", "title": "基础规则", "subtitle": "行、列、宫，都不重复", "art": "tutor_sudoku_basic",
         "lessons": [S1, S2, S3, S4, S5]}


# ----------------------------------------------------------------------------- 第二组 · 找唯一（四宫格：水果 → 数字）

S6 = lesson("s6", "看三个方向", "eye.fill", "看行、列、宫，找出一个格子只能填谁", [
    step("有时候一行里空着好几个格子。那就换个办法：盯住一个格子，看它的行、列和宫。",
         board=G.rows(["....", "3..2", ".1..", "...."], True), marks=["cell:r2c2"]),
    step("它这一行，已经有胡萝卜和草莓。", marks=["cell:r2c2", "row:2"]),
    step("它这一列，已经有苹果。所以苹果、草莓、胡萝卜都不能填。", marks=["cell:r2c2", "col:2"]),
    step("那它只能填什么？填上！", marks=["cell:r2c2"], task=fill("cell:r2c2", "naked"),
         hint="这个格子不能填苹果、草莓和胡萝卜，四种水果还剩哪一种？", ok="只能填气球！"),
    step("再来一个：发光的格子能填什么？", board=G.rows(["..3.", "....", "2...", "...1"], True),
         task=fill("cell:r3c3", "naked"),
         hint="看看这个格子的行、列、宫里都有谁了，剩下的那一种就是答案。", ok="对啦，是气球！"),
    step("这个呢？", board=G.rows(["1...", "....", "2...", ".3.."], True), task=fill("cell:r4c1", "naked"),
         hint="这个格子的列里有苹果和草莓，行里有胡萝卜。还剩谁？", ok="完全正确！"),
])

FULL4D = A4.copy()
S7 = lesson("s7", "换成数字", "textformat.123", "用数字 1 到 4 的四宫格", [
    step("水果换成数字，规则一模一样：每一行、每一列、每一宫，1、2、3、4 各有一个。", board=FULL4D),
    step("发光的格子里能填哪些数字？把它们都点出来。", board=G.rows(["....", "3...", ".1..", "...."]),
         task=cands("cands:r2c2"),
         hint="这个格子的行里有 3，列里有 1。别的数字都能填。", ok="对，可以填 2 或者 4。"),
    step("能填的有两个，还定不下来。再多一个数字就好了。", board=G.rows([".2..", "3...", ".1..", "...."]),
         marks=["cell:r2c2", "box:1"]),
    step("现在呢？把它填上！", task=fill("cell:r2c2", "naked"),
         hint="这个格子的行、列、宫里已经有 1、2、3 了。", ok="只能填 4！"),
    step("再来一个：发光的格子能填几？", board=G.rows(["...4", "....", "2...", "...1"]),
         task=fill("cell:r3c4", "naked"),
         hint="看这个格子：行里有 2，列里有 4 和 1。", ok="对，是 3！"),
])

S8_BOARD = holes(A4, "r1c2 r1c3 r2c1 r2c4 r3c2 r4c3")
S8 = lesson("s8", "找能确定的格子", "magnifyingglass", "在一整盘里找能确定的格子", [
    step("一整盘的时候，先找最好找的：只剩一个空格的地方，或者只能填一个数的格子。", board=S8_BOARD),
    step("找一个能确定的格子，填上！", task=fill("single"),
         hint="先看只空着一个格子的行和列。", ok="对啦！"),
    step("再找一个！", task=fill("single"), hint="哪个格子的行、列、宫里已经有三个数字了？", ok="真棒！"),
    step("继续！", task=fill("single"), hint="找只剩一个空格的地方。", ok="就是这样！"),
    step("还有三个。", task=fill("single"), hint="哪一行、哪一列只剩一个空格了？", ok="对啦！"),
    step("还有两个。", task=fill("single"), hint="看看还空着的格子，它的列里缺几？", ok="填对了！"),
    step("最后一个！", task=fill("single"), hint="只剩一个空格了，它这一行缺谁？", ok="全部填好啦！"),
])

S9_BOARD = holes(A4, "r1c1 r1c2 r1c4 r2c2 r3c1 r3c3 r4c4")
S9 = lesson("s9", "先找哪里", "scope", "先看空格最少的地方", [
    step("不知道从哪里开始？先找空格最少的行、列或者宫，那里最容易。", board=S9_BOARD),
    step("哪一行的空格最少？点一下这一行！", task=pick("fullest:row"),
         hint="一行一行看，哪一行空着的格子最少？", ok="对，就从这里开始。"),
    step("在那里找一个能确定的格子，填上！", task=fill("single"),
         hint="空格最少的那一行，缺的是哪一个？", ok="填对了！"),
    step("现在哪一列的空格最少？", task=pick("fullest:col"),
         hint="竖着看，哪一列空着的格子最少？", ok="找到了！"),
    step("再填一个！", task=fill("single"), hint="空格最少的那一列，缺的是哪一个？", ok="对啦！"),
    step("行、列、宫都算上，现在哪里空格最少？", task=pick("fullest"),
         hint="行、列、宫都看一看，哪里空着的格子最少？", ok="对！"),
    step("填一个！", task=fill("single"), hint="在空格最少的地方找。", ok="太厉害了！"),
])

UNIQUE = {"id": "unique", "title": "找唯一", "subtitle": "这个格子只能填谁？", "art": "tutor_sudoku_unique",
          "lessons": [S6, S7, S8, S9]}


# ----------------------------------------------------------------------------- 第三组 · 排除法（六宫格）

S10_BOARD = holes(P6, "r3c5 r5c2 r1c6")
S10 = lesson("s10", "认识六宫格", "square.grid.3x2.fill", "六宫格：数字 1 到 6，一宫是两行三列", [
    step("这是六宫格：一行有六个格子，数字是 1 到 6。粗线围起来的一宫，是两行三列。",
         board=P6, marks=["box:1"]),
    step("点一下右下角那一宫里的格子。", task=pick("inUnit:box:6"),
         hint="粗线围起来的六块里，右下角那一块。", ok="对，这就是一宫！"),
    step("这一行只空着一个格子。1 到 6 里，缺的是哪一个？", board=S10_BOARD, marks=["row:3"],
         task=value("missing:row:3"),
         hint="这一行已经有五个数字了，1 到 6 里还缺哪一个？", ok="对！"),
    step("把它填进去。", task=fill("cell:r3c5", "full:row"), hint="这一行只缺这一个数字，填进空格子。",
         ok="填对了！"),
    step("这一宫只空着一个格子，填好它！", marks=["box:5"], task=fill("cell:r5c2", "full:box"),
         hint="这一宫只空着一个格子，1 到 6 里缺哪一个？", ok="真棒！"),
])


def hidden_board(sol, blanks, seed, kind, min_blanks=3):
    """挑一个排除法的局面：某个数在这一宫（行、列）里只能放一个地方，而且那里空着好几个格子、那一格自己还定不下来"""
    def ok(g):
        return find_move(g, "hidden:" + kind, lambda m: good(g, m)) is not None

    def good(g, m):
        k, i = kind, g.unit_of(kind, m[1])
        return len(g.blanks(k, i)) >= min_blanks and len(g.cands(m[1])) >= 2 and \
            all(not mv[3].startswith("full") for mv in g.moves() if mv[1] == m[1])
    g = carve(sol, blanks, seed, ok)
    m = find_move(g, "hidden:" + kind, lambda m: good(g, m))
    return g, m


def crosses(g, m, kind):
    """排除法里被挡住的格子（同一宫 / 行 / 列里别的空格）"""
    unit = g.unit_cells(kind, g.unit_of(kind, m[1]))
    return [f"cross:{g.name(c)}" for c in unit if g.cells[c] == 0 and c != m[1]]


def unit_mark(g, kind, cell):
    return f"{kind}:{g.unit_of(kind, cell) + 1}"


Q, QM = hidden_board(P6, 18, 11, "box")
Q2, Q2M = hidden_board(P6, 18, 12, "box")
S11 = lesson("s11", "排除法：一宫里放哪", "xmark.square", "用排除法找一个数字在一宫里的位置", [
    step("新办法：盯住一个数字，问它：『在这一宫里，我能放在哪？』", board=Q,
         marks=[unit_mark(Q, "box", QM[1]), f"val:{QM[2]}"]),
    step("亮起来的数字已经出现在好几行、好几列里了。它在的那一行、那一列，都不能再放它。这一宫里被挡住的格子，打上叉。",
         marks=[unit_mark(Q, "box", QM[1]), f"val:{QM[2]}"] + crosses(Q, QM, "box")),
    step("只剩一个格子能放它了。点一下这个格子！", marks=[unit_mark(Q, "box", QM[1]), f"val:{QM[2]}"] + crosses(Q, QM, "box"),
         task=pick(f"where:{QM[2]}:{unit_mark(Q, 'box', QM[1])}", "hidden:box"),
         hint="这一宫里，打叉的格子都不能放，没打叉的空格子只有一个。", ok="对，它只能放在这里！"),
    step("换一个：亮起来的数字，在圈出来的这一宫里能放在哪？", board=Q2,
         marks=[unit_mark(Q2, "box", Q2M[1]), f"val:{Q2M[2]}"],
         task=pick(f"where:{Q2M[2]}:{unit_mark(Q2, 'box', Q2M[1])}", "hidden:box"),
         hint="看看亮起来的数字挡住了这一宫的哪几行、哪几列，这一宫里剩下的那个空格子就是答案。", ok="找到了！"),
    step("把它填进去！", marks=[unit_mark(Q2, "box", Q2M[1]), f"val:{Q2M[2]}"],
         task=fill(f"cell:{Q2.name(Q2M[1])}", "hidden:box"),
         hint="这一宫里只有这个格子能放亮起来的数字，填上它。", ok="填对了！这就是排除法。"),
])

R, RM = hidden_board(P6, 18, 21, "row")
T, TM = hidden_board(P6, 18, 22, "col")
S12 = lesson("s12", "排除法：一行、一列里放哪", "arrow.left.and.right.square", "用排除法找一个数字在一行、一列里的位置", [
    step("排除法在一行、一列里也能用：这一行还没有亮起来的数字，它能放在哪？", board=R,
         marks=[unit_mark(R, "row", RM[1]), f"val:{RM[2]}"] + crosses(R, RM, "row")),
    step("打叉的格子，它们那一列或者那一宫里已经有这个数字了。点一下能放它的格子！",
         marks=[unit_mark(R, "row", RM[1]), f"val:{RM[2]}"] + crosses(R, RM, "row"),
         task=pick(f"where:{RM[2]}:{unit_mark(R, 'row', RM[1])}", "hidden:row"),
         hint="这一行里，没打叉的空格子只有一个。", ok="对！"),
    step("这一列还没有亮起来的数字。它在这一列里能放在哪？", board=T,
         marks=[unit_mark(T, "col", TM[1]), f"val:{TM[2]}"],
         task=pick(f"where:{TM[2]}:{unit_mark(T, 'col', TM[1])}", "hidden:col"),
         hint="这一列里，哪些格子的行或者宫里已经有这个数字了？剩下的那个格子就是答案。", ok="找到了！"),
    step("填进去吧！", marks=[unit_mark(T, "col", TM[1]), f"val:{TM[2]}"],
         task=fill(f"cell:{T.name(TM[1])}", "hidden:col"),
         hint="这一列里只有这个格子能放亮起来的数字。", ok="对啦！"),
])

S13_BOARD = carve(P6, 7, 31, lambda g: any(m[3].startswith("hidden") or m[3] == "naked" for m in g.moves()))
S13 = lesson("s13", "六宫格实战", "flag.checkered", "用学过的办法填完六宫格", [
    step("用学过的三个办法：只剩一个空格、看三个方向、排除法。把这个六宫格填完！", board=S13_BOARD),
    step("找一个能确定的格子，填上！", task=fill("single"), hint="先找只剩一个空格的行、列、宫。", ok="对啦！"),
    step("再来！", task=fill("single"), hint="盯住一个数字，看它在一宫里能放哪。", ok="真棒！"),
    step("继续！", task=fill("single"), hint="盯住一个格子，看它的行、列、宫里都有谁了。", ok="就是这样！"),
    step("还有四个。", task=fill("single"), hint="哪里空格最少？从那里找。", ok="对啦！"),
    step("还有三个。", task=fill("single"), hint="只剩一个空格的地方，缺谁就填谁。", ok="填对了！"),
    step("还有两个。", task=fill("single"), hint="看看还空着的格子，它的行里缺谁？", ok="太厉害了！"),
    step("最后一个！", task=fill("single"), hint="它这一行只缺一个数字了。", ok="六宫格完成啦！"),
])

EXCLUDE = {"id": "exclude", "title": "排除法", "subtitle": "这个数字只能放在哪？", "art": "tutor_sudoku_exclude",
           "lessons": [S10, S11, S12, S13]}


# ----------------------------------------------------------------------------- 第四组 · 九宫格

def lone(g, kind):
    """只空着一个格子的行 / 列 / 宫，和它的那个空格"""
    for i in range(g.n):
        b = g.blanks(kind, i)
        if len(b) == 1:
            return i, b[0]
    raise SystemExit("no lone " + kind)


S14_BOARD = holes(P9, "r4c6 r7c2")
S14_ROW = lone(S14_BOARD, "row")
S14 = lesson("s14", "认识九宫格", "square.grid.3x3.fill", "九宫格：九行、九列、九个宫，数字 1 到 9", [
    step("这就是真正的数独：九行、九列、九个宫。每一行、每一列、每一宫里，1 到 9 都各有一个。",
         board=P9, marks=["box:5"]),
    step("点一下正中间的那一宫。", task=pick("inUnit:box:5"),
         hint="粗线围起来的九块里，最中间的那一块。", ok="对，这是正中间的一宫！"),
    step("这一行只空着一个格子。1 到 9 里，缺的是哪一个？", board=S14_BOARD, marks=[f"row:{S14_ROW[0] + 1}"],
         task=value(f"missing:row:{S14_ROW[0] + 1}"),
         hint="这一行已经有八个数字了，1 到 9 里还缺哪一个？", ok="对！"),
    step("把它填进去。", task=fill(f"cell:{S14_BOARD.name(S14_ROW[1])}", "full:row"),
         hint="这一行只缺这一个数字，填进空格子。", ok="填对了！"),
    step("这一宫也只空着一个格子，填好它！", marks=["box:7"], task=fill("cell:r7c2", "full:box"),
         hint="这一宫只空着一个格子，1 到 9 里缺哪一个？", ok="真棒！"),
])

S15_BOARD = carve(P9, 36, 41)
S15 = lesson("s15", "先找最满的", "chart.bar.fill", "九宫格里先找空格最少的地方", [
    step("九宫格的空格多，别着急。先找填得最满的地方，那里最容易。", board=S15_BOARD),
    step("哪一行的空格最少？点一下这一行！", task=pick("fullest:row"),
         hint="一行一行看，哪一行空着的格子最少？", ok="对！"),
    step("在那里找一个能确定的格子，填上！", task=fill("single"),
         hint="空格最少的地方，缺的数字最好找。", ok="填对了！"),
    step("现在哪一宫的空格最少？", task=pick("fullest:box"),
         hint="一宫一宫看，哪一宫空着的格子最少？", ok="找到了！"),
    step("再填一个！", task=fill("single"), hint="在空格最少的那一宫里找。", ok="真棒！"),
    step("哪一列的空格最少？", task=pick("fullest:col"),
         hint="竖着看，哪一列空着的格子最少？", ok="对！"),
    step("再填一个！", task=fill("single"), hint="在空格最少的那一列里找。", ok="太厉害了！"),
])

W, WM = hidden_board(P9, 40, 51, "box", min_blanks=4)
S16 = lesson("s16", "九宫格的排除法", "xmark.square.fill", "在九宫格里用排除法", [
    step("排除法在九宫格里最好用：挑一个数字，看它在一宫里能放哪。", board=W,
         marks=[unit_mark(W, "box", WM[1]), f"val:{WM[2]}"]),
    step("亮起来的数字挡住了好多格子。只剩一个格子能放它，点一下！",
         marks=[unit_mark(W, "box", WM[1]), f"val:{WM[2]}"] + crosses(W, WM, "box"),
         task=pick(f"where:{WM[2]}:{unit_mark(W, 'box', WM[1])}", "hidden:box"),
         hint="这一宫里，打叉的格子都不能放，没打叉的空格子只有一个。", ok="对！"),
    step("把它填进去！", marks=[unit_mark(W, "box", WM[1]), f"val:{WM[2]}"],
         task=fill(f"cell:{W.name(WM[1])}", "hidden:box"),
         hint="这一宫里只有这个格子能放亮起来的数字。", ok="填对了！"),
])


def next_hidden(g, kind, after, min_blanks=3):
    g2 = g.copy()
    g2.cells[after[1]] = after[2]
    m = find_move(g2, "hidden:" + kind,
                  lambda m: len(g2.blanks(kind, g2.unit_of(kind, m[1]))) >= min_blanks and len(g2.cands(m[1])) >= 2)
    if m is None:
        raise SystemExit("no follow-up hidden single")
    return g2, m


W2, WM2 = next_hidden(W, "box", WM)
W3, WM3 = next_hidden(W2, "row", WM2)
S16["steps"] += [
    step("再来一个：亮起来的数字，在圈出来的这一宫里能放在哪？",
         marks=[unit_mark(W2, "box", WM2[1]), f"val:{WM2[2]}"],
         task=pick(f"where:{WM2[2]}:{unit_mark(W2, 'box', WM2[1])}", "hidden:box"),
         hint="看看亮起来的数字挡住了这一宫的哪几行、哪几列。", ok="找到了！"),
    step("这次看一行：亮起来的数字，在这一行里能放在哪？",
         board=W3, marks=[unit_mark(W3, "row", WM3[1]), f"val:{WM3[2]}"],
         task=pick(f"where:{WM3[2]}:{unit_mark(W3, 'row', WM3[1])}", "hidden:row"),
         hint="这一行里，哪些格子的列或者宫里已经有这个数字了？剩下的那个就是答案。", ok="太厉害了！"),
]


def naked_board(sol, blanks, seed):
    """有一个格子只剩一个能填（而且它的行、列、宫都还空着好几个），还有一个格子能填两三个"""
    def ok(g):
        return pick_naked(g) is not None and pick_pair(g) is not None

    g = carve(sol, blanks, seed, ok)
    return g, pick_pair(g), pick_naked(g)


def pick_naked(g):
    for c in range(g.n * g.n):
        if g.cells[c] == 0 and len(g.cands(c)) == 1 and \
                all(len(g.blanks(k, g.unit_of(k, c))) >= 3 for k in ("row", "col", "box")) and \
                all(mv[3] == "naked" for mv in g.moves() if mv[1] == c):
            return c
    return None


def pick_pair(g):
    for c in range(g.n * g.n):
        if g.cells[c] == 0 and len(g.cands(c)) in (2, 3):
            return c
    return None


X, XP, XN = naked_board(P9, 44, 61)
S17 = lesson("s17", "小笔记", "pencil", "用小笔记记下一个格子能填哪些数字", [
    step("有的格子一下子想不出来。可以写小笔记：把能填的数字都小小地写在格子里。", board=X,
         marks=[f"notes:{X.name(XP)}:{''.join(map(str, X.cands(XP)))}"]),
    step("看，这个格子能填的就这几个。现在轮到你：发光的格子能填哪些数字？都点出来！",
         marks=[f"notes:{X.name(XP)}:{''.join(map(str, X.cands(XP)))}"], task=cands(f"cands:{X.name(XN)}"),
         hint="看看它这一行、这一列、这一宫，已经有的都不能填，剩下的都记下来。", ok="对，只有这一个！"),
    step("笔记里只剩一个数字，就可以放心地填上了！", task=fill(f"cell:{X.name(XN)}", "naked"),
         hint="这个格子的笔记里只有一个数字，把它填上。", ok="填对了！"),
    step("在闯关的时候，点『笔记』按钮，就能写小笔记；再点一次，就回到填数字。"),
])

Y1 = P9.copy()
Y1.cells[2 * 9 + 4] = P9.cells[2 * 9 + 6]          # 第三行：第五格写成了第七格的数
Y2 = P9.copy()
Y2.cells[6 * 9 + 1] = P9.cells[8 * 9 + 0]          # 第七行第二格写成了同一宫里另一格的数
S18 = lesson("s18", "检查", "checkmark.seal.fill", "填完以后检查每一行、每一列、每一宫", [
    step("填完了还要检查：每一行、每一列、每一宫，1 到 9 是不是都只有一个。", board=P9),
    step("这一盘里有一个填重复了，把它找出来！", board=Y1, task=pick("clash"),
         hint="一行一行看，哪一行里有两个一样的数字？", ok="找到了！这两个数字挤在同一行里。"),
    step("再检查一盘！", board=Y2, task=pick("clash"),
         hint="一宫一宫看，哪一宫里有两个一样的数字？", ok="对！"),
    step("闯关的时候，填错的格子会变成红色。别担心，擦掉再想一想就好。"),
])

NINE = {"id": "nine", "title": "九宫格", "subtitle": "真正的数独", "art": "tutor_sudoku_nine",
        "lessons": [S14, S15, S16, S17, S18]}

course = {"game": "sudoku", "title": "数独教学", "tracks": [BASIC, UNIQUE, EXCLUDE, NINE]}

if __name__ == "__main__":
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(course, f, ensure_ascii=False, indent=1)
    n = sum(len(l["steps"]) for t in course["tracks"] for l in t["lessons"])
    print(OUT, "lessons", sum(len(t["lessons"]) for t in course["tracks"]), "steps", n)
