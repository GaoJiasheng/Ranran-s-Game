#!/bin/zsh
# 国际象棋的命令行测试：zsh tools/chess/test.sh（加 -v 看教学每一步的答案）
#   rules     走法计数对照标准 perft；FEN、易位、过路兵、升变、将死、逼和、三次重复、50 回合、子力不足、记谱
#   ai        电脑从不走不合法的棋；第 10 档能找到两步杀；第 1 档经常丢子；各档想一步的时间
#   tutorial  每道题按 ChessLessonLogic 都有答案；黑方每一种应着后面都接得上；练习的每种样子也有答案；
#             走错时演示的后果成立；每课至少两道题；drill 和通用说法不提方向和格子；固定台词和 extra_chess.json 一致
# 全部通过时最后一行是 ALL PASSED。
ROOT=${0:A:h:h:h}
T=$ROOT/tools/chess
V=$ROOT/tools/tutorials/validate
R=$ROOT/RanranGame/Games
TMP=$(mktemp -d)
SRC=($V/stub.swift $R/Tutorial/LessonLogic.swift $R/Tutorial/TutorialModel.swift
     $R/Tutorial/LessonPractice.swift $R/Tutorial/LessonConsequence.swift
     $R/Xiangqi/XiangqiBoard.swift $R/Xiangqi/XiangqiAI.swift $R/Gomoku/GomokuModel.swift $R/Go/GoBoard.swift
     $R/Tutorial/TutorialKit.swift $ROOT/RanranGame/Core/Rewards/PuzzlePack.swift
     $R/Chess/Logic/*.swift(N) $R/Sudoku/Logic/*.swift(N) $R/Tangram/Logic/*.swift(N) $R/Klotski/Logic/*.swift(N))
fail=0
for t in rules ai tutorial; do
  mkdir -p $TMP/$t
  cp $T/$t.swift $TMP/$t/main.swift
  swiftc -O -o $TMP/$t/run $TMP/$t/main.swift $T/support.swift $SRC 2>&1 | grep -E "error|warning: (var|init)" && fail=1
  [[ -x $TMP/$t/run ]] || fail=1
done
[[ $fail == 1 ]] && { echo "COMPILE FAILED"; rm -rf $TMP; exit 1 }
ok=1
for t in rules ai tutorial; do
  echo "== $t"
  $TMP/$t/run $ROOT $1 || ok=0
done
rm -rf $TMP
[[ $ok == 1 ]] && echo "ALL PASSED" || { echo "SOME TESTS FAILED"; exit 1 }
