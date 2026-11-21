#!/bin/zsh
# 校验三门棋的教学内容：zsh tools/tutorials/validate.sh（加 -v 看每一步的详细输出）
#   1. 五子棋、象棋：每一步都有答案，对手的应着合法
#   2. 围棋：把每一种走法分支都走一遍（征子、枷的循环也走到底）
#      1、2 里练习题也要查：每一段 × 每一种对称变换（五子棋 / 围棋 8 种，象棋左右镜像）都还有答案；
#      走错时演示的后果（白棋连五 / 逃掉、黑方吃子……）每一种错法都成立
#   3. 教学框架：对称变换、练习 / 复习出题、小奖杯、解锁不倒退、drill 不提方向
#   4. 配音清单：每一句台词都在 tools/voice/manifest.json 里，文件名对得上
# 改了 build_tutorials.py 或 LessonLogic.swift 之后都要跑一遍，每一段都要通过。
ROOT=${0:A:h:h:h}
V=$ROOT/tools/tutorials/validate
R=$ROOT/RanranGame/Games
TMP=$(mktemp -d)
SRC=($V/stub.swift $R/Tutorial/LessonLogic.swift $R/Tutorial/TutorialModel.swift
     $R/Tutorial/LessonPractice.swift $R/Tutorial/LessonConsequence.swift
     $R/Xiangqi/XiangqiBoard.swift $R/Xiangqi/XiangqiAI.swift $R/Gomoku/GomokuModel.swift $R/Go/GoBoard.swift
     # 后来加的游戏：教学接入点，加上每个游戏 Logic 文件夹里的全部代码（规则、关卡、判题，只用 Foundation）
     $R/Tutorial/TutorialKit.swift $ROOT/RanranGame/Core/Rewards/PuzzlePack.swift
     $R/Chess/Logic/*.swift(N) $R/Sudoku/Logic/*.swift(N) $R/Tangram/Logic/*.swift(N) $R/Klotski/Logic/*.swift(N))
fail=0
for t in gomoku_xiangqi go framework voice_hash; do
  mkdir -p $TMP/$t
  cp $V/$t.swift $TMP/$t/main.swift
  swiftc -O -o $TMP/$t/run $TMP/$t/main.swift $SRC || fail=1
done
[[ $fail == 1 ]] && { echo "COMPILE FAILED"; rm -rf $TMP; exit 1 }
if [[ $1 == -v ]]; then
  for t in gomoku_xiangqi go framework voice_hash; do $TMP/$t/run $ROOT; done
else
  echo "五子棋/象棋: $($TMP/gomoku_xiangqi/run $ROOT | grep -E '❌|ALL GOOD|PROBLEMS|variants')"
  echo "围棋:        $($TMP/go/run $ROOT | grep -E '❌|ALL GOOD|PROBLEMS|variants')"
  echo "教学框架:    $($TMP/framework/run $ROOT | grep -E '❌|⚠️|ALL GOOD|PROBLEMS|practisable')"
  echo "配音清单:    $($TMP/voice_hash/run $ROOT | tail -3)"
fi
rm -rf $TMP
