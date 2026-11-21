#!/bin/zsh
# 出题：zsh tools/sudoku/generate.sh —— 重写 RanranGame/Games/Sudoku/Logic/SudokuLevelData.swift。
# 关卡发布以后不要再跑（题目一变，存档里的星星就对不上了）；要加关卡，加新的组 / 新的 id。
set -e
ROOT=${0:A:h:h:h}
source $ROOT/tools/sudoku/sources.zsh
TMP=$(mktemp -d)
cp $ROOT/tools/sudoku/generate.swift $TMP/main.swift
swiftc -O -o $TMP/gen $TMP/main.swift $SUDOKU_SRC
$TMP/gen $ROOT
rm -rf $TMP
