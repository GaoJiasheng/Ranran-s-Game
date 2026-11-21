#!/usr/bin/env python3
"""把数独的固定台词抄进 tools/voice/extra_sudoku.json（和 SudokuTutorial.kit.fixedLines 一模一样，test.sh 会对一遍）。

读音修正（对数独的每一句都生效）：
  行 → 杭      数独里的"行"都是 háng（一行、这一行、每一行）；课文里不用"不行、进行"这类词（test.sh 查）
  重复 → 虫复  chóng
  空格 / 空着 → 控格 / 控着  kòng（空着的格子）
"""
import json
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
src = open(os.path.join(ROOT, "RanranGame/Games/Sudoku/Logic/SudokuTutorialKit.swift"), encoding="utf-8").read()
consts = dict(re.findall(r'static let (\w+) = "([^"]+)"', src))
order = re.search(r"static let all = \[(.*?)\]", src, re.S).group(1)
names = [n.strip() for n in order.replace("\n", " ").split(",") if n.strip()]
prompts = re.findall(r'^\s+"[\w:]+": "([^"]+)",$', src, re.M)
lines = [consts[n] for n in names] + sorted(prompts) + [consts["goPlayLine"]]
data = {
    "lines": lines,
    "replace": [["重复", "虫复"], ["空格", "控格"], ["空着", "控着"]],
    "regex": [["行", "杭"]],
}
out = os.path.join(ROOT, "tools/voice/extra_sudoku.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
print(out, len(lines), "lines")
