# Ranran-s-Game · 然然的游戏屋

给然然的 iPad 游戏合集（SwiftUI，iPadOS 17+）。主页选择游戏，目前收录：

- **五子棋** — 和小兔（入门）、熊猫（进阶）、猫头鹰（高手）对战，或和家人双人对战。
  按住棋盘瞄准、松手落子；支持悔棋、提示，小兔和熊猫会在你快输时提醒你。赢了能攒星星。

## 目录

```
project.yml              XcodeGen 配置（改完运行 `xcodegen generate` 重新生成 .xcodeproj）
RanranGame/
  Core/                  主题配色、音效、星星存储
  Views/HomeView.swift   主页（游戏合集入口）
  Games/Gomoku/          五子棋：规则、AI、棋盘、界面
  Sounds/                合成的音效（落子声等）
  Assets.xcassets/       插画、头像、图标
art/                     Codex 生成的原始插画
```

## 装到 iPad 上

1. 用数据线把 iPad 连到这台 Mac，iPad 上点「信任此电脑」。
2. iPad 打开 **设置 → 隐私与安全性 → 开发者模式**，打开后重启。
3. 双击打开 `RanranGame.xcodeproj`，顶部设备选成她的 iPad，点 ▶︎ 运行。
4. 签名用的是你的开发者账号（Team `D33974QQTD`），装好后一年内有效。

> 项目放在 iCloud Drive 里，`codesign` 不接受 iCloud 加的文件属性，所以构建产物必须放在 iCloud 之外
> （Xcode 默认的 DerivedData 就可以，别把构建目录设在项目文件夹里）。
