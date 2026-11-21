#!/usr/bin/env python3
"""把国际象棋的固定台词抄进 tools/voice/extra_chess.json（和 ChessTutorial.kit.fixedLines 同样的内容、同样的顺序）。

固定台词在 RanranGame/Games/Chess/Logic/ 里：ChessTutorLines（走错的后果、不合规则时的提醒）和
ChessTutorial.practicePrompts（练习题的通用说法）。改了它们以后跑一次：python3 tools/chess/sync_voice.py
读音修正（replace / regex）写在下面，对国际象棋的每一句都生效。
"""
import json
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
LOGIC = os.path.join(ROOT, "RanranGame", "Games", "Chess", "Logic")

# 车（棋子）读 jū；闷杀的闷读 mèn；得子的得读 dé；露出来读 lòu。
# 将军 / 将死里的将读 jiāng，是语音默认的读法，不用改；国际象棋里没有"将"这个棋子。
REPLACE = [["车", "居"], ["闷杀", "焖杀"], ["得子", "德子"], ["露出来", "漏出来"]]
REGEX = []

src = open(os.path.join(LOGIC, "ChessLessonLogic.swift"), encoding="utf-8").read()
part = src[src.index("enum ChessTutorLines"):]
named = dict(re.findall(r'static let (\w+) = "([^"]+)"', part))
order = re.search(r"static var all: \[String\] \{ \[([^\]]+)\] \}", part).group(1).replace(" ", "").split(",")
lines = [named[k] for k in order]

kit = open(os.path.join(LOGIC, "ChessTutorialKit.swift"), encoding="utf-8").read()
prompts = kit[kit.index("practicePrompts: [String: String] = ["):kit.index("static let kit")]
lines += sorted(re.findall(r'"[^"]+": "([^"]+)"', prompts))

out = os.path.join(ROOT, "tools", "voice", "extra_chess.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump({"lines": lines, "replace": REPLACE, "regex": REGEX}, f, ensure_ascii=False, indent=1)
    f.write("\n")
print(out, len(lines), "fixed lines")
