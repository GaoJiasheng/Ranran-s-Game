import AVFoundation
import CryptoKit

/// 把题目一句一句读出来。小朋友不用自己读长句子，也能听懂故事。
/// 题库里的句子都预先录好了（VoiceEN 文件夹，Codex 生成的英式英语神经网络语音），有录音就放录音；
/// 拖物品时报数量这类随时变化的话，用系统语音读。
@MainActor
final class Narrator: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let shared = Narrator()
    static let voiceKey = "story.voice"

    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    /// 每次被打断（stop）就加一，连读到一半的句子发现变了就不再往下读
    private var generation = 0
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

    /// 录音文件名：en_<文字的 sha1 前 10 位>.mp3（和 tools/storybank 生成清单时的算法一样）
    nonisolated static func fileName(_ text: String) -> String {
        "en_" + Insecure.SHA1.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined().prefix(10)
    }

    /// 读一句，读完才返回（会打断正在读的话）
    func speak(_ text: String) async {
        stop()
        await play(text)
    }

    /// 真正读出一句。声音关掉时按句子长短停一会儿，节奏不变。
    private func play(_ text: String) async {
        halt()
        let words = StoryText.spoken(text)
        guard enabled, !words.isEmpty else {
            try? await Task.sleep(for: .milliseconds(min(3200, 400 + words.count * 45)))
            return
        }
        if let url = Bundle.main.url(forResource: Self.fileName(text), withExtension: "mp3"),
           let p = try? AVAudioPlayer(contentsOf: url) {
            p.delegate = self
            player = p
            await withCheckedContinuation { c in
                continuation = c
                if !p.play() { resumeWaiting() }
            }
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

    /// 一句接一句读；中途被别的话打断就停下
    func speak(_ lines: [String]) async {
        stop()
        let g = generation
        for line in lines {
            if Task.isCancelled || g != generation { return }
            await play(line)
        }
    }

    func say(_ lines: [String]) {
        Task { await speak(lines) }
    }

    private func resumeWaiting() {
        continuation?.resume()
        continuation = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard p === self.player else { return }
            self.player = nil
            self.resumeWaiting()
        }
    }

    func stop() {
        generation += 1
        halt()
    }

    /// 停下正在读的这一句（不打断连读）
    private func halt() {
        player?.stop()
        player = nil
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
