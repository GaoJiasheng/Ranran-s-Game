# Ranran-s-Game · 冉冉的游戏屋

给冉冉的 iPad 游戏合集（SwiftUI，iPadOS 17+）。主页选择游戏，目前收录：

- **五子棋** — 十档难度（小兔 1–3、熊猫 4–6、猫头鹰 7–9、龙宝宝 10），或和家人双人对战。
  按住棋盘瞄准、松手落子；支持悔棋、提示，低档对手会在你快输时提醒你。赢了按「赢下 / 没悔棋 / 没用提示」拿 1–3 颗星。
- **加减乘除** — 英文数学应用题，照新加坡小学一、二年级的思路出题（冉冉在海外上学，题目、提示、朗读全是英文）。
  八章：Altogether / Part & Whole / How Many More? / More or Fewer?（"Bunny has 3 fewer than Panda" 这类陷阱）/
  Giving / Equal Groups（乘法）/ Sharing（除法：平均分、每份几个）/ Challenge（两步题，数到 100）。
  每章三关 = 新加坡数学的 C-P-A：**Act it out**（亲手拖物品、往盘子里分）→ **Draw a model**（每读一句画一段线段图，
  part-whole 和 comparison 两种模型）→ **Just read**。答错时先针对错法解释，再给帮助（只看文字 → 画线段图 → 用实物演）。
  **每道题一次就答对 = 1 颗星**，星星当场飞进右上角的计数器；连对会出现 🔥 连击；关卡页显示一共做对了多少题。
  每关 6 / 8 / 10 题（演 / 画 / 读），题目每次随机生成。

**我的**（点主页左上角头像进入，不占主界面）：
- 自定义名字（最多 8 个字），不需要登录，所有数据只存在这台 iPad 上。
- 棋谱：每盘下完自动保存，可以一步一步**复盘**；电脑逐手**分析**（妙手 / 好棋 / 疑问手 / 失误 / 错过胜机），
  画形势曲线，并在棋盘上标出推荐的下法。棋谱格式是通用的（`GameRecord.game` 区分棋种），以后的棋类可以共用。
- 应用题：按题型统计做对 / 做错多少（标出最需要多练的题型），做错的题收进**错题本**，点一道就能再做一遍（能演就演，不能演就画线段图）。
- 存档导入 / 导出：整份存档（名字、星星、进度、棋谱、错题、设置）导出成一个 JSON 文件，换 iPad 时再导入。

## 目录

```
project.yml              XcodeGen 配置（改完运行 `xcodegen generate` 重新生成 .xcodeproj）
RanranGame/
  Core/                  主题配色、音效、玩家存档（PlayerStore：名字/星星/棋谱/导入导出）
  Views/HomeView.swift   主页（游戏合集入口）
  Views/ProfileView.swift「我的」：名字、战绩、棋谱列表、存档
  Games/Gomoku/          五子棋：规则、AI（十档 + 复盘分析）、棋盘、界面、复盘页
  Games/Story/           加减乘除：出题器（题型 + 常见错法 + 线段图）、演故事的舞台（含分盘子）、线段图、做题流程、英文朗读
  Sounds/                合成的音效（落子声、故事里的拿起/放下、答对/答错、过关等）
  Assets.xcassets/       插画、头像、图标
art/                     Codex 生成的原始插画
tools/                   重新生成音效的脚本（make_sounds.py：棋子等；make_sfx.py：故事和关键时刻）
```

## 装到 iPad 上

1. 用数据线把 iPad 连到这台 Mac，iPad 上点「信任此电脑」。
2. iPad 打开 **设置 → 隐私与安全性 → 开发者模式**，打开后重启。
3. 双击打开 `RanranGame.xcodeproj`，顶部设备选成她的 iPad，点 ▶︎ 运行。
4. 签名用的是你的开发者账号（Team `D33974QQTD`），装好后一年内有效。

> 项目放在 iCloud Drive 里，`codesign` 不接受 iCloud 加的文件属性，所以构建产物必须放在 iCloud 之外
> （Xcode 默认的 DerivedData 就可以，别把构建目录设在项目文件夹里）。
