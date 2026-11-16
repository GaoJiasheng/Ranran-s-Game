import AVFoundation

/// 播放 Sounds 文件夹里的小音效（落子声、胜利音乐等）。跟随静音键。
@MainActor
enum Sound {
    private static var pools: [String: [AVAudioPlayer]] = [:]

    static func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        let steps = (1...10).map { "step_\($0)" }
        for name in ["stone_a", "stone_b", "tap", "win", "lose", "hint", "undo"] + steps {
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
}
