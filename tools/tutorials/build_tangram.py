#!/usr/bin/env python3
"""生成七巧板的教学内容：RanranGame/Tutorials/tangram.json。课程规划见 docs/tutorial-tangram.md。

改了这里以后：
  1. python3 tools/tutorials/build_tangram.py
  2. zsh tools/tangram/test.sh（每道题都有答案、每种练习变换也有答案、台词读音）
  3. 重新生成配音（tools/voice/）

局面的写法见 RanranGame/Games/Tangram/Logic/TangramLessonLogic.swift。这里用板子的顶点来写（和 tools/tangram/figures.py 一样，
大正方形边长 4，'r' 是 √2），脚本认出每块是哪块板、怎么转，写成 "L.0.0.0.0.0.0" 这样的格式。
题目：fill = 把托盘里的板子全部放进影子正好盖满（任何正确拼法都算对）；pick:L = 点一下大三角形（L M S Q P）。
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "tangram"))
from geom import identify, pt  # noqa: E402
import figures_tool  # noqa: E402

OUT = os.path.join(ROOT, "RanranGame", "Tutorials", "tangram.json")
FIGS = {f.id: f for f in figures_tool.load()}


def enc_placement(kind, k, f, t):
    (mx, nx), (my, ny) = t[0].lattice(), t[1].lattice()
    return f"{kind}.{k}.{1 if f else 0}.{mx}.{nx}.{my}.{ny}"


def piece(*vs):
    """一块板子（顶点）→ (kind, k, f, t)"""
    r = identify([pt(x, y) for x, y in vs])
    if r is None:
        raise ValueError(f"not a piece: {vs}")
    return r


def fig_pieces(fid, kinds=None):
    """图形里的板子；kinds 给了就只要这几块（"S2" = 图形里的第二块小三角）"""
    ps = list(FIGS[fid].placements)
    if kinds is None:
        return ps
    marked = list(enumerate(ps))
    out = []
    for k in kinds:
        kind, nth = k[0], int(k[1:] or 1)
        same = [m for m in marked if m[1][0] == kind]
        pick = same[nth - 1] if nth <= len(same) else same[0]
        marked.remove(pick)
        out.append(pick[1])
    return out


def fig_rest(fid, kinds):
    """图形里除了 kinds 这几块以外的板子"""
    taken = fig_pieces(fid, kinds)
    rest = list(FIGS[fid].placements)
    for t in taken:
        rest.remove(t)
    return rest


def board(target, fixed=(), tray="std", lines=False, show=False):
    """tray: "std" 全部摆正（不转）；"pre" 和影子里一样的方向；或者 [(kind, k, flip), ...]"""
    target = list(target)
    fixed = list(fixed)
    parts = ["target=" + "|".join(enc_placement(*p) for p in target)]
    if fixed:
        parts.append("fixed=" + "|".join(enc_placement(*p) for p in fixed))
    movable = [p for p in target if not any(p[0] == q[0] and p[1:] == q[1:] for q in fixed)]
    if show:
        tray_items = []
    elif tray == "std":
        tray_items = [(p[0], 0, 0) for p in movable]
    elif tray == "pre":
        tray_items = [(p[0], p[1], 1 if p[2] else 0) for p in movable]
    else:
        tray_items = tray
    order = {"L": 0, "M": 1, "Q": 2, "P": 3, "S": 4}
    tray_items = sorted(tray_items, key=lambda t: order[t[0]])
    if tray_items:
        parts.append("tray=" + ",".join(f"{k}.{r}.{f}" for k, r, f in tray_items))
    if lines:
        parts.append("lines=1")
    if show:
        parts.append("show=1")
    return ";".join(parts)


FULL_SET = [("L", 0, 0), ("L", 0, 0), ("M", 0, 0), ("Q", 0, 0), ("P", 0, 0), ("S", 0, 0), ("S", 0, 0)]


def step(say, board=None, task=None, hint=None, ok=None, drill=None):
    s = {"say": say}
    if drill:
        s["drill"] = drill
    if board is not None:
        s["board"] = board
    if task:
        s["task"] = task
    if hint:
        s["hint"] = hint
    if ok:
        s["ok"] = ok
    return s


def fill():
    return {"type": "fill", "rule": "fill"}


def pick(letter):
    return {"type": "pick", "rule": f"pick:{letter}"}


def lesson(lid, title, icon, learned, steps):
    return {"id": lid, "title": title, "icon": icon, "learned": learned, "steps": steps}


# ----------------------------------------------------------------------------- 常用的形状

L_UP = piece((0, 0), (4, 0), (2, 2))            # 大三角，尖朝上
L_RIGHT = piece((0, 0), (0, 4), (2, 2))         # 大三角，尖朝右（要转）
L_TILT = piece((0, 0), ("2r", 0), (0, "2r"))    # 大三角，直角在左下（转 45°）
M_STD = piece((0, 0), (2, 0), (0, 2))
M_TURN = piece((0, 0), (2, 0), (2, 2))          # 中三角，直角在右下
S_UP = piece((0, 0), (2, 0), (1, 1))
S_TILT = piece((0, 0), ("r", 0), (0, "r"))      # 小三角，直角在左下（转 45°）
Q_STD = piece((0, 1), (1, 0), (2, 1), (1, 2))
Q_TILT = piece((0, 0), ("r", 0), ("r", "r"), (0, "r"))  # 正方形摆正（转 45°）
P_STD = piece((0, 0), (2, 0), (3, 1), (1, 1))
P_FLIP = piece((0, 0), (2, 0), (1, 1), (-1, 1))         # 平行四边形翻过来
P_FLIP_UP = piece((0, 0), (0, 2), (1, 3), (1, 1))       # 翻过来再立起来
P_UP = piece((0, 0), (0, 2), (-1, 3), (-1, 1))          # 立起来（不用翻）

# ----------------------------------------------------------------------------- 第一组：认识七巧板

T1 = lesson("t1", "七块板子", "square.grid.3x3.fill", "七块板子的名字", [
    step("七巧板一共有七块板子，它们能拼成一个大正方形。我们先来认识每一块。",
         board=board(fig_pieces("square"), show=True, lines=True)),
    step("最大的两块三角形，叫大三角形。点一点大三角形！",
         board=board(fig_pieces("square"), tray=FULL_SET, lines=True), task=pick("L"),
         hint="找最大的那块三角形，有两块哦。", ok="对，这是大三角形！"),
    step("比它小一点的三角形只有一块，叫中三角形。点一点它！", task=pick("M"),
         hint="中三角形比大三角形小，比小三角形大。", ok="这就是中三角形。"),
    step("最小的两块三角形，叫小三角形。点一点小三角形！", task=pick("S"),
         hint="找最小的三角形。", ok="对啦，小三角形！"),
    step("四条边一样长、四个角都一样的，叫正方形。点一点正方形！", task=pick("Q"),
         hint="找四条边一样长的那一块。", ok="正方形找到啦！"),
    step("最后一块斜斜的，叫平行四边形。点一点平行四边形！", task=pick("P"),
         hint="找那块斜斜的、像被推歪了的板子。", ok="七块板子你都认识啦！"),
])

T2 = lesson("t2", "拖一拖", "hand.draw.fill", "把板子拖进影子里", [
    step("黑黑的是影子。用手指按住一块板子，拖到影子上，对齐了它会自己吸进去。"
         "把大三角形拖进影子里！",
         board=board([L_UP], tray="pre", lines=True), task=fill(),
         hint="按住托盘里的大三角形，别松手，拖到影子上面再松开。", ok="吸进去啦！"),
    step("这次是正方形。", board=board([Q_STD], tray="pre", lines=True), task=fill(),
         hint="把正方形拖到影子上，对准了再松手。", ok="放得真准！"),
    step("两块一起：大三角形和中三角形，按影子里的线放好。",
         board=board([L_UP, piece((4, 0), (6, 0), (4, 2))], tray="pre", lines=True), task=fill(),
         hint="先看线，大的放大的地方，小的放小的地方。", ok="影子填满啦！"),
    step("放错了也没关系，再按住它拖到别的地方就行。三块一起试试！",
         board=board([L_UP, piece((4, 0), (6, 0), (4, 2)), piece((0, 0), (-2, 0), (-1, 1))], tray="pre", lines=True),
         task=fill(), hint="一块一块来，每块都找和它一样的形状。", ok="三块都放好了！"),
])

T3 = lesson("t3", "转一转", "arrow.clockwise", "点一下板子，它就会转", [
    step("这块大三角形的方向和影子不一样。轻轻点一下板子，它就会转一下。",
         board=board([L_RIGHT], tray="std", lines=True)),
    step("一直点，转到和影子一样的方向，再拖进去！", task=fill(),
         hint="看影子的尖尖朝哪边，把板子的尖尖也转到那边。", ok="转对了，也放对了！"),
    step("中三角形也要转一转方向。", board=board([M_TURN], tray="std", lines=True), task=fill(),
         hint="影子的直角在哪个角，板子的直角也要转到那里。", ok="真棒！"),
    step("这块小三角形要斜着放，点一下转一点点，多点几下试试。",
         board=board([S_TILT], tray="std", lines=True), task=fill(),
         hint="每点一下转一点点，转到和影子一模一样再拖进去。", ok="一点点转，转对了！"),
    step("正方形也能转。把它摆正，放进影子里。",
         board=board([Q_TILT], tray="std", lines=True), task=fill(),
         hint="点一下正方形，它会从菱形变成摆正的样子。", ok="正方形摆正啦！"),
])

T4 = lesson("t4", "翻一翻", "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", "平行四边形可以翻面", [
    step("平行四边形很特别：怎么转都放不进这个影子，因为它要翻一个面。",
         board=board([P_FLIP], tray="std", lines=True)),
    step("按「翻面」按钮，平行四边形就翻过来了。翻好再拖进影子里！", task=fill(),
         hint="先按翻面按钮，再把它拖进去。", ok="翻过来就放进去了！"),
    step("这个影子要先翻面，再转一转。", board=board([P_FLIP_UP], tray="std", lines=True), task=fill(),
         hint="翻面以后，再点一点它，转到和影子一样。", ok="又翻又转，真厉害！"),
    step("这个影子不用翻面，只要转一转。你看出来了吗？",
         board=board([P_UP], tray="std", lines=True), task=fill(),
         hint="先转一转试试，转不进去再翻面。", ok="对，这次不用翻！"),
])

T5 = lesson("t5", "拼回大正方形", "square.fill", "七块板子能拼成一个大正方形", [
    step("看，七块板子是这样拼成大正方形的：两块大三角形占了一半，五块小板子占了另一半。",
         board=board(fig_pieces("square"), show=True, lines=True)),
    step("现在把七块板子拼回大正方形。先帮你放好了四块，剩下三块交给你！",
         board=board(fig_pieces("square"), fixed=fig_pieces("square", ["L", "L", "M", "Q"]), tray="std", lines=True),
         task=fill(), hint="看剩下的地方：两个小三角，一个平行四边形。", ok="大正方形拼好啦！"),
    step("这次七块全部交给你。先放两块大三角形，再放别的。",
         board=board(fig_pieces("square"), tray="std", lines=True), task=fill(),
         hint="两块大三角形占了正方形的一半。先放它们，剩下的就好拼了。", ok="你自己拼出了大正方形！"),
    step("记住：大块先放，小块后放，拼起来最快。"),
])

# ----------------------------------------------------------------------------- 第二组：小块拼大块

two_s_square = [S_UP, piece((0, 0), (2, 0), (1, -1))]
two_s_tri = [S_UP, piece((0, 0), (1, 1), (0, 2))]
two_s_para = [S_UP, piece((2, 0), (3, 1), (1, 1))]

C1 = lesson("c1", "两个小三角", "triangle.fill", "两个小三角形能拼成正方形、中三角形和平行四边形", [
    step("两个小三角形拼在一起，能变出别的形状。这个影子里没有线了，要自己想。",
         board=board(two_s_square, tray="std")),
    step("用两个小三角形，拼出这个正方形！", task=fill(),
         hint="两个小三角形的长边对着长边。", ok="两个小三角形，拼成了正方形！"),
    step("还是两个小三角形，这次拼一个大一点的三角形。", board=board(two_s_tri, tray="std"), task=fill(),
         hint="让两个小三角形的直角边贴在一起。", ok="和中三角形一样大！"),
    step("再拼一个平行四边形。", board=board(two_s_para, tray="std"), task=fill(),
         hint="一个小三角形朝上，另一个翻个方向朝下。", ok="平行四边形也拼出来了！"),
    step("中三角形、正方形、平行四边形，都正好是两个小三角形那么大。"),
])

L_BY_M = [piece((0, 0), (2, 0), (2, 2)), piece((2, 0), (3, 1), (2, 2)), piece((2, 0), (4, 0), (3, 1))]
L_BY_Q = [piece((0, 0), (2, 0), (1, 1)), piece((1, 1), (2, 0), (3, 1), (2, 2)), piece((2, 0), (4, 0), (3, 1))]
L_BY_P = [piece((0, 0), (2, 0), (3, 1), (1, 1)), piece((2, 0), (4, 0), (3, 1)), piece((1, 1), (3, 1), (2, 2))]

C2 = lesson("c2", "拼大三角形", "triangle.lefthalf.filled", "大三角形可以用小块拼出来", [
    step("大三角形可以用小板子拼出来。用中三角形和两个小三角形，拼出这个大三角形！",
         board=board(L_BY_M, tray="std", lines=True), task=fill(),
         hint="中三角形放一半，两个小三角形放另一半。", ok="拼出了大三角形！"),
    step("换成正方形和两个小三角形，也能拼出大三角形。这次没有线了！",
         board=board(L_BY_Q, tray="std"), task=fill(),
         hint="正方形放在中间，两个小三角形放在两个尖角。", ok="又拼出来了！"),
    step("平行四边形和两个小三角形，也行！",
         board=board(L_BY_P, tray="std"), task=fill(),
         hint="平行四边形放在底下，小三角形一个放在尖角，一个放在顶上。", ok="三种拼法你都会啦！"),
    step("一样大的形状可以互相换。拼不出来的时候，想想能不能用别的板子换一换。"),
])

TWO_L_SQUARE = [piece((0, 0), (4, 0), (2, 2)), piece((0, 0), (4, 0), (2, -2))]
TWO_L_TRI = [piece((0, 0), (4, 0), (2, 2)), piece((0, 0), (2, 2), (0, 4))]
TWO_L_PARA = [piece((0, 0), (4, 0), (2, 2)), piece((2, 2), (4, 0), (6, 2))]

C3 = lesson("c3", "两个大三角", "square.on.square", "两个大三角形能拼成正方形、三角形和平行四边形", [
    step("两个大三角形拼在一起，能拼成三种大形状。先拼一个大正方形！",
         board=board(TWO_L_SQUARE, tray="std"), task=fill(),
         hint="两个大三角形的长边贴在一起。", ok="拼成正方形了！"),
    step("再拼一个更大的三角形。", board=board(TWO_L_TRI, tray="std"), task=fill(),
         hint="让两个大三角形的短边贴在一起。", ok="大三角形拼好了！"),
    step("最后拼一个平行四边形。", board=board(TWO_L_PARA, tray="std"), task=fill(),
         hint="一个尖朝上，一个尖朝下，并排放。", ok="平行四边形！"),
    step("很多图形里都藏着这三种拼法。看到它们，就知道两块大三角形放哪里了。"),
])

HALF = fig_rest("triangle", ["L", "L"])  # 大三角形图形去掉两块大三角，剩下的五块正好是一个三角形

C4 = lesson("c4", "五块小板子", "square.stack.3d.up.fill", "五块小板子能拼成一个三角形", [
    step("除了两块大三角形，剩下五块小板子也能拼成一个三角形。照着线拼拼看！",
         board=board(HALF, tray="std", lines=True), task=fill(),
         hint="中三角形放在直角那里，再沿着长边放正方形和小三角形。", ok="五块拼成了一个三角形！"),
    step("这次没有线了。记得刚才是怎么拼的吗？",
         board=board(HALF, tray="std"), task=fill(),
         hint="中三角形放在直角那里，平行四边形放在尖尖旁边。", ok="不看线也拼出来了！"),
    step("最后把七块都用上：两个大三角形加五块小板子，拼一个更大的三角形。",
         board=board(fig_pieces("triangle"), tray="std", lines=True), task=fill(),
         hint="两块大三角形拼成一半，五块小板子拼成另一半。", ok="七块拼成一个大三角形！"),
    step("七块板子，就是两块大三角形加上五块小板子。很多图形都是这样分成两半拼的。"),
])

# ----------------------------------------------------------------------------- 第三组：看图的窍门

K1 = lesson("k1", "先找大三角", "eye.fill", "先想两块大三角形放在哪里", [
    step("影子里没有线的时候，先想：两块最大的三角形放在哪里？找到它们，剩下的就容易了。",
         board=board(fig_pieces("cat"), fixed=fig_rest("cat", ["L", "L"]), tray="std")),
    step("小猫的身子是两块大三角形，把它们放进去！", task=fill(),
         hint="小猫的身子是一个很大的三角形，两块大三角形拼起来正好。", ok="小猫有身子啦！"),
    step("这只小鸭子，大三角形藏在哪里？",
         board=board(fig_pieces("duck"), fixed=fig_rest("duck", ["L", "L"]), tray="std"), task=fill(),
         hint="鸭子的身子最大，两块大三角形一块尖朝上，一块尖朝下。", ok="找到啦！"),
    step("小房子的屋顶最大，你来试试。",
         board=board(fig_pieces("house"), fixed=fig_rest("house", ["L", "L"]), tray="std"), task=fill(),
         hint="屋顶是一个大三角形，用两块大三角形拼。", ok="屋顶盖好啦！"),
])

K2 = lesson("k2", "看尖角", "triangle", "尖尖的角要放三角形", [
    step("影子里尖尖的角，只有三角形的尖角才放得进去；方方的角，可以放正方形或者三角形的直角。",
         board=board(fig_pieces("boat"), fixed=fig_pieces("boat", ["L", "L", "M"]), tray="std")),
    step("帆船的船身还空着。看看两头尖尖的角，放什么？", task=fill(),
         hint="船身用两个小三角形、一个正方形、一个平行四边形。尖尖的角放三角形的尖角。", ok="船身拼好了，可以开船啦！"),
    step("这棵小树，尖尖的树顶放什么？",
         board=board(fig_pieces("tree"), fixed=fig_pieces("tree", ["L", "L", "M", "P"]), tray="std"), task=fill(),
         hint="树顶上是一个正方形；两个小三角形在下面一层的中间。", ok="小树长好了！"),
    step("小鱼的尾巴是什么形状？",
         board=board(fig_pieces("fish"), fixed=fig_pieces("fish", ["L", "L", "P"]), tray="std"), task=fill(),
         hint="尾巴是一个大一点的三角形，用中三角形。", ok="小鱼会游了！"),
])

K3 = lesson("k3", "剩下的是什么形状", "puzzlepiece.fill", "看剩下的地方是什么形状，再挑板子", [
    step("拼到最后，看看剩下的地方是什么形状，再挑一样的板子放进去。",
         board=board(fig_pieces("square"), fixed=fig_rest("square", ["Q", "P"]), tray="std")),
    step("剩下一个菱形和一个斜斜的形状，放什么？", task=fill(),
         hint="菱形放正方形，斜斜的放平行四边形，可能要翻个面。", ok="对，形状一样就放得进去！"),
    step("小兔子还差两块。", board=board(fig_pieces("rabbit"), fixed=fig_rest("rabbit", ["Q", "S"]), tray="std"),
         task=fill(), hint="头是一个菱形，头旁边的小耳朵是一个小三角形。", ok="小兔子拼好啦！"),
    step("天鹅还差三块，仔细看剩下的形状。",
         board=board(fig_pieces("swan"), fixed=fig_rest("swan", ["P", "Q", "S2"]), tray="std"), task=fill(),
         hint="长长的脖子是平行四边形，头是正方形，嘴巴是小三角形。", ok="天鹅拼好了，真漂亮！"),
])

K4 = lesson("k4", "自己拼一个", "star.fill", "大块先放、看尖角、看剩下的形状", [
    step("把三个窍门都用上：先放大三角形，再看尖角，最后看剩下的形状。拼一座小房子！",
         board=board(fig_pieces("house"), tray="std"), task=fill(),
         hint="屋顶是两块大三角形；房子下面是一个正方形，用五块小板子拼。", ok="小房子拼好啦！"),
    step("再拼一个火箭！", board=board(fig_pieces("rocket"), tray="std"), task=fill(),
         hint="两块大三角形是火箭两边的翅膀，中三角形是火箭头。", ok="火箭要飞上天啦！"),
    step("最后，拼一只小猫。", board=board(fig_pieces("cat"), tray="std"), task=fill(),
         hint="身子是两块大三角形，头是正方形，耳朵是两个小三角形。", ok="你自己拼出了小猫！"),
    step("以后看到没有线的影子，就用这三个窍门：大块先放，看尖角，看剩下的形状。"),
])

COURSE = {
    "game": "tangram",
    "title": "七巧板教学",
    "tracks": [
        {"id": "basic", "title": "认识七巧板", "subtitle": "七块板子叫什么，怎么拖、怎么转、怎么翻",
         "art": "tutor_tangram_basic", "lessons": [T1, T2, T3, T4, T5]},
        {"id": "combine", "title": "小块拼大块", "subtitle": "一样大的形状可以互相换",
         "art": "tutor_tangram_combine", "lessons": [C1, C2, C3, C4]},
        {"id": "tricks", "title": "看图的窍门", "subtitle": "没有线的影子也会拼",
         "art": "tutor_tangram_tricks", "lessons": [K1, K2, K3, K4]},
    ],
}

if __name__ == "__main__":
    assert P_FLIP[2] and P_FLIP_UP[2] and not P_UP[2], "翻面的题要真的需要翻面"
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(COURSE, f, ensure_ascii=False, indent=1)
        f.write("\n")
    n = sum(len(t["lessons"]) for t in COURSE["tracks"])
    print("wrote", OUT, n, "lessons")
