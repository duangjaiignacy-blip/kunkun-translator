import AVFoundation

final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String, lang: String? = nil) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let langCode = lang ?? SettingsStore.shared.englishAccent.langCode
        let utt = AVSpeechUtterance(string: text)
        utt.voice = pickVoice(for: langCode)
        utt.rate = Float(SettingsStore.shared.speechRate)
        utt.pitchMultiplier = 1.05
        utt.preUtteranceDelay = 0.1
        utt.postUtteranceDelay = 0.05
        synth.speak(utt)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    private func pickVoice(for langCode: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == langCode }

        if let premium = voices.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: langCode)
    }
}
