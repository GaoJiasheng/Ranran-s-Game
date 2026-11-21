#!/bin/zsh
# 全局奖励规矩的命令行测试（发星星、防刷、今天的三颗星）：zsh tools/rewards/test.sh
set -e
ROOT=${0:A:h:h:h}
TMP=$(mktemp -d)
R="$ROOT/RanranGame/Core/Rewards"
cp "$ROOT/tools/rewards/test.swift" $TMP/main.swift
swiftc -O -o $TMP/test $TMP/main.swift "$ROOT/tools/rewards/stub.swift" "$R/RewardRules.swift" "$R/RewardStore.swift"
$TMP/test
rm -rf $TMP
