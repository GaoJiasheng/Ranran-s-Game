import Foundation

// 复盘里点评出来的错误，对应教学里的哪一课（只连到已有的课，课的 id 不会变）。
// 复盘的点评旁边会出现「复习这一课」。

extension MoveReview {
    /// 这一步的错误对应哪一课
    var lessonID: String? {
        switch kind {
        case .missedWin:
            // 能直接连五没连 → 连成五个就赢；错过连续冲四的杀棋 → 双重威胁
            return note.contains("直接连成五") ? "g2" : "g6"
        case .mistake:
            if note.contains("连成五") { return "g3" }   // 对方只差一个就连成五，没堵
            if note.contains("活三") { return "g7" }     // 对方有活三，没挡
            return nil
        default:
            return nil
        }
    }
}

enum XiangqiReplayLessons {
    /// 走 played 之前是 before：这一步的错误对应哪一课。只在点评说"亏了"的时候问。
    static func lessonID(before: XBoard, played: XMove) -> String? {
        let after = before.applying(played)
        // 能一步将死没将死 → 将军和将死
        if !after.isCheckmate, !before.matesInOne().isEmpty { return "x8" }
        // 走完以后对方一步就能将死（没解好将、没防住杀） → 将军和将死
        if !after.isLost, !after.matesInOne().isEmpty { return "x8" }
        // 走过去的子白白被吃 → 棋子的价值
        if let p = before[played.from], p.kind != .king, p.kind != .pawn,
           XiangqiLessonLogic.isHanging(played, before) { return "x9" }
        return nil
    }
}
