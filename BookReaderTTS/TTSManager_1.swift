
import AVFoundation
import MediaPlayer
import Combine

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    private let synth = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var currentRange: NSRange?
    @Published var rate: Float = 0.52
    @Published var voiceLang = "ko-KR"
    @Published var currentTitle = "책 뷰어"
    @Published var currentChapter = "재생 중"
    var fullText = ""
    var currentChapterIndex = 0
    
    override init() {
        super.init()
        synth.delegate = self
        setupAudio()
        setupRemoteCommands()
    }
    
    func setupAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowAirPlay])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in self.resume(); return .success }
        center.pauseCommand.addTarget { _ in self.pause(); return .success }
        center.stopCommand.addTarget { _ in self.stop(); return .success }
        center.nextTrackCommand.addTarget { _ in self.nextChapter(); return .success }
        center.previousTrackCommand.addTarget { _ in self.prevChapter(); return .success }
    }
    
    func updateNowPlaying(title: String, chapter: String) {
        currentTitle = title
        currentChapter = chapter
        var info: [String:Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: chapter,
            MPMediaItemPropertyAlbumTitle: "책 뷰어",
            MPNowPlayingInfoPropertyPlaybackRate: isSpeaking ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    func speak(_ text: String, title: String = "책", chapter: String = "") {
        fullText = text
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLang) ?? AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.2
        updateNowPlaying(title: title, chapter: chapter.isEmpty ? "재생 중" : chapter)
        synth.speak(utterance)
        isSpeaking = true
    }
    
    func speakChapter(at index: Int, chapters: [(id:String,title:String,offset:Int)], fullText: String, fileName: String) {
        guard index >= 0 && index < chapters.count else { return }
        currentChapterIndex = index
        let lines = fullText.components(separatedBy: .newlines)
        let startOffset = chapters[index].offset
        let endOffset = index+1 < chapters.count ? chapters[index+1].offset : lines.count
        let start = max(0, min(startOffset, lines.count-1))
        let end = max(start, min(endOffset, lines.count))
        let chunk = lines[start..<end].joined(separator: "\n")
        let actual = chunk.isEmpty ? fullText : chunk
        speak(actual, title: fileName, chapter: chapters[index].title)
    }
    
    func nextChapter() { NotificationCenter.default.post(name: .nextChapter, object: nil) }
    func prevChapter() { NotificationCenter.default.post(name: .prevChapter, object: nil) }
    func pause() { synth.pauseSpeaking(at: .immediate); isSpeaking = false }
    func resume() { synth.continueSpeaking(); isSpeaking = true }
    func stop() { synth.stopSpeaking(at: .immediate); isSpeaking = false }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.currentRange = range }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false; self.currentRange = nil; NotificationCenter.default.post(name: .ttsFinished, object: nil) }
    }
}

extension Notification.Name {
    static let nextChapter = Notification.Name("nextChapter")
    static let prevChapter = Notification.Name("prevChapter")
    static let ttsFinished = Notification.Name("ttsFinished")
}
