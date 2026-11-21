# 数独命令行工具要编译的 App 代码（和 tools/tutorials/validate.sh 一样：教学框架 + 四个新游戏的 Logic 文件夹）。
# 用法：source tools/sudoku/sources.zsh 之后用 $SUDOKU_SRC
ROOT=${ROOT:-${0:A:h:h:h}}
_V=$ROOT/tools/tutorials/validate
_R=$ROOT/RanranGame/Games
SUDOKU_SRC=($_V/stub.swift $_R/Tutorial/LessonLogic.swift $_R/Tutorial/TutorialModel.swift
     $_R/Tutorial/LessonPractice.swift $_R/Tutorial/LessonConsequence.swift
     $_R/Xiangqi/XiangqiBoard.swift $_R/Xiangqi/XiangqiAI.swift $_R/Gomoku/GomokuModel.swift $_R/Go/GoBoard.swift
     $_R/Tutorial/TutorialKit.swift $ROOT/RanranGame/Core/Rewards/PuzzlePack.swift
     $_R/Chess/Logic/*.swift(N) $_R/Sudoku/Logic/*.swift(N) $_R/Tangram/Logic/*.swift(N) $_R/Klotski/Logic/*.swift(N)
     $ROOT/tools/sudoku/common.swift)
