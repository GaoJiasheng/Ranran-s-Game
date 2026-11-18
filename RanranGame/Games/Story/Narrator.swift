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
        // 英文题用英文声音：优先质量好的；同样质量时英式口音（新加坡学校的口音更接近）在前
        let order = ["en-GB", "en-AU", "en-US", "en-IE", "en-ZA", "en-IN"]
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { order.contains($0.language) }
        // 不要 Eloquence（Grandpa、Rocko……）和搞怪声音（Bubbles……）
        func rank(_ v: AVSpeechSynthesisVoice) -> (Int, Int, Int) {
            let odd = v.identifier.contains("eloquence") || v.identifier.contains("speech.synthesis")
            return (odd ? 0 : 1, v.quality.rawValue, -(order.firstIndex(of: v.language) ?? order.count))
        }
        return voices.max { rank($0) < rank($1) } ?? AVSpeechSynthesisVoice(language: "en-GB")
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
            try? await Task.sleep(for: .milliseconds(min(3200, 400 + words.count * 45)))
            return
        }
        let u = AVSpeechUtterance(string: words)
        u.voice = voice
        u.rate = 0.42
        u.pitchMultiplier = 1.05
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
