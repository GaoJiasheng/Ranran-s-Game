#!/bin/zsh
# 数独的测试：zsh tools/sudoku/test.sh（全部通过时最后一行是 ALL PASSED）
# 解题器、每一关（唯一解、只用这一组的几招、难度不降、不重复、不变）、教学的每道题和练习变换、配音台词。
# 编译的是 App 里同一份 Logic 代码（RanranGame/Games/Sudoku/Logic）。
ROOT=${0:A:h:h:h}
source $ROOT/tools/sudoku/sources.zsh
TMP=$(mktemp -d)
cp $ROOT/tools/sudoku/test.swift $TMP/main.swift
swiftc -O -o $TMP/test $TMP/main.swift $SUDOKU_SRC || { echo "COMPILE FAILED"; rm -rf $TMP; exit 1 }
$TMP/test $ROOT
code=$?
rm -rf $TMP
exit $code
