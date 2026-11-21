#!/bin/zsh
# 七巧板的全部测试：zsh tools/tangram/test.sh
#   1. python3 figures_tool.py check：每个图形七块各用一次、不重叠、连成一片、坐标在格子上
#   2. 导出的 TangramFigureData.swift 和 figures.py 一致
#   3. tangram.json 是 build_tangram.py 生成的最新版本
#   4. test.swift：几何、判断拼好没有、吸附、关卡、教学每道题和每种练习变换、配音
# 全部通过时最后一行打印 ALL PASSED。
ROOT=${0:A:h:h:h}
T=$ROOT/tools/tangram
R=$ROOT/RanranGame/Games
TMP=$(mktemp -d)
fail=0

echo "[图形校验]"
python3 $T/figures_tool.py check || fail=1

echo "[导出的数据是最新的]"
cp $R/Tangram/Logic/TangramFigureData.swift $TMP/figures_before.swift
python3 $T/figures_tool.py export > /dev/null || fail=1
if ! cmp -s $TMP/figures_before.swift $R/Tangram/Logic/TangramFigureData.swift; then
  echo "✗ TangramFigureData.swift 和 figures.py 对不上（已经重新导出，请提交）"; fail=1
fi
cp $ROOT/RanranGame/Tutorials/tangram.json $TMP/course_before.json
python3 $ROOT/tools/tutorials/build_tangram.py > /dev/null || fail=1
if ! cmp -s $TMP/course_before.json $ROOT/RanranGame/Tutorials/tangram.json; then
  echo "✗ tangram.json 不是 build_tangram.py 生成的最新版本（已经重新生成，请提交）"; fail=1
fi

SRC=($ROOT/tools/tutorials/validate/stub.swift $R/Tutorial/LessonLogic.swift $R/Tutorial/TutorialModel.swift
     $R/Tutorial/LessonPractice.swift $R/Tutorial/LessonConsequence.swift
     $R/Xiangqi/XiangqiBoard.swift $R/Xiangqi/XiangqiAI.swift $R/Gomoku/GomokuModel.swift $R/Go/GoBoard.swift
     $R/Tutorial/TutorialKit.swift $ROOT/RanranGame/Core/Rewards/PuzzlePack.swift
     $R/Chess/Logic/*.swift(N) $R/Sudoku/Logic/*.swift(N) $R/Tangram/Logic/*.swift(N) $R/Klotski/Logic/*.swift(N))
cp $T/test.swift $TMP/main.swift
if swiftc -O -o $TMP/run $TMP/main.swift $SRC; then
  $TMP/run $ROOT > $TMP/out.txt
  rc=$?
  grep -v -e "^ALL PASSED$" -e "^FAILED$" $TMP/out.txt
  [[ $rc == 0 ]] || fail=1
else
  echo "COMPILE FAILED"; fail=1
fi
rm -rf $TMP
if [[ $fail == 0 ]]; then echo "ALL PASSED"; else echo "FAILED"; exit 1; fi
