# 往合集里加一个新游戏

这份说明是给动手做新游戏的人（或者代理）看的：哪些是你的，哪些已经有了直接用，做到什么程度才算完。
先读 `README.md`（整个 App 是什么）和 `docs/tutorials.md`（教学怎么设计），再读这一份。

## 标准

- 给 6–8 岁的冉冉用。一次只把一件事做精，界面要有设计感，和现有的五子棋、象棋、围棋、加减乘除是一家人
  （配色、圆角、字体、按钮都用 `Core/Theme.swift` 里的：`Palette`、`.kid(...)`、`softCard`、`PillButtonStyle`、`RoundIconButton`、`PressableStyle`、`CreamBackground`、`ArtImage`、`Avatar`）。
- 孩子用的页面**固定布局、不滚动**，横屏竖屏都要好用（11 寸 1210×834 和 13 寸 1376×1032 两种 iPad，横竖都算）。用 `GeometryReader` 按地方大小排，不要写死尺寸。
- 全部数据存在本机（`PlayerStore`），不联网、不登录。
- 界面文字是中文（数学那个游戏例外）。给孩子看的话要短、具体、听得懂。
- 每个益智游戏的首页右上角都有「教学」，猫头鹰老师一步一步教，**每一句话都有预先录好的配音**。
- 星星、奖章只走全局的那一套（见下面「奖励」），不要自己另起一套。
- 没有时间压力：不倒计时，不因为慢扣星星。

## 你的地盘

以国际象棋（`Chess` / `chess`）为例，别的游戏把名字换掉：

| 路径 | 内容 |
|---|---|
| `RanranGame/Games/Chess/` | 这个游戏的全部界面代码。里面已经有几个占位文件，直接改掉 |
| `RanranGame/Games/Chess/Logic/` | 规则、电脑、关卡、判题、`ChessTutorialKit.swift`。**只用 Foundation**（不 import SwiftUI / UIKit，不碰 `PlayerStore`），因为命令行校验工具会把这个文件夹整个编译进去。类型名都带上游戏的前缀（`ChessBoard`、`SudokuGrid`……），免得和别的游戏撞名 |
| `RanranGame/Tutorials/chess.json` | 教学内容，由你的生成脚本写出来 |
| `RanranGame/Content/chess_*.json` | 需要的话，放预先生成好的关卡数据 |
| `tools/tutorials/build_chess.py` | 生成 `chess.json` 的脚本（课文写在脚本里，照 `build_tutorials.py` 的写法） |
| `tools/chess/` | 你的命令行测试和工具，入口是 `zsh tools/chess/test.sh`，全部通过时最后一行打印 `ALL PASSED` |
| `tools/voice/extra_chess.json` | 固定台词和读音修正（见「配音」） |
| `docs/tutorial-chess.md` | 这门课的规划：每组每课教什么、为什么这样排 |

**别的文件一律不要改**（`Core/`、`Views/`、`Games/Tutorial/`、别的游戏、`project.yml`、`README.md`、`docs/tutorials.md`、`tools/voice/*.py`……）。
公共部分缺了什么、哪里不合用，写在最后的报告里，由合并的人来改。`RanranGame.xcodeproj` 是 XcodeGen 生成的：加了文件要跑 `xcodegen generate` 才编得过，但**不要把它提交进去**。

## 已经接好的地方

这些已经写好并且指向你的占位文件，名字和参数不要改：

- 主页卡片、路由：`GameEntry.chess` → `ChessSetupView()`。调试时 `-route chess` 直接进这一页。
  「我的」里「主页上的游戏」的开关也是按 `GameEntry` 列出来的，新游戏自动多一行、默认摆在主页上。
- 教学：`TutorialHomeView(game: "chess", accent:onPlay:)` 是课程表；打开一课时框架会创建
  `ChessLessonView(course:lesson:mode:onNextLesson:)`。`TutorialCourse.bundled["chess"]` 读 `Tutorials/chess.json`。
- 教学接入点：`ChessTutorial.kit`（`TutorialKit`，在 `Games/Tutorial/TutorialKit.swift` 里有每一项的说明）。
- 奖励：`Subjects.all` 里已经登记了你的科目，主页、奖章墙、「我的」会自动带上。
- 「我的」里的棋谱列表（只有棋类）：`GameRecord.game == "chess"` 的会用 `ChessReplayView(record:)` 打开。

## 教学怎么接

读 `Games/Tutorial/` 里的 `TutorialModel.swift`（数据）、`LessonFlow.swift`（一课的流程 `LessonFlow` 和外壳 `LessonScaffold`）、
`XiangqiLessonView.swift` / `GoLessonView.swift`（两个现成的例子）。要点：

- 一课 = 若干步（`TutorialStep`）。每步老师说一句（`say`），可以换局面（`board`）、加标记（`marks`）、出一道题（`task`）。
  `board` / `marks` / `task.type` / `task.rule` / `task.accept` 都是字符串，格式你自己定；不够用就放进 `extra`（步骤和题目上各有一个 `[String: String]`）。
- 你的 `ChessLessonView` 用 `LessonScaffold` 包住自己的棋盘 / 盘面，孩子操作后调 `flow.succeed()`、`flow.fail(...)`、`flow.nudge(...)`……
  小奖杯、星星、今天的三颗星、解锁、结算页都是 `LessonFlow` / `LessonScaffold` 管的，不用你写。
- **每道题都由规则引擎判断**，不是只认写死的一个答案；错一次给提示（`hint`），错两次亮出答案再让她自己做一遍（框架已经这样做了）。
- 第一组课的 id 固定叫 `basic`，一开始只开这一组，学完一组才解锁下一组。每组的封面图叫 `tutor_<game>_<组 id>`（比如 `tutor_chess_basic`）。
- 一课 4–8 步，其中至少 2 道题；每课有一句 `learned`（"学会了……"里的省略号部分）。一门课 12 课起步，内容够多就多写，按 `docs/tutorials.md` 的思路循序渐进。
- 练一练 / 复习：没写 `drill` 的题按 `kit.practicePrompts[task.rule]` 配通用说法；能换样子的题在 `kit.practiceTransform` 里换（镜像、换数字……），
  让她靠看懂而不是靠记住。`drill` 和通用说法里不能提方向和具体位置。
- 学完一组可以直接去玩：`kit.playLevels["<组 id>"]`，棋类是第几档，解谜类是第几组关卡（从 1 开始）。解谜类把
  `kit.goPlayLine` 设成"这一组学完啦，去闯关吧！"、`kit.goPlayTitle` 设成"去闯关"。

## 配音

- 孩子听到的每一句话都要预先录好：课文（`say` / `hint` / `ok` / `after` / `drill` / 每课的 `learned`）会自动收集；
  游戏里和教学里要说的其他固定句子，写进 `ChessTutorial.kit.fixedLines`，并且**原样**抄进 `tools/voice/extra_chess.json` 的 `lines`。
- 不要用系统语音现场合成，不要拼接句子（"第 3 关"这类带数字的话只显示、不朗读）。
- 多音字、术语读音：在 `extra_chess.json` 的 `replace`（整词替换）和 `regex` 里把会读错的字换成同音字（做法看 `build_manifest.py` 里象棋、围棋的例子）。把你所有台词里的多音字都过一遍。
- 你只管把台词写对；录音由合并的人统一交给 Codex 生成（`python3 tools/voice/build_manifest.py` 之后跑 `generate_voice.py`）。
  你可以跑 `python3 tools/voice/build_manifest.py` 确认自己的句子都进了清单，但**不要提交 `tools/voice/manifest.json`**。

## 奖励

规矩全在 `Core/Rewards/`，先读 `RewardRules.swift` 开头的那张表。

- **棋类**（国际象棋）：和象棋一模一样——十档对手（`Opponent`、`LevelShowcase`、`LevelLadder` 都是现成的），赢了调
  `store.recordWin(game:level:earned:)`（earned = 赢 + 没悔棋 + 没用提示），一盘下完（输赢、和家人下都算）调 `store.noteDaily(.play)`，
  结果页用现成的 `WinRewardNote`。照 `Games/Xiangqi/` 的做法来。
- **解谜类**（数独、七巧板、华容道、编程）：
  - 关卡分组写在 `Logic/<Game>Catalog.swift`：`packs: [PuzzlePack]`（每组最多 20 关，3–5 组，从易到难）和 `passPacks`（通过前几组算"学会了"）。
    组和关的 id 会写进存档，定了就永远不改。每组的小图叫 `pack_<game>_<组 id>`。
  - 首页直接用 `Views/Puzzle/PuzzleSetupView`（选组、关卡格子、解锁、星星、新手提示、进教学都在里面），你只给每一关的小图和点开之后的页面。
    现在 `Games/Sudoku/SudokuSetupView.swift` 里的占位就是用法示例。
  - 过了一关：`let result = store.recordPuzzle(game:level:earned:)`，然后盖上 `Views/Puzzle/PuzzleDoneOverlay`。
    三颗星 = 过关 1 颗 + 你定的另外两颗（比如"没用提示""没填错"）。只记最好的一次，变好了补差额，所以重玩刷不了星。
    「下一关」用 `store.puzzleAfter(game, packs, level)`。
- 不要直接调 `addStars` / `earnStars`。

## 插画

- 画不出来的东西（角色、封面、棋子）用图片：`ArtImage(name:fallback:)`，图片还没到时显示 emoji，所以先用约定好的名字写代码，能编过就行。
- 需要哪些图，在最后的报告里列一张表：文件名、尺寸、透明底还是整幅、画什么。由合并的人交给 Codex 画。
- 能用代码画好的（棋盘、格子、几何图形、木块）就用 SwiftUI 画，不要图片。已有的图在 `art/` 和 `Assets.xcassets` 里，可以直接用
  （四个小伙伴 `avatar_bunny` / `avatar_panda` / `avatar_owl` / `avatar_dragon`，小贴纸 `item_apple` / `item_cookie` / `item_pencil` / `item_balloon` / `item_candy` / `item_basket` / `item_strawberry` / `item_sticker` / `item_carrot`）。

## 调试入口

每个页面留好启动参数，合并的人要靠它们在模拟器里一页一页截图检查（照现有的 `#if DEBUG` 写法，读 `UserDefaults.standard`）：
直接打开某一关 / 某一档对局、直接摆出过关或者赢了的结算页、直接打开某一课（`-lesson <id>`，课程表已经支持）。在报告里列出来。

## 做完的标准

1. `xcodegen generate` 后模拟器构建通过，没有新的警告：
   `xcodebuild -project RanranGame.xcodeproj -scheme RanranGame -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath <你自己的目录> build`
2. `zsh tools/<game>/test.sh` 全过：规则 / 关卡的正确性（国际象棋要对照标准 perft；解谜类每一关都验证有解、难度合适），
   教学里每道题按你的判题逻辑都有答案、提示里说的和答案对得上，练习的每一种变换也都有答案。
3. `zsh tools/tutorials/validate.sh`、`zsh tools/rewards/test.sh` 仍然全过（你的 `Logic/` 会被编进前一个）。
4. 不要启动模拟器，也不要动别人的构建目录。界面你看不到，所以布局要写得保守、按比例、留余量；拿不准的地方在报告里点出来。
5. 提交到你自己的分支（不含 `.xcodeproj`、`manifest.json`），报告里写清楚：做了什么、每个文件是干什么的、调试参数、要画的图、
   公共部分想改的地方、你自己觉得还不够好的地方。
