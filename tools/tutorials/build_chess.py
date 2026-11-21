#!/usr/bin/env python3
"""生成国际象棋的教学内容：RanranGame/Tutorials/chess.json。

改了这里以后：
  1. python3 tools/tutorials/build_chess.py
  2. zsh tools/chess/test.sh（每道题都有答案、黑方怎么应后面都接得上、练习的镜像也有答案；-v 看每一步的答案）
  3. python3 tools/voice/build_manifest.py，再生成配音

坐标 "e4"：a…h 从白方左边数，1…8 从白方底线往上。冉冉执白，白方在下面。
局面用 pos("Kg1 Rd1 Pf2", "Kg8 Pf7")：第一个是白方，第二个是黑方，每个子写「字母 + 格子」：
  K 王 Q 后 R 车 B 象 N 马 P 兵
学认棋子的课里可以不摆王（只摆这一课要用的子），别的课都有两个王。
课的 id（c1…）是存档的钥匙：可以调顺序、改内容，不能改 id、不能复用。
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "RanranGame", "Tutorials", "chess.json")


def step(say, board=None, marks=None, task=None, hint=None, ok=None, reply=None, after=None, drill=None):
    s = {"say": say}
    if drill: s["drill"] = drill
    if board is not None: s["board"] = board
    if marks: s["marks"] = marks
    if task: s["task"] = task
    if hint: s["hint"] = hint
    if ok: s["ok"] = ok
    if reply: s["reply"] = reply
    if after: s["after"] = after
    return s


def pick(accept):
    return {"type": "pick", "accept": accept}


def move(rule=None, accept=None, piece=None):
    t = {"type": "move"}
    if rule: t["rule"] = rule
    if accept: t["accept"] = accept
    if piece: t["piece"] = piece
    return t


def pos(white="", black="", turn="w", castle="-", ep="-"):
    cells = {}
    for side, text in ((0, white), (1, black)):
        for tok in text.split():
            letter, sq = tok[0], tok[1:]
            assert letter in "KQRBNP" and len(sq) == 2 and sq not in cells, tok
            cells[sq] = letter if side == 0 else letter.lower()
    rows = []
    for rank in range(8, 0, -1):
        row, empty = "", 0
        for f in "abcdefgh":
            p = cells.get(f"{f}{rank}")
            if p:
                if empty: row += str(empty); empty = 0
                row += p
            else:
                empty += 1
        if empty: row += str(empty)
        rows.append(row)
    return "/".join(rows) + f" {turn} {castle} {ep} 0 1"


START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"


def glow(*squares):
    return [f"glow:{s}" for s in squares]


def dots(*squares):
    return [f"dot:{s}" for s in squares]


def lesson(id, title, icon, learned, steps):
    return {"id": id, "title": title, "icon": icon, "learned": learned, "steps": steps}


# ----------------------------------------------------------------------------- 第一组：认识棋子

basic = [
    lesson("c1", "棋盘和棋子", "square.grid.3x3.fill", "棋盘、白先黑后，还有六种棋子", [
        step("这是国际象棋的棋盘，一共六十四个格子，浅色格和深色格一个隔一个。白方在下面，黑方在上面，白方先走。", board=START),
        step("每一方都有六种棋子：王、后、车、象、马、兵。棋子都走在格子里。"),
        step("最重要的是『王』，头上戴着十字小王冠。点一下白王。",
             task=pick(["e1"]), hint="白王在最下面一排，就在白后的旁边。", ok="对！这就是白王。",
             drill="点一下白王。"),
        step("王旁边、头上有一圈小圆珠的是『后』，它是最厉害的棋子。点一下黑后。",
             task=pick(["d8"]), hint="黑后在最上面一排，和白后面对面。", ok="对！白后站在白格，黑后站在黑格。",
             drill="点一下黑后。"),
        step("四个角上像小城堡的是『车』。点一下白方的一个车。",
             task=pick(["a1", "h1"]), hint="车在白方最下面一排的两头。", ok="对！这是白车。",
             drill="点一下白方的一个车。"),
        step("车旁边是马头的『马』，再往里是戴尖帽子的『象』。点一下白方的一个马。",
             task=pick(["b1", "g1"]), hint="马挨着车站，长着马头。", ok="对！这是白马。",
             drill="点一下白方的一个马。"),
        step("前面一排小小的是『兵』，每一方有八个。下面我们一个一个学它们怎么走。"),
    ]),
    lesson("c2", "车", "arrow.up.and.down.and.arrow.left.and.right", "车走直线，走多远都行", [
        step("这是车。它走直线：往前、往后、往左、往右，想走多远就走多远。",
             board=pos("Rd4"), marks=["arrow:d4:d8", "arrow:d4:d1", "arrow:d4:a4", "arrow:d4:h4"]),
        step("把车走到发光的格子。", marks=glow("d8"), task=move(piece="d4", accept=["d8"]),
             hint="一直往上走，走到最上面那一格。", ok="对！车一下子就走过去了。", drill="把车走到发光的格子！"),
        step("车不能跳过别的棋子，被挡住了就要停下来。", board=pos("Ra1 Pa4"),
             marks=["ring:a4", "dot:a2", "dot:a3", "cross:a5"]),
        step("走到对方棋子的格子上，就把它吃掉。用车吃掉黑兵！", board=pos("Rb2 Pd2", "Pb7 Pf2"),
             task=move(piece="b2", rule="capture"), hint="右边那个黑兵被白兵挡住了，往上看看。", ok="吃掉了！",
             drill="用车吃掉一个黑兵！"),
        step("车能吃到哪个黑棋？吃掉一个！", board=pos("Re4", "Pe6 Ne8 Ba4 Qh7"),
             task=move(piece="e4", rule="capture"), hint="车只走直线，被挡住的吃不到。", ok="对！",
             after="被挡在后面的子，车吃不到。"),
    ]),
    lesson("c3", "象", "square.split.diagonal.2x2.fill", "象斜着走，一直走同一种颜色的格子", [
        step("这是象。它斜着走，想走多远就走多远。", board=pos("Bc1"),
             marks=["arrow:c1:h6", "arrow:c1:a3"]),
        step("把象走到发光的格子。", marks=glow("g5"), task=move(piece="c1", accept=["g5"]),
             hint="沿着斜线一直走。", ok="对！", drill="把象走到发光的格子！"),
        step("你发现了吗？这个象站在深色格子上，它永远只能走深色格子。另一个象呢，只走浅色格子。",
             board=pos("Bc1 Bf1"), marks=["ring:c1", "ring:f1"]),
        step("用象吃掉一个黑棋！", board=pos("Bd3", "Pg6 Nd6 Rb3"),
             task=move(piece="d3", rule="capture"), hint="象只能斜着吃。", ok="吃掉了！"),
        step("象也会被挡住。找一个能吃到的黑棋，吃掉它！", board=pos("Be2 Pf3", "Qh5 Rb5"),
             task=move(piece="e2", rule="capture"), hint="被白兵挡住的那条斜线过不去，换一条。", ok="对！"),
    ]),
    lesson("c4", "后", "crown", "后又能走直线，又能走斜线", [
        step("后是最厉害的棋子：车的直线和象的斜线，它全都会走。", board=pos("Qd4"),
             marks=["arrow:d4:d8", "arrow:d4:h8", "arrow:d4:h4", "arrow:d4:g1", "arrow:d4:d1", "arrow:d4:a1",
                    "arrow:d4:a4", "arrow:d4:a7"]),
        step("把后走到发光的格子。", marks=glow("h8"), task=move(piece="d4", accept=["h8"]),
             hint="沿着斜线一直走到角上。", ok="对！", drill="把后走到发光的格子！"),
        step("后能吃到两个黑棋，吃掉哪个都行！", board=pos("Qd1", "Nd7 Bh5"),
             task=move(piece="d1", rule="capture"), hint="一个在直线上，一个在斜线上。", ok="吃掉了！"),
        step("这次只有一个黑棋吃得到，找到它！", board=pos("Qa1 Pb2", "Rh8 Na7 Pc3"),
             task=move(piece="a1", rule="capture"), hint="斜线被自己的兵挡住了，看看直线。", ok="对！"),
        step("后这么厉害，可千万别让对方白白吃掉它。"),
    ]),
    lesson("c5", "王", "crown.fill", "王每次走一格，不能走到会被吃的地方", [
        step("王每次只走一格，往哪个方向都可以。", board=pos("Ke4"),
             marks=dots("d3", "e3", "f3", "d4", "f4", "d5", "e5", "f5")),
        step("把王走到发光的格子。", marks=glow("f5"), task=move(piece="e4", accept=["f5"]),
             hint="往斜上方走一格。", ok="对！", drill="把王走到发光的格子！"),
        step("王不能走到会被对方吃掉的地方。这一排有黑车，王不能走上去。", board=pos("Ke1", "Ra2"),
             marks=["ring:a2", "cross:d2", "cross:e2", "cross:f2", "dot:d1", "dot:f1"]),
        step("王也能吃子。吃掉一个没有保护的黑兵！", board=pos("Ke4", "Pd5 Pc6 Pf5"),
             task=move(piece="e4", rule="capture"), hint="有黑兵在后面保护的那个不能吃，吃了王就会被吃掉。",
             ok="对！没有保护的子才能用王吃。", drill="用王吃掉一个没有保护的黑兵！"),
        step("王是最重要的棋子。下棋就是要保护好自己的王，去抓对方的王。"),
    ]),
    lesson("c6", "马", "figure.equestrian.sports", "马走日字，能跳过别的棋子", [
        step("马走『日』字：先直着走两格，再拐一格。这些发光的格子，马都能去。", board=pos("Nd4"),
             marks=glow("c6", "e6", "f5", "f3", "e2", "c2", "b3", "b5")),
        step("把马走到发光的格子。", marks=glow("e6"), task=move(piece="d4", accept=["e6"]),
             hint="往上走两格，再往右拐一格。", ok="对，这就是日字！", drill="把马走到发光的格子！"),
        step("马和别的棋子不一样：它可以跳过挡在中间的棋子。", board=pos("Nb1 Pa2 Pb2 Pc2 Pd2"),
             marks=["arrow:b1:c3", "arrow:b1:a3"]),
        step("马被自己的兵围住了也不怕。跳出去，吃掉黑象！", board=pos("Ng1 Pf2 Pg2 Ph2", "Bf3 Re5"),
             task=move(piece="g1", rule="capture"), hint="马跳一个日字，就能落到黑象的格子上。", ok="吃掉了！",
             drill="让马跳出去吃掉一个黑棋！"),
        step("马能吃到哪个黑棋？吃掉它！", board=pos("Ne4", "Qd6 Re6 Bc4"),
             task=move(piece="e4", rule="capture"), hint="数一数：两格再拐一格。", ok="对！"),
    ]),
    lesson("c7", "兵", "figure.walk", "兵往前走，斜着吃子；第一步可以走两格", [
        step("兵只能往前走，一次一格，不能后退。", board=pos("Pe3"), marks=["arrow:e3:e4"]),
        step("兵第一次走的时候，可以一下走两格。把兵往前走两格！", board=pos("Pe2"), marks=glow("e4"),
             task=move(piece="e2", accept=["e4"]), hint="点兵，再点它前面第二个格子。", ok="对！",
             drill="把兵一下走两格！"),
        step("兵吃子很特别：它斜着往前吃。正前方有棋子挡着，它就走不动了。", board=pos("Pd4", "Pd5 Ne5"),
             marks=["warn:d5", "arrow:d4:e5"]),
        step("用兵吃掉黑马！", task=move(piece="d4", rule="capture"), hint="兵斜着往前吃。", ok="吃掉了！"),
        step("这个兵能吃哪一个？吃掉它！", board=pos("Pc3", "Rb4 Qc4 Nd5"),
             task=move(piece="c3", rule="capture"), hint="正前方的吃不到，要斜着吃。", ok="对！"),
        step("兵一直走到对面最后一排，还能变成后！这个本领我们以后再学。"),
    ]),
]

# ----------------------------------------------------------------------------- 第二组：将军和将死

rules = [
    lesson("c8", "吃子", "fork.knife", "走到对方的子上就是吃掉它，自己的子不能吃", [
        step("走到对方棋子的格子上，就把它吃掉，拿下棋盘。自己的棋子不能吃。",
             board=pos("Kg1 Nc3 Bf4 Pe4", "Kg8 Pd5 Pc7 Qb4"), marks=["ring:d5", "ring:c7", "ring:b4"]),
        step("用马吃掉一个黑棋！", task=move(piece="c3", rule="capture"), hint="马跳日字。", ok="吃掉了！"),
        step("用象吃掉一个黑棋！", board=pos("Kg1 Nc3 Bf4 Pe4", "Kg8 Pd5 Pc7 Qb4"),
             task=move(piece="f4", rule="capture"), hint="象走斜线。", ok="对！"),
        step("用兵吃掉一个黑棋！", board=pos("Kg1 Nc3 Bf4 Pe4", "Kg8 Pd5 Pc7 Qb4"),
             task=move(piece="e4", rule="capture"), hint="兵斜着往前吃。", ok="真棒！"),
        step("王不能被吃掉。王被攻击的时候会发生什么？下一课就学。"),
    ]),
    lesson("c9", "将军", "exclamationmark.triangle.fill", "攻击对方的王，叫将军", [
        step("如果你的棋子下一步就能吃到对方的王，这叫『将军』。把车走到这里，就将军了。",
             board=pos("Kg1 Ra1", "Ke8 Pd7 Pe7 Pf7"), marks=["arrow:a1:a8", "ring:e8"]),
        step("你来将一军！", board=pos("Kg1 Rd1 Nc3 Pf2 Pg2 Ph2", "Ke8 Pf7 Pg7 Ph7"),
             task=move(rule="check"), hint="车走到黑王的那一条直线上。", ok="将军！"),
        step("用马将军！", board=pos("Kg1 Ne4 Pf2 Pg2 Ph2", "Ke8 Pd7 Pe7 Pf7"),
             task=move(piece="e4", rule="check"), hint="马跳到一个能跳到黑王的格子。", ok="将军！"),
        step("用象将军！", board=pos("Kg1 Bf1 Pf2 Pg2 Ph2", "Ke8 Pe7 Pf7"),
             task=move(piece="f1", rule="check"), hint="象沿着斜线，走到能吃到黑王的地方。", ok="将军！"),
        step("被将军的一方一定要马上保护王，不能不管。"),
    ]),
    lesson("c10", "被将军了怎么办", "shield.lefthalf.filled", "解将的三种办法：走开、挡住、吃掉", [
        step("你的王被黑车将军了！有三种办法：把王走开、用别的子挡住、吃掉将军的子。",
             board=pos("Ke1", "Re8 Ka8"), marks=["warn:e8", "arrow:e8:e1"]),
        step("这里只能把王走开。走到安全的格子！", task=move(rule="escape:king"),
             hint="别往黑车的那条直线上走。", ok="躲开了！"),
        step("王被自己的兵堵住，走不开。用别的子挡住将军！", board=pos("Kg1 Pf2 Pg2 Ph2 Bd3", "Ra1 Kg8"),
             marks=["warn:a1"], task=move(rule="escape:block"), hint="象可以挡在黑车和王的中间。", ok="挡住了！"),
        step("这次把将军的黑车吃掉！", board=pos("Kg1 Pf2 Pg2 Ph2 Rd4", "Rd1 Kg8"), marks=["warn:d1"],
             task=move(rule="escape:capture"), hint="白车顺着直线就能吃到它。", ok="吃掉了！"),
        step("这次你自己选办法！", board=pos("Ke1 Nb1 Pf2 Pg2", "Bb4 Ke8"), marks=["warn:b4"],
             task=move(rule="escape"), hint="王走开、马挡住都可以。", ok="解将成功！"),
    ]),
    lesson("c11", "将死", "flag.checkered", "被将军、又没有办法解，就是将死，赢了", [
        step("如果王被将军了，走开、挡住、吃掉都不行，那就是『将死』。将死对方的王，你就赢了！",
             board=pos("Kg1 Ra1 Pf2 Pg2 Ph2", "Kh8 Pg7 Ph7"), marks=["arrow:a1:a8", "ring:h8"]),
        step("你来将死黑王！", task=move(rule="mate"), hint="车走到最上面一排将军，黑王被自己的兵挡住了。",
             ok="将死！你赢了！"),
        step("后和王一起，将死黑王！", board=pos("Kf6 Qa7", "Kf8"),
             task=move(rule="mate"), hint="后贴着黑王将军，白王在旁边保护后。", ok="将死！"),
        step("车和王一起，将死黑王！", board=pos("Ke6 Rh1", "Ke8"),
             task=move(rule="mate"), hint="车走到最上面一排，白王挡住黑王往下的路。", ok="将死！"),
        step("将死的时候比赛就结束了，不用真的把王吃掉。"),
    ]),
    lesson("c12", "逼和不是赢", "equal.circle.fill", "没被将军却一步也走不了，是逼和，算和棋", [
        step("看：轮到黑王走，它没有被将军，可是往哪儿走都会被吃。它一步也走不了，这叫『逼和』，算和棋，不算赢！",
             board=pos("Kf7 Qg6", "Kh8"), marks=["ring:h8", "cross:g8", "cross:h7", "cross:g7"]),
        step("快赢的时候要小心。将死黑王，可别把它逼和了！", board=pos("Kf7 Qg4", "Kh8"),
             task=move(rule="mate"), hint="一定要将军！后走到能吃到黑王的地方，白王在旁边保护。", ok="将死，不是逼和！"),
        step("再来一次：将死黑王，别逼和！", board=pos("Kb6 Qc5", "Ka8"),
             task=move(rule="mate"), hint="后要将军，黑王的格子要全被看住。", ok="真棒！"),
        step("记住：只困住王还不够，一定要将军才是将死。"),
    ]),
]

# ----------------------------------------------------------------------------- 第三组：特殊走法

special = [
    lesson("c13", "王车易位", "arrow.left.arrow.right", "王车易位：王走两格，车跳到王的另一边", [
        step("有一种特别的走法，王和车一起走，叫『王车易位』。王往车那边走两格，车跳到王的另一边。",
             board=pos("Ke1 Ra1 Rh1 Pa2 Pb2 Pc2 Pf2 Pg2 Ph2", "Ke8", castle="KQ"),
             marks=["arrow:e1:g1", "arrow:h1:f1"]),
        step("点王，再点发光的格子，做一次王车易位！", marks=glow("g1"), task=move(rule="castle:k"),
             hint="先点白王，再点它右边第二个格子。", ok="易位成功！王躲进了角落，车走到了中间。"),
        step("王车易位要满足三个条件：王和车都还没走过；它们中间没有别的子；王不在被将军，也不能经过或者走到被攻击的格子。"),
        step("这边被马和象挡住了，往另一边易位吧！",
             board=pos("Ke1 Ra1 Rh1 Bf1 Ng1 Pa2 Pb2 Pc2 Pf2 Pg2 Ph2", "Ke8", castle="KQ"),
             task=move(rule="castle"), hint="王和车中间的格子要全空着才能易位。", ok="对，这叫长易位！"),
        step("黑象看住了王要经过的格子，这边不能易位。选另一边！",
             board=pos("Ke1 Ra1 Rh1 Pa2 Pb2 Pc2 Pg2 Ph2", "Ke8 Bc4", castle="KQ"), marks=["warn:c4", "cross:f1"],
             task=move(rule="castle"), hint="王不能经过被黑象攻击的格子。", ok="对！"),
        step("易位以后，王躲到了安全的角落，车也来到了中间，一举两得！"),
    ]),
    lesson("c14", "兵升变", "arrow.up.circle.fill", "兵走到最后一排，可以变成后、车、象或马", [
        step("兵一直走到对面的最后一排，就能『升变』：变成后、车、象或者马。一般都变成最厉害的后！",
             board=pos("Pc7"), marks=["arrow:c7:c8"]),
        step("把兵走到底，升变成后！", board=pos("Pb7"), marks=glow("b8"), task=move(piece="b7", rule="promote:q"),
             hint="兵走到最后一排时，会出来一个小窗口，选后。", ok="变成后啦！", drill="把兵走到底，升变成后！"),
        step("前面被挡住了，那就斜着吃子升变！", board=pos("Pd7", "Qd8 Rc8 Ne8"),
             task=move(piece="d7", rule="promote"), hint="兵斜着往前吃，吃完正好到最后一排。", ok="又吃子又升变！",
             drill="吃掉一个黑棋，同时升变！"),
        step("升变的时候，还能直接将死黑王！", board=pos("Kg1 Pb7", "Kh8 Pg7 Ph7"),
             task=move(rule="mate"), hint="兵走到最后一排变成后，正好在那一排将军。", ok="升变将死！"),
        step("兵是最小的子，可是走到底就能变成后，千万别小看兵！"),
    ]),
    lesson("c15", "吃过路兵", "arrow.down.right.circle", "对方的兵一下走两格停在你的兵旁边时，可以吃过路兵", [
        step("这是最特别的一条规则。黑兵刚刚从这里一下走了两格，停在了白兵的旁边。",
             board=pos("Ke1 Pe5", "Ke8 Pd5", ep="d6"), marks=["arrow:d7:d5", "ring:d5"]),
        step("这时候，白兵可以斜着走到黑兵跳过去的那一格，把它吃掉。这叫『吃过路兵』。",
             marks=["arrow:e5:d6", "glow:d6"]),
        step("你来吃过路兵！", task=move(piece="e5", rule="enpassant"),
             hint="点白兵，再点黑兵后面那个发光的格子。", ok="吃掉了！黑兵被拿下棋盘。"),
        step("先把王往前走一步，看看黑兵会怎么走。", board=pos("Ke1 Pg5", "Ke8 Ph7"),
             task=move(piece="e1", rule="any"), hint="点白王，再点它前面的格子。", ok="好，轮到黑方了。",
             reply=["h7h5"], after="黑兵一下走了两格，停在白兵旁边！"),
        step("快，吃过路兵！", task=move(rule="enpassant"), hint="白兵斜着走到黑兵后面的那一格。", ok="抓住机会了！"),
        step("吃过路兵只能在黑兵刚走完两格的下一步马上吃，过了这一步就不能吃了。"),
    ]),
]

# ----------------------------------------------------------------------------- 第四组：基本杀法

mates = [
    lesson("c16", "底线杀", "rectangle.bottomthird.inset.filled", "王被自己的兵挡住时，到底线将军就能将死", [
        step("黑王躲在角落里，前面三个兵把它的路堵住了。车到底线一将军，它就跑不掉，这叫『底线杀』。",
             board=pos("Kg1 Rd1 Pf2 Pg2 Ph2", "Kg8 Pf7 Pg7 Ph7"), marks=["arrow:d1:d8", "ring:g8"]),
        step("你来底线杀！", task=move(rule="mate"), hint="车冲到最上面一排。", ok="底线杀！"),
        step("黑车守着底线。两个白车一起上，先送一个车将军！",
             board=pos("Kg1 Re1 Re2 Pf2 Pg2 Ph2", "Kg8 Rc8 Pf7 Pg7 Ph7"),
             task=move(rule="mateIn:2"), hint="车冲到底线将军，黑车吃掉它，另一个车再来。", ok="将军！",
             reply=["engine"], after="黑车只好吃掉白车。"),
        step("另一个车冲上去，将死！", task=move(rule="mate"), hint="后面那个车沿着同一条线冲到底。", ok="底线杀！"),
        step("自己的王也要小心：别让兵把王的路全堵死，可以早点给王留一个出口。"),
    ]),
    lesson("c17", "双车错", "stairs", "两个车轮流将军，把王一排一排赶到底线", [
        step("两个车配合起来很厉害：一个车看住一排，另一个车往前将军，一层一层把王赶到边上。这叫『双车错』。",
             board=pos("Kh1 Ra6 Rb1", "Ke7"), marks=["arrow:b1:b7", "arrow:a6:a8"]),
        step("一个车看住了下面那一排。用另一个车将军，把王赶到最上面！", task=move(rule="mateIn:2"),
             hint="车走到黑王的那一排将军。", ok="将军！", reply=["engine"], after="黑王只能往上走。"),
        step("现在换另一个车，到最上面一排将死它！", task=move(rule="mate"), hint="另一个车冲到最上面一排。",
             ok="双车错，将死！"),
        step("自己再做一遍：两个车轮流将军！", board=pos("Kh1 Ra5 Rb1", "Kf6"),
             task=move(rule="mateIn:3"), hint="一个车看住一排，另一个车在王的那一排将军。", ok="将军！",
             reply=["engine"], after="王又往上躲了。"),
        step("继续，换另一个车将军！", task=move(rule="mateIn:2"), hint="另一个车走到王的那一排将军。",
             ok="将军！", reply=["engine"]),
        step("最后一下，将死！", task=move(rule="mate"), hint="车冲到王的那一排。", ok="将死！"),
    ]),
    lesson("c18", "后和王配合", "person.2.fill", "后在王的保护下贴着对方的王将军，就能将死", [
        step("后最厉害，可是只靠后一个子，常常会被王吃掉。让自己的王站在旁边保护后，就能将死对方的王。",
             board=pos("Ke6 Qe7", "Ke8"), marks=["ring:e6", "ring:e7"]),
        step("后和王一起，将死黑王！", board=pos("Ke6 Qa1", "Ke8"), task=move(rule="mate"),
             hint="后沿着直线或者斜线将军，白王会看住黑王往下的格子。", ok="将死！"),
        step("再来一个！", board=pos("Kb6 Qh7", "Kb8"), task=move(rule="mate"),
             hint="后走到黑王旁边，白王保护着它；或者在最上面一排将军。", ok="将死！"),
        step("两步杀：先把黑王的路堵上，再将死！", board=pos("Kf6 Qd5", "Kh8"),
             task=move(rule="mateIn:2"), hint="后把黑王关在角落里，可别逼和了。", ok="好棋！", reply=["engine"]),
        step("现在将死它！", task=move(rule="mate"), hint="后贴着黑王将军，白王在旁边保护。", ok="将死！"),
    ]),
    lesson("c19", "闷杀", "shippingbox.fill", "王被自己的子围住时，马一将军就是闷杀", [
        step("黑王被自己的棋子围得紧紧的，一步也动不了。马跳过去将军，谁也挡不住，这叫『闷杀』。",
             board=pos("Kg1 Ne5 Pf2 Pg2 Ph2", "Kh8 Rg8 Pg7 Ph7"), marks=["arrow:e5:f7", "ring:h8"]),
        step("你来闷杀！", task=move(rule="mate"), hint="马跳一个日字，落到能吃到黑王的格子。", ok="闷杀！"),
        step("更厉害的：先送后将军！黑车吃掉后以后，黑王就被自己的车堵住了。",
             board=pos("Kg1 Qc4 Nh6 Pf2 Pg2 Ph2", "Kh8 Ra8 Pg7 Ph7"), marks=["arrow:c4:g8"],
             task=move(rule="mateIn:2"), hint="后冲到黑王旁边将军，马保护着它，黑王不能吃。", ok="勇敢的一步！",
             reply=["engine"], after="黑车只能吃掉白后。"),
        step("马来闷杀！", task=move(rule="mate"), hint="马跳到能吃到黑王的格子。", ok="闷杀！"),
        step("闷杀是马的拿手好戏，因为只有马能跳过别的子将军。"),
    ]),
]

# ----------------------------------------------------------------------------- 第五组：得子战术

tactics = [
    lesson("c20", "棋子的价值", "scalemass.fill", "兵一分、马和象三分、车五分、后九分", [
        step("棋子有大有小：兵算一分，马和象各三分，车五分，后九分。王是无价之宝，丢了就输了。", board=START),
        step("马可以吃两个黑棋。吃哪一个最划算？", board=pos("Kg1 Nf3 Pg2 Ph2", "Kg8 Pe5 Pd6 Rg5 Pg7 Ph7"),
             task=move(piece="f3", rule="bestCapture"), hint="有黑兵保护的那个，吃了马会被吃回去。没保护的车才划算。",
             ok="对！白白吃到一个车。"),
        step("黑兵在攻击你的马！把马走到不会被吃的地方。",
             board=pos("Kg1 Nd4 Pg2 Ph2", "Kg8 Pe5 Pb7 Pf7 Pg7 Ph7"), marks=["warn:e5"],
             task=move(piece="d4", rule="safe"), hint="看看黑兵能斜着吃到哪些格子，别走到那里。", ok="安全了！"),
        step("能吃就吃没有保护的子；被攻击的子，要赶快走开。"),
    ]),
    lesson("c21", "保护和交换", "shield.fill", "有保护的子被吃了能吃回来，用小换大才划算", [
        step("一个子被吃掉的时候，如果你能马上吃回来，就说它『有保护』。这个马有兵保护着。",
             board=pos("Kg1 Nd4 Pc3 Pg2 Ph2", "Kg8 Bb6 Pg7 Ph7"), marks=["ring:d4", "arrow:c3:d4"]),
        step("黑车在攻击你的象！保护它，或者让它躲开。", board=pos("Kg1 Ra1 Bc4 Pa2 Pb2 Pg2 Ph2", "Kg8 Rc8 Pf7 Pg7 Ph7"),
             marks=["warn:c8"], task=move(rule="hold"), hint="象可以躲开；也可以派车或者兵去保护它。", ok="好！"),
        step("你的马能吃黑车，可是黑车有兵保护。用三分的马换五分的车，划算吗？吃掉它！",
             board=pos("Kg1 Ne4 Pf2 Pg2 Ph2", "Kg8 Rd6 Pc7 Pf7 Pg7 Ph7"),
             task=move(rule="gain:2"), hint="马跳过去吃车，就算马被吃回去，你也赚了。", ok="划算！"),
        step("黑马有兵保护。用哪一个子去吃最好？", board=pos("Kg1 Qe2 Pf4 Pg2 Ph2", "Kg8 Ne5 Pd6 Pg7 Ph7"),
             task=move(rule="bestCapture"), hint="用最小的子去吃：兵吃马，就算兵被吃回去也不亏。", ok="对，用小换大！"),
        step("记住：用小子吃大子最划算；用大子去吃有保护的小子，就亏了。"),
    ]),
    lesson("c22", "捉双", "arrow.triangle.branch", "一步同时攻击两个子，对方只能救一个", [
        step("一个子一下子攻击对方两个子，对方只能救一个，另一个就被你吃掉了。这叫『捉双』。马最会捉双！",
             board=pos("Kg1 Nd5 Pf2 Pg2 Ph2", "Ke8 Ra8 Pf7 Pg7 Ph7"), marks=["ring:e8", "ring:a8"]),
        step("找到马捉双的那一步！",
             task=move(rule="gain:4"), hint="马跳过去，同时将军、又攻击黑车。", ok="捉双！",
             reply=["engine"], after="黑王只能躲开，黑车保不住了。"),
        step("吃掉黑车！", task=move(rule="capture"), hint="马跳到黑车的格子。", ok="赚到一个车！"),
        step("后也会捉双！一步将军，同时攻击黑车。", board=pos("Kg1 Qd1 Pf2 Pg2 Ph2", "Kg8 Ra8 Pg7 Ph7"),
             task=move(rule="gain:4"), hint="后走到一个能同时看到黑王和黑车的格子。", ok="捉双！",
             reply=["engine"]),
        step("吃掉黑车！", task=move(rule="capture"), hint="后沿着斜线吃过去。", ok="真棒！"),
    ]),
    lesson("c23", "牵制", "pin.fill", "挡在王前面的子不能动，这叫牵制", [
        step("黑马挡在白象和黑王中间。马要是走开，白象就能吃到黑王，所以马不能动，它被『牵制』住了。",
             board=pos("Kg1 Bb5", "Ke8 Nc6"), marks=["arrow:b5:e8", "ring:c6"]),
        step("哪一个黑子被牵制住了？点一下它。", board=pos("Kg1 Re1 Pf2 Pg2", "Ke8 Ne5 Bc6 Pf7"),
             task=pick(["e5"]), hint="找挡在白车和黑王中间的那个子。", ok="对！黑马挡在王的前面，动不了。",
             drill="点一下被牵制住、不能动的那个黑子。"),
        step("黑马被牵制住了。用兵去攻击它，它跑不掉！", board=pos("Kg1 Bb5 Pd4 Pf2 Pg2", "Ke8 Nc6 Pb7 Pf7 Pg7"),
             task=move(rule="gain:2"), hint="兵往前走一格，就能攻击被牵制的马。", ok="马跑不掉了！",
             reply=["engine"]),
        step("吃掉被牵制的马！", task=move(rule="bestCapture"), hint="兵斜着往前吃。", ok="赚到一个马！"),
        step("被牵制的子就像被钉子钉住了一样，可以放心地去攻击它。"),
    ]),
    lesson("c24", "串击", "arrow.right.to.line", "先攻击前面的大子，它躲开以后吃掉后面的子", [
        step("串击和牵制正好反过来：前面是大子，后面是小子。将军以后，王躲开，就能吃到王后面的子。",
             board=pos("Kg1 Rh1", "Ke6 Rb6"), marks=["arrow:h1:h6", "ring:e6", "ring:b6"]),
        step("用车将军，串击王后面的黑车！",
             task=move(rule="gain:4"), hint="车走到黑王和黑车的那一排将军。", ok="串击！", reply=["engine"],
             after="王躲开了，后面的车露出来了。"),
        step("吃掉黑车！", task=move(rule="capture"), hint="车沿着这一排吃过去。", ok="赚到一个车！"),
        step("象也会串击！斜着将军，吃掉王后面的车。", board=pos("Kg1 Bd2", "Ke7 Rf8"),
             task=move(rule="gain:2"), hint="象走到黑王、黑车的那条斜线上将军。", ok="串击！", reply=["engine"]),
        step("吃掉黑车！", task=move(rule="bestCapture"), hint="象沿着斜线吃过去。", ok="真棒！"),
    ]),
    lesson("c25", "闪击", "bolt.fill", "前面的子一走开，后面的子就能攻击", [
        step("白车被自己的马挡住了。马一跳开，车就将军；马跳的时候顺便吃一个子，对方顾不过来。这叫『闪击』。",
             board=pos("Kg1 Re1 Ne4 Pf2 Pg2", "Ke8 Qc5 Pf7 Pg7"), marks=["ring:e4", "arrow:e1:e8"]),
        step("马跳开、同时吃掉黑后！", task=move(rule="gain:5"), hint="马跳一个日字，正好落在黑后的格子上，车同时在将军。",
             ok="闪击！"),
        step("象挡在后的前面。象跳开去将军，后就能吃到黑后！", board=pos("Kg1 Qd1 Bd3 Pf2 Pg2", "Kg8 Qd8 Pf7 Pg7 Ph7"),
             task=move(rule="gain:5"), hint="象吃掉黑王旁边的兵将军，白后同时看着黑后。", ok="闪击！",
             reply=["engine"], after="黑方只顾得上王。"),
        step("吃掉黑后！", task=move(rule="bestCapture"), hint="白后沿着直线吃过去。", ok="赚到一个后！"),
        step("闪击的时候，后面的子和前面的子一起进攻，对方一下子要防两个，常常顾不过来。"),
    ]),
]

# ----------------------------------------------------------------------------- 第六组：开局和残局

OPEN_AFTER_QXD5 = "rnb1kbnr/ppp1pppp/8/3q4/8/8/PPPP1PPP/RNBQKBNR w KQkq - 0 3"
EARLY_QUEEN = "r1bqkbnr/pppp1p1p/2n3p1/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 4"
SCHOLAR = "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4"

endgame = [
    lesson("c26", "开局三原则", "flag.fill", "开局占中心、先出马和象、早点王车易位", [
        step("开局有三个好习惯：先用兵占中心；把马和象放出来；早一点王车易位，让王躲到安全的地方。", board=START,
             marks=["tint:d4", "tint:e4", "tint:d5", "tint:e5"]),
        step("第一步，用中间的兵占中心！", marks=glow("e4"), task=move(piece="e2", rule="center"),
             hint="把王前面的兵往前走两格。", ok="占住中心了！", reply=["e7e5"], after="黑方也占中心。"),
        step("把马放出来！马要跳向中间。", marks=["glow:g1"], task=move(piece="g1", rule="develop"),
             hint="马往中间跳，别跳到边上。", ok="出马！", reply=["b8c6"]),
        step("再把象放出来！", marks=["glow:f1"], task=move(piece="f1", rule="develop"),
             hint="象沿着斜线出去，别走到会被吃的地方。", ok="出象！", reply=["f8c5|g8f6"]),
        step("王和车中间已经空了，王车易位！", task=move(rule="castle:k"), hint="点白王，再点它右边第二个格子。",
             ok="王安全了！"),
        step("中心、出子、易位，三件事都做到了，这就是一个好开局。"),
    ]),
    lesson("c27", "开局别犯的错", "exclamationmark.bubble.fill", "别太早出后，别把子白白送掉", [
        step("黑后太早出来了。你可以一边出子，一边赶它走，黑方就白白浪费了步数。", board=OPEN_AFTER_QXD5,
             marks=["ring:d5"]),
        step("出一个马，顺便攻击黑后！", task=move(rule="develop:q"), hint="马跳到能攻击黑后的格子。",
             ok="一边出子，一边赶后！", reply=["d5a5|d5d8"]),
        step("你的后出来得太早了，黑兵正在赶它。把后走到安全的地方！", board=EARLY_QUEEN, marks=["warn:g6"],
             task=move(piece="h5", rule="safe"), hint="别走到黑棋能吃到的格子。", ok="躲开了，可是浪费了一步。"),
        step("如果对方不小心，开局也能抓住机会！黑方没有保护好 f7 这一格，一步将死！", board=SCHOLAR,
             marks=["ring:f7"], task=move(rule="mate"), hint="后吃掉黑王旁边的兵，白象在后面保护着后。",
             ok="将死！这叫『四步杀』。"),
        step("所以开局要先出马和象，别急着出后；还要看好自己王旁边的格子。"),
    ]),
    lesson("c28", "王后杀单王", "crown.fill", "后把王赶到边上，王过来帮忙将死，别逼和", [
        step("对方只剩一个王了！后先把它赶到边上，自己的王再走过来帮忙，就能将死。一定要小心别逼和。",
             board=pos("Kc6 Qh7", "Kb8"), marks=["ring:b8"]),
        step("将死黑王！", task=move(rule="mate"), hint="后到黑王旁边将军，白王保护着后；或者在最上面一排将军。",
             ok="将死！"),
        step("黑王在边上。先走一步，下一步再将死！", board=pos("Kc6 Qg7", "Ke8"),
             task=move(rule="mateIn:2"), hint="把白王走近一点，或者让后把黑王关住。别逼和！", ok="好！",
             reply=["engine"]),
        step("将死它！", task=move(rule="mate"), hint="后贴着黑王将军，白王保护着后。", ok="将死！"),
        step("后加王，一定能将死单王：后先关住，王再靠近。"),
    ]),
    lesson("c29", "王车杀单王", "square.and.line.vertical.and.square.filled", "两个王面对面时，车到底线将军就能将死", [
        step("车比后弱一些。要先让两个王面对面，车再到最上面一排将军。", board=pos("Ke6 Ra1", "Ke8"),
             marks=["ring:e6", "ring:e8", "arrow:a1:a8"]),
        step("将死黑王！", task=move(rule="mate"), hint="车冲到最上面一排。", ok="将死！"),
        step("两个王还没有面对面。先把王走过去，下一步车再将死！", board=pos("Kf6 Ra1", "Kh8"),
             task=move(rule="mateIn:2"), hint="想办法让黑王没有地方躲。", ok="好！", reply=["engine"]),
        step("将死它！", task=move(rule="mate"), hint="车到黑王那一排将军。", ok="将死！"),
        step("王和车配合：王看住下面，车在底线将军。"),
    ]),
    lesson("c30", "送兵升变", "arrow.up.to.line", "兵跑在王前面就冲，王在旁边保护兵升变", [
        step("只剩王和兵的时候，兵升变成后就赢定了。黑王离得远，追不上你的兵！", board=pos("Kh1 Pb5", "Kh7"),
             marks=["arrow:b5:b8"]),
        step("兵冲啊！", task=move(rule="promoteIn:3"), hint="一直把兵往前走。", ok="冲！", reply=["engine"]),
        step("继续冲！", task=move(rule="promoteIn:2"), hint="兵再往前一格。", ok="快到了！", reply=["engine"]),
        step("升变成后！", task=move(rule="promote:q"), hint="兵走到最后一排，选后。", ok="变成后了！"),
        step("这次黑王守在兵的前面。白王保护着兵，先走哪一步，兵才能安全地升变？", board=pos("Kd7 Pe6", "Kf6"),
             task=move(rule="promoteIn:2"), hint="兵往前走，白王在旁边保护着它，黑王吃不了。", ok="好！",
             reply=["engine"]),
        step("升变成后！", task=move(rule="promote:q"), hint="白王保护着那一格，放心走。", ok="赢定了！"),
    ]),
]

chess = {
    "game": "chess",
    "title": "国际象棋教学",
    "tracks": [
        {"id": "basic", "title": "认识棋子", "subtitle": "每个棋子怎么走", "art": "tutor_chess_basic", "lessons": basic},
        {"id": "rules", "title": "将军和将死", "subtitle": "保护王，抓住对方的王", "art": "tutor_chess_rules", "lessons": rules},
        {"id": "special", "title": "特殊走法", "subtitle": "易位、升变、吃过路兵", "art": "tutor_chess_special", "lessons": special},
        {"id": "mates", "title": "基本杀法", "subtitle": "几种常见的将死办法", "art": "tutor_chess_mates", "lessons": mates},
        {"id": "tactics", "title": "得子战术", "subtitle": "价值、交换、捉双、牵制", "art": "tutor_chess_tactics", "lessons": tactics},
        {"id": "endgame", "title": "开局和残局", "subtitle": "开个好头，收好尾", "art": "tutor_chess_endgame", "lessons": endgame},
    ],
}

if __name__ == "__main__":
    ids = [l["id"] for t in chess["tracks"] for l in t["lessons"]]
    assert len(ids) == len(set(ids)), "lesson ids must be unique"
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(chess, f, ensure_ascii=False, indent=1)
        f.write("\n")
    n = sum(len(t["lessons"]) for t in chess["tracks"])
    print(OUT, f"{len(chess['tracks'])} tracks, {n} lessons")
