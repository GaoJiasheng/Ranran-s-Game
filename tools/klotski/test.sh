#!/bin/zsh
# 华容道的命令行测试：zsh tools/klotski/test.sh（全部通过时最后一行是 ALL PASSED）
# 编译 Games/Klotski/Logic/ 里的全部代码（只用 Foundation），加上教学框架里不带界面的那几个文件（和 tools/tutorials/validate.sh 一样）。
ROOT=${0:A:h:h:h}
R=$ROOT/RanranGame/Games
V=$ROOT/tools/tutorials/validate
TMP=$(mktemp -d)
SRC=($V/stub.swift $R/Tutorial/LessonLogic.swift $R/Tutorial/TutorialModel.swift
     $R/Tutorial/LessonPractice.swift $R/Tutorial/LessonConsequence.swift
     $R/Xiangqi/XiangqiBoard.swift $R/Xiangqi/XiangqiAI.swift $R/Gomoku/GomokuModel.swift $R/Go/GoBoard.swift
     $R/Tutorial/TutorialKit.swift $ROOT/RanranGame/Core/Rewards/PuzzlePack.swift
     $R/Chess/Logic/*.swift(N) $R/Sudoku/Logic/*.swift(N) $R/Tangram/Logic/*.swift(N) $R/Klotski/Logic/*.swift(N))
cp $ROOT/tools/klotski/test.swift $TMP/main.swift
swiftc -O -o $TMP/run $TMP/main.swift $SRC || { echo "COMPILE FAILED"; rm -rf $TMP; exit 1 }
$TMP/run $ROOT
code=$?
rm -rf $TMP
exit $code
