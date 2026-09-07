
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var text = ""
    @State private var chapters: [(id:String, title:String, offset:Int)] = []
    @State private var fileName = "파일을 선택하세요"
    @StateObject private var tts = TTSManager.shared
    @State private var showPicker = false
    @State private var fontSize: CGFloat = 18
    @State private var currentChapterIdx = 0
    @State private var showTOC = false
    
    var body: some View {
        NavigationView {
            VStack(spacing:0) {
                ScrollView {
                    VStack(alignment:.leading, spacing:16) {
                        if !text.isEmpty {
                            Text(attributedText).font(.system(size: fontSize, design:.serif)).lineSpacing(8).padding(.horizontal,16).textSelection(.enabled)
                        } else {
                            VStack(spacing:12){
                                Image(systemName:"book.closed").font(.system(size:48)).foregroundColor(.secondary)
                                Text("폴더 아이콘으로\n.txt .md 파일을 여세요").multilineTextAlignment(.center).foregroundColor(.secondary)
                                Text("모험 없는 스마샤 같은 한글 소설 자동 인코딩 지원").font(.caption).foregroundColor(.secondary)
                            }.padding(60)
                        }
                    }.padding(.bottom,160)
                }
                
                // Chapter indicator
                if !chapters.isEmpty {
                    HStack{
                        Text("\(currentChapterIdx+1)/\(chapters.count) • \(chapters[currentChapterIdx].title.prefix(20))").font(.caption).lineLimit(1)
                        Spacer()
                        Button(action:prev){ Image(systemName:"backward.fill") }
                        Button(action:next){ Image(systemName:"forward.fill") }
                    }.padding(.horizontal).frame(height:32).background(.thinMaterial)
                }
                
                // TTS Bar with lock screen info
                VStack(spacing:8){
                    HStack(spacing:16){
                        Button(action:{ tts.isSpeaking ? tts.pause() : (tts.fullText.isEmpty ? playCurrent() : tts.resume()) }){
                            Image(systemName: tts.isSpeaking ? "pause.circle.fill" : "play.circle.fill").font(.system(size:36))
                        }
                        VStack(alignment:.leading){
                            Text(fileName).font(.caption).bold().lineLimit(1)
                            Text(tts.currentChapter).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Menu {
                            Button("느리게"){ tts.rate=0.42 }
                            Button("보통"){ tts.rate=0.52 }
                            Button("빠르게"){ tts.rate=0.62 }
                            Divider()
                            Button("한국어"){ tts.voiceLang="ko-KR" }
                            Button("영어"){ tts.voiceLang="en-US" }
                            Divider()
                            Button("정지"){ tts.stop() }
                        } label:{ Image(systemName:"ellipsis.circle").font(.title3) }
                    }
                    if tts.isSpeaking { ProgressView().tint(.black) }
                }.padding().background(Color(.systemBackground)).shadow(radius:6)
                
                // Bottom TOC bar
                HStack{
                    Text(chapters.isEmpty ? "자동 구분 (단락 기준)" : "목차 \(chapters.count)개").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Button("목차 열기"){ showTOC=true }
                }.padding(.horizontal).frame(height:44).background(.ultraThinMaterial)
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.navigationBarLeading){ Button(action:{showPicker=true}){ Image(systemName:"folder.badge.plus") } }
                ToolbarItem(placement:.navigationBarTrailing){
                    Menu{
                        Button("글자 작게"){ fontSize=max(12,fontSize-1) }
                        Button("글자 크게"){ fontSize=min(28,fontSize+1) }
                    } label:{ Image(systemName:"textformat.size") }
                }
            }
            .sheet(isPresented:$showPicker){ DocumentPicker { url, content in
                self.fileName = url.lastPathComponent
                self.text = content
                self.chapters = Self.makeChapters(from: content)
                self.currentChapterIdx = 0
                if !content.isEmpty {
                    tts.fullText = content
                    tts.updateNowPlaying(title: url.lastPathComponent, chapter: chapters.first?.title ?? "시작")
                }
            }}
            .sheet(isPresented:$showTOC){ TOCSheet(chapters:chapters, currentIdx:currentChapterIdx){ idx in
                currentChapterIdx = idx
                playCurrent()
                showTOC=false
            }}
            .onReceive(NotificationCenter.default.publisher(for: .nextChapter)){ _ in next() }
            .onReceive(NotificationCenter.default.publisher(for: .prevChapter)){ _ in prev() }
            .onReceive(NotificationCenter.default.publisher(for: .ttsFinished)){ _ in
                // auto play next chapter
                if currentChapterIdx+1 < chapters.count { next() }
            }
        }
    }
    
    func playCurrent(){
        guard !chapters.isEmpty else { tts.speak(text, title: fileName, chapter: "전체"); return }
        tts.speakChapter(at: currentChapterIdx, chapters: chapters, fullText: text, fileName: fileName)
    }
    func next(){ if currentChapterIdx+1 < chapters.count { currentChapterIdx+=1; playCurrent() } }
    func prev(){ if currentChapterIdx>0 { currentChapterIdx-=1; playCurrent() } }
    
    var attributedText: AttributedString {
        var attr = AttributedString(text)
        if let r = tts.currentRange, r.location+ r.length < text.count {
            if let s = attr.index(attr.startIndex, offsetByCharacters: r.location, limitedBy: attr.endIndex),
               let e = attr.index(s, offsetByCharacters: r.length, limitedBy: attr.endIndex){
                attr[s..<e].backgroundColor = .yellow
                attr[s..<e].foregroundColor = .black
            }
        }
        return attr
    }
    
    static func makeChapters(from txt:String)->[(id:String,title:String,offset:Int)]{
        var res:[(String,String,Int)]=[]
        let lines = txt.components(separatedBy: .newlines)
        var seen = Set<String>()
        for (i,line) in lines.enumerated(){
            let t = line.trimmingCharacters(in:.whitespaces)
            if t.count<2||t.count>40 {continue}
            if t.hasPrefix("\"")||t.hasPrefix("'")||t.hasPrefix("“")||t.hasPrefix("”")||t.hasPrefix("—")||t.hasPrefix("-"){continue}
            if t.hasPrefix("자,")||t.hasPrefix("아,")||t.hasPrefix("어,")||t.hasPrefix("네,")||t.hasPrefix("그래,"){continue}
            if t.contains("\"") && t.count>10 {continue}
            if t.range(of:"[요까네]\s*[\"”’]$", options:.regularExpression) != nil {continue}
            if seen.contains(t){continue}
            if t.range(of:"^(제\\s*\\d+\\s*[장화막]|\\d+\\s*[장화막]|프롤로그|에필로그|외전|후기|서문|Chapter)", options:.regularExpression) != nil {
                res.append((UUID().uuidString,t,i)); seen.insert(t)
            } else if t.count<=20 && !t.contains(".") && !t.contains("?") && !t.contains("!") {
                let prev = i>0 ? lines[i-1].trimmingCharacters(in:.whitespaces) : ""
                let next = i+1<lines.count ? lines[i+1].trimmingCharacters(in:.whitespaces) : ""
                if prev.isEmpty && next.isEmpty {
                    let cnt = txt.components(separatedBy:t).count-1
                    if cnt<=2 { res.append((UUID().uuidString,t,i)); seen.insert(t) }
                }
            }
        }
        if res.isEmpty {
            let paras = txt.components(separatedBy:"\n\n").filter{ $0.trimmingCharacters(in:.whitespaces).count>20 }
            let n = paras.count
            let chunk = max(10, n/18)
            var idx=0
            for i in stride(from:0,to:n,by:chunk){
                let preview = String(paras[i].prefix(25)).replacingOccurrences(of:"\n",with:" ")
                let lineIdx = txt.components(separatedBy:"\n\n").firstIndex(of:paras[i]) ?? 0
                res.append((UUID().uuidString,"\(idx+1). \(preview)...", lineIdx))
                idx+=1
            }
        }
        return res
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL,String)->Void
    func makeUIViewController(context:Context)->UIDocumentPickerViewController{
        let p = UIDocumentPickerViewController(forOpeningContentTypes:[.plainText,.text,UTType(filenameExtension:"md")!,UTType(filenameExtension:"docx")!,UTType.pdf,UTType(filenameExtension:"epub")!,UTType.rtf,UTType.html], asCopy:true)
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context:Context){}
    func makeCoordinator()->Coordinator{Coordinator(onPick:onPick)}
    class Coordinator:NSObject,UIDocumentPickerDelegate{
        var onPick:(URL,String)->Void
        init(onPick:@escaping (URL,String)->Void){self.onPick=onPick}
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]){
            guard let url=urls.first else {return}
            var txt=""
            for enc in [String.Encoding.utf8, .windowsCP949, .eucKR]{
                if let s = try? String(contentsOf:url, encoding:enc){ txt=s; break }
            }
            if txt.isEmpty { txt = (try? String(contentsOf:url)) ?? "" }
            onPick(url,txt)
        }
    }
}

struct TOCSheet: View {
    var chapters:[(id:String,title:String,offset:Int)]
    var currentIdx:Int
    var onSelect:(Int)->Void
    var body: some View {
        NavigationView{
            List{
                ForEach(Array(chapters.enumerated()), id:\.element.id){ idx,ch in
                    HStack{
                        Text(ch.title).font(idx==currentIdx ? .headline : .body)
                        if idx==currentIdx { Spacer(); Image(systemName:"speaker.wave.2.fill") }
                    }.contentShape(Rectangle()).onTapGesture{ onSelect(idx) }
                }
            }.navigationTitle("목차 - \(chapters.count)개 (단락 기반)")
        }
    }
}
