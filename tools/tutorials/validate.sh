#!/bin/zsh
# 校验三门棋的教学内容：zsh tools/tutorials/validate.sh
#   1. 五子棋、象棋：每一步都有答案，对手的应着合法
#   2. 围棋：把每一种走法分支都走一遍（征子、枷的循环也走到底）
#   3. 配音清单：每一句台词都在 tools/voice/manifest.json 里，文件名对得上
# 改了 build_tutorials.py 或 LessonLogic.swift 之后都要跑一遍，三段都要通过。
ROOT=${0:A:h:h:h}
V=$ROOT/tools/tutorials/validate
R=$ROOT/RanranGame/Games
TMP=$(mktemp -d)
SRC=($R/Tutorial/LessonLogic.swift $R/Tutorial/TutorialModel.swift $R/Xiangqi/XiangqiBoard.swift
     $R/Xiangqi/XiangqiAI.swift $R/Gomoku/GomokuModel.swift $R/Go/GoBoard.swift)
fail=0
cp $V/gomoku_xiangqi.swift $TMP/main.swift
swiftc -O -o $TMP/gx $TMP/main.swift $SRC || fail=1
cp $V/go.swift $TMP/main.swift
swiftc -O -o $TMP/go $TMP/main.swift $SRC || fail=1
cp $V/voice_hash.swift $TMP/main.swift
swiftc -O -o $TMP/vh $TMP/main.swift $R/Tutorial/TutorialModel.swift || fail=1
[[ $fail == 1 ]] && { echo "COMPILE FAILED"; exit 1 }
if [[ $1 == -v ]]; then
  $TMP/gx $ROOT; $TMP/go $ROOT; $TMP/vh $ROOT
else
  echo "五子棋/象棋: $($TMP/gx $ROOT | grep -E '❌|ALL GOOD|PROBLEMS')"
  echo "围棋:        $($TMP/go $ROOT | grep -E '❌|ALL GOOD|PROBLEMS')"
  echo "配音清单:    $($TMP/vh $ROOT | tail -3)"
fi
rm -rf $TMP
