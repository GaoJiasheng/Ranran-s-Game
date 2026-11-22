#!/bin/zsh
# 编程的命令行测试：zsh tools/coding/test.sh（全部通过时最后一行是 ALL PASSED）
#   zsh tools/coding/test.sh levels   只查关卡（设计关卡时用，快一点）
# 编译 Games/Coding/Logic/ 里的全部代码（只用 Foundation），加上教学框架里不带界面的那几个文件（和 tools/tutorials/validate.sh 一样），
# 再加上只给测试用的穷举求解器 tools/coding/solver.swift。
ROOT=${0:A:h:h:h}
R=$ROOT/RanranGame/Games
V=$ROOT/tools/tutorials/validate
TMP=$(mktemp -d)
SRC=($V/stub.swift $R/Tutorial/LessonLogic.swift $R/Tutorial/TutorialModel.swift
     $R/Tutorial/LessonPractice.swift $R/Tutorial/LessonConsequence.swift
     $R/Xiangqi/XiangqiBoard.swift $R/Xiangqi/XiangqiAI.swift $R/Gomoku/GomokuModel.swift $R/Go/GoBoard.swift
     $R/Tutorial/TutorialKit.swift $ROOT/RanranGame/Core/Rewards/PuzzlePack.swift
     $R/Chess/Logic/*.swift(N) $R/Sudoku/Logic/*.swift(N) $R/Tangram/Logic/*.swift(N) $R/Klotski/Logic/*.swift(N)
     $R/Coding/Logic/*.swift(N) $ROOT/tools/coding/solver.swift)
cp $ROOT/tools/coding/test.swift $TMP/main.swift
swiftc -O -o $TMP/run $TMP/main.swift $SRC || { echo "COMPILE FAILED"; rm -rf $TMP; exit 1 }
$TMP/run $ROOT "$@"
code=$?
rm -rf $TMP
exit $code
