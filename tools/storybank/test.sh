#!/bin/zsh
# 「加减乘除」逻辑的命令行测试（老存档升级、先选算式、练一练）：zsh tools/storybank/test.sh
set -e
ROOT=${0:A:h:h:h}
TMP=$(mktemp -d)
S="$ROOT/RanranGame/Games/Story"
sed '/^\/\/ MARK: - 画出来/,$d' "$S/BarModel.swift" > $TMP/bar.swift
cp "$ROOT/tools/storybank/test.swift" $TMP/main.swift
swiftc -O -o $TMP/test $TMP/main.swift "$ROOT/tools/storybank/stub.swift" \
  "$S/StoryModel.swift" "$S/StoryBig.swift" "$S/StoryTwoStep.swift" "$S/StoryChoice.swift" \
  "$S/StoryVoiceLines.swift" $TMP/bar.swift 2>&1 | grep -E "error" || true
$TMP/test "$ROOT"
rm -rf $TMP
