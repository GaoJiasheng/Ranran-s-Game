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


def step(say, board=None, marks=None, task=None, hint=None, ok=None, reply=None, after=None):
    s = {"say": say}
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
                             hint="要放在发光的那个交叉点上哦。", ok="放得真准！", reply=["f4"],
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
                             ok="对！B 这五颗斜着紧紧连在一起。"),
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
                             ok="对，B 两头都空着，是活三！"),
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
                             reply=["block"], after="白棋只能堵住一头。现在从另一头连成五颗吧！"),
                        step("最后一步！", task=place(rule="five"), ok="你赢了！这就是活四的厉害。"),
                        step("所以反过来，看到对手有活三，一定要马上去堵，不然它就变成活四了。"),
                    ],
                },
                {
                    "id": "g6", "title": "双重威胁", "icon": "sparkles", "learned": "一步同时做出两个威胁",
                    "steps": [
                        step("看这里：横着有三颗，竖着有两颗。有一个点，下下去能同时做出『四颗』和『活三』，这叫『四三』！",
                             board=g("b6,c6,d6,e4,e5", "a6,g3,c3")),
                        step("找到那个点，下下去！", task=place(rule="winIn:2"),
                             hint="找横着那一排和竖着那一排交叉的地方。",
                             ok="对！横着变成了四颗，竖着变成了活三。",
                             reply=["block"], after="白棋只能先堵横着的四颗。现在，把竖着的活三变成活四！"),
                        step("变成活四！", task=place(rule="winIn:1"), ok="活四！白棋堵不住了。",
                             reply=["block"], after="最后一步，连成五颗！"),
                        step("连成五颗！", task=place(rule="five"), ok="赢啦！这就是双重威胁的厉害。"),
                        step("下棋的时候，找一找有没有一个点能同时做出两个威胁。这是赢棋最常用的办法。"),
                    ],
                },
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
                             ok="找到了！这是白棋的活三。"),
                        step("活三不堵，就会变成活四。现在把它堵住！", task=place(rule="stopOpenFour"),
                             hint="堵在紧挨着这三颗的地方。", ok="堵住了！白棋做不成活四了。"),
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
                             ok="对！堵在中间，三颗就被分开了。"),
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
                             ok="对！堵住了白棋，自己还连成了一个活三。"),
                        step("最好的防守，是一边堵住对手，一边帮自己进攻。"),
                    ],
                },
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
                             ok="对！", reply=["e4"], after="白棋一般贴着黑棋下。白棋下在正上方，这叫『直指』。"),
                        step("第三颗黑棋也要贴近。下在既挨着白棋、又挨着黑棋的地方。",
                             task=place(accept=["d4", "f4", "d5", "f5"]),
                             hint="找一个和黑棋、白棋都挨着的点。", ok="很好！三颗子挨在一起，黑棋就有了进攻的基础。"),
                        step("如果白棋斜着贴，叫『斜指』。第三颗也一样贴着下。", board=g("e5", "f4"),
                             task=place(accept=["e4", "f5"]), hint="找一个和黑棋、白棋都挨着的点。", ok="对！"),
                        step("记住：开局下中间，棋子要挨在一起，不要东一颗西一颗。"),
                    ],
                },
                {
                    "id": "g11", "title": "四四", "icon": "square.on.square", "learned": "一步做出两个四",
                    "steps": [
                        step("一步棋同时做出两个『四颗』，叫『四四』，对手也只能堵一个。",
                             board=g("c4,d4,e4,f6,f7,f8", "b4,f9,h2,c7")),
                        step("找到那个点！", task=place(rule="winIn:1"),
                             hint="横着的三颗和竖着的三颗，它们延长以后在哪里相交？",
                             ok="对！横着一个四，竖着一个四。", reply=["block"], after="白棋只能堵一个。用另一个四赢下来！"),
                        step("连成五颗！", task=place(rule="five"), ok="赢啦！"),
                        step("再来一道：这次是斜线和横线。找到四三的那一点。",
                             board=g("f5,g5,h5,c7,d6", "i5,b3,h8"), task=place(rule="winIn:2"),
                             hint="横着那三颗往左接一颗，看看是不是正好在斜线上。",
                             ok="漂亮！", reply=["block"], after="继续，把活三变成活四！"),
                        step("变成活四！", task=place(rule="winIn:1"), reply=["block"], after="最后一步！"),
                        step("连成五颗！", task=place(rule="five"), ok="你已经会用双重威胁了！"),
                    ],
                },
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

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for course in (gomoku, xiangqi):
        path = os.path.join(OUT, course["game"] + ".json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(course, f, ensure_ascii=False, indent=1)
        n = sum(len(l["steps"]) for t in course["tracks"] for l in t["lessons"])
        print(path, "lessons", sum(len(t["lessons"]) for t in course["tracks"]), "steps", n)
