#!/bin/zsh
# 重新生成题库和英文配音清单：zsh tools/storybank/build.sh
set -e
ROOT=${0:A:h:h:h}
TMP=$(mktemp -d)
# BarModel.swift 只要数据部分（"画出来"之前），界面部分在命令行里用不到
sed '/^\/\/ MARK: - 画出来/,$d' "$ROOT/RanranGame/Games/Story/BarModel.swift" > $TMP/bar.swift
swiftc -O -o $TMP/bank "$ROOT/tools/storybank/main.swift" "$ROOT/tools/storybank/stub.swift" \
  "$ROOT/RanranGame/Games/Story/StoryModel.swift" "$ROOT/RanranGame/Games/Story/StoryVoiceLines.swift" $TMP/bar.swift
$TMP/bank "$ROOT"
rm -rf $TMP
