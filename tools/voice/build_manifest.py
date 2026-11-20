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
          "帅走到这里会被吃掉，或者和将面对面，不可以。", "走了这一步，帅就会被吃掉，不可以。",
          "找到一个，还有呢？", "打劫的时候，被提的一方要先在别处下一手，才能提回来。", "这里下进去一口气都没有，是禁入点。"]


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
    add(t, "xiangqi" if ("帅" in t or "将" in t) else "common")

out = os.path.join(os.path.dirname(__file__), "manifest.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(list(items.values()), f, ensure_ascii=False, indent=1)
changed = [i for i in items.values() if i["speak"] != i["text"]]
print(out, len(items), "lines;", len(changed), "with pronunciation fixes")
for i in changed[:12]:
    print("  ", i["text"], "→", i["speak"])
