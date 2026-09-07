
import AVFoundation
import MediaPlayer

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    private let synth = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var currentRange: NSRange?
    @Published var rate: Float = 0.50
    @Published var voiceLang = "ko-KR"
    var fullText = ""
    var currentChapterIndex = 0
    private var chunkBaseOffset = 0

    override init() {
        super.init()
        synth.delegate = self
        setupAudio()
        setupRemote()
    }
    func setupAudio(){
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    func setupRemote(){
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { _ in self.resume(); return .success }
        c.pauseCommand.addTarget { _ in self.pause(); return .success }
        c.nextTrackCommand.addTarget { _ in self.nextChapter(); return .success }
        c.previousTrackCommand.addTarget { _ in self.prevChapter(); return .success }
    }
    func updateNowPlaying(title: String, chapter: String){
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: chapter,
            MPNowPlayingInfoPropertyPlaybackRate: isSpeaking ? 1.0 : 0.0
        ]
    }
    func speakFull(_ full: String, title: String){
        fullText = full
        chunkBaseOffset = 0
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: full)
        u.voice = AVSpeechSynthesisVoice(language: voiceLang) ?? AVSpeechSynthesisVoice(language: "ko-KR")
        u.rate = rate
        u.pitchMultiplier = 1.05
        updateNowPlaying(title: title, chapter: "전체")
        synth.speak(u)
        isSpeaking = true
    }
    func speakChapter(at index: Int, chapters: [(id:String,title:String,offset:Int)], fullText: String, fileName: String){
        guard index>=0 && index<chapters.count else { return }
        currentChapterIndex = index
        self.fullText = fullText
        let lines = fullText.components(separatedBy: .newlines)
        let startLine = chapters[index].offset
        let endLine = index+1<chapters.count ? chapters[index+1].offset : lines.count
        let safeStart = max(0, min(startLine, lines.count-1))
        let safeEnd = max(safeStart, min(endLine, lines.count))
        var accumulated = 0
        for i in 0..<safeStart {
            accumulated += (lines[i] as NSString).length + 1
        }
        chunkBaseOffset = accumulated
        let chunkLines = lines[safeStart..<safeEnd].joined(separator: "\n")
        let chunk = chunkLines.isEmpty ? fullText : chunkLines
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: chunk)
        u.voice = AVSpeechSynthesisVoice(language: voiceLang) ?? AVSpeechSynthesisVoice(language: "ko-KR")
        u.rate = rate
        u.pitchMultiplier = 1.05
        updateNowPlaying(title: fileName, chapter: chapters[index].title)
        synth.speak(u)
        isSpeaking = true
    }
    func pause(){ synth.pauseSpeaking(at: .word); isSpeaking = false }
    func resume(){ synth.continueSpeaking(); isSpeaking = true }
    func stop(){ synth.stopSpeaking(at: .immediate); isSpeaking = false; currentRange = nil }
    func nextChapter(){ NotificationCenter.default.post(name: .nextChapter, object: nil) }
    func prevChapter(){ NotificationCenter.default.post(name: .prevChapter, object: nil) }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance){
        DispatchQueue.main.async {
            let global = NSRange(location: self.chunkBaseOffset + range.location, length: range.length)
            self.currentRange = global
        }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance){
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentRange = nil
            NotificationCenter.default.post(name: .ttsFinished, object: nil)
        }
    }
}
extension Notification.Name {
    static let nextChapter = Notification.Name("nextChapter")
    static let prevChapter = Notification.Name("prevChapter")
    static let ttsFinished = Notification.Name("ttsFinished")
}
