#!/usr/bin/env python3
"""生成编程的教学内容：RanranGame/Tutorials/coding.json。

改了这里以后：
  1. python3 tools/tutorials/build_coding.py
  2. zsh tools/coding/test.sh（每道题 × 四种样子都由解释器判出唯一的答案；claim 里写的事实要对得上）
  3. 重新生成配音（tools/voice/）

写法（见 RanranGame/Games/Coding/Logic/CodingLessonLogic.swift 开头的说明）：
  board    花园，行用 / 隔开，好几个花园用 | 隔开。. 草地  # 石头  C 胡萝卜  B 小兔  H 家  b 蓝花  y 黄花
  program  程序的文字写法：U D L R 箭头；3[R U] 重复；S T 绝招（S=R R U）；?b[U] ?y[D] 如果；*[...] 一直重复；栏用 ; 隔开
  limits   "main=6 loop=3 proc=4 when=1 | U D L R rep S T ?b ?y *"（几格、积木盒里有什么）
  格子的名字：列 a b c …（从左到右），行 1 2 3 …（从上到下）
题目：build / fix（answer = 参考程序）· predict（点终点）· spot（点错的那一块）· choose（options 用 | 隔开）· count（template 里 # 是数，counts）
claim：课文 / 提示里说到的事实，测试会用解释器核对（cell=c3、option=2、answer=4、outcome=bump、culprit=0:4、spot=1:1、size=6、count=4）

每道题都要写 drill（练习时代替课文，不能提方向、位置、数字），练习时花园、程序里的箭头会左右 / 上下翻。
数字在要朗读的句子里一律写成汉字。
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "RanranGame", "Tutorials")


def step(say, board=None, program=None, limits=None, run=False, marks=None, task=None, hint=None, ok=None, drill=None):
    s = {"say": say}
    if drill: s["drill"] = drill
    if board is not None: s["board"] = board
    if marks: s["marks"] = marks
    extra = {}
    if program is not None: extra["program"] = program
    if limits is not None: extra["limits"] = limits
    if run: extra["run"] = "yes"
    if extra: s["extra"] = extra
    if task: s["task"] = task
    if hint: s["hint"] = hint
    if ok: s["ok"] = ok
    return s


def task(kind, claim=None, **extra):
    e = {k: str(v) for k, v in extra.items() if v is not None}
    if claim: e["claim"] = claim
    t = {"type": kind, "rule": kind}
    if e: t["extra"] = e
    return t


def build(answer, need=None, mx=None, claim=None):
    return task("build", claim, answer=answer, need=need, max=mx)


def fix(answer, claim=None):
    return task("fix", claim, answer=answer)


def predict(cell):
    return task("predict", f"cell={cell}")


def spot(ref, claim=None):
    return task("spot", f"spot={ref}" + ("," + claim if claim else ""))


def choose(options, option):
    return task("choose", f"option={option}", options="|".join(options))


def count(template, counts, answer):
    return task("count", f"answer={answer}", template=template, counts="|".join(str(c) for c in counts))


def lim(main, palette="U D L R", loop=None, proc=None, when=None):
    parts = [f"main={main}"]
    if loop: parts.append(f"loop={loop}")
    if proc: parts.append(f"proc={proc}")
    if when: parts.append(f"when={when}")
    return " ".join(parts) + " | " + palette


ARROWS = "U D L R"
REP = "U D L R rep"
FN = "U D L R S"
FNREP = "U D L R rep S"

DR_BUILD = "排一个程序，带小兔吃到胡萝卜！"
DR_REP = "用「重复」排一个程序，带小兔吃到胡萝卜！"
DR_FN = "用绝招排一个程序，带小兔吃到胡萝卜！"
DR_IF = "用「如果」排一个程序，每个花园都要过！"
DR_FIX = "程序里有一只小虫子，把它改对！"
DR_PREDICT = "点一点，小兔最后会站在哪儿？"
DR_SPOT = "点出程序里错的那一块！"
DR_CHOOSE = "哪一个程序能过关？点一下！"
DR_COUNT = "要几次才够？选一个！"
DR_STEPS = "要走多远才够？选一个！"

# ----------------------------------------------------------------------------- 基础：指令和顺序

basic = [
    {
        "id": "listen", "title": "小兔听指令", "icon": "arrow.right.square.fill",
        "learned": "用箭头让小兔走路",
        "steps": [
            step("这是小兔的花园。小兔想吃胡萝卜，可是它要听你的指令才会走。", "..../BC../....", program="", limits=lim(3)),
            step("积木盒里的箭头，点一下就排进程序里。一个箭头，小兔走一格。点往右的箭头，再点「开始」。",
                 "..../BC../....", program="", limits=lim(3),
                 task=build("R"), hint="点积木盒里往右的箭头，它会落进闪着的空位里。再点「开始」。", drill=DR_BUILD),
            step("胡萝卜远一点，就多排几个箭头。小兔要走三格才到胡萝卜。", "..../B..C/....", program="", limits=lim(4),
                 task=build("R R R", claim="size=3"), hint="排三个往右的箭头，再点「开始」。", drill=DR_BUILD),
            step("排错了也没关系：点一下程序里的积木，它就被拿掉了。这一次，胡萝卜在小兔的上面。", ".C./.../.B.", program="", limits=lim(3),
                 task=build("U U", claim="size=2"), hint="要用往上的箭头，排两个。", drill=DR_BUILD),
        ],
    },
    {
        "id": "order", "title": "排好队再出发", "icon": "list.number",
        "learned": "程序从第一块做到最后一块",
        "steps": [
            step("小兔会从第一块积木开始，一块一块往后做。看，它先往右，再往右，最后往下。", "..../B.../..C.", program="R R D", limits=lim(3), run=True),
            step("先别跑！看着程序想一想：小兔最后会站在哪一格？点那一格。", "..../B.../...C", program="R D R", limits=lim(3),
                 task=predict("c3"), hint="跟着积木一块一块走：先往右，再往下，再往右。", drill=DR_PREDICT),
            step("这三个程序用的积木一样多，只是顺序不同。哪一个能吃到胡萝卜？", ".#C./B.../....", limits=lim(3),
                 task=choose(["R R U", "U R R", "R U R"], 1), hint="石头挡在上面，要先往右走两格，再往上。", drill=DR_CHOOSE),
            step("现在你来排。先想好先往哪边走，别撞到石头。", "..C./.#../B...", program="", limits=lim(5),
                 task=build("R R U U", claim="size=4"), hint="石头在中间，可以先往右走两格，再往上走两格。", drill=DR_BUILD),
        ],
    },
    {
        "id": "turn", "title": "拐个弯", "icon": "arrow.turn.up.right",
        "learned": "把几个方向接起来拐弯",
        "steps": [
            step("路不一定是直的。几个方向的箭头接起来，小兔就能拐弯。排之前，先用手指在花园里比一比路。", "...C/..../B...", program="U U R R R", limits=lim(6), run=True),
            step("看着程序想一想，小兔最后站在哪一格？", "..../..../B..C", program="U U R R R", limits=lim(6),
                 task=predict("d1"), hint="先往上走两格，再往右走三格。", drill=DR_PREDICT),
            step("你来排：胡萝卜在右上角。", "...C/..../B...", program="", limits=lim(7),
                 task=build("R R R U U", claim="size=5"), hint="往右走三格，再往上走两格。", drill=DR_BUILD),
            step("再来一个。这一次胡萝卜在下面。", "B.../...#/..C.", program="", limits=lim(6),
                 task=build("D D R R", claim="size=4"), hint="可以先往下走两格，再往右走两格。", drill=DR_BUILD),
        ],
    },
    {
        "id": "rock", "title": "绕开石头", "icon": "mountain.2.fill",
        "learned": "绕开石头走",
        "steps": [
            step("石头走不上去。小兔要是往石头上走，就会撞到，程序也就停在那一块。", "..../B#C./....", program="R R", limits=lim(3), run=True),
            step("这个程序有一块错了，小兔撞到了。看看它是在哪一块撞上去的？点出那一块。", "..../B.#C", program="U R R R U", limits=lim(6),
                 task=spot("0:4", claim="outcome=bump,culprit=0:4"), hint="跟着积木走一遍：最后一块要往下，才回到胡萝卜那一排。", drill=DR_SPOT),
            step("你来排。石头挡在中间，从旁边绕过去。", "B..../.##../....C", program="", limits=lim(8),
                 task=build("R R R D D R", claim="size=6"), hint="可以先往右走三格，再往下走两格，最后往右一格。", drill=DR_BUILD),
            step("最后一个，小心别撞到石头。", "...C/.##./B...", program="", limits=lim(7),
                 task=build("U U R R R", claim="size=5"), hint="先往上走到最上面那一排，再往右。", drill=DR_BUILD),
        ],
    },
    {
        "id": "count", "title": "先数再排", "icon": "number.circle.fill",
        "learned": "先数清楚每段走几格",
        "steps": [
            step("路长的时候，要先数一数每一段走几格，再排积木。", "...C/..../B...", program="R R R U U", limits=lim(6)),
            step("小兔要先往右走几格，再往上走两格。往右要走几格？选一个。", "...C/..../B...", limits=lim(6),
                 task=count("R# U U", [2, 3, 4], 3), hint="用手指从小兔开始，一格一格比到胡萝卜的下面。", drill=DR_STEPS),
            step("两根胡萝卜：先吃近的那一根，路才短。", "C..../.B.../....C", program="", limits=lim(9),
                 task=build("L U R R R R D D", mx=8, claim="size=8"), hint="左上角那一根近，先吃它，再去右下角。", drill=DR_BUILD,
                 ok="先吃近的，路最短！"),
            step("这两根在同一条路上，顺路就吃掉了。", "B.C../...../....C", program="", limits=lim(8),
                 task=build("R R R R D D", claim="size=6"), hint="往右走到头，再往下。", drill=DR_BUILD),
        ],
    },
    {
        "id": "bug", "title": "捉虫子", "icon": "ladybug.fill",
        "learned": "一步一步找到错的那一块，只改那一块",
        "steps": [
            step("程序不对，是很正常的事。程序里错的地方，叫虫子。找虫子的办法是：点「一步」，看着小兔一块一块走。", "...C/B#..", program="U R R D", limits=lim(5)),
            step("这个程序走完了，可是没吃到胡萝卜。点出错的那一块。", "...C/B#..", program="U R R D", limits=lim(5),
                 task=spot("0:3", claim="outcome=end"), hint="点「一步」走一走：走到最后一块的时候，往哪边走才对？", drill=DR_SPOT),
            step("这个程序最后一块错了。把错的那一块换掉，别的都不用动。", "B..../.##../....C", program="R R R D D L", limits=lim(7),
                 task=fix("R R R D D R"), hint="点最后一块把它拿掉，再放一个往右的箭头。", drill=DR_FIX),
            step("这个程序少了一块，小兔还差一步。加上一块，让它吃到胡萝卜。", "....C/B....", program="R R R U", limits=lim(6),
                 task=fix("R R R R U"), hint="往右要走四格，程序里只有三个往右。", drill=DR_FIX, ok="虫子捉到啦！"),
        ],
    },
]

# ----------------------------------------------------------------------------- 重复

loop = [
    {
        "id": "repeat", "title": "一样的事说一遍", "icon": "repeat",
        "learned": "用「重复」把一样的事只说一遍",
        "steps": [
            step("小兔要往右走好多格，就要排好多个往右的箭头。有一个更省的办法：「重复」。", "......./B.....C", program="6[R]", limits=lim(2, REP, loop=1), run=True),
            step("「重复」积木上的数字，就是里面的积木要做几次。点那个数字，可以用加号、减号来改。", "......./B.....C", program="6[R]", limits=lim(2, REP, loop=1)),
            step("你来试一试：主程序里只有一格，要用「重复」。", "B....C/......", program="", limits=lim(1, REP, loop=1),
                 task=build("5[R]", need="rep", claim="size=2,count=5"), hint="放一个「重复」，里面放往右的箭头，再把次数改成五。", drill=DR_REP),
            step("要重复几次，小兔才能走到胡萝卜？选一个数字。", "..C/.../.../.../.B.", program="4[U] R", limits=lim(2, REP, loop=1),
                 task=count("#[U] R", [3, 4, 5], 4), hint="往上走到最上面那一排，要几格？", drill=DR_COUNT),
        ],
    },
    {
        "id": "times", "title": "重复几次", "icon": "number.square.fill",
        "learned": "数清楚格子，定重复几次",
        "steps": [
            step("次数要刚刚好：少一次，走不到；多一次，就走过头了。", "B...../....C.", program="4[R] D", limits=lim(2, REP, loop=1)),
            step("往右要重复几次，再往下一格，才能吃到胡萝卜？", "B...../....C.", limits=lim(2, REP, loop=1),
                 task=count("#[R] D", [3, 4, 5], 4), hint="胡萝卜的上面那一格，离小兔有几格？", drill=DR_COUNT),
            step("看着程序想一想，小兔最后站在哪一格？", "B.C/.../.../...", program="3[D] R", limits=lim(2, REP, loop=1),
                 task=predict("b4"), hint="先往下走三格，再往右一格。", drill=DR_PREDICT),
            step("这个程序的次数不对，改一改。", "......C/B......", program="4[R] U", limits=lim(2, REP, loop=1),
                 task=fix("6[R] U", claim="outcome=end,count=6"), hint="小兔要往右走六格，才到胡萝卜的下面。点重复上的数字改一改。", drill=DR_FIX),
        ],
    },
    {
        "id": "stairs", "title": "重复一小段", "icon": "stairs",
        "learned": "把一小段放进「重复」",
        "steps": [
            step("上楼梯是往右、往上，往右、往上……一样的一小段一直出现。把这一小段放进「重复」里。", "...C/..../..../B...", program="3[R U]", limits=lim(1, REP, loop=2), run=True),
            step("看着程序想一想，小兔最后站在哪一格？", "..../..../..../B..C", program="3[U R]", limits=lim(1, REP, loop=2),
                 task=predict("d1"), hint="往上、往右，做三次。", drill=DR_PREDICT),
            step("你来排：重复里面放两块。", "....C/...../...../...../B....", program="", limits=lim(1, REP, loop=2),
                 task=build("4[R U]", need="rep", claim="size=3,count=4"), hint="一小段是往右、往上，放进重复里，做四次。", drill=DR_REP),
            step("这一次是下楼梯。", "B..../...../...../...../....C", program="", limits=lim(1, REP, loop=2),
                 task=build("4[R D]", need="rep", claim="size=3,count=4"), hint="一小段是往右、往下，做四次。", drill=DR_REP),
        ],
    },
    {
        "id": "pattern", "title": "找一样的一段", "icon": "square.stack.3d.up.fill",
        "learned": "在长长的路里找出一样的一段",
        "steps": [
            step("长长的路里，常常藏着完全一样的一段。先找出这一段，再用重复。", "......C/......./......./B......", program="3[R R U]", limits=lim(1, REP, loop=3), run=True),
            step("哪一个程序能吃到胡萝卜？", "......C/......./......./B......", limits=lim(1, REP, loop=3),
                 task=choose(["3[R U]", "3[R R U]", "3[R U U]"], 2), hint="一小段是往右、往右、往上。", drill=DR_CHOOSE),
            step("你来排：找出一样的那一段。", "B....../......./......./......C", program="", limits=lim(1, REP, loop=3),
                 task=build("3[R R D]", need="rep", claim="size=4"), hint="一小段是往右、往右、往下，做三次。", drill=DR_REP),
            step("再找一个。", "..C/.../.../.../B..", program="", limits=lim(1, REP, loop=3),
                 task=build("2[U U R]", need="rep", claim="size=4"), hint="一小段是往上、往上、往右，做两次。", drill=DR_REP),
        ],
    },
    {
        "id": "mix", "title": "重复再加几步", "icon": "plus.square.fill",
        "learned": "重复前后还能接别的积木",
        "steps": [
            step("重复的前面和后面，还可以接别的积木，也可以再接一个重复。", "B.../..../...C", program="3[R] 2[D]", limits=lim(2, REP, loop=1), run=True),
            step("看着程序想一想，小兔最后站在哪一格？", "..../B..C", program="U 3[R]", limits=lim(2, REP, loop=1),
                 task=predict("d1"), hint="先往上一格，再往右走三格。", drill=DR_PREDICT),
            step("你来排：用两个重复。", "B.../..../...C", program="", limits=lim(2, REP, loop=1),
                 task=build("3[R] 2[D]", need="rep", claim="size=4"), hint="先往右走三格，再往下走两格：一个重复管一段。", drill=DR_REP),
            step("小兔下面是石头，先往右一步，再用重复往上。", ".C../..../..../#.../B...", program="", limits=lim(2, REP, loop=1),
                 task=build("R 4[U]", need="rep", claim="size=3,count=4"), hint="先放一个往右的箭头，再放重复，里面放往上，做四次。", drill=DR_REP),
        ],
    },
    {
        "id": "loopbug", "title": "给重复捉虫", "icon": "ladybug.circle.fill",
        "learned": "找到重复里的虫子",
        "steps": [
            step("重复里要是有虫子，每一次都会错。常见的虫子有两种：次数不对，或者里面的顺序反了。", "...C/..../..../B...", program="2[R U]", limits=lim(1, REP, loop=2)),
            step("这个程序，小兔还没走到。点出错的那一块。", "...C/..../..../B...", program="2[R U]", limits=lim(1, REP, loop=2),
                 task=spot("0:0", claim="outcome=end"), hint="重复的次数对不对？楼梯有三级。", drill=DR_SPOT),
            step("这个重复里的顺序反了，小兔一出发就撞到石头。改一改。", "...C/..../#.../B...", program="3[U R]", limits=lim(1, REP, loop=2),
                 task=fix("3[R U]", claim="outcome=bump"), hint="小兔头上是石头，要先往右，再往上。把里面的两块换一换。", drill=DR_FIX),
            step("最后一个：小兔走过头了。", "....C./B.....", program="5[R] U", limits=lim(2, REP, loop=1),
                 task=fix("4[R] U", claim="outcome=end,count=4"), hint="多走了一格，把次数改小一点。", drill=DR_FIX),
        ],
    },
]

# ----------------------------------------------------------------------------- 绝招

func = [
    {
        "id": "star", "title": "教小兔一个绝招", "icon": "star.fill",
        "learned": "用绝招把一小段起个名字",
        "steps": [
            step("绝招是你自己排的一小段。在星星绝招那一栏排好，主程序里放一个星星，小兔就会把那一整段做一遍。",
                 "B..../...../..C../...../....C", program="S S ; S=R R D D", limits=lim(2, FN, proc=4), run=True),
            step("看着程序想一想，小兔最后站在哪一格？", "B../.../..C", program="S S ; S=R D", limits=lim(2, FN, proc=2),
                 task=predict("c3"), hint="星星是往右、往下。做两次星星。", drill=DR_PREDICT),
            step("你来排：先在绝招那一栏排好一小段，主程序里放两个星星。", "B..../...../..C../...../....C", program="", limits=lim(2, FN, proc=4),
                 task=build("S S ; S=R R D D", need="S", claim="size=6"), hint="绝招里排往右、往右、往下、往下。", drill=DR_FN),
            step("看，用了绝招，主程序里只要放两块。", "B..../...../..C../...../....C", program="S S ; S=R R D D", limits=lim(2, FN, proc=4)),
        ],
    },
    {
        "id": "reuse", "title": "绝招用好几次", "icon": "star.square.on.square.fill",
        "learned": "同样的一段用好几次",
        "steps": [
            step("同一段路出现好几次的时候，绝招最省力。", "......./B#C#C#C", program="S S S ; S=U R R D", limits=lim(3, FN, proc=4), run=True),
            step("哪一个程序能吃到全部的胡萝卜？", "......C/....C../..C..../B......", limits=lim(3, FN, proc=3),
                 task=choose(["S S S ; S=R U", "S S S ; S=R R U", "S S S ; S=U U R"], 2), hint="一小段是往右、往右、往上。", drill=DR_CHOOSE),
            step("你来排：跳过石头的那一段，排进绝招里。", "......./B#C#C#C", program="", limits=lim(3, FN, proc=4),
                 task=build("S S S ; S=U R R D", need="S", claim="size=7"), hint="跳过一块石头是：往上、往右、往右、往下。", drill=DR_FN),
            step("再来一个。", "B....../...C.../......C", program="", limits=lim(2, FN, proc=4),
                 task=build("S S ; S=D R R R", need="S", claim="size=6"), hint="一小段是往下一格，再往右三格。", drill=DR_FN),
        ],
    },
    {
        "id": "nest", "title": "绝招和重复", "icon": "square.on.square.squareshape.controlhandles",
        "learned": "绝招和重复一起用",
        "steps": [
            step("绝招可以放进重复里，重复也可以放进绝招里。", "......./B#C#C#C", program="3[S] ; S=U R R D", limits=lim(1, FNREP, loop=1, proc=4), run=True),
            step("看着程序想一想，小兔最后站在哪一格？", "C..../...../B....", program="S S ; S=2[R] U", limits=lim(2, FNREP, loop=1, proc=2),
                 task=predict("e1"), hint="星星是往右两格、往上一格。做两次。", drill=DR_PREDICT),
            step("你来排：主程序里只有一格。", "......./B#C#C#C", program="", limits=lim(1, FNREP, loop=1, proc=4),
                 task=build("3[S] ; S=U R R D", need="S", claim="size=6"), hint="跳过石头的那一段排进绝招，再用重复做三次。", drill=DR_FN),
            step("这一次，绝招那一栏只有两格。在绝招里放一个重复。", "B....../...C.../......C", program="", limits=lim(2, FNREP, loop=1, proc=2),
                 task=build("S S ; S=3[R] D", need="S", claim="size=5"), hint="绝招里放一个重复，往右三次，后面再放往下。", drill=DR_FN),
        ],
    },
    {
        "id": "fixstar", "title": "改一处，处处对", "icon": "wand.and.stars",
        "learned": "改好绝招里的一处，每一处就都对了",
        "steps": [
            step("绝招里要是有一只虫子，每一次用绝招都会错。把绝招里的那一块改对，用到它的地方就全都对了。",
                 "......C/....C../.#C..../B......", program="S S S ; S=R U U", limits=lim(3, FN, proc=3)),
            step("点出绝招里错的那一块。", "......C/....C../.#C..../B......", program="S S S ; S=R U U", limits=lim(3, FN, proc=3),
                 task=spot("1:1"), hint="一小段应该是往右、往右、往上。", drill=DR_SPOT),
            step("这个绝招有虫子，把它改对。", "B..../...../..C../...../....C", program="S S ; S=R D D D", limits=lim(2, FN, proc=4),
                 task=fix("S S ; S=R R D D", claim="outcome=bump"), hint="绝招里多往下走了一格，少往右走了一格。", drill=DR_FIX),
            step("还有一个绝招，叫菱形。星星往右往上，菱形往右往下，两个绝招轮着用。", ".C.C./B.C.C", program="", limits=lim(4, "U D L R S T", proc=2),
                 task=build("S T S T ; S=R U ; T=R D", need="T", claim="size=8"), hint="星星是往右、往上；菱形是往右、往下。主程序里星星、菱形、星星、菱形。", drill=DR_FN),
        ],
    },
]

# ----------------------------------------------------------------------------- 如果

IFS = "U D L R rep ?b"

cond = [
    {
        "id": "blue", "title": "如果踩着蓝花", "icon": "camera.macro",
        "learned": "「如果」只在踩着蓝花的时候才做",
        "steps": [
            step("「如果」积木里的东西，只在小兔踩着蓝花的时候才做；没踩着，就跳过。", "......C/Bb.....", program="6[R ?b[U]]",
                 limits=lim(1, IFS, loop=2, when=1), run=True),
            step("看着程序想一想，小兔最后站在哪一格？", "..../Bb.C", program="3[R ?b[U]]", limits=lim(1, IFS, loop=2, when=1),
                 task=predict("d1"), hint="第一步就踩到了蓝花，所以往上走了一格，后面都是往右。", drill=DR_PREDICT),
            step("这一次，「如果」里面是往下。小兔最后站在哪一格？", "B.b./...C", program="3[R ?b[D]]", limits=lim(1, IFS, loop=2, when=1),
                 task=predict("d2"), hint="走到蓝花上，往下一格，再往右。", drill=DR_PREDICT),
            step("你来排：重复里放一个往右，再放一个「如果」。", ".....C/B..b..", program="", limits=lim(1, IFS, loop=2, when=1),
                 task=build("5[R ?b[U]]", need="?b"), hint="重复里先放往右的箭头，再放「如果」，「如果」里放往上。", drill=DR_IF),
        ],
    },
    {
        "id": "two", "title": "一个程序，两个花园", "icon": "square.split.2x1.fill",
        "learned": "同一个程序，走好几个花园",
        "steps": [
            step("这一关有两个花园，蓝花不在同一个地方。点上面的页签，两个花园都看一看。用「如果」，同一个程序两个花园都能过。",
                 "......C/.b...../Bb.....|......C/......./B..b...", program="6[R ?b[U]]", limits=lim(1, IFS, loop=2, when=1)),
            step("哪一个程序，两个花园都能过？", ".....C/Bb#...|..#..C/B...b.", limits=lim(3, IFS, loop=2, when=1),
                 task=choose(["4[R] U R", "5[R ?b[U]]", "R U 4[R]"], 2), hint="只有用了「如果」的那个，才知道什么时候往上。", drill=DR_CHOOSE),
            step("你来排，两个花园都要过。", "......C/...b.../Bb.....|......C/.....b./B..b...", program="", limits=lim(1, IFS, loop=2, when=1),
                 task=build("6[R ?b[U]]", need="?b"), hint="每一次先往右，踩着蓝花就往上。", drill=DR_IF),
            step("再来一个：这一次，踩着蓝花往下走。", "B.b.../....b./.....C|Bb..../...b../.....C", program="", limits=lim(1, IFS, loop=2, when=1),
                 task=build("5[R ?b[D]]", need="?b"), hint="每一次先往右，踩着蓝花就往下。", drill=DR_IF),
        ],
    },
    {
        "id": "forever", "title": "一直重复", "icon": "infinity",
        "learned": "「一直重复」做到过关为止",
        "steps": [
            step("「一直重复」不用管次数：它会一直做下去，过关了才停下来。", "......C/B...b..|...C.../Bb.....", program="*[R ?b[U]]",
                 limits=lim(1, "U D L R ?b *", loop=2, when=1), run=True),
            step("看着程序想一想，小兔最后站在哪一格？", "....C/B.b..", program="*[R ?b[U]]", limits=lim(1, "U D L R ?b *", loop=2, when=1),
                 task=predict("e1"), hint="走到蓝花上往上一格，再一直往右，吃到胡萝卜就停。", drill=DR_PREDICT),
            step("你来排：两个花园一长一短，用「一直重复」。", ".....C/B..b../......|.../..C/Bb.", program="", limits=lim(1, "U D L R ?b *", loop=2, when=1),
                 task=build("*[R ?b[U]]", need="*"), hint="一直重复里放往右，再放「如果」，里面放往上。", drill=DR_IF),
            step("这一次小兔往下走，踩着蓝花就往右。", "B../b../.b./..C|B../.../b../.C.", program="", limits=lim(1, "U D L R ?b *", loop=2, when=1),
                 task=build("*[D ?b[R]]", need="*"), hint="一直重复里放往下，再放「如果」，里面放往右。", drill=DR_IF),
        ],
    },
    {
        "id": "yellow", "title": "两种花", "icon": "sun.max.fill",
        "learned": "用两个「如果」管两种花",
        "steps": [
            step("黄花也有「如果」。蓝花往上，黄花往下，把两个「如果」放在一起。", "......./B.b.y.C/.......",
                 program="*[R ?b[U] ?y[D]]", limits=lim(1, "U D L R ?b ?y *", loop=3, when=1)),
            step("看着程序想一想，小兔最后站在哪一格？", "..y../Bb.../....C", program="4[R ?b[U] ?y[D]]",
                 limits=lim(1, "U D L R rep ?b ?y", loop=3, when=1),
                 task=predict("e2"), hint="踩着蓝花往上一格，踩着黄花往下一格，别的时候往右。", drill=DR_PREDICT),
            step("这个程序有虫子：踩着黄花的时候走错了。改一改。", "......./B..y.../.#....C|....y../B.b#..C/.......",
                 program="*[R ?b[U] ?y[U]]", limits=lim(1, "U D L R ?b ?y *", loop=3, when=1),
                 task=fix("*[R ?b[U] ?y[D]]"), hint="踩着黄花的时候，要往下走。", drill=DR_FIX),
            step("最后一个，你来排：两种花，两个花园。", "...y#../B.b..y./.#.#..C|..#..y./By.b#.C/..b.#..", program="",
                 limits=lim(1, "U D L R ?b ?y *", loop=3, when=1),
                 task=build("*[R ?b[U] ?y[D]]", need="?y"), hint="一直重复里放三块：往右、蓝花往上、黄花往下。", drill=DR_IF,
                 ok="两种花都没难住你！"),
        ],
    },
]

COURSE = {
    "game": "coding",
    "title": "编程教学",
    "tracks": [
        {"id": "basic", "title": "指令和顺序", "subtitle": "用箭头带小兔走路", "art": "tutor_coding_basic", "lessons": basic},
        {"id": "loop", "title": "重复", "subtitle": "一样的事只说一遍", "art": "tutor_coding_loop", "lessons": loop},
        {"id": "func", "title": "绝招", "subtitle": "给一小段起个名字", "art": "tutor_coding_func", "lessons": func},
        {"id": "cond", "title": "如果", "subtitle": "一个程序管好几种情况", "art": "tutor_coding_cond", "lessons": cond},
    ],
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "coding.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(COURSE, f, ensure_ascii=False, indent=1)
        f.write("\n")
    lessons = sum(len(t["lessons"]) for t in COURSE["tracks"])
    tasks = sum(1 for t in COURSE["tracks"] for l in t["lessons"] for s in l["steps"] if "task" in s)
    print(f"{path}: {lessons} lessons, {tasks} tasks")
