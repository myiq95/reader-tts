
import AVFoundation
import MediaPlayer

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = TTSManager()
    private let synth = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    @Published var currentRange: NSRange? // 이건 항상 전체 문서 기준
    @Published var rate: Float = 0.50
    @Published var voiceLang = "ko-KR"
    @Published var currentTitle = "책 뷰어"
    @Published var currentChapter = ""
    var fullText = ""
    var currentChapterIndex = 0
    private var chunkBaseOffset = 0 // 조각이 전체에서 시작하는 위치 (UTF16 offset)

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
    func updateNowPlaying(title: String, chapter: String){
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: chapter,
            MPNowPlayingInfoPropertyPlaybackRate: isSpeaking ? 1.0 : 0.0
        ]
    }
    func speak(_ text: String, title: String, chapter: String, baseOffset: Int = 0){
        fullText = text // 전체 문서 유지
        chunkBaseOffset = baseOffset
        stopInternal()
        let chunk = baseOffset==0 ? text : String((text as NSString).substring(from: baseOffset).prefix(100000))
        // baseOffset이 있으면 전체에서 잘라낸 텍스트가 chunk, 없으면 전체
        let speakText: String
        if baseOffset==0 {
            speakText = text
            self.fullText = text
        } else {
            // fullText는 그대로 두고, speakText는 잘라낸 부분
            speakText = String((text as NSString).substring(from: baseOffset).prefix(200000) as String)
            // 실제로는 fullText를 유지하고 speak만 chunk
        }
        // 정확한 구현: fullText는 전체, speak는 부분
        let actualSpeak = baseOffset==0 ? text : (text as NSString).substring(with: NSRange(location: baseOffset, length: min((text as NSString).length - baseOffset, 200000)))
        let u = AVSpeechUtterance(string: actualSpeak)
        u.voice = AVSpeechSynthesisVoice(language: voiceLang) ?? AVSpeechSynthesisVoice(language: "ko-KR")
        u.rate = rate
        u.pitchMultiplier = 1.05
        updateNowPlaying(title: title, chapter: chapter)
        synth.speak(u)
        isSpeaking = true
    }
    // 전체 문서 + 챕터 오프셋 기반으로 읽기
    func speakChapter(at index: Int, chapters: [(id:String,title:String,offset:Int)], fullText: String, fileName: String){
        guard index>=0 && index<chapters.count else { return }
        currentChapterIndex = index
        self.fullText = fullText
        // lines 기준 offset을 문자 offset으로 변환
        let lines = fullText.components(separatedBy: .newlines)
        let startLine = chapters[index].offset
        let endLine = index+1<chapters.count ? chapters[index+1].offset : lines.count
        let safeStart = max(0, min(startLine, lines.count-1))
        let safeEnd = max(safeStart, min(endLine, lines.count))
        // 문자 offset 계산
        let nsFull = fullText as NSString
        var charOffset = 0
        if safeStart>0 {
            let prefix = lines[0..<safeStart].joined(separator: "\n")
            charOffset = (prefix as NSString).length + 1 // + \n
        }
        // 경계 보정: 실제 prefix가 fullText에서 어디서 시작하는지 정확히 찾기 위해 lines로 누적
        var accumulated = 0
        for i in 0..<safeStart {
            accumulated += (lines[i] as NSString).length + 1
        }
        charOffset = accumulated
        chunkBaseOffset = charOffset
        let chunkLines = lines[safeStart..<safeEnd].joined(separator: "\n")
        let chunk = chunkLines.isEmpty ? fullText : chunkLines
        stopInternal()
        let u = AVSpeechUtterance(string: chunk)
        u.voice = AVSpeechSynthesisVoice(language: voiceLang) ?? AVSpeechSynthesisVoice(language: "ko-KR")
        u.rate = rate
        u.pitchMultiplier = 1.05
        currentTitle = fileName
        currentChapter = chapters[index].title
        updateNowPlaying(title: fileName, chapter: chapters[index].title)
        synth.speak(u)
        isSpeaking = true
    }
    func speakFull(_ full: String, title: String){
        fullText = full
        chunkBaseOffset = 0
        stopInternal()
        let u = AVSpeechUtterance(string: full)
        u.voice = AVSpeechSynthesisVoice(language: voiceLang) ?? AVSpeechSynthesisVoice(language: "ko-KR")
        u.rate = rate
        u.pitchMultiplier = 1.05
        updateNowPlaying(title: title, chapter: "전체")
        synth.speak(u)
        isSpeaking = true
    }
    private func stopInternal(){ synth.stopSpeaking(at: .immediate) }
    func pause(){ synth.pauseSpeaking(at: .word); isSpeaking = false }
    func resume(){ synth.continueSpeaking(); isSpeaking = true }
    func stop(){ synth.stopSpeaking(at: .immediate); isSpeaking = false; currentRange = nil }
    func nextChapter(){ NotificationCenter.default.post(name: .nextChapter, object: nil) }
    func prevChapter(){ NotificationCenter.default.post(name: .prevChapter, object: nil) }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance){
        DispatchQueue.main.async {
            // range는 chunk 기준, 전체 기준으로는 base + range
            let global = NSRange(location: self.chunkBaseOffset + range.location, length: range.length)
            self.currentRange = global
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
