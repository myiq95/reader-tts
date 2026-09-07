
import AVFoundation
import MediaPlayer

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    private let synth = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var currentRange: NSRange?
    @Published var rate: Float = 0.50
    @Published var voiceLang = "ko-KR"
    @Published var currentTitle = "책 뷰어"
    @Published var currentChapter = ""
    var fullText = ""
    var currentChapterIndex = 0
    private var utteranceStartTime: Date?
    private var totalChars: Int = 0
    
    override init() {
        super.init()
        synth.delegate = self
        setupAudio()
        setupRemote()
    }
    func setupAudio(){
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowAirPlay])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    func setupRemote(){
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { _ in self.resume(); return .success }
        c.pauseCommand.addTarget { _ in self.pause(); return .success }
        c.nextTrackCommand.addTarget { _ in self.nextChapter(); return .success }
        c.previousTrackCommand.addTarget { _ in self.prevChapter(); return .success }
    }
    func updateNowPlaying(title: String, chapter: String, progress: Double = 0){
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: chapter,
            MPNowPlayingInfoPropertyPlaybackRate: isSpeaking ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress
        ]
    }
    func speak(_ text: String, title: String, chapter: String){
        fullText = text
        stop()
        totalChars = (text as NSString).length
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: voiceLang) ?? AVSpeechSynthesisVoice(language: "ko-KR")
        u.rate = rate
        u.pitchMultiplier = 1.05
        u.postUtteranceDelay = 0.15
        utteranceStartTime = Date()
        updateNowPlaying(title: title, chapter: chapter)
        synth.speak(u)
        isSpeaking = true
    }
    func speakChapter(at index: Int, chapters: [(id:String,title:String,offset:Int)], fullText: String, fileName: String){
        guard index>=0 && index<chapters.count else { return }
        currentChapterIndex = index
        let lines = fullText.components(separatedBy: .newlines)
        let s = chapters[index].offset
        let e = index+1<chapters.count ? chapters[index+1].offset : lines.count
        let chunk = lines[max(0,s)..<min(e,lines.count)].joined(separator: "\n")
        speak(chunk.isEmpty ? fullText : chunk, title: fileName, chapter: chapters[index].title)
    }
    func pause(){ synth.pauseSpeaking(at: .word); isSpeaking = false }
    func resume(){ synth.continueSpeaking(); isSpeaking = true }
    func stop(){ synth.stopSpeaking(at: .immediate); isSpeaking = false; currentRange = nil }
    func nextChapter(){ NotificationCenter.default.post(name: .nextChapter, object: nil) }
    func prevChapter(){ NotificationCenter.default.post(name: .prevChapter, object: nil) }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance){
        DispatchQueue.main.async {
            self.currentRange = range
            let progress = self.totalChars>0 ? Double(range.location)/Double(self.totalChars) : 0
            self.updateNowPlaying(title: self.currentTitle, chapter: self.currentChapter, progress: progress)
        }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance){
        DispatchQueue.main.async { self.isSpeaking = false; self.currentRange = nil; NotificationCenter.default.post(name: .ttsFinished, object: nil) }
    }
}
extension Notification.Name {
    static let nextChapter = Notification.Name("nextChapter")
    static let prevChapter = Notification.Name("prevChapter")
    static let ttsFinished = Notification.Name("ttsFinished")
}
