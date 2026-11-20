#!/usr/bin/env python3
"""从教学内容里收集所有要配音的句子，写出 tools/voice/manifest.json。

每一项：file（vo_<sha1 前 10 位>，按屏幕上显示的文字算，和 App 里 VoiceOver.fileName 一致）、
text（屏幕上的文字）、speak（真正交给语音合成的文字：象棋里的多音字换成同音字，免得读错）。
通用台词要和 RanranGame/Games/Tutorial/TutorialModel.swift 里的 TutorLines 保持一致。
"""
import hashlib, json, os, re

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")

COMMON = ["对啦！", "真棒！", "就是这样！", "太厉害了！", "完全正确！",
          "再想一想。", "看，亮起来的就是答案，你来试一下。", "不是这个哦，再看看。",
          "这个子不能这样走哦。", "这一步要动发光的那个子。", "新的一组课程解锁啦！",
          "找到一个，还有呢？",
          # 小奖杯、练一练、复习
          "每一题都是一次做对，拿到金杯啦！", "拿到银杯！每一题都一次做对，就能拿金杯。", "拿到铜杯！再来一次，争取拿金杯。",
          "练完啦，真棒！", "复习完啦，记得真牢！", "这一组学完啦，去和小伙伴下一盘吧！",
          # 五子棋：走错的后果、练习题的通用说法（PracticePrompts.gomoku）
          "看，白棋连成五颗了。", "看，白棋变成活四，堵不住了。",
          "找到连成五颗的那一步！", "白棋快连成五颗了，快堵住！", "再下一颗，摆出一个活三！", "白棋有一个活三，把它堵住！",
          "下一颗，做出一个活四！", "找到一步，让白棋堵不过来！"]

# 象棋的固定台词：车 / 相 / 将 按象棋读音（PracticePrompts.xiangqi 也在这里）
COMMON_XIANGQI = ["帅走到这里会被吃掉，或者和将面对面，不可以。", "走了这一步，帅就会被吃掉，不可以。",
                  "看，被黑方吃掉了。", "看，黑将逃走了。",
                  "吃掉一个黑方的子！", "将黑方一军！", "一步将死！", "先将一军，再将死它！", "被将军了，快解开！",
                  "被将军了，把帅躲开！", "被将军了，用别的子挡一下！", "被将军了，把将军的子吃掉！", "吃哪一个最划算？",
                  "黑方要吃你的子了，走到安全的地方！", "把一个还没动过的马、炮或者车放出来！"]

# 围棋的固定台词：术语按围棋读音（PracticePrompts.go 也在这里）
COMMON_GO = ["打劫的时候，被提的一方要先在别处下一手，才能提回来。", "这里下进去一口气都没有，是禁入点。",
             "看，白棋逃掉了。", "看，黑子被吃掉了。",
             "把能吃的白子吃掉！", "叫吃一颗白子！", "一下子叫吃两颗白子！", "圈出来的黑子被叫吃了，快逃！",
             "想办法吃掉圈出来的白子！", "一直叫吃，吃掉圈出来的白子！", "用枷把圈出来的白子关住！", "关住它，一直到吃掉为止！",
             "把圈出来的黑子连在一起！", "占一个空着的角！", "找一个安全的地方下！"]


def lesson_done(learned):
    return f"这一课学完啦！你学会了{learned}。"


def xiangqi_spoken(t):
    # 车（棋子）读 jū；相（棋子）读 xiàng；将（棋子）读 jiàng，动词"将军 / 将死 / 将一军 / 解将"读 jiāng
    t = t.replace("车", "居").replace("相", "象")
    t = re.sub(r"(?<!解)将(?!军|死|一军|黑方一军)", "酱", t)
    return t


def go_spoken(t):
    # 围棋术语：长（往外长）读 cháng；曲三 qū；刀把五 bà；数子 shǔ；倒扑 dào；粘 zhān
    for a, b in [("刀把五", "刀霸五"), ("曲三", "屈三"), ("数子", "属子"), ("倒扑", "到扑"), ("粘", "沾"), ("长", "常")]:
        t = t.replace(a, b)
    return t


def fname(text):
    return "vo_" + hashlib.sha1(text.encode("utf-8")).hexdigest()[:10]


items = {}


def add(text, game):
    if not text or text in items:
        return
    speak = xiangqi_spoken(text) if game == "xiangqi" else go_spoken(text) if game == "go" else text
    items[text] = {"file": fname(text), "text": text, "speak": speak}


for game in ("gomoku", "xiangqi", "go"):
    with open(os.path.join(ROOT, "RanranGame", "Tutorials", game + ".json"), encoding="utf-8") as f:
        course = json.load(f)
    for track in course["tracks"]:
        for lesson in track["lessons"]:
            add(lesson_done(lesson["learned"]), game)
            for s in lesson["steps"]:
                for k in ("say", "hint", "ok", "after", "drill"):
                    add(s.get(k), game)
for t in COMMON:
    add(t, "common")
for t in COMMON_XIANGQI:
    add(t, "xiangqi")
for t in COMMON_GO:
    add(t, "go")

out = os.path.join(os.path.dirname(__file__), "manifest.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(list(items.values()), f, ensure_ascii=False, indent=1)
changed = [i for i in items.values() if i["speak"] != i["text"]]
print(out, len(items), "lines;", len(changed), "with pronunciation fixes")
for i in changed[:12]:
    print("  ", i["text"], "→", i["speak"])
