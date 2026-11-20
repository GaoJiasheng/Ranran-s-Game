#!/bin/zsh
# 补齐题库和英文配音清单：zsh tools/storybank/build.sh [--samples]
# 已有的关原样保留，只给还没有的关出题（详见 main.swift）。跑两遍结果一样。
set -e
ROOT=${0:A:h:h:h}
TMP=$(mktemp -d)
S="$ROOT/RanranGame/Games/Story"
# BarModel.swift 只要数据部分（"画出来"之前），界面部分在命令行里用不到
sed '/^\/\/ MARK: - 画出来/,$d' "$S/BarModel.swift" > $TMP/bar.swift
swiftc -O -o $TMP/bank "$ROOT/tools/storybank/main.swift" "$ROOT/tools/storybank/stub.swift" \
  "$S/StoryModel.swift" "$S/StoryBig.swift" "$S/StoryTwoStep.swift" "$S/StoryChoice.swift" \
  "$S/StoryVoiceLines.swift" $TMP/bar.swift
$TMP/bank "$ROOT" "$@"
rm -rf $TMP
