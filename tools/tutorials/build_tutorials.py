#!/usr/bin/env python3
"""生成教学内容：RanranGame/Tutorials/gomoku.json 和 xiangqi.json。

改了这里以后：
  1. python3 tools/tutorials/build_tutorials.py
  2. 跑校验（见 tools/tutorials/README.md），确认每道题都有正确答案
  3. 重新生成配音（tools/voice/）

五子棋坐标 "c3"：第 c 列、从上往下第 3 行（9 路棋盘 a1 在左上角）。
象棋坐标 "e0"：第 e 列、红方底线是 0（ICCS 记谱）。局面用 {格子: 子} 写，大写红方、小写黑方：
  K 帅 A 仕 B 相 N 马 R 车 C 炮 P 兵
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "RanranGame", "Tutorials")


def step(say, board=None, marks=None, task=None, hint=None, ok=None, reply=None, after=None, loop=None, drill=None):
    s = {"say": say}
    if drill: s["drill"] = drill
    if loop: s["loop"] = loop
    if board is not None: s["board"] = board
    if marks: s["marks"] = marks
    if task: s["task"] = task
    if hint: s["hint"] = hint
    if ok: s["ok"] = ok
    if reply: s["reply"] = reply
    if after: s["after"] = after
    return s


def place(rule=None, accept=None):
    t = {"type": "place"}
    if rule: t["rule"] = rule
    if accept: t["accept"] = accept
    return t


def pick(accept):
    return {"type": "pick", "accept": accept}


def move(rule=None, accept=None, piece=None):
    t = {"type": "move"}
    if rule: t["rule"] = rule
    if accept: t["accept"] = accept
    if piece: t["piece"] = piece
    return t


def g(b="", w="", size=9):
    return f"size={size};b={b};w={w}"


# ----------------------------------------------------------------------------- 五子棋

# 连续冲四的三个局面（第一个、第二个是同一个思路换了摆法；第三个多了白棋的活三）
VCF1 = g("d5,e5,f5,g6,g7,e6,d7", "c5,g8,c8")
VCF2 = g("e4,e5,e6,d7,c7,d5,c4", "e3,b7,b3")
VCF3 = g("d5,e5,f5,g6,g7,e6,d7", "c5,g8,c8,d2,e2,f2")

# 新增课程：用变量放在这里，下面按轨道摆进去（id 不能改，也不要复用）
G13 = {
    "id": "g13", "title": "冲四逼对手", "icon": "bolt.fill", "learned": "冲四会逼着对手马上堵",
    "steps": [
        step("三颗连在一起，一头被白棋挡住了。再下一颗变成四颗，只有一头能赢，这叫『冲四』。",
             board=g("c5,d5,e5", "b5,c8,g2"), marks=["cross:b5", "glow:f5"]),
        step("你来冲一个四！", task=place(rule="four"),
             hint="接在三颗棋的右边，让它变成四颗。", ok="冲四！",
             reply=["block"], after="白棋必须马上堵住。不堵，你下一步就连成五颗了。冲四就是逼着对手下棋。",
             drill="冲一个四，逼白棋立刻堵！"),
        step("哪一组是冲四？点一下它的棋子。",
             board=g("c2,d2,e2,f2,c6,d6,e6,f6", "b2,h9"), marks=["label:c2:A", "label:c6:B"],
             task=pick(["c2", "d2", "e2", "f2"]),
             hint="冲四只有一头能赢。B 的两头都空着，那是活四。",
             ok="对！A 只有一头空着，是冲四。",
             drill="点出只有一头能赢的那个四，也就是冲四。"),
        step("冲四要用得聪明：有两个冲四的点，选一个顺便还能连出新三颗的。",
             board=g("c5,d5,e5,g6,g7", "b5,c8,h3"), task=place(accept=["g5"]),
             hint="想一想，哪个点还能和旁边的两颗黑棋连在一起？", ok="聪明！",
             reply=["block"], after="白棋被逼着堵了一手，你却多出了一个活三。冲四，白赚一步！",
             drill="有两个冲四的点，选一个还能连出新三颗的。"),
        step("记住：冲四，对手必须马上堵。用冲四逼对手，自己就多下一步。"),
    ],
}

G14 = {
    "id": "g14", "title": "连续冲四", "icon": "bolt.horizontal.fill", "learned": "连着冲四，对手只能一直堵",
    "steps": [
        step("如果一个接一个地冲四，白棋就只能一直堵。先找一步冲四！",
             board=VCF1, task=place(rule="winIn:2"),
             hint="找一个点，下下去能做出四颗。有两个点都可以。", ok="冲四！",
             reply=["block"], after="白棋只能堵。再来一个冲四！",
             drill="找到连续冲四的第一步！"),
        step("这一次，要一下子冲出两个四。", task=place(rule="winIn:1"),
             hint="找一个点，下下去让两条线都变成四颗。", ok="两个四！白棋堵不了两个。",
             reply=["block"], after="最后一步！"),
        step("连成五颗！", task=place(rule="five"), ok="连续冲四，赢啦！"),
        step("换一个摆法，你自己找。先冲哪一步？",
             board=VCF2, task=place(rule="winIn:2"),
             hint="先找能做出四颗的点，每一个冲四都要让白棋只能堵。", ok="冲四！",
             reply=["block"], after="白棋只能堵。接着冲！",
             drill="找到连续冲四的第一步！"),
        step("再冲一个，同时冲出两个四。", task=place(rule="winIn:1"), ok="两个四！",
             reply=["block"], after="最后一步！"),
        step("连成五颗！连续冲四，一个接一个，白棋没空反击。", task=place(rule="five"), ok="又赢啦！"),
    ],
}

G15 = {
    "id": "g15", "title": "三三", "icon": "3.square.fill", "learned": "一步做出两个活三，对手堵不过来",
    "steps": [
        step("这里横着有两颗，竖着也有两颗。有一个点，下下去横竖一起变成活三，这叫『三三』！",
             board=g("c5,d5,e3,e4", "h8,a8,g2")),
        step("找到那个点！", task=place(rule="doubleThree"),
             hint="横着那两颗和竖着那两颗，往前延长，在哪里碰在一起？",
             ok="两个活三！", reply=["e6"],
             after="白棋只能堵一个。另一个活三，变成活四！",
             drill="找到一步同时做出两个活三的点！"),
        step("变成活四！", task=place(rule="winIn:1"), ok="活四！白棋堵不住了。",
             reply=["block"], after="最后一步！"),
        step("连成五颗！", task=place(rule="five"), ok="赢啦！三三也能赢。"),
        step("再找一个三三。这次是一条斜线和一条横线。",
             board=g("g3,f4,f5,g5", "a8,b2,h8"), task=place(rule="doubleThree"),
             hint="找一个点，让斜着和横着都变成三颗。", ok="漂亮！两个活三！",
             drill="找到一步同时做出两个活三的点！"),
        step("两个活三一起出现，对手只能堵一个。用之前先看看对手有没有冲四。"),
    ],
}

G16 = {
    "id": "g16", "title": "先冲四再防守", "icon": "arrow.left.arrow.right", "learned": "有冲四，先冲再防",
    "steps": [
        step("白棋有活三了！别急着堵：你手里有一个冲四，能一边堵、一边冲。找到它！",
             board=g("f4,f5,f6", "c3,d3,e3,f7"), task=place(accept=["f3"]),
             hint="冲四的那一点，要正好挨着白棋的三颗。", ok="一举两得！",
             reply=["block"], after="白棋只能去堵你的四。你堵住了对手，还白赚了一步。",
             drill="白棋有活三。找一步既能堵住它、又能冲四的点！"),
        step("再来一次！白棋有活三，你也有三颗。找一个既堵又冲四的点。",
             board=g("d3,e3,f3", "c4,c5,c6,g3"), task=place(accept=["c3"]),
             hint="想一想：白棋三颗的一头，正好是你冲四的点。", ok="对！",
             reply=["block"], after="白棋被逼着堵在另一头。",
             drill="白棋有活三。找一步既能堵住它、又能冲四的点！"),
        step("还有一种：白棋有活三，可你能连续冲四赢。冲四比活三快，先冲！",
             board=VCF3, task=place(rule="winIn:2"),
             hint="白棋的活三要两步才能赢，你的冲四每一步都逼它堵。", ok="冲四！",
             reply=["block"], after="白棋只能堵，没空做自己的活四。",
             drill="白棋有活三，但你能连续冲四赢。找到第一步！"),
        step("再冲出两个四！", task=place(rule="winIn:1"), ok="两个四！",
             reply=["block"], after="最后一步！"),
        step("连成五颗！", task=place(rule="five"), ok="你先赢了！"),
        step("对手有活三，先看自己有没有冲四：能一边堵一边冲最好，能连续冲四赢，就直接赢。"),
    ],
}

gomoku = {
    "game": "gomoku",
    "title": "五子棋教学",
    "tracks": [
        {
            "id": "basic", "title": "基础规则", "subtitle": "怎么下、怎么赢", "art": "tutor_gomoku_basic",
            "lessons": [
                {
                    "id": "g1", "title": "认识棋盘", "icon": "square.grid.3x3.fill", "learned": "在交叉点上轮流下棋",
                    "steps": [
                        step("这是五子棋的棋盘。棋子不放在格子里，而是放在两条线交叉的点上。", board=g(), marks=["glow:e5"]),
                        step("黑棋先下。把一颗黑棋放在发光的点上吧。", task=place(accept=["e5"]),
                             hint="要放在发光的那个交叉点上哦。", ok="放得真准！", reply=["f4"], drill="把黑棋放在发光的点。",
                             after="现在轮到白棋了，白棋下在这里。两个人就这样一人一颗，轮流下。"),
                        step("又轮到你了。这次随便找一个空着的交叉点，下一颗黑棋。", task=place(rule="any"),
                             ok="很好！", reply=["d6|f6|d4"],
                             after="白棋也下了一颗。棋子下了就不能再挪动，所以每一步都要想好再下。"),
                        step("记住三件事：下在交叉点上，黑棋先下，两个人轮流下。下一课，我们学怎样才能赢！"),
                    ],
                },
                {
                    "id": "g2", "title": "连成五个就赢", "icon": "line.diagonal", "learned": "横着、竖着、斜着连成五个就赢",
                    "steps": [
                        step("谁先把五颗自己的棋子连成一排，谁就赢了。像这样横着连起来的五颗，就是赢了。",
                             board=g("b5,c5,d5,e5,f5", "c3,e7,g6"), marks=["line:b5:f5"]),
                        step("黑棋已经横着连了四颗。再下一颗，变成五颗，就赢啦！",
                             board=g("b3,c3,d3,e3", "c6,d6,e7,b2"), task=place(rule="five"),
                             hint="数一数，第五颗要和这四颗黑棋排在同一条线上，紧紧挨着。", ok="五颗连起来了，你赢了！"),
                        step("竖着连也可以。下在哪里，能竖着连成五颗？",
                             board=g("e2,e3,e4,e5", "d3,f4,d6,f2"), task=place(rule="five"),
                             hint="看这一竖排黑棋的上面和下面。", ok="竖着的五颗，赢啦！"),
                        step("斜着连也算哦！这四颗黑棋斜着排成一排，再补上一颗。",
                             board=g("c7,d6,e5,f4", "c5,d4,f6,e7"), task=place(rule="five"),
                             hint="沿着这条斜线，看看两头。", ok="斜着也连成五颗了！"),
                        step("另一个方向的斜线也一样。在哪里补一颗？",
                             board=g("c3,d4,e5,f6", "d3,e4,c5,g5"), task=place(rule="five"),
                             hint="沿着斜线往左上看，或者往右下看。", ok="完全正确！"),
                        step("考考你：下面三排黑棋，哪一排已经赢了？点一下那一排里的棋子。",
                             board=g("b2,c2,d2,e2,b4,c5,d6,e7,f8,h2,h3,h4,h6,h7", "a2,g9"),
                             marks=["label:b2:A", "label:b4:B", "label:h2:C"],
                             task=pick(["b4", "c5", "d6", "e7", "f8"]),
                             hint="要五颗紧紧挨着、中间没有空，才算赢。A 只有四颗，C 中间空了一格。",
                             ok="对！B 这五颗斜着紧紧连在一起。", drill="点出已经连成五颗的那一排。"),
                    ],
                },
                {
                    "id": "g3", "title": "堵住对手", "icon": "hand.raised.fill", "learned": "对手连了四颗要马上堵住",
                    "steps": [
                        step("白棋横着连了四颗！如果不管它，白棋下一步就赢了。快在它连成五颗之前，把它堵住！",
                             board=g("b3,d5,e6", "c3,d3,e3,f3"), task=place(rule="block"),
                             hint="看白棋这四颗的两头，哪一头还空着？", ok="堵住了！白棋连不成五颗了。"),
                        step("这次白棋中间空了一格。白棋要是下在那个空里，也会连成五颗！把它堵住。",
                             board=g("d3,g7,c7", "b5,c5,e5,f5"), task=place(rule="block"),
                             hint="中间那个空着的点最危险。", ok="对！堵在中间，白棋就断开了。"),
                        step("白棋竖着连了四颗，快找到要堵的地方。",
                             board=g("e1,c4,g5", "e2,e3,e4,e5"), task=place(rule="block"),
                             hint="上面已经被你堵住了，看看下面。", ok="堵得好！"),
                        step("现在黑棋和白棋都连了四颗。轮到你下，该怎么办？",
                             board=g("b7,c7,d7,e7,a7", "c3,d3,e3,f3,b3"), task=place(rule="five"),
                             hint="先看看自己能不能马上赢！自己能连成五颗，就不用去堵了。",
                             ok="对！自己能赢，就先赢。"),
                        step("记住：每下一步之前，先看自己能不能赢；不能赢，再看对手是不是连了四颗，有就马上堵。"),
                    ],
                },
            ],
        },
        {
            "id": "attack", "title": "进攻招数", "subtitle": "活三、活四、双重威胁", "art": "tutor_gomoku_attack",
            "lessons": [
                {
                    "id": "g4", "title": "活三和眠三", "icon": "3.circle.fill", "learned": "两头都空着的三颗叫活三",
                    "steps": [
                        step("三颗连在一起，而且两头都空着，这叫『活三』。活三很危险，再下一颗就是四颗了。",
                             board=g("c5,d5,e5", "g2,b8"), marks=["glow:b5", "glow:f5"]),
                        step("如果有一头已经被对手挡住了，这叫『眠三』，就没那么厉害了。",
                             board=g("c5,d5,e5", "b5,g2"), marks=["cross:b5", "glow:f5"]),
                        step("哪一组是活三？点一下它的棋子。",
                             board=g("b2,c2,d2,d6,e6,f6", "a2,h8"), marks=["label:b2:A", "label:d6:B"],
                             task=pick(["d6", "e6", "f6"]),
                             hint="看看三颗棋子的两头，是不是都空着。A 的左边被白棋挡住了。",
                             ok="对，B 两头都空着，是活三！", drill="点出两头都空着的那个活三。"),
                        step("现在轮到你：再下一颗，摆出一个活三！",
                             board=g("d5,e5", "c3,g7"), task=place(rule="openThree"),
                             hint="要和这两颗黑棋排在一条线上，而且两头都要空着。", ok="摆出活三了！"),
                        step("活三很厉害：对手要是不管它，你再下一颗，就变成活四了。下一课学活四。"),
                    ],
                },
                {
                    "id": "g5", "title": "活四必胜", "icon": "4.circle.fill", "learned": "活四对手堵不住",
                    "steps": [
                        step("四颗连在一起，两头都空着，叫『活四』。对手只能堵住一头，你就从另一头赢！",
                             board=g("c5,d5,e5,f5", "c3,e7"), marks=["glow:b5", "glow:g5"]),
                        step("这里有一个活三。再下一颗，把它变成活四！",
                             board=g("d5,e5,f5", "d3,f7,b2"), task=place(rule="winIn:1"),
                             hint="接在这三颗的一头，变成四颗，而且两头都要空着。", ok="变成活四了！",
                             drill="把活三变成活四！",
                             reply=["block"], after="白棋只能堵住一头。现在从另一头连成五颗吧！"),
                        step("最后一步！", task=place(rule="five"), ok="你赢了！这就是活四的厉害。"),
                        step("所以反过来，看到对手有活三，一定要马上去堵，不然它就变成活四了。"),
                    ],
                },
                G13,
                {
                    "id": "g6", "title": "双重威胁", "icon": "sparkles", "learned": "一步同时做出两个威胁",
                    "steps": [
                        step("看这里：横着有三颗，竖着有两颗。有一个点，下下去能同时做出『四颗』和『活三』，这叫『四三』！",
                             board=g("b6,c6,d6,e4,e5", "a6,g3,c3")),
                        step("找到那个点，下下去！", task=place(rule="winIn:2"),
                             hint="找横着那一排和竖着那一排交叉的地方。",
                             ok="对！横着变成了四颗，竖着变成了活三。",
                             drill="找到一步同时做出四和活三的点！",
                             reply=["block"], after="白棋只能先堵横着的四颗。现在，把竖着的活三变成活四！"),
                        step("变成活四！", task=place(rule="winIn:1"), ok="活四！白棋堵不住了。",
                             reply=["block"], after="最后一步，连成五颗！"),
                        step("连成五颗！", task=place(rule="five"), ok="赢啦！这就是双重威胁的厉害。"),
                        step("下棋的时候，找一找有没有一个点能同时做出两个威胁。这是赢棋最常用的办法。"),
                    ],
                },
                G15,
            ],
        },
        {
            "id": "defense", "title": "防守", "subtitle": "看清危险，堵对地方", "art": "tutor_gomoku_defense",
            "lessons": [
                {
                    "id": "g7", "title": "先看对手", "icon": "eye.fill", "learned": "每一步先看对手的威胁",
                    "steps": [
                        step("下棋前，先看看对手有没有危险的棋。白棋哪一组最危险？点一下。",
                             board=g("g8,f2,b7", "c4,d4,e4,g6,g7,h2"), task=pick(["c4", "d4", "e4"]),
                             hint="找三颗连在一起、两头都空着的白棋。",
                             ok="找到了！这是白棋的活三。", drill="点出白棋最危险的活三。"),
                        step("活三不堵，就会变成活四。现在把它堵住！", task=place(rule="stopOpenFour"),
                             hint="堵在紧挨着这三颗的地方。", ok="堵住了！白棋做不成活四了。",
                             drill="堵住白棋的活三！"),
                        step("换一个摆法。白棋哪一组是活三？点一下。",
                             board=g("b8,i2", "d3,e4,f5,b5,b6,b7"), task=pick(["d3", "e4", "f5"]),
                             hint="找两头都空着的三颗。竖着那三颗，下面已经被你堵住了。",
                             ok="对！斜着的三颗两头都空着，是活三。", drill="点出白棋最危险的活三。"),
                        step("把它堵住！", task=place(rule="stopOpenFour"),
                             hint="堵在斜线上紧挨着的一头。", ok="堵住了！", drill="堵住白棋的活三！"),
                        step("每一步都要先看一看：对手有没有活三？有没有四颗？看清楚了再下。"),
                    ],
                },
                {
                    "id": "g8", "title": "跳三堵中间", "icon": "arrow.down.to.line", "learned": "跳三要堵中间的空",
                    "steps": [
                        step("白棋这样也是活三：中间空了一格，叫『跳三』。", board=g("c7,g8", "b5,c5,e5"),
                             marks=["glow:d5"]),
                        step("跳三怎么堵最好？", task=place(accept=["d5"]),
                             hint="堵两头也能挡一下，但堵中间最好：一下子就把它们分开了。",
                             ok="对！堵在中间，三颗就被分开了。", drill="白棋有一个跳三，堵在中间的空点！"),
                        step("这个竖着的活三，你堵在哪里？", board=g("c3,h7", "f3,f4,f5"),
                             task=place(rule="stopOpenFour"), hint="堵在紧挨着它的上面或者下面。", ok="堵得好！"),
                        step("连着的活三，堵紧挨着的一头；跳三，堵中间的空。"),
                    ],
                },
                {
                    "id": "g9", "title": "边堵边攻", "icon": "arrow.triangle.2.circlepath", "learned": "找一举两得的点",
                    "steps": [
                        step("白棋有一个活三，必须堵。可以堵左边，也可以堵右边。", board=g("f4,f5,b7", "c3,d3,e3,h8"),
                             marks=["glow:b3", "glow:f3"]),
                        step("哪一边更好？想一想，哪个点堵完，还能帮自己连子？", task=place(accept=["f3"]),
                             hint="看看哪一头挨着你自己的黑棋。",
                             ok="对！堵住了白棋，自己还连成了一个活三。",
                             drill="找一个既堵住白棋、又能帮自己连子的点！"),
                        step("再来一个。白棋竖着有活三，哪一头堵了更好？",
                             board=g("f7,g7", "e4,e5,e6,h3"), task=place(accept=["e7"]),
                             hint="看看哪一头挨着你自己的黑棋。",
                             ok="对！堵住了白棋，自己又连成了一个活三。",
                             drill="找一个既堵住白棋、又能帮自己连子的点！"),
                        step("最好的防守，是一边堵住对手，一边帮自己进攻。"),
                    ],
                },
                G16,
            ],
        },
        {
            "id": "master", "title": "开局与实战", "subtitle": "开局、四四、综合练习", "art": "tutor_gomoku_master",
            "lessons": [
                {
                    "id": "g10", "title": "开局下中间", "icon": "scope", "learned": "开局下中间，棋子挨在一起",
                    "steps": [
                        step("开局的时候，第一颗黑棋下在棋盘的正中间，四面八方都可以发展。", board=g(),
                             task=place(accept=["e5"]), hint="正中间：横着数第五条线，竖着也数第五条线。",
                             ok="对！", drill="第一颗棋放在棋盘正中间。", reply=["e4"], after="白棋一般贴着黑棋下。白棋下在正上方，这叫『直指』。"),
                        step("第三颗黑棋也要贴近。下在既挨着白棋、又挨着黑棋的地方。",
                             task=place(accept=["d4", "f4", "d5", "f5"]),
                             hint="找一个和黑棋、白棋都挨着的点。", ok="很好！三颗子挨在一起，黑棋就有了进攻的基础。"),
                        step("如果白棋斜着贴，叫『斜指』。第三颗也一样贴着下。", board=g("e5", "f4"),
                             task=place(accept=["e4", "f5"]), hint="找一个和黑棋、白棋都挨着的点。", ok="对！",
                             drill="找一个和黑棋、白棋都挨着的点。"),
                        step("记住：开局下中间，棋子要挨在一起，不要东一颗西一颗。"),
                    ],
                },
                {
                    "id": "g11", "title": "四四", "icon": "square.on.square", "learned": "一步做出两个四",
                    "steps": [
                        step("一步棋同时做出两个『四颗』，叫『四四』，对手也只能堵一个。",
                             board=g("c4,d4,e4,f6,f7,f8", "b4,f9,h2,c7")),
                        step("找到那个点！", task=place(rule="winIn:1"),
                             drill="找一步同时做出两个四的点！",
                             hint="横着的三颗和竖着的三颗，它们延长以后在哪里相交？",
                             ok="对！横着一个四，竖着一个四。", reply=["block"], after="白棋只能堵一个。用另一个四赢下来！"),
                        step("连成五颗！", task=place(rule="five"), ok="赢啦！"),
                        step("再来一道：这次是斜线和横线。找到四三的那一点。",
                             board=g("f5,g5,h5,c7,d6", "i5,b3,h8"), task=place(rule="winIn:2"),
                             hint="横着那三颗往左接一颗，看看是不是正好在斜线上。",
                             ok="漂亮！", reply=["block"], after="继续，把活三变成活四！",
                             drill="找到一步同时做出四和活三的点！"),
                        step("变成活四！", task=place(rule="winIn:1"), reply=["block"], after="最后一步！"),
                        step("连成五颗！", task=place(rule="five"), ok="你已经会用双重威胁了！"),
                    ],
                },
                G14,
                {
                    "id": "g12", "title": "实战练习", "icon": "trophy.fill", "learned": "看清局面找最好的一步",
                    "steps": [
                        step("五道练习题！第一题：找一步马上赢。", board=g("d2,d3,d4,d5,b6", "d1,c4,e6,f3"),
                             task=place(rule="five"), hint="哪里能连成五颗？", ok="第一题答对！"),
                        step("第二题：白棋很危险，怎么办？", board=g("f2,d5,b7", "f3,f4,f5,f6"),
                             task=place(rule="block"), hint="白棋竖着连了四颗。", ok="第二题答对！"),
                        step("第三题：白棋有一个斜着的活三，堵住它。", board=g("e3,g5", "c3,d4,e5"),
                             task=place(rule="stopOpenFour"), hint="堵在斜线紧挨着的两头之一。", ok="第三题答对！"),
                        step("第四题：做出一个活四。", board=g("c6,d6,e6", "c4,e8,h3"),
                             task=place(rule="winIn:1"), hint="接在三颗的一头。", ok="第四题答对！"),
                        step("最后一题：找到四三的那一点。", board=g("d2,d3,d4,b7,c6", "d1,g6,h8"),
                             task=place(rule="winIn:2"), hint="竖着三颗往下接一颗，看看斜线。",
                             ok="全部答对！你已经是五子棋小高手了！"),
                    ],
                },
            ],
        },
    ],
}

# ----------------------------------------------------------------------------- 象棋

START = {}
for sq, p in {"a0": "R", "b0": "N", "c0": "B", "d0": "A", "e0": "K", "f0": "A", "g0": "B", "h0": "N", "i0": "R",
              "b2": "C", "h2": "C", "a3": "P", "c3": "P", "e3": "P", "g3": "P", "i3": "P"}.items():
    START[sq] = p
    START[sq[0] + str(9 - int(sq[1]))] = p.lower()


def fen(pieces, turn="w"):
    rows = []
    for y in range(9, -1, -1):
        row, empty = "", 0
        for x in "abcdefghi":
            p = pieces.get(f"{x}{y}")
            if p:
                if empty: row += str(empty); empty = 0
                row += p
            else:
                empty += 1
        if empty: row += str(empty)
        rows.append(row)
    return "/".join(rows) + " " + turn


def x(**kw):
    return fen({k: v for k, v in kw.items()})


S = fen(START)
PALACE_RED = ["d0", "e0", "f0", "d1", "e1", "f1", "d2", "e2", "f2"]

xiangqi = {
    "game": "xiangqi",
    "title": "象棋教学",
    "tracks": [
        {
            "id": "basic", "title": "基础规则", "subtitle": "每个棋子怎么走", "art": "tutor_xiangqi_basic",
            "lessons": [
                {
                    "id": "x1", "title": "认识棋盘", "icon": "square.grid.3x3.fill", "learned": "棋盘、九宫和楚河汉界",
                    "steps": [
                        step("这是象棋的棋盘。红方在下面，黑方在上面，红方先走。", board=S),
                        step("中间这一条空空的地方，叫『楚河汉界』，它把棋盘分成了两半。", marks=["river"]),
                        step("两边各有一个画着叉叉的小方框，叫『九宫』，是帅和将的家。", marks=["palace:red", "palace:black"]),
                        step("考考你：点一下红方九宫里的任意一个点。", task=pick(PALACE_RED),
                             hint="九宫在下面正中间，就是画着两条斜线的小方框。", ok="对！这就是红帅的家。"),
                        step("棋子都走在线的交叉点上。走到对方棋子的位置上，就把它吃掉了。"),
                    ],
                },
                {
                    "id": "x2", "title": "帅和仕", "icon": "crown.fill", "learned": "帅在九宫里走一格，仕斜着走",
                    "steps": [
                        step("帅只能待在九宫里，每次走一格，可以往前、往后、往左、往右。",
                             board=x(e0="K", d9="k"), marks=["glow:e1", "glow:d0", "glow:f0", "palace:red"]),
                        step("敌人跑进了九宫！用帅把黑炮吃掉。", board=x(e0="K", d0="c", f9="k"),
                             task=move(piece="e0", accept=["d0"]), hint="帅往旁边走一格，就能吃到它。", ok="吃掉了！"),
                        step("九宫外面的点，帅是去不了的。把帅往前走一格吧。", board=x(e0="K", d9="k"),
                             marks=["glow:e1", "cross:e3"], task=move(piece="e0", accept=["e1"]),
                             hint="往上走一格，走到发光的点。", ok="对！"),
                        step("这是仕。它也待在九宫里，但只能斜着走一格。", board=x(e0="K", d0="A", f0="A", d9="k"),
                             marks=["arrow:d0:e1"]),
                        step("把左边的仕斜着走到九宫中心。", task=move(piece="d0", accept=["e1"]),
                             hint="仕要斜着走，沿着九宫里的斜线。", ok="对，仕走斜线。"),
                        step("仕也能吃子。用仕吃掉这个卒！", board=x(e0="K", e1="A", d2="p", f9="k"),
                             task=move(piece="e1", rule="capture"), hint="仕斜着走一格就能吃到它。", ok="吃得好！"),
                    ],
                },
                {
                    "id": "x3", "title": "相", "icon": "square.split.diagonal.2x2.fill", "learned": "相走田字，不能过河",
                    "steps": [
                        step("这是相。它走『田』字：斜着一下走两格。", board=x(c0="B", g0="B", e0="K", d9="k"),
                             marks=["arrow:c0:e2", "arrow:c0:a2"]),
                        step("把相走到发光的点。", marks=["glow:e2"], task=move(piece="c0", accept=["e2"]),
                             hint="斜着走两格，像在田字格里走对角线。", ok="对！"),
                        step("如果田字中间有棋子挡着，叫『塞象眼』，相就走不过去了。",
                             board=x(c0="B", d1="A", e0="K", d9="k"), marks=["ring:d1", "cross:e2", "glow:a2"]),
                        step("相也能吃子。吃掉河边的这个卒！", board=x(e2="B", c4="p", e0="K", d9="k"),
                             task=move(piece="e2", rule="capture"), hint="沿着田字的对角线走过去。", ok="吃掉了！"),
                        step("相走到河边就停住了，它永远不能过河，是专门守家的。", marks=["river"]),
                    ],
                },
                {
                    "id": "x4", "title": "马", "icon": "figure.equestrian.sports", "learned": "马走日字，会被蹩马腿",
                    "steps": [
                        step("马走『日』字：先直着走一格，再斜着走一格。这些发光的点，马都能去。",
                             board=x(e4="N", e0="K", d9="k"),
                             marks=["glow:c3", "glow:c5", "glow:d2", "glow:d6", "glow:f2", "glow:f6", "glow:g3", "glow:g5"]),
                        step("把马走到发光的点。", marks=["glow:g5"], task=move(piece="e4", accept=["g5"]),
                             hint="往右走一格，再斜着往上走一格。", ok="对，这就是日字！"),
                        step("马的前面如果有棋子挡着，叫『蹩马腿』，那个方向就走不了。",
                             board=x(b0="N", b1="C", e0="K", d9="k"), marks=["ring:b1", "cross:a2", "cross:c2", "glow:d1"]),
                        step("这两匹马，哪一匹被蹩了马腿，一步都走不了？点一下它。",
                             board=x(b0="N", b1="C", c0="B", h0="N", e0="K", d9="k"), marks=["label:b0:A", "label:h0:B"],
                             task=pick(["b0"]), hint="看看马腿：马往哪边走，紧挨着它的那一格要空着。",
                             ok="对！A 马前面和旁边都被挡住了。"),
                        step("马也能吃子。用马吃掉黑车！", board=x(e4="N", g5="r", e0="K", d9="k"),
                             task=move(piece="e4", rule="capture"), hint="黑车正好在马的一个日字上。", ok="吃掉了黑车！"),
                    ],
                },
                {
                    "id": "x5", "title": "车", "icon": "arrow.up.and.down.and.arrow.left.and.right", "learned": "车走直线，走多远都行",
                    "steps": [
                        step("车走直线，横着、竖着都行，想走多远就走多远。", board=x(a0="R", e0="K", d9="k"),
                             marks=["arrow:a0:a8", "arrow:a0:d0"]),
                        step("车不能跳过别的棋子，但可以一路走过去吃子。吃掉那匹黑马！",
                             board=x(a0="R", a7="n", e0="K", d9="k"), task=move(piece="a0", accept=["a7"]),
                             hint="沿着这条竖线一直往上。", ok="一口气就吃掉了！"),
                        step("这一次，车能吃到哪一个？", board=x(e4="R", e6="P", e8="n", b4="c", g6="p", e0="K", d9="k"),
                             task=move(piece="e4", rule="capture"),
                             hint="车不能跳过棋子。上面的马被你自己的兵挡住了。", ok="对！马被兵挡住了，只能吃炮。"),
                        step("车是象棋里最厉害的棋子，要好好保护它，别让它被吃掉。"),
                    ],
                },
                {
                    "id": "x6", "title": "炮", "icon": "scope", "learned": "炮吃子要隔一个炮架",
                    "steps": [
                        step("炮不吃子的时候，走法和车一样，走直线。", board=x(b2="C", e0="K", d9="k"),
                             marks=["arrow:b2:b6", "arrow:b2:e2"]),
                        step("把炮走到中间这条线上，这叫『当头炮』。", marks=["glow:e2"],
                             task=move(piece="b2", accept=["e2"]), hint="横着走到中间那条线。", ok="当头炮！"),
                        step("炮吃子的时候，中间要隔着一个棋子跳过去，这个棋子叫『炮架』。",
                             board=x(b2="C", b6="p", b9="n", e0="K", d9="k"), marks=["ring:b6", "arrow:b2:b9"]),
                        step("用炮隔着炮架，吃掉黑马！", task=move(piece="b2", rule="capture"),
                             hint="炮要跳过中间那个卒，去吃后面的马。", ok="跳过去吃掉了！"),
                        step("炮现在能吃掉谁？试试看。", board=x(d0="K", e2="C", e6="r", g2="p", h2="n", f9="k"),
                             task=move(piece="e2", rule="capture"),
                             hint="炮吃子一定要隔一个棋子。黑车前面没有炮架，吃不到。", ok="对！隔着卒吃掉了马。"),
                    ],
                },
                {
                    "id": "x7", "title": "兵", "icon": "figure.walk", "learned": "兵过河才能横走，永远不后退",
                    "steps": [
                        step("兵在过河之前，只能往前走一格。往前走一步吧。", board=x(e3="P", e0="K", d9="k"),
                             marks=["glow:e4"], task=move(piece="e3", accept=["e4"]), hint="往上走一格。", ok="往前一步！"),
                        step("再往前走一格，兵就过河了。", marks=["glow:e5", "river"], task=move(piece="e4", accept=["e5"]),
                             hint="继续往上走一格。", ok="过河啦！"),
                        step("过了河的兵，可以往前，也可以往左右走一格，但是永远不能往后退。",
                             marks=["glow:e6", "glow:d5", "glow:f5", "cross:e4"]),
                        step("用兵横着吃掉旁边的马！", board=x(e5="P", d5="n", e0="K", d9="k"),
                             task=move(piece="e5", accept=["d5"]), hint="过了河的兵可以横着走一格。", ok="吃掉了！"),
                        step("兵虽然小，过了河以后也很有用，还能帮忙去将军呢。"),
                    ],
                },
                {
                    "id": "x8", "title": "将军和将死", "icon": "exclamationmark.triangle.fill", "learned": "将军、解将和将死",
                    "steps": [
                        step("用棋子去威胁对方的将，叫『将军』。走一步，将黑方一军！", board=x(d0="K", a5="R", e9="k"),
                             task=move(rule="check"), hint="让车和黑将在同一条直线上，中间不要有棋子。", ok="将军！"),
                        step("黑车在将军！被将军的时候，必须马上解。第一种办法：把帅躲开。",
                             board=x(e0="K", e7="r", d9="k"), task=move(rule="escape:king"),
                             hint="把帅往旁边躲一格，躲开黑车的那条线。", ok="躲开了！"),
                        step("第二种办法：用别的棋子挡在中间。", board=x(e0="K", d0="A", f0="A", c3="N", e7="r", d9="k"),
                             task=move(rule="escape:block"), hint="让一个棋子走到黑车和帅的中间。", ok="挡住了！"),
                        step("第三种办法：把将军的棋子吃掉！", board=x(e0="K", d0="A", f0="A", a7="R", e7="r", d9="k"),
                             task=move(rule="escape:capture"), hint="你的车能吃到黑车吗？", ok="吃掉了！这是最好的解法。"),
                        step("如果被将军以后，躲不开、挡不住、也吃不掉，就是被『将死』了，输了。现在轮到你将死黑将！",
                             board=x(e0="K", a7="R", b8="R", d9="k"), task=move(rule="mate"),
                             hint="一个车已经封住了一排，用另一个车去将军。", ok="将死了！你赢了！"),
                        step("还有一条特别的规则：帅和将不能在同一条直线上面对面，中间一定要有棋子隔着。帅走一步试试。",
                             board=x(d0="K", e9="k"), marks=["cross:e0"], task=move(piece="d0", rule="any"),
                             hint="帅走到中间那条线，就和将面对面了，不可以。", ok="对，往前走就安全了。"),
                        step("另外，如果轮到你走，却一步也走不了，也算输哦。基础规则全部学完啦！"),
                    ],
                },
            ],
        },
        {
            "id": "tactics", "title": "基本杀法", "subtitle": "怎样将死对方", "art": "tutor_xiangqi_tactics",
            "lessons": [
                {
                    "id": "x9", "title": "棋子的价值", "icon": "scalemass.fill", "learned": "车最大，马炮次之，不要白白送子",
                    "steps": [
                        step("棋子的力量不一样：车最厉害，马和炮差不多，兵最小，但过了河的兵也很有用。", board=S),
                        step("车可以吃黑马，也可以吃黑炮。吃哪一个更好？",
                             board=x(e4="R", e7="n", b4="c", b9="r", d0="K", f9="k"), task=move(rule="bestCapture"),
                             hint="炮后面有黑车保护着，吃了炮，你的车就会被吃掉。", ok="对！马没有人保护，吃掉它最安全。"),
                        step("黑车要吃你的马！把马走到安全的地方。", board=x(c4="N", c8="r", e0="K", d9="k"),
                             task=move(piece="c4", rule="safe"), hint="看看黑车能走到的地方，别停在那条线上。", ok="安全了！"),
                        step("每走一步都想一想：我的子会不会被吃掉？能不能吃到对方没人保护的子？"),
                    ],
                },
                {
                    "id": "x10", "title": "对面笑", "icon": "face.smiling.inverse", "learned": "利用帅将不能见面来杀棋",
                    "steps": [
                        step("帅和将不能面对面——这条规则也能用来杀棋！红帅占住了一条线，黑将就不能往那边走。",
                             board=x(d0="K", a2="R", g9="P", e9="k"), marks=["arrow:d0:d8"]),
                        step("找一步棋，将死黑将！", task=move(rule="mate"),
                             hint="用车从正下方将军。左边有帅看着，右边有兵守着。", ok="将死了！这叫『对面笑』。"),
                        step("两个车配合，一个封路、一个将军，叫『双车错』。将死它！",
                             board=x(e0="K", a8="R", b1="R", d9="k"), task=move(rule="mate"),
                             hint="一个车已经封住了将前面那一排，另一个车去最上面一排将军。", ok="将死了！"),
                    ],
                },
                {
                    "id": "x11", "title": "马后炮、重炮", "icon": "flame.fill", "learned": "马后炮和重炮",
                    "steps": [
                        step("马守住将的两边，炮在马的后面将军，叫『马后炮』。",
                             board=x(e7="N", a2="C", d0="K", e9="k"), marks=["ring:e7"]),
                        step("走一步，用马后炮将死黑将！", task=move(rule="mate"),
                             hint="把炮走到马的正下方，马就是炮架。", ok="马后炮！将死了！"),
                        step("两个炮叠在一条线上，前面的炮当炮架，叫『重炮』。将死它！",
                             board=x(e4="C", a3="C", d9="a", f9="a", e9="k", d0="K"), task=move(rule="mate"),
                             hint="把另一个炮也走到中间那条线上。", ok="重炮！将死了！"),
                    ],
                },
                {
                    "id": "x12", "title": "马的杀法", "icon": "bolt.fill", "learned": "卧槽马和两步杀",
                    "steps": [
                        step("马跳到黑将侧前方的『卧槽』位置去将军，叫『卧槽马』。找一步将死黑将！",
                             board=x(e7="P", d6="N", f1="R", d0="K", e9="k"), task=move(rule="mate"),
                             hint="马走日字跳过去将军。左边有帅看着，右边有车守着，前面有兵守着，黑将哪儿也去不了。", ok="卧槽马！将死了！"),
                        step("这一道要走两步：先将一军，等黑方应了以后，再将死它。",
                             board=x(a1="R", b2="R", d0="K", e9="k"), task=move(rule="mate2"),
                             hint="先用一个车去将军，把黑将赶到边上。", ok="好棋！", reply=["engine"],
                             after="黑将躲开了。现在一步将死它！"),
                        step("一步将死！", task=move(rule="mate"), hint="另一个车也来帮忙。", ok="两步杀成功！"),
                    ],
                },
            ],
        },
        {
            "id": "opening", "title": "开局", "subtitle": "开局怎么走", "art": "tutor_xiangqi_opening",
            "lessons": [
                {
                    "id": "x13", "title": "开局三原则", "icon": "list.number", "learned": "开局先出车马炮",
                    "steps": [
                        step("开局的时候，要先把车、马、炮这些厉害的棋子放出来，不要急着动帅和仕。", board=S),
                        step("你来走红方的第一步吧！选一个好的开局。",
                             task=move(accept=["h2e2", "b2e2", "h0g2", "b0c2", "c3c4", "g3g4", "c0e2", "g0e2"]),
                             hint="开局先动炮、马，或者往前挺兵，不要先动帅和仕。", ok="好棋！",
                             reply=["engine"], after="黑方也出子了。"),
                        step("再走一步，把一个还没动过的马、炮或者车放出来。", task=move(rule="develop"),
                             hint="选一个还没动过的马、车或者炮，而且别走到会被吃掉的地方。", ok="很好，棋子越来越活了！"),
                        step("记住三件事：先出车马炮；一个棋子不要连着走好多次；帅和仕先别乱动。"),
                    ],
                },
                {
                    "id": "x14", "title": "当头炮对屏风马", "icon": "shield.lefthalf.filled", "learned": "当头炮和屏风马",
                    "steps": [
                        step("这是最常见的开局。红方先把炮走到中间，叫『当头炮』，瞄准黑方中间的卒。", board=S,
                             marks=["arrow:h2:e2"], task=move(accept=["h2e2"]), hint="把右边的炮走到中间那条线。",
                             ok="当头炮！", reply=["h9g7"], after="黑方跳马保护中间的卒。"),
                        step("红方也把马跳出来，保护中间的兵。", marks=["arrow:h0:g2"], task=move(accept=["h0g2"]),
                             hint="右边的马往前跳。", ok="很好！", reply=["i9h9"], after="黑方把车放出来了。"),
                        step("红车也要出来，走到马原来的位置。", marks=["arrow:i0:h0"], task=move(accept=["i0h0"]),
                             hint="右边的车往左走一格。", ok="车出动了！", reply=["b9c7"],
                             after="黑方另一匹马也跳出来了。两匹马像屏风一样护住中间，这叫『屏风马』。"),
                        step("红方另一匹马也跳出来吧。", marks=["arrow:b0:c2"], task=move(accept=["b0c2"]),
                             hint="左边的马往前跳。", ok="对！", reply=["c6c5"], after="黑方挺起卒子，给马让路。"),
                        step("最后把左边的车也放出来。", marks=["arrow:a0:b0"], task=move(accept=["a0b0"]),
                             hint="左边的车往右走一格。", ok="开局完成！车、马、炮都出动了。"),
                    ],
                },
                {
                    "id": "x15", "title": "飞相局、仙人指路", "icon": "leaf.fill", "learned": "飞相局和仙人指路",
                    "steps": [
                        step("也有稳一点的开局。比如先把相飞到中间，叫『飞相局』。", board=S,
                             task=move(accept=["c0e2", "g0e2"]), hint="把一个相走田字，飞到中间。",
                             ok="飞相局！", reply=["b9c7"], after="飞相局很稳，帅的家门口被保护起来了。"),
                        step("还有一种开局：先把兵往前挺一步，给马让出路来，叫『仙人指路』。", board=S,
                             task=move(accept=["c3c4", "g3g4"]), hint="把第三路或第七路的兵往前走一格。",
                             ok="仙人指路！", reply=["engine"], after="这样，马以后就可以从兵后面跳出来了。"),
                        step("开局没有唯一的走法。只要记住先出子、保护好帅，就是好的开局！"),
                    ],
                },
            ],
        },
    ],
}


# ----------------------------------------------------------------------------- 围棋
# 坐标同五子棋："c3" = 第 c 列、从上往下第 3 行。冉冉执黑。


def pickall(accept):
    return {"type": "pickAll", "accept": accept}


def wq(b="", w="", size=9):
    return f"size={size};b={b};w={w}"


STAR9 = ["c3", "g3", "c7", "g7", "e5"]


def names(s):
    return s.split(",")


# 反复用到的局面（每一个的死活、吃子结论都用 GoBoard 的程序验证过，见 docs/tutorials.md）
BRIDGE = wq("a5,b5,c5,d5,e5,f5,f4,g4,h4,i4", "a4,b4,c4,d4,e4,e3,f3,g3,h3,i3")          # 黑 49 : 白 32
JIN9 = wq("c1,c2,a3,b3,c9,c8,f9,f8,d7,e7,f3,g3,e4,h4,e5,h5,f6,g6")                       # 角 4 子、边 6 子、中间 8 子各围 4 点
JIN9_DOTS = ["dot:" + p for p in names("a1,b1,a2,b2,d8,e8,d9,e9,f4,g4,f5,g5")]
DAME9 = wq("e1,e2,e3,d3,d4,d5,e5,e6,e7,d7,d8,d9", "f1,f2,f3,f4,f5,f6,f7,f8,f9")          # 单官 e4、e8、e9
DEAD9 = wq("e1,e2,e3,d4,e5,f5,g5,h5,i5,a6,b6,c6,d6,d7,d8,d9,i3", "f1,f2,f3,f4,g4,h4,i4,b8")  # 死子 b8、i3；单官 e4
GAME7 = "size=7;b=d4,c4,e3,e4;w=c3,d3,e2,d2"                                              # 七路对局第 8 手以后
GAME7_BLACK = names("d4,c4,e3,e4,f3,g3,b4,a4")

go = {
    "game": "go",
    "title": "围棋教学",
    "tracks": [
        {
            "id": "basic", "title": "认识围棋", "subtitle": "气、提子、打劫、地盘", "art": "tutor_go_basic",
            "lessons": [
                {
                    "id": "go1", "title": "棋盘和棋子", "icon": "square.grid.3x3.fill", "learned": "棋子下在交叉点上，黑先白后",
                    "steps": [
                        step("这是围棋的棋盘，横着竖着各有九条线。棋子下在线和线交叉的点上，黑棋先下，两个人轮流。", board=wq()),
                        step("棋盘上这几个小黑点叫『星位』。把一颗黑棋下在正中间的星位上吧。", marks=["glow:e5"],
                             task=place(accept=["e5"]), hint="正中间那个小黑点。", ok="下得好！", reply=["e3"],
                             after="白棋也下了一颗。围棋的棋子下了就不能挪动，但是可以被对方吃掉。",
                             drill="把一颗黑棋下在正中间的星位上。"),
                        step("真正比赛用的棋盘有十九路，很大。我们先在九路的小棋盘上学，道理是一模一样的。"),
                    ],
                },
                {
                    "id": "go2", "title": "气", "icon": "wind", "learned": "棋子旁边直线相连的空点是它的气",
                    "steps": [
                        step("一颗棋子上下左右紧挨着的空点，叫做它的『气』。棋盘中间的一颗子，有四口气。",
                             board=wq("e5"), marks=["dot:e4", "dot:e6", "dot:d5", "dot:f5"]),
                        step("这颗子在边上，它的气少了一口。把它的气全部点出来。", board=wq("e1"),
                             task=pickall(["d1", "f1", "e2"]), hint="上下左右看一看，挨着它的空点才是气，斜着的不算。",
                             ok="对！边上的子只有三口气。", drill="把边上这颗子的气全部点出来。"),
                        step("角上的子气更少。把它的气点出来。", board=wq("a1"), task=pickall(["b1", "a2"]),
                             hint="角上只有两边挨着空点。", ok="对，角上只有两口气。", drill="把角上这颗子的气全部点出来。"),
                        step("连在一起的棋子是一个整体，它们共用所有的气。这三颗连着的黑子一共有几口气？全部点出来。",
                             board=wq("c4,d4,d5"), task=pickall(["b4", "c3", "c5", "d3", "e4", "e5", "d6"]),
                             hint="一颗一颗看，每颗子旁边的空点都算，重复的只算一次。", ok="七口气，全找到了！",
                             drill="把这三颗连着的黑子的气全部点出来。"),
                        step("记住：气越多，棋子越安全；气越少，就越危险。"),
                    ],
                },
                {
                    "id": "go3", "title": "提子", "icon": "hand.raised.fill", "learned": "堵住对方所有的气就能提子",
                    "steps": [
                        step("这颗白子只剩一口气了。黑棋把它最后一口气也堵住，就能把它『提』掉，拿出棋盘！",
                             board=wq("d5,f5,e6", "e5"), task=place(rule="capture"), hint="找到白子还空着的那一口气。",
                             ok="提掉了！被提掉的子要拿出棋盘。"),
                        step("边上的子气少，更容易被吃。提掉这颗白子。", board=wq("d1,e2", "e1"),
                             task=place(rule="capture"), hint="白子在边上，还剩哪一口气？", ok="提掉了！"),
                        step("角上的白子只有两口气，现在只剩一口了。提掉它！", board=wq("b1", "a1"),
                             task=place(rule="capture"), hint="角上的子，看看它下面。", ok="真棒！"),
                        step("两颗连在一起的白子，要把它们所有的气都堵住才能提掉。", board=wq("c5,f5,d4,e4,d6", "d5,e5"),
                             task=place(rule="capture:2"), hint="两颗白子一共只剩一口气了，在哪里？", ok="一下提掉两颗！"),
                        step("记住：数清楚对方还剩几口气，堵住最后一口，就能提子。"),
                    ],
                },
                {
                    "id": "go4", "title": "吃子练习", "icon": "target", "learned": "先找只剩一口气的子",
                    "steps": [
                        step("这几颗白子里，哪一颗只剩一口气？吃掉它！", board=wq("c2,b3,d3,f5,g2", "c3,f6,g3"),
                             task=place(rule="capture"), hint="一颗一颗数它们的气，找只剩一口气的那颗。", ok="找对了！"),
                        step("角上的两颗白子，一起吃掉！", board=wq("a2,b2", "a1,b1"), task=place(rule="capture:2"),
                             hint="这两颗白子还剩哪一口气？", ok="两颗都提掉了！"),
                        step("这两颗白子还剩几口气？把它们吃掉。", board=wq("d5,d6,f5,f6,e4", "e5,e6"),
                             task=place(rule="capture:2"), hint="往下看，白子的下面还空着。", ok="吃得漂亮！"),
                        step("现在你会吃子了！去和小兔下『吃子棋』吧：第一档到第三档都是吃子棋，谁先吃到子谁就赢。"),
                    ],
                },
                {
                    "id": "go5", "title": "不能下的地方", "icon": "nosign", "learned": "没有气的地方不能下，能提子除外",
                    "steps": [
                        step("白棋如果下在中间这个点，四面都是黑子，一口气也没有。这样的点叫『禁入点』，白棋不能下。",
                             board=wq("d5,f5,e4,e6"), marks=["cross:e5"]),
                        step("考考你：黑棋不能下在哪个点？点一下它。", board=wq("", "c2,b3,d3,c4"),
                             marks=["label:c3:A", "label:g7:B"], task=pick(["c3"]),
                             hint="看看哪个点被白子围住了，黑棋下进去一口气都没有。", ok="对！A 是黑棋的禁入点。",
                             drill="黑棋不能下在哪个点？点一下它。"),
                        step("这个点四面都是白子，看起来不能下。可是黑棋下进去，能把一颗白子提掉，提掉以后就有气了，所以可以下！试试看。",
                             board=wq("d4,f4,e3", "d5,f5,e4,e6"), task=place(accept=["e5"]),
                             hint="下在被白子围住的那个点。", ok="能提子的话，禁入点也可以下！",
                             drill="这个点被白子围住了，可是下进去能提子。下进去！"),
                        step("记住：没有气的地方不能下；但如果下进去能提掉对方的子，就可以下。"),
                    ],
                },
                {
                    "id": "go6", "title": "打劫", "icon": "arrow.left.arrow.right", "learned": "被提劫以后要先在别处下一手",
                    "steps": [
                        step("黑棋下在这里，能提掉一颗白子。提掉它！", board=wq("c5,d4,d6", "d5,e4,e6,f5"),
                             task=place(rule="capture"), hint="白子 d5 只剩一口气。", ok="提掉了！", reply=["h8"],
                             after="白棋很想马上提回来，可是不行！你提我一颗、我马上提回来，会没完没了。所以规定：被提的一方要先在别处下一手，才能提回来。这叫『打劫』。"),
                        step("白棋只好在别处下了一手。现在轮到黑棋，把这个劫『粘』住，白棋就再也提不回来了。",
                             marks=["glow:d5"], task=place(accept=["d5"]), hint="下在刚才被提掉的那个点上。",
                             ok="粘住了！这个劫黑棋赢了。"),
                        # 第二个劫：这次是她被禁止马上提回（马上提会听到打劫的提醒），要先在别处叫吃一手
                        step("再打一次劫。先把只剩一口气的白子提掉！",
                             board=wq("c5,d4,d6,h3,b8,c9", "d5,e4,e6,f5,h2,i3,c8"),
                             task=place(rule="capture"), hint="中间那颗白子只剩一口气。", ok="提掉了！",
                             reply=["h4"], after="白棋没法马上提回来，就先叫吃了你的一颗子。"),
                        step("你的子被叫吃了，先把它救出来！", task=place(rule="escape:h3"),
                             hint="往还空着的那一边长出去。", ok="救出来了！", reply=["d5"],
                             after="白棋趁机把劫提回去了。"),
                        step("这次轮到你不能马上提回来了。先在别处叫吃一颗白子，逼白棋去救它！",
                             task=place(accept=["c7", "d8"]), hint="找一颗只有两口气的白子，堵住它一口气。",
                             ok="叫吃！白棋只好先去救它。", reply=["escape:c8"], after="白棋去救那颗子了。"),
                        step("你已经在别处下过一手，现在可以提回来了！", task=place(accept=["e5"]),
                             hint="下在刚才被白棋提走的那个点上。", ok="提回来了！"),
                        step("打劫的时候，谁有更多『在别处逼对方应』的棋，谁就能赢下这个劫。基础规则全部学完啦！"),
                    ],
                },
                {
                    "id": "go27", "title": "谁的地盘大谁赢", "icon": "map.fill", "learned": "谁的地盘大谁赢",
                    "steps": [
                        step("吃子棋比谁先吃到子。真正的围棋不一样：比谁的『地盘』大！", board=BRIDGE),
                        step("地盘就是自己的棋子，加上自己围住的空点。点出黑棋在角上围住的空点。",
                             board=wq("c1,c2,a3,b3"), task=pickall(["a1", "b1", "a2", "b2"]),
                             hint="被黑子围在角里的空点，一个一个点。", ok="四个空点，加上四颗黑子，这个角上黑棋有八个。",
                             drill="点出黑棋在角上围住的所有空点。"),
                        step("这盘棋下完了。谁的地盘大？黑棋大就点一颗黑子，白棋大就点一颗白子。", board=BRIDGE,
                             task=pick(names("a5,b5,c5,d5,e5,f5,f4,g4,h4,i4")),
                             hint="比一比：黑子围住的空点和白子围住的空点，哪边多？", ok="黑棋的地盘大，黑棋赢！",
                             drill="谁的地盘大？点一颗那一方的棋子。"),
                        step("所以吃子只是帮你围地的办法。第四档开始就是完整的围棋：下完数一数，谁的地盘大谁赢。"),
                    ],
                },
            ],
        },
        {
            "id": "capture", "title": "吃子技巧", "subtitle": "叫吃、抱吃、门吃、征子、枷", "art": "tutor_go_capture",
            "lessons": [
                {
                    "id": "go7", "title": "叫吃和逃跑", "icon": "exclamationmark.bubble.fill", "learned": "只剩一口气叫叫吃，被叫吃要往外长",
                    "steps": [
                        step("让对方只剩一口气，叫做『叫吃』，也叫『打吃』。叫吃这颗白子！", board=wq("d5,e4", "e5"),
                             task=place(rule="atari"), hint="白子现在有两口气，堵住其中一口。", ok="叫吃！",
                             reply=["escape:e5"], after="白棋往外长出了一颗，逃跑了，气又变多了。"),
                        step("黑子被叫吃了！快往外长一步，增加气。", board=wq("e5", "d5,e4,f5"),
                             task=place(rule="escape:e5"), hint="往还空着的那一边长出去。", ok="逃出来了！"),
                        step("叫吃要看方向：把白棋往边上赶，它就逃不掉；往中间赶，它就跑了。这颗白子，从哪边叫吃能吃掉它？",
                             board=wq("c4,b3", "b4"), task=place(rule="kill:b4"),
                             hint="把它往棋盘边上赶。", ok="对！白棋被赶到边上，跑不掉了。"),
                        step("记住：叫吃的时候，要把对方往边上、往自己子多的地方赶。"),
                    ],
                },
                {
                    "id": "go8", "title": "双叫吃", "icon": "arrow.up.left.and.arrow.down.right", "learned": "一步同时叫吃两块",
                    "steps": [
                        step("找一个点，一下子把两颗白子同时叫吃！", board=wq("d3,c4,f3,g4", "d4,f4"),
                             task=place(rule="doubleAtari"), hint="找两颗白子中间共同的那口气。", ok="双叫吃！",
                             reply=["escape:d4"], after="白棋只能救一颗，另一颗就跑不掉了！"),
                        step("吃掉另一颗白子。", task=place(rule="capture"), hint="那颗没被救的白子还剩一口气。", ok="吃到了！"),
                        step("双叫吃是最常用的吃子办法。下棋时多找找：有没有一个点能同时叫吃两块？"),
                    ],
                },
                {
                    # 抱吃：从外面叫吃，它往黑子那边逃，逃出来还是只有一口气（kill:P 只有一个答案，程序验证过）
                    "id": "go28", "title": "抱吃", "icon": "figure.arms.open", "learned": "从外面叫吃，把它抱住",
                    "steps": [
                        step("这颗白子有两口气。从外面叫吃它，让它只能往黑子堆里逃，这叫『抱吃』，像把它抱在怀里！",
                             board=wq("c4,d5,e5,f4", "d4"), task=place(rule="kill:d4"),
                             hint="两口气里，堵住离黑子远的那一口。", ok="抱住了！", reply=["escape:d4"],
                             after="白棋逃出来一步，可是旁边都是黑子，还是只有一口气！",
                             drill="从外面叫吃这颗白子，让它逃也逃不掉！"),
                        step("吃掉它们！", task=place(rule="capture:2"), hint="两颗白子最后一口气在哪里？", ok="抱吃成功！"),
                        step("这颗白子靠着棋盘边。还是从外面叫吃，把它抱住！", board=wq("a6,b6,c5", "b5"),
                             task=place(rule="kill:b5"), hint="堵住它往中间跑的那口气，让它只能往边上逃。",
                             ok="抱住了！", reply=["escape:b5"], after="白棋往边上逃，还是只有一口气。",
                             drill="从外面叫吃这颗白子，让它逃也逃不掉！"),
                        step("提掉它们！", task=place(rule="capture:2"), hint="两颗白子只剩一口气了。", ok="又抱吃成功了！"),
                        step("抱吃的诀窍：叫吃以前先看看，它逃的那一边是不是都是你的子。"),
                    ],
                },
                {
                    # 门吃：白子站在黑子"房子"的门口，关上门它就进不去也出不来（kill:P 只有一个答案）
                    "id": "go29", "title": "门吃", "icon": "door.left.hand.closed", "learned": "把门关上，让它逃不出去",
                    "steps": [
                        step("黑子围成了一间小房子，白子正站在门口。把门关上！这叫『门吃』。",
                             board=wq("c3,e3,c4,e4,d2", "d4"), task=place(rule="kill:d4"),
                             hint="门在房子开口的那一边，堵在白子外面。", ok="门关上了！", reply=["pass"],
                             after="白子想往屋里躲，可是屋里一口气都没有，进不去！",
                             drill="把门关上，让白子逃不出去！"),
                        step("把它提掉！", task=place(rule="capture"), hint="白子只剩屋里那一口气了。", ok="门吃成功！"),
                        step("棋盘边也可以算一面墙。这颗白子背后就是边，把门关上！", board=wq("b1,d1,b2,d2", "c2"),
                             task=place(rule="kill:c2"), hint="白子往外跑的那一口气，就是门。", ok="关门了！",
                             reply=["pass"], after="白子背后是棋盘边，没地方逃了。",
                             drill="把门关上，让白子逃不出去！"),
                        step("提掉它！", task=place(rule="capture"), hint="白子最后一口气在屋里。", ok="又关门吃掉一颗！"),
                        step("门吃：对方只剩一条往外跑的路，就把那扇门关上。"),
                    ],
                },
                {
                    "id": "go9", "title": "征子", "icon": "stairs", "learned": "一直叫吃，把对方赶到边上吃掉",
                    "steps": [
                        step("这颗白子有两口气。黑棋一直叫吃它，它往哪里逃都只有两口气，最后会被赶到边上吃掉。这叫『征子』，也叫『扭羊头』。叫吃它，一直追到吃掉为止！",
                             board=wq("d3,c4,e5", "d4"), task=place(rule="chase:d4"),
                             hint="叫吃的时候，别让它逃出来以后有三口气。", ok="追得好！", reply=["extend:d4"],
                             after="白棋又逃了一步，继续追！", loop="d4"),
                        step("征子成功，一大串白子都被吃掉了！"),
                        step("但是如果征子的路上有白子接应，白棋逃到那里就连上了，征子就不成立。看：这里有一颗白子在路上，往这边征就不行了。往另一边征吧！",
                             board=wq("d3,c4,e5", "d4,b7"), marks=["ring:b7"], task=place(rule="kill:d4"),
                             hint="往左下方追会碰到那颗白子，换一个方向叫吃。", ok="对！换个方向，征子又成了。"),
                    ],
                },
                {
                    "id": "go10", "title": "枷吃", "icon": "square.dashed", "learned": "不贴着叫吃，在外面一步关住它",
                    "steps": [
                        step("这颗白子有两口气。如果去叫吃它，它会逃到右下方那颗白子那里接上。这时候要用『枷』：不贴着叫吃，而是在它斜前方一步，把它关在门里。",
                             board=wq("c4,d3", "d4,g7"), marks=["ring:g7"]),
                        step("找到那个枷的点！", task=place(rule="net:d4"), hint="在白子斜着的右下方，把它两个逃跑的方向一起堵住。",
                             ok="枷住了！", reply=["extend:d4"], after="白棋想冲出来——"),
                        step("挡住它，一直关到吃掉为止！", task=place(rule="netChase:d4"), hint="堵在它冲出来的方向。", ok="关住了！",
                             reply=["extend:d4"], after="它还想跑，继续挡！", loop="d4"),
                        step("枷吃成功！白棋被关在门里，跑不掉了。"),
                    ],
                },
                {
                    "id": "go11", "title": "倒扑", "icon": "arrow.uturn.down", "learned": "先送一颗给对方吃，再提回一大块",
                    "steps": [
                        step("这块白棋只剩里面两口气。黑棋先往里面送一颗子，让白棋吃掉——这叫『倒扑』。",
                             board=wq("a3,b3,c3,d3,e2,e1", "a1,a2,b2,c2,d2,d1"), marks=["dot:b1", "dot:c1"]),
                        step("往里面送一颗！", task=place(accept=["b1", "c1"]), hint="下在白棋里面的两口气中的一个。",
                             ok="送进去了！", reply=["b1|c1"], after="白棋把这颗子提掉了。可是你看，提完以后白棋只剩一口气了！",
                             drill="往白棋里面送一颗子，准备倒扑！"),
                        step("马上提回来，吃掉一大块！", task=place(rule="capture:3"), hint="下在刚才被提掉的那个点上。",
                             ok="倒扑成功！送一颗，吃回七颗！"),
                    ],
                },
                {
                    "id": "go12", "title": "接不归", "icon": "link.badge.plus", "learned": "叫吃以后对方连回去也逃不掉",
                    "steps": [
                        step("边上这两颗白子，可以从左边叫吃。白棋想接回去，可是接回去以后整块还是只剩一口气——这叫『接不归』。",
                             board=wq("a2,b2,c2,e2,e1,c3,e3,d4,b3,a3", "b1,c1,d2")),
                        step("从左边叫吃！", task=place(accept=["a1"]), hint="下在两颗白子的左边。", ok="叫吃！",
                             reply=["d1"], after="白棋接回去了……但是整块只剩一口气了！",
                             drill="叫吃边上这两颗白子，让它们接不归！"),
                        step("吃掉整块！", task=place(rule="capture:4"), hint="白棋最后一口气在下面。", ok="接不归，一下吃四颗！"),
                    ],
                },
            ],
        },
        {
            "id": "connect", "title": "连接与对杀", "subtitle": "连起来、切开它、比气", "art": "tutor_go_connect",
            "lessons": [
                {
                    "id": "go13", "title": "连接", "icon": "link", "learned": "把自己的棋连起来才强",
                    "steps": [
                        step("两颗黑子斜着挨在一起，中间有个缺口。白棋已经下了一边，黑棋要把另一边补上，把两颗子连起来！",
                             board=wq("d4,e5", "e4"), task=place(rule="connect:d4:e5"), hint="下在两颗黑子都挨着的那个空点。",
                             ok="连上了！连在一起的棋子更强。"),
                        step("像这样三颗黑子围出一个口子，叫『虎口』。白棋下进来马上会被提掉，所以黑棋不用急着补。",
                             board=wq("d3,c4,e4"), marks=["glow:d4"]),
                        step("白棋想把这两块黑棋切开。补一手，把它们连起来！", board=wq("c5,e5,d6", "d4"),
                             task=place(rule="connect:c5:e5"), hint="两块黑棋中间还空着的地方。", ok="连好了！"),
                    ],
                },
                {
                    "id": "go14", "title": "切断", "icon": "scissors", "learned": "找对方的断点把它分开",
                    "steps": [
                        step("两颗白子斜着，中间有两个『断点』。黑棋已经占了一个，再下另一个，就把白棋切成两块了！",
                             board=wq("e4", "d4,e5"), task=place(accept=["d5"]), hint="两颗白子都挨着的另一个空点。",
                             ok="切断了！分开的棋更好吃。", drill="把两颗斜着的白子切断！"),
                        step("切断以后，白棋变成两颗孤零零的子。叫吃其中一颗！", task=place(rule="atari"),
                             hint="看看哪颗白子气少。", ok="追着它打！"),
                        # 切断以后两块白棋不相连，黑棋 d4、e3 两块白先也吃不掉（程序验证）
                        step("再来一个：两对白子斜着连在一起。找到它们的断点，切开！", board=wq("d4,d5,e2", "c3,d3,e4,f4"),
                             task=place(accept=["e3"]), hint="两对白子中间斜着的地方，有一个点还空着。",
                             ok="切断了！白棋变成了两块。", drill="找到断点，把白棋切成两块！"),
                        step("记住：看到对方的子斜着连，就去找它的断点。"),
                    ],
                },
                {
                    "id": "go15", "title": "对杀", "icon": "bolt.horizontal.fill", "learned": "比气，先紧对方外面的气",
                    "steps": [
                        step("左上角黑白两块棋互相包围，谁先把对方的气堵完，谁就赢，这叫『对杀』。白棋两颗子有三口气，黑棋两颗子也有三口气，轮到黑棋下。",
                             board=wq("a3,b3", "a2,b2"), marks=["dot:a1", "dot:b1", "dot:c2"]),
                        step("先堵白棋的气！注意：别先下到最里面的角上，那样会被白棋吃掉。", task=place(accept=["c2", "b1"]),
                             hint="堵白棋外面的气，角上那一点留到最后。", ok="好！白棋只剩两口气了。",
                             reply=["a4"], after="白棋也来堵黑棋的气了。"),
                        step("继续堵白棋的气，叫吃它！", task=place(accept=["c2", "b1"]), hint="白棋还剩两口气，再堵外面的那一口。", ok="叫吃！",
                             reply=["b4"], after="白棋又堵了黑棋一口气，可是白棋已经来不及了！"),
                        step("吃掉白棋！", task=place(rule="capture:2"), hint="白棋最后一口气在角上。", ok="对杀赢了！"),
                        step("对杀的秘诀：数清双方的气；先紧对方外面的气，里面的气留到最后。"),
                    ],
                },
            ],
        },
        {
            "id": "life", "title": "死活", "subtitle": "眼、两眼活棋、要点", "art": "tutor_go_life",
            "lessons": [
                {
                    "id": "go16", "title": "眼", "icon": "eye.fill", "learned": "被自己的子围起来的空点是眼",
                    "steps": [
                        step("被黑子围起来的这个空点叫『眼』。白棋下进去一口气都没有，不能下。",
                             board=wq("d4,e4,f4,d5,f5,d6,e6,f6"), marks=["glow:e5"]),
                        step("眼有真的也有假的：看眼的斜角，被对方占了两个，就是『假眼』。哪个是真眼？点一下它。",
                             board=wq("b4,c4,d4,b5,d5,b6,c6,d6,f5,h5,g4,g6,h4,f6", "f4,h6"),
                             marks=["label:c5:A", "label:g5:B"], task=pick(["c5"]),
                             hint="看看两个眼的斜角，B 的斜角被白棋占了两个。", ok="对！A 是真眼，B 是假眼。",
                             drill="哪个是真眼？点一下它。"),
                        step("这个眼的斜角有一个被白棋占了，还有一个空着。补上空着的斜角，它就变成真眼了！",
                             board=wq("d5,f5,e4,e6,d4,f6", "d6"), task=place(accept=["f4"]),
                             hint="看看眼斜着的四个角，哪个还空着？", ok="真眼做好了！",
                             drill="补上眼的斜角，把它变成真眼！"),
                    ],
                },
                {
                    "id": "go17", "title": "两只眼才能活", "icon": "eyes", "learned": "有两只真眼的棋是活棋",
                    "steps": [
                        step("这块黑棋有两只眼。白棋两只眼都下不进去，所以这块黑棋永远不会被吃掉，叫『活棋』。",
                             board=wq("b1,d1,a2,b2,c2,d2", "a3,b3,c3,d3,e3,e2,e1"), marks=["glow:a1", "glow:c1"]),
                        step("这块白棋只有一只眼。只有一只眼的棋是死棋：先把外面的气堵住，再下到眼里，就能整块提掉。先堵外面的气！",
                             board=wq("a3,b3,c3,d2", "b1,c1,a2,b2,c2"), task=place(rule="atari"),
                             hint="白棋外面还有一口气没堵。", ok="叫吃！", reply=["pass"], after="白棋没办法了，只剩眼里这一口气。"),
                        step("下到眼里，整块提掉！", task=place(rule="capture:5"), hint="下在白棋那只眼里。",
                             ok="一只眼的棋，被整块吃掉了！"),
                        step("这块黑棋已经有一只眼了。再做一只，就活了！", board=wq("b1,a2,b2,c2,d2", "a3,b3,c3,d3,e3,e2,e1"),
                             task=place(accept=["d1"]), hint="还差一颗子，就能再围出一只眼。", ok="两只眼，活了！",
                             drill="再做一只眼，让这块黑棋活！"),
                    ],
                },
                {
                    "id": "go18", "title": "直三和曲三", "icon": "3.square.fill", "learned": "直三、曲三的要点在中间",
                    "steps": [
                        step("这块黑棋里面有三个空点排成一排，叫『直三』。中间那个点最重要：黑棋下在这里，就分成两只眼，活了！",
                             board=wq("a2,b2,c2,d2,d1", "a3,b3,c3,d3,e3,e2,e1"), task=place(accept=["b1"]),
                             hint="下在三个空点的正中间。", ok="活了！", drill="下在直三的要点上，做活！"),
                        step("反过来，如果是白棋的直三，黑棋抢先下在中间的要点上，白棋就只剩一只眼，死了！",
                             board=wq("a3,b3,c3,d3,e3,e2,e1", "a2,b2,c2,d2,d1"), task=place(accept=["b1"]),
                             hint="还是三个空点的中间。", ok="点死了！这叫『点眼』。", drill="点在白棋直三的要点上，点死它！"),
                        step("三个空点拐了个弯，叫『曲三』。要点在拐弯的地方。黑棋下在要点上做活！",
                             board=wq("a3,b3,b2,c2,c1", "a4,b4,c4,d3,d2,d1"), task=place(accept=["a1"]),
                             hint="三个空点拐角的那一点。", ok="曲三也活了！", drill="下在曲三的要点上，做活！"),
                        step("记住：直三、曲三，自己先下要点就活，对方先下要点就死。所以要点要抢着下！"),
                    ],
                },
                {
                    # 直四：白点 b1 黑只有 c1 能活（白点 c1 时只有 b1）；方四：白下 a1 后只有 b2 能杀；
                    # 刀把五只有 b1 能杀；梅花五只有 c2 能杀。都用小范围穷举搜索证明过。
                    "id": "go19", "title": "直四、方四、刀把五", "icon": "square.grid.2x2.fill", "learned": "直四活，方四死，刀把五、梅花五要点",
                    "steps": [
                        step("四个空点排成一排，叫『直四』。白棋点进来了，你下另一个中间点，就还有两只眼！",
                             board=wq("a2,b2,c2,d2,e2,e1", "a3,b3,c3,d3,e3,f3,f2,f1,b1"), task=place(accept=["c1"]),
                             hint="四个空点中间有两个点，白棋占了一个，你下另一个。", ok="活了！直四是活棋。",
                             drill="白棋点进了直四。下另一个中间点，做活！"),
                        step("四个空点挤成一个方块，叫『方四』。不管怎么下都只能做出一只眼，所以方四是死棋。",
                             board=wq("a4,b4,c4,d4,d3,d2,d1", "a3,b3,c3,c2,c1"), marks=["dot:a1", "dot:b1", "dot:a2", "dot:b2"]),
                        step("白棋不服气，在方四里下了一手。剩下三个空点拐了个弯，点在要点上杀死它！",
                             board=wq("a4,b4,c4,d4,d3,d2,d1", "a3,b3,c3,c2,c1,a1"), task=place(accept=["b2"]),
                             hint="剩下的三个空点是曲三，要点在拐弯的地方。", ok="杀死了！方四真的活不了。",
                             drill="白棋在方四里下了一手。点在要点上，杀死它！"),
                        step("五个空点像一把刀，叫『刀把五』。要点是挨着最多空点的那一点。黑棋先点进去，白棋就做不出两只眼了！",
                             board=wq("a4,b4,c4,d4,d3,e2,e1", "a3,b3,c3,c2,d2,d1"), task=place(accept=["b1"]),
                             hint="找挨着三个空点的那一点。", ok="刀把五被点死了！", drill="点在刀把五的要点上，点死它！"),
                        step("五个空点像一朵梅花，叫『梅花五』。要点在正中间，抢先点进去！",
                             board=wq("a4,a5,b5,c5,d5,e5,e4,f4,f3,f2,f1", "a1,b1,d1,e1,a2,e2,a3,b3,d3,e3,b4,c4,d4"),
                             task=place(accept=["c2"]), hint="挨着四个空点的那一点，就是花心。", ok="梅花五也被点死了！",
                             drill="点在梅花五的正中间，点死它！"),
                    ],
                },
                {
                    "id": "go20", "title": "死活练习", "icon": "checkmark.seal.fill", "learned": "找到死活的要点",
                    "steps": [
                        step("第一题：白棋在右上角是直三，点死它！", board=wq("i3,h3,g3,f3,e3,e2,e1", "i2,h2,g2,f2,f1"),
                             task=place(accept=["h1"]), hint="直三的要点在中间。", ok="第一题答对！", drill="白棋是直三，点死它！"),
                        step("第二题：黑棋在左下角是曲三，做活！", board=wq("a7,b7,b8,c8,c9", "a6,b6,c6,d7,d8,d9"),
                             task=place(accept=["a9"]), hint="曲三的要点在拐弯处。", ok="第二题答对！", drill="黑棋是曲三，做活！"),
                        step("第三题：右下角的黑棋已经有一只眼，再做一只！", board=wq("h9,i8,h8,g8,f8", "i7,h7,g7,f7,e8,e9"),
                             task=place(accept=["f9"]), hint="还差一颗子就能再围出一只眼。", ok="全部答对！死活你已经入门了！",
                             drill="黑棋已经有一只眼，再做一只！"),
                    ],
                },
            ],
        },
        {
            # 布局全部用 9 路：她自己下的就是 9 路棋
            "id": "opening", "title": "布局", "subtitle": "金角银边、拆边、大场", "art": "tutor_go_opening",
            "lessons": [
                {
                    "id": "go21", "title": "金角银边草肚皮", "icon": "square.dashed.inset.filled", "learned": "先占角，再占边，最后中间",
                    "steps": [
                        step("同样围四个空点：角上用四颗子，边上要六颗，中间要八颗。所以说『金角银边草肚皮』。",
                             board=JIN9, marks=JIN9_DOTS),
                        step("哪一块用的子最少？点一颗它的子。", marks=JIN9_DOTS, task=pick(names("c1,c2,a3,b3")),
                             hint="数一数，每一块用了几颗子？", ok="对！角上最省子，所以开局先占角。",
                             drill="哪一块围地用的子最少？点一颗它的子。"),
                        step("九路棋盘上，第一手下在四个星位，或者正中间的天元，都很好。下第一手吧！", board=wq(),
                             task=place(accept=STAR9), hint="找棋盘上的小黑点。第一、二条线离边太近，开局不要下。",
                             ok="好开局！", reply=["g7|c3"], after="白棋也占了一个角。",
                             drill="开局第一手，下在星位或者天元上！"),
                        step("再占一个空着的角！", task=place(rule="corner"), hint="找一个还没有棋子的角，离边三、四条线的地方。",
                             ok="很好！开局就是这样抢角。"),
                    ],
                },
                {
                    "id": "go22", "title": "沿着边拆开", "icon": "arrow.left.and.right", "learned": "占了角，沿着边拆开",
                    "steps": [
                        step("黑棋占了角。沿着第三条线往边上走，隔一两个点再下，叫『拆』。拆一手吧！",
                             board=wq("c3", "g7"), task=place(accept=["c5", "c6", "e3", "f3"]),
                             hint="从角上的黑子出发，沿着第三条线，隔一两个点再下。", ok="拆得好！角和边连起来了。",
                             reply=["g5"], after="白棋也在它那边拆了一手。", drill="从角上的黑子出发，沿着边拆一手！"),
                        step("两个角都是黑棋的。在两颗黑子中间拆一手，把这条边连成一片！", board=wq("c3,c7", "g3,g7"),
                             task=place(accept=["c5"]), hint="两颗黑子正中间的那一点。", ok="这一整条边都是黑棋的了！",
                             reply=["g5"], after="白棋也在它那边拆了。", drill="在两颗黑子正中间拆一手！"),
                        step("占了角，就沿着边拆开。角和边连成一大片，最好围地。"),
                    ],
                },
                {
                    "id": "go23", "title": "先占大地方", "icon": "star.fill", "learned": "不在第一线爬，先占大地方",
                    "steps": [
                        step("黑棋在第一条线上爬了五步，什么也没围到；白棋在外面却围了一大片。",
                             board=wq("b1,c1,d1,e1,f1", "b2,c2,d2,e2,f2,g2")),
                        step("所以开局不要下在第一、二条线上。A 在第二条线，B 在第三条线，哪个好？", board=wq("c3", "g7"),
                             marks=["label:b8:A", "label:c7:B"], task=pick(["c7"]),
                             hint="离边太近，围不到地。", ok="对！第三条线才好围地。"),
                        step("棋盘上还有一个角空着，那是最大的地方。占住它！", board=wq("c3,c5,c7", "g3"),
                             task=place(accept=["f6", "f7", "g6", "g7"]), hint="找没有棋子的那个角，离边三、四条线。",
                             ok="抢到大地方了！", drill="找到还空着的角，占住它！"),
                        step("开局先占空角、空边这些大地方。以后到了十三路、十九路的大棋盘，还要学守角和挂角。"),
                    ],
                },
            ],
        },
        {
            "id": "endgame", "title": "终局与数子", "subtitle": "收官、停一手、数子、下一盘", "art": "tutor_go_endgame",
            "lessons": [
                {
                    "id": "go24", "title": "围地", "icon": "square.on.square.dashed", "learned": "围起来的空地是自己的地",
                    "steps": [
                        step("黑棋的子在下面围出了一大块空地，可是边界上有一个缺口，白棋会从这里钻进来。把它补上！",
                             board=wq("a6,b6,d6,e7,e8,e9", "a4,b4,c4,d4,e5,f6"), task=place(accept=["c6"]),
                             hint="看看黑棋的墙哪里还开着口。", ok="补上了！下面这块空地都是黑棋的了。",
                             drill="黑棋的墙上有个缺口，补上它！"),
                        step("被自己的子围起来的空地，就是自己的『地』。下棋的目的，就是比谁的地更大。"),
                        step("这次缺口在棋盘边上，最容易忘！补上它。", board=wq("f2,f3,f4,g4,h4,i4", "e1,e2,e3,e4,e5,f5"),
                             task=place(accept=["f1"]), hint="顺着黑墙一直看到棋盘边。", ok="补上了！",
                             drill="黑墙在棋盘边上还有个缺口，补上它！"),
                        step("数一数：点出黑棋在角上围住的所有空点。", task=pickall(names("g1,h1,i1,g2,h2,i2,g3,h3,i3")),
                             hint="黑墙里面的空点，一个一个点。", ok="九个空点，都是黑棋的地！",
                             drill="点出黑棋在角上围住的所有空点。"),
                    ],
                },
                {
                    "id": "go25", "title": "收官", "icon": "flag.checkered", "learned": "最后先下大的地方",
                    "steps": [
                        step("快下完了，还有两个地方没下：一个是黑棋这边墙上的缺口，一个是白棋那边的小缺口。先下哪一个更重要？",
                             board=wq("a6,b6,d6,e7,e8,e9,g3,g4,h4", "h1,h2,h3,f4,f5,g5,i5"), task=place(accept=["c6"]),
                             hint="黑棋那个缺口后面有一大块地，被白棋钻进来损失可就大了。", ok="对！先补大的。", reply=["i4|i3"],
                             after="白棋也补上了它的小缺口。"),
                        # 白棋先下 d3，黑棋 d1、d2 两颗就被切开、吃得掉（程序验证）
                        step("又快下完了：黑墙中间有个缺口，白墙在边上也有个小缺口。先下哪个？",
                             board=wq("d1,d2,d4,d5,d6,d7,d8,d9", "e1,e2,e3,e4,e5,e6,e7,e8"), task=place(accept=["d3"]),
                             hint="白棋要是从黑墙的缺口钻进来，边上两颗黑子就被切断了。", ok="对！先补大的。",
                             reply=["e9"], after="白棋也补上了它的小缺口。"),
                        step("收官就是比谁先下到大的地方。"),
                    ],
                },
                {
                    "id": "go30", "title": "单官", "icon": "circle.dotted", "learned": "单官最小，最后下掉",
                    "steps": [
                        step("棋快下完了。这个点挨着黑子也挨着白子，谁下都围不到地，叫『单官』。",
                             board=DAME9, marks=["glow:e4"]),
                        step("还有别的单官吗？把所有的单官都点出来。", task=pickall(["e4", "e8", "e9"]),
                             hint="找夹在黑墙和白墙中间的空点。", ok="三个单官，全找到了！", drill="点出所有的单官。"),
                        step("单官最小，下一个只多一个子。可是最后也要下掉。下一个单官！", task=place(rule="dame"),
                             hint="下在黑墙和白墙中间的空点上。", ok="下好了！", reply=["e4|e8|e9"], after="白棋也下了一个。",
                             drill="下一个单官！"),
                        step("还剩最后一个单官，下掉它！", task=place(rule="dame"), hint="黑墙和白墙中间还空着的那个点。",
                             ok="单官下完，边界全部封好啦！"),
                        step("记住：先下大的地方，单官留到最后再下掉。"),
                    ],
                },
                {
                    # 死子 b8、i3：各自那一方先下也逃不掉；h3 送进去白棋应一手就能吃掉，白棋那块怎么都是活的（穷举验证）
                    "id": "go31", "title": "死子", "icon": "xmark.circle.fill", "learned": "死子不用提，数子时直接拿掉",
                    "steps": [
                        step("棋下完了。黑棋地里有一颗白子，白棋地里也有一颗黑子。它们做不出两只眼，叫『死子』。", board=DEAD9),
                        step("把所有的死子都点出来，黑的白的都算。", task=pickall(["b8", "i3"]),
                             hint="找被对方的子围在中间、孤零零的那颗。", ok="两颗死子都找到了！", drill="把所有的死子都点出来。"),
                        step("死子不用花一手去提。数子的时候，直接把它们拿出棋盘，那里算对方的地。"),
                        step("那现在黑棋下哪里有用？A 在自己的地里，B 在白棋的活棋里，C 是单官。",
                             marks=["label:b7:A", "label:h3:B", "label:e4:C"], task=pick(["e4"]),
                             hint="往自己的地里下、往对方活棋里送子，地都不会变多。", ok="对！只有单官还有用。"),
                        step("记住：不往自己的地里下，不往对方活棋里送子，死子留到数子的时候拿掉。"),
                    ],
                },
                {
                    "id": "go32", "title": "停一手", "icon": "pause.circle.fill", "learned": "下完了就两边停一手",
                    "steps": [
                        step("还剩最后一个缺口，把它补上！", board=wq("e1,e2,e3,e4,e6,e7,e8,e9", "f1,f2,f3,f4,f5,f6,f7,f8,f9"),
                             task=place(accept=["e5"]), hint="黑墙上还开着一个口。", ok="补好了！", reply=["pass"],
                             after="白棋没有要下的地方了，它『停一手』：这一步不下棋。", drill="把墙上最后一个缺口补上！"),
                        step("现在你也没有有用的地方可下了，也停一手。两个人接连都停一手，这盘棋就结束了。"),
                        step("和电脑下棋的时候，点『停一手』按钮就行。两边都停了，电脑会帮你们数子。"),
                        step("可是别太早停！这盘棋还有没下完的地方，全部点出来。",
                             board=wq("e1,e2,e4,e5,e6,e7,e8,e9", "f1,f2,f3,f4,f5,f6,g7,f8,f9"), task=pickall(["e3", "f7"]),
                             hint="找墙上的缺口，还有夹在两边中间的单官。", ok="都找到了！缺口和单官都下完，才能停一手。",
                             drill="把还没下完的地方全部点出来。"),
                    ],
                },
                {
                    "id": "go26", "title": "数子定胜负", "icon": "number.circle.fill", "learned": "数子加贴目定胜负",
                    "steps": [
                        step("下完以后数一数：自己的棋子加上围住的空地，就是自己的『子数』。黑棋先下占了便宜，所以白棋要加上七个半，这叫『贴目』。",
                             board=wq("a5,b5,c5,d5,e5,f5,g5,h5,i5", "a6,b6,c6,d6,e6,f6,g6,h6,i6")),
                        step("黑棋有四十五子，白棋三十六子，再加七个半。谁赢了？黑棋赢就点一颗黑子，白棋赢就点一颗白子。",
                             task=pick(["a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5", "i5"]),
                             hint="三十六加七个半是四十三个半，和四十五比一比。", ok="黑棋赢了一个半子！"),
                        step("这一盘呢？黑棋三十六子，白棋四十五子加七个半。谁赢了？",
                             board=wq("a4,b4,c4,d4,e4,f4,g4,h4,i4", "a5,b5,c5,d5,e5,f5,g5,h5,i5"),
                             task=pick(["a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5", "i5"]),
                             hint="白棋的子本来就多，还要再加贴目。", ok="白棋赢了！"),
                        step("数子你也会了！最后，我们从第一手开始，下一整盘小棋。"),
                    ],
                },
                {
                    # 七路完整的一盘（共 16 手）：黑 d4 c4 e3 e4 | f3 g3 b4 a4，白 c3 d3 e2 d2 | f2 g2 b3 a3，
                    # 然后双方停一手。终局黑 8 子 + 23 空 = 31，白 8 子 + 10 空 = 18，没有单官、没有死子（程序数过）
                    "id": "go33", "title": "下一盘小棋：开局", "icon": "play.circle.fill", "learned": "从第一手下起，抢好位置",
                    "steps": [
                        step("这次从第一手开始，下一整盘棋！这是七路的小棋盘，你执黑先下。", board="size=7;b=;w="),
                        step("小棋盘上，第一手下在正中间最好，往哪边都能围地。", task=place(accept=["d4"]),
                             hint="找棋盘正中间的那个点。", ok="好棋！", reply=["c3"], after="白棋下在了角上。"),
                        step("白棋想往下面发展。在白子下面挡一手，挡住它的路！", task=place(accept=["c4"]),
                             hint="紧贴着白子的下面，挨着中间的黑子。", ok="挡住了！", reply=["d3"], after="白棋往旁边长了一步。"),
                        step("白棋两颗子排成一排。在它的头上扳一手，不让它往前长！", task=place(accept=["e3"]),
                             hint="下在两颗白子往前走的那一头。", ok="扳得好！", reply=["e2"],
                             after="白棋也来扳。小心，黑棋有一个断点！"),
                        step("两颗黑子斜着挨在一起，中间有个断点。把它连起来！", task=place(rule="connect:d4:e3"),
                             hint="下在两颗黑子都挨着的那个空点。", ok="连好了！", reply=["d2"], after="白棋也补好了自己的断点。"),
                        step("开局下好了：上面一块是白棋的，下面一大块是黑棋的。下一课接着下，把边界封好！"),
                    ],
                },
                {
                    "id": "go34", "title": "下一盘小棋：收官和数子", "icon": "trophy.fill", "learned": "下完一整盘，数子定胜负",
                    "steps": [
                        step("接着上一课下。白棋想从右边钻进来，往右长一步挡住它！", board=GAME7, task=place(accept=["f3"]),
                             hint="沿着黑子那一排，往右边下一颗。", ok="挡住了！", reply=["f2"], after="白棋也往右长了。"),
                        step("再往边上挡一手，把右边封住！", task=place(accept=["g3"]), hint="一直挡到棋盘的边上。",
                             ok="右边封好了！", reply=["g2"], after="白棋也把它那边封好了。"),
                        step("左边还开着口。挡住白棋，别让它往下钻！", task=place(accept=["b4"]),
                             hint="挨着黑子，往左边再下一颗。", ok="挡住了！", reply=["b3"], after="白棋也挡住了。"),
                        step("最后一个缺口在棋盘边上，补上它！", task=place(accept=["a4"]), hint="看看最左边那条线。",
                             ok="补好了！", reply=["a3"], after="白棋也补好了。现在边界全部封好啦！"),
                        step("哪里都没有要下的地方了。两边都停一手，这盘棋就下完了。来数子！"),
                        step("先数白棋：白棋有八颗子。再点出白棋围住的所有空点。",
                             task=pickall(names("a1,b1,c1,d1,e1,f1,g1,a2,b2,c2")),
                             hint="白墙上面的空点都算。", ok="十个空点，加八颗子，白棋一共十八。"),
                        step("黑棋八颗子加二十三个空点，一共三十一。白棋十八加七个半，是二十五个半。谁赢了？",
                             task=pick(GAME7_BLACK), hint="三十一和二十五个半，哪个大？", ok="黑棋赢了！你下完了一整盘围棋！"),
                    ],
                },
            ],
        },
    ],
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for course in (gomoku, xiangqi, go):
        path = os.path.join(OUT, course["game"] + ".json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(course, f, ensure_ascii=False, indent=1)
        n = sum(len(l["steps"]) for t in course["tracks"] for l in t["lessons"])
        print(path, "lessons", sum(len(t["lessons"]) for t in course["tracks"]), "steps", n)
