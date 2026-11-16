import AVFoundation

/// 把题目一句一句读出来。小朋友不用自己读长句子，也能听懂故事。
@MainActor
final class Narrator: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Narrator()
    static let voiceKey = "story.voice"

    private let synth = AVSpeechSynthesizer()
    private var current: AVSpeechUtterance?
    private var continuation: CheckedContinuation<Void, Never>?
    private lazy var voice: AVSpeechSynthesisVoice? = {
        // 优先用质量更好的中文声音
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "zh-CN" }
        return voices.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "zh-CN")
    }()

    override private init() {
        super.init()
        synth.delegate = self
    }

    var enabled: Bool {
        UserDefaults.standard.object(forKey: Self.voiceKey) as? Bool ?? true
    }

    /// 读一句，读完才返回。声音关掉时按句子长短停一会儿，节奏不变。
    func speak(_ text: String) async {
        stop()
        let words = StoryText.spoken(text)
        guard enabled, !words.isEmpty else {
            try? await Task.sleep(for: .milliseconds(min(2600, 400 + words.count * 110)))
            return
        }
        let u = AVSpeechUtterance(string: words)
        u.voice = voice
        u.rate = 0.44
        u.pitchMultiplier = 1.08
        u.postUtteranceDelay = 0.12
        await withCheckedContinuation { c in
            continuation = c
            current = u
            synth.speak(u)
        }
    }

    /// 不等它读完
    func say(_ text: String) {
        Task { await speak(text) }
    }

    func stop() {
        current = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        continuation?.resume()
        continuation = nil
    }

    private func finished(_ u: AVSpeechUtterance) {
        guard u === current else { return }
        current = nil
        continuation?.resume()
        continuation = nil
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.finished(u) }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in self.finished(u) }
    }
}
