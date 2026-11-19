import AVFoundation
import CryptoKit

/// 预先录好的配音（Codex 用高质量神经网络语音生成，放在 Voice 文件夹里）。
/// 文件名是文字的哈希：vo_<sha1 前 10 位>.mp3，改了文字就要重新生成那一句。
/// 找不到录音时，退回系统自带的中文语音，保证每句话都能读出来。
@MainActor
final class VoiceOver: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    static let shared = VoiceOver()
    static let enabledKey = "tutor.voice"

    private var player: AVAudioPlayer?
    private let synth = AVSpeechSynthesizer()
    private var current: AVSpeechUtterance?
    private var continuation: CheckedContinuation<Void, Never>?
    private lazy var fallbackVoice: AVSpeechSynthesisVoice? = {
        let zh = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "zh-CN" }
        return zh.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "zh-CN")
    }()

    override private init() {
        super.init()
        synth.delegate = self
    }

    var enabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    nonisolated static func fileName(_ text: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(text.utf8))
        return "vo_" + digest.map { String(format: "%02x", $0) }.joined().prefix(10)
    }

    static func hasRecording(_ text: String) -> Bool {
        Bundle.main.url(forResource: fileName(text), withExtension: "mp3") != nil
    }

    /// 读一句，读完才返回
    func speak(_ text: String) async {
        stop()
        guard enabled, !text.isEmpty else { return }
        if let url = Bundle.main.url(forResource: Self.fileName(text), withExtension: "mp3"),
           let p = try? AVAudioPlayer(contentsOf: url) {
            p.delegate = self
            player = p
            await withCheckedContinuation { c in
                continuation = c
                if !p.play() { finish() }
            }
            return
        }
        let u = AVSpeechUtterance(string: text)
        u.voice = fallbackVoice
        u.rate = 0.47
        u.pitchMultiplier = 1.08
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
        player?.stop()
        player = nil
        current = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        finish()
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard p === self.player else { return }
            self.player = nil
            self.finish()
        }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in if u === self.current { self.current = nil; self.finish() } }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in if u === self.current { self.current = nil; self.finish() } }
    }
}
