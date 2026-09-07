
import AVFoundation
import Combine

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    private let synth = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var currentRange: NSRange?
    @Published var rate: Float = 0.52 // 0.0~1.0
    @Published var voiceLang = "ko-KR"
    
    override init() {
        super.init()
        synth.delegate = self
        setupAudio()
    }
    
    func setupAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func speak(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLang) ?? AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.15
        synth.speak(utterance)
        isSpeaking = true
    }
    
    func pause() { synth.pauseSpeaking(at: .immediate); isSpeaking = false }
    func resume() { synth.continueSpeaking(); isSpeaking = true }
    func stop() { synth.stopSpeaking(at: .immediate); isSpeaking = false }
    
    // Highlight current spoken word
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.currentRange = range }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false; self.currentRange = nil }
    }
}
