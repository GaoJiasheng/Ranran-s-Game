#!/usr/bin/env python3
"""生成华容道的教学内容：RanranGame/Tutorials/klotski.json。

改了这里以后：
  1. python3 tools/tutorials/build_klotski.py
  2. zsh tools/klotski/test.sh（每道题都要有答案，题目里说的步数要对得上求解器）
  3. 重新生成配音（tools/voice/）

盘面写法（见 Logic/KlotskiBoard.swift）：5 行 × 4 列，行与行用 / 隔开
  B 小兔（2×2）  V 竖块（1 宽 2 高）  H 横块（2 宽 1 高）  S 小方块  . 空格
格子的名字：列 a b c d（从左到右），行 1~5（从上到下）。方向：u d l r。
标记（marks）：glow:b3 木块发光 · arrow:b3:d:1 箭头（往下 1 格）· ring:b3 圈一个格子 · door 出口亮
题目（见 Logic/KlotskiLessonLogic.swift 开头的说明）：
  slide：move:b3:d:1 · far:a3:r · at:b3:d4 · bunnyAt:b4 · empty:b3,c3 · free:3 · undo
  pick： kind:tall|wide|small|big · blocker · movable · stuck · cells（accept 里列格子）

每一道题都要写 drill（练习时代替课文，不能提左右、上下、横竖、面/边/方，也不能带字母），
所有写着位置的东西都会在练习里左右镜像。
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "RanranGame", "Tutorials")


def step(say, board=None, marks=None, task=None, hint=None, ok=None, drill=None):
    s = {"say": say}
    if drill: s["drill"] = drill
    if board is not None: s["board"] = board
    if marks: s["marks"] = marks
    if task: s["task"] = task
    if hint: s["hint"] = hint
    if ok: s["ok"] = ok
    return s


def slide(rule, limit=None):
    t = {"type": "slide", "rule": rule}
    if limit: t["extra"] = {"limit": str(limit)}
    return t


def pick(rule, accept=None):
    t = {"type": "pick", "rule": rule}
    if accept: t["accept"] = accept
    return t


def free(n):
    return slide(f"free:{n}")


def rings(*cells):
    return [f"ring:{c}" for c in cells]


CN = {1: "一", 2: "两", 3: "三", 4: "四", 5: "五", 6: "六"}


def steps_word(n):
    return f"{CN[n]}步"


def drill_free(n):
    return f"想办法让小兔走到出口，只用{steps_word(n)}！"


DRILL_ARROW = "照着箭头，把发光的木块滑过去！"
DRILL_FAR = "把发光的木块一直滑到头，滑到被挡住为止！"
DRILL_AT = "让发光的木块走到圈出来的格子！"
DRILL_EMPTY = "把圈出来的格子都空出来！"
DRILL_BLOCKER = "点一块挡着小兔的木块！"

# ----------------------------------------------------------------------------- 盘面

BOARD_HOME = "SBBS/.BB./V.HH/V.../.S.."          # 四种木块都有
BOARD_SMALL_DOWN = "BB../BB../..S./..../.HH."
BOARD_FAR = "BB../BB../S.../..../..HH"
BOARD_WIDE_DOWN = ".BB./.BB./..../HH../...."
BOARD_TALL_UP = "..BB/..BB/V.../V.../...."
BOARD_BLOCKED = "..BB/..BB/S.S./..../...."        # 向右滑，被第二块小方块挡住
BOARD_CORNER = "BB../BB../..../..S./...."          # 去左下角要拐一个弯
BOARD_PACKED = "VBBV/VBBV/V..V/VHHV/S..S"          # 四块竖块被围住，动不了
BOARD_CLASSIC = "VBBV/VBBV/VHHV/VSSV/S..S"         # 横刀立马：开局只有小方块能动
BOARD_ONE_BLOCK = ".BB./.BB./.S../..../...."       # 小兔下面一块小方块，2 步
BOARD_ONE_BLOCK_GONE = ".BB./.BB./S.../..../...."  # 路空了，1 步
BOARD_SIDE_BUNNY = "BB../BB../.V../.V../...."      # 小兔在角上，3 步
BOARD_BUNNY_FREE3 = "BB../BB../HH../..../...."     # 小兔自己走，3 步
BOARD_WHO = "SBBS/.BB./..../.V../.V.."             # 一块竖块挡路，2 步
BOARD_TWO_BLOCKERS = ".BB./.BB./..S./.S../...."    # 两块挡路，3 步
BOARD_TWO_SMALL = ".BB./.BB./.SS./..../...."       # 两块并排的小方块，3 步
BOARD_WIDE_BELOW = ".BB./.BB./.HH./..../...."      # 横块在下面，小兔先让一让，4 步
BOARD_QUEUE = ".BB./.BB./.S../.S../...."           # 两块小方块排队，3 步
BOARD_VV = ".BB./.BB./..../VVVV/VVVV"              # 竖块挤在下面，5 步
BOARD_SHIP = "SBBS/.BB./..../..../.HH."            # 6 步
BOARD_BACK5 = ".BB./.BB./..../HH../HH.."           # 5 步
BOARD_BACK4 = "BB../BB../..../.HH./...."           # 4 步
BOARD_SWAP = "..BB/..BB/V.../V.../HH.."            # 竖块和横块要换位置
BOARD_SIDE_H = ".BB./.BB./.HH./S.../...."          # 4 步
BOARD_SIDE_V5 = "BB../BB../V.../V.../.HH."         # 5 步
BOARD_V_SMALL = ".BB./.BB./..../.VV./SVVS"         # 5 步

# ----------------------------------------------------------------------------- 第一组：基础

basic = [
    {
        "id": "home", "title": "小兔要回家", "icon": "house.fill",
        "learned": "认识木盘、出口和四种木块",
        "steps": [
            step("这是一个木盘。小兔住在盘子里，它想从下面的门走出去，回家。", BOARD_HOME, ["door"]),
            step("盘子里有好几块木块。大大的这一块，就是小兔。点一下小兔吧。", BOARD_HOME,
                 task=pick("kind:big"), hint="小兔是最大的一块，有四个格子那么大。", drill="点一下小兔！"),
            step("高高站着的木块，叫竖块。点一下竖块。", BOARD_HOME,
                 task=pick("kind:tall"), hint="竖块是站着的，占两个格子。", drill="点一块高高站着的木块！"),
            step("躺着的长木块，叫横块。点一下横块。", BOARD_HOME,
                 task=pick("kind:wide"), hint="横块是躺着的，占两个格子。", drill="点一块躺着的长木块！"),
            step("只占一个格子的，叫小方块。点一下小方块。", BOARD_HOME,
                 task=pick("kind:small"), hint="小方块最小，只有一个格子。", drill="点一块只有一格的小方块！"),
            step("出口在木盘最下面，正中间。点一下出口前面的格子。", BOARD_HOME, ["door"],
                 task=pick("cells", ["b5", "c5"]), hint="出口在最下面一排，正中间。", drill="点一下出口前面的格子！"),
            step("小兔走到出口，就能回家了。别的木块都出不去，只有小兔可以。我们一起来帮它吧！", BOARD_HOME, ["door"]),
        ],
    },
    {
        "id": "slide", "title": "滑一滑", "icon": "arrow.left.and.right",
        "learned": "把木块滑到想去的地方",
        "steps": [
            step("木块是用手指滑的。按住一块木块，朝想去的方向拖一拖，松开手，它就停在格子里。", BOARD_SMALL_DOWN, ["glow:c3"]),
            step("试一试，把发光的小方块往下滑一格。", BOARD_SMALL_DOWN, ["glow:c3", "arrow:c3:d:1"],
                 task=slide("move:c3:d:1"), hint="按住发光的小方块，往下拖一格，再松手。",
                 ok="对啦，滑一格，就是一步。", drill=DRILL_ARROW),
            step("木块可以滑很远。把发光的小方块一直往右滑，滑到不能再滑为止。", BOARD_FAR, ["glow:a3", "arrow:a3:r:3"],
                 task=slide("far:a3:r"), hint="再往右滑远一点，一直滑到木盘的边上。",
                 ok="滑得再远，也只算一步。", drill=DRILL_FAR),
            step("横块也可以上下滑，只要那边有空位。把发光的横块往下滑一格。", BOARD_WIDE_DOWN, ["glow:a4", "arrow:a4:d:1"],
                 task=slide("move:a4:d:1"), hint="按住发光的横块，往下拖一格，再松手。", drill=DRILL_ARROW),
            step("竖块也一样。把发光的竖块往上滑，滑一格或者两格都可以。", BOARD_TALL_UP, ["glow:a3", "arrow:a3:u:2"],
                 task=slide("move:a3:u"), hint="按住发光的竖块，往上拖。", drill=DRILL_ARROW),
            step("每滑一次，就算一步。闯关的时候，步数越少越好。"),
        ],
    },
    {
        "id": "blocked", "title": "过不去的路", "icon": "nosign",
        "learned": "木块不能跳过别的木块，也不能拐弯",
        "steps": [
            step("木块不能跳过别的木块。把发光的小方块一直往右滑，看看它会停在哪里。", BOARD_BLOCKED, ["glow:a3", "arrow:a3:r:1"],
                 task=slide("far:a3:r"), hint="一直往右滑，直到碰到另一块木块。",
                 ok="看，它被挡住了，只能停在这里。", drill=DRILL_FAR),
            step("木块也不能拐弯。想去斜对面的格子，要分两步：先直着滑，再直着滑。", BOARD_CORNER, ["glow:c4"] + rings("a5")),
            step("试一试，让发光的小方块走到圈出来的格子。", BOARD_CORNER, ["glow:c4"] + rings("a5"),
                 task=slide("at:c4:a5", 4), hint="分两步走：先直着滑一次，再直着滑一次。", drill=DRILL_AT),
            step("有的木块被围住了，动不了。点一下现在动不了的木块。", BOARD_PACKED,
                 task=pick("stuck"), hint="动不了的木块，四面都被挡住了。", drill="点一块现在动不了的木块！"),
            step("再点一下，现在能动的木块。", BOARD_PACKED,
                 task=pick("movable"), hint="能动的木块，旁边有空位。", drill="点一块现在能动的木块！"),
        ],
    },
    {
        "id": "clear", "title": "挡路的先挪开", "icon": "arrow.up.and.down.and.arrow.left.and.right",
        "learned": "先把挡路的木块挪开，再走小兔",
        "steps": [
            step("现在小兔要往下走，可是下面有一块木块挡着。", BOARD_ONE_BLOCK, ["door"]),
            step("点一下挡着小兔的那块木块。", BOARD_ONE_BLOCK,
                 task=pick("blocker"), hint="看看小兔的正下面，是哪一块木块？", drill=DRILL_BLOCKER),
            step("先把它挪开，把圈出来的路空出来。", BOARD_ONE_BLOCK, rings("b3", "c3", "b4", "c4", "b5", "c5"),
                 task=slide("empty:b3,c3,b4,c4,b5,c5", 3), hint="往旁边滑，别再挡在小兔的下面。", drill="把圈出来的路空出来！"),
            step("路空出来了，一步就能把小兔滑到出口。试试吧！", BOARD_ONE_BLOCK_GONE, ["door"],
                 task=free(1), hint="小兔一直往下滑，滑到最下面。", ok="小兔回家啦！", drill=drill_free(1)),
            step("看，先挪开挡路的，再走小兔，就这么简单。"),
            step("再来一个。这次小兔在角落里，要先走到中间。想一想，三步让小兔出门。", BOARD_SIDE_BUNNY, ["door"],
                 task=free(3), hint="先让小兔往旁边走一步，再让路，最后下去。", drill=drill_free(3)),
        ],
    },
    {
        "id": "undo", "title": "走错了怎么办", "icon": "arrow.uturn.backward",
        "learned": "走错了可以撤销，也可以回到开头",
        "steps": [
            step("走错了不要紧。点一下木盘下面的「撤销」，上一步就回来了。", BOARD_ONE_BLOCK),
            step("先随便滑一块木块，再点一下「撤销」试试。", BOARD_ONE_BLOCK,
                 task=slide("undo"), hint="先滑一块木块，然后点木盘下面的撤销。", drill="先滑一块木块，再点撤销！"),
            step("看，木块又回到原来的地方了。点「回到开头」，所有的木块，都会回到最开始的样子。"),
            step("走了很多步，想不起来错在哪里，就点「回到开头」。现在，用三步让小兔出门，走错了就撤销。", BOARD_BUNNY_FREE3, ["door"],
                 task=free(3), hint="小兔不用等别的木块，自己就能走。", drill=drill_free(3)),
        ],
    },
]

# ----------------------------------------------------------------------------- 第二组：让路的办法

space = [
    {
        "id": "who", "title": "先看谁挡路", "icon": "eye.fill",
        "learned": "先看清是谁挡着小兔",
        "steps": [
            step("小兔要往下走。每一次，先看一看：谁挡着路？", BOARD_WHO, ["door"]),
            step("点一下挡着小兔的木块。", BOARD_WHO,
                 task=pick("blocker"), hint="小兔的正下面有一块竖块。", drill=DRILL_BLOCKER),
            step("不用管别的木块，只要把挡路的挪开。用两步让小兔出门。", BOARD_WHO, ["door"],
                 task=free(2), hint="先把挡路的竖块滑到旁边，再让小兔下去。", drill=drill_free(2)),
            step("有时候，挡路的不止一块。看，这里有两块。点一下其中一块。", BOARD_TWO_BLOCKERS,
                 task=pick("blocker"), hint="小兔的正下面，有两块小方块。", drill=DRILL_BLOCKER),
            step("两块都挡着路，要一块一块挪开。用三步让小兔出门。", BOARD_TWO_BLOCKERS, ["door"],
                 task=free(3), hint="先把挡路的两块都挪开，最后再走小兔。", drill=drill_free(3)),
        ],
    },
    {
        "id": "gaps", "title": "腾出两个空位", "icon": "square.dashed",
        "learned": "给小兔腾出两个并排的空位",
        "steps": [
            step("小兔是大块，要两个并排的空位，才能钻过去。", BOARD_TWO_SMALL, rings("b3", "c3")),
            step("把圈出来的两个格子，都空出来。", BOARD_TWO_SMALL, rings("b3", "c3"),
                 task=slide("empty:b3,c3", 3), hint="两块小方块，一块往左滑，一块往右滑。", drill=DRILL_EMPTY),
            step("空位够了，小兔可以下去了。用三步让小兔出门。", BOARD_TWO_SMALL, ["door"],
                 task=free(3), hint="先给小兔腾空位，再让它下去。", drill=drill_free(3)),
            step("横块占两个格子，让路更费劲。这时候，小兔自己也可以让一让。用四步让小兔出门。", BOARD_WIDE_BELOW, ["door"],
                 task=free(4), hint="先把小兔往旁边挪，横块才有地方去。", drill=drill_free(4)),
        ],
    },
    {
        "id": "small", "title": "小方块最灵活", "icon": "square.fill",
        "learned": "木块太挤的时候，先动灵活的小方块",
        "steps": [
            step("木块太挤的时候，先看看哪些木块能动。这一盘，大块都被围住了。点一块能动的木块。", BOARD_CLASSIC,
                 task=pick("movable"), hint="能动的，都是只占一个格子的小方块。", drill="点一块现在能动的木块！"),
            step("小方块最灵活，哪里有空位，它就能钻过去。把发光的小方块往下滑，滑到圈出来的格子。", BOARD_CLASSIC,
                 ["glow:b4"] + rings("b5"),
                 task=slide("at:b4:b5", 2), hint="发光的小方块下面有空位，往下滑一格。", drill=DRILL_AT),
            step("小方块先走开，大块才有地方挪。看，两块小方块排着队，挡着小兔。用三步让小兔出门。", BOARD_QUEUE, ["door"],
                 task=free(3), hint="两块小方块，都往旁边滑开。", drill=drill_free(3)),
            step("记住：木块太挤的时候，先找能动的小方块，让它们走开，大块就有地方挪了。"),
        ],
    },
    {
        "id": "ship", "title": "把空位送过去", "icon": "arrow.right.circle.fill",
        "learned": "把空位送到需要的地方",
        "steps": [
            step("木块一动，空位就换了地方。想要空位在哪里，就把那里的木块挪走。", BOARD_VV, ["door"]),
            step("小兔下面全被竖块占满了。把圈出来的四个格子都空出来。", BOARD_VV, rings("b4", "c4", "b5", "c5"),
                 task=slide("empty:b4,c4,b5,c5", 6), hint="先把边上的竖块滑上去，再把中间的竖块挪到边上。", drill=DRILL_EMPTY),
            step("空位送到了，小兔就能下去了。用五步让小兔出门。", BOARD_VV, ["door"],
                 task=free(5), hint="四块竖块都要让开，最后再走小兔。", drill=drill_free(5)),
            step("再来一个。想一想，怎么把空位送到小兔旁边，让小兔走到圈出来的格子。", BOARD_SHIP, rings("a4"),
                 task=slide("bunnyAt:a4", 6), hint="先让小兔往下，横块再让开，小兔才有地方去。", drill="让小兔走到圈出来的格子！"),
        ],
    },
]

# ----------------------------------------------------------------------------- 第三组：多想几步

plan = [
    {
        "id": "backward", "title": "倒着想", "icon": "arrow.uturn.left.circle.fill",
        "learned": "从终点倒着往回想",
        "steps": [
            step("遇到难题，可以倒着想。小兔最后要走到出口。", BOARD_BACK5, ["door"]),
            step("小兔走到出口的时候，会盖住下面的哪些格子？点一个。", BOARD_BACK5, ["door"],
                 task=pick("cells", ["b4", "c4", "b5", "c5"]), hint="出口在最下面一排的正中间，小兔有四个格子大。",
                 drill="小兔到了出口，会盖住哪些格子？点一个！"),
            step("所以，出口前面的格子要空着。可是现在，下面有两块横块。倒着想一想，用五步让小兔出门。", BOARD_BACK5, ["door"],
                 task=free(5), hint="小兔可以先走到右边，等横块上去了，再回来。", ok="你倒着想了，真聪明！", drill=drill_free(5)),
            step("再来一个。先想想小兔最后要走到哪里，再往回想。用四步让小兔出门。", BOARD_BACK4, ["door"],
                 task=free(4), hint="下面的横块要先让开，小兔才能去出口。", drill=drill_free(4)),
        ],
    },
    {
        "id": "swap", "title": "竖块和横块", "icon": "arrow.left.arrow.right",
        "learned": "木块不会转身，要一块一块让位",
        "steps": [
            step("竖块不会躺下，横块也不会站起来。它们想换位置，要一块一块让路。", BOARD_SWAP, ["glow:a3", "glow:a5"]),
            step("让发光的竖块，走到圈出来的格子。", BOARD_SWAP, ["glow:a3"] + rings("b5"),
                 task=slide("at:a3:b5", 5), hint="横块要先让开，竖块再挪过去。", drill=DRILL_AT),
            step("再来，让发光的横块走到圈出来的格子。想一想，谁挡着它？", BOARD_SWAP, ["glow:a5"] + rings("b3"),
                 task=slide("at:a5:b3", 4), hint="竖块要先让开，横块才能上去。", drill=DRILL_AT),
            step("看，每一块木块都有自己的路。先让开挡路的，再走自己的路。"),
        ],
    },
    {
        "id": "noback", "title": "不走回头路", "icon": "arrow.triangle.turn.up.right.diamond.fill",
        "learned": "每一步都要有用，不走回头路",
        "steps": [
            step("一块木块滑过去，又滑回来，就白白多走了两步。每一步都要有用，不走回头路。", BOARD_WIDE_BELOW, ["door"]),
            step("用四步让小兔出门。", BOARD_WIDE_BELOW, ["door"],
                 task=free(4), hint="小兔先让一让，横块过去，小兔就能下来了。", drill=drill_free(4)),
            step("再来一个，五步。想好再走，不要走回头路。", BOARD_SIDE_V5, ["door"],
                 task=free(5), hint="先让下面的横块让开，再把竖块挪到旁边。", drill=drill_free(5)),
            step("最后一个，也是五步。", BOARD_V_SMALL, ["door"],
                 task=free(5), hint="下面的竖块，一块一块往上挪，给小兔让出路。", drill=drill_free(5)),
        ],
    },
    {
        "id": "final", "title": "小兔回家", "icon": "house.circle.fill",
        "learned": "用学到的办法，帮小兔回家",
        "steps": [
            step("你已经学会所有的办法了：先看谁挡路，把挡路的挪开，给小兔腾出空位，还要倒着想一想。", BOARD_SIDE_H, ["door"]),
            step("用四步让小兔出门。", BOARD_SIDE_H, ["door"],
                 task=free(4), hint="小兔先让一让，横块过去，小兔就能下来了。", drill=drill_free(4)),
            step("再来一个，五步。", BOARD_V_SMALL, ["door"],
                 task=free(5), hint="下面的竖块，一块一块往上挪，给小兔让出路。", drill=drill_free(5)),
            step("最后一个，六步。你可以的！", BOARD_SHIP, ["door"],
                 task=free(6), hint="小兔先下去一格，再往旁边让，横块上去以后，小兔再走。", drill=drill_free(6)),
            step("小兔都回家啦！现在，去闯关吧。"),
        ],
    },
]

COURSE = {
    "game": "klotski",
    "title": "华容道教学",
    "tracks": [
        {"id": "basic", "title": "基础", "subtitle": "认识木盘，学会滑木块", "art": "tutor_klotski_basic", "lessons": basic},
        {"id": "space", "title": "让路的办法", "subtitle": "挡路的木块怎么让开", "art": "tutor_klotski_space", "lessons": space},
        {"id": "plan", "title": "多想几步", "subtitle": "倒着想，少走弯路", "art": "tutor_klotski_plan", "lessons": plan},
    ],
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "klotski.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(COURSE, f, ensure_ascii=False, indent=1)
        f.write("\n")
    lessons = sum(len(t["lessons"]) for t in COURSE["tracks"])
    tasks = sum(1 for t in COURSE["tracks"] for l in t["lessons"] for s in l["steps"] if "task" in s)
    print(f"{path}: {lessons} lessons, {tasks} tasks")
