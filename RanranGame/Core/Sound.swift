import AVFoundation

/// 播放 Sounds 文件夹里的小音效（落子声、胜利音乐等）。跟随静音键。
@MainActor
enum Sound {
    private static var pools: [String: [AVAudioPlayer]] = [:]

    static func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        let steps = (1...10).map { "step_\($0)" }
        let story = ["pop", "pick", "drop", "nope", "done", "key", "correct", "oops",
                     "sparkle", "start", "fanfare", "record"]
        for name in ["stone_a", "stone_b", "tap", "win", "lose", "hint", "undo"] + steps + story {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { continue }
            pools[name] = (0..<3).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
    }

    private static func play(_ name: String, volume: Float = 1) {
        guard let pool = pools[name], !pool.isEmpty else { return }
        let player = pool.first { !$0.isPlaying } ?? pool[0]
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    static func place(_ stone: Stone) { play(stone == .black ? "stone_a" : "stone_b") }
    static func tap()  { play("tap", volume: 0.55) }
    static func win()  { play("win", volume: 0.8) }
    static func lose() { play("lose", volume: 0.7) }
    static func hint() { play("hint", volume: 0.7) }
    static func undo() { play("undo", volume: 0.6) }
    /// 难度阶梯上每一档的音，档位越高音越高
    static func step(_ level: Int) { play("step_\(min(max(level, 1), 10))", volume: 0.5) }

    // MARK: 关键时刻

    /// 开始一关 / 一局
    static func start()   { play("start", volume: 0.55) }
    /// 过关
    static func fanfare() { play("fanfare", volume: 0.8) }
    /// 破了自己的纪录
    static func record()  { play("record", volume: 0.7) }

    // MARK: 故事里的小动作

    /// 物品出现在台上
    static func pop()     { play("pop", volume: 0.45) }
    /// 手指拿起物品
    static func pick()    { play("pick", volume: 0.4) }
    /// 物品放下
    static func drop()    { play("drop", volume: 0.55) }
    /// 这样拖不行（方向反了）
    static func nope()    { play("nope", volume: 0.5) }
    /// 这一步演好了
    static func done()    { play("done", volume: 0.6) }
    /// 按数字键
    static func key()     { play("key", volume: 0.5) }
    /// 答对了
    static func correct() { play("correct", volume: 0.7) }
    /// 答错了，再想想
    static func oops()    { play("oops", volume: 0.55) }
    /// 比一比时"多出来的"亮起来
    static func sparkle() { play("sparkle", volume: 0.5) }
}
