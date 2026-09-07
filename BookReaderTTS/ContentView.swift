
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var text = ""
    @State private var chapters: [(id:String,title:String,offset:Int)] = []
    @State private var fileName = "파일을 선택하세요"
    @StateObject private var tts = TTSManager.shared
    @State private var showPicker = false
    @State private var fontSize: CGFloat = 19
    @State private var currentChapterIdx = 0
    @State private var showTOC = false
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        NavigationView {
            ZStack(alignment:.bottom){
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment:.leading, spacing:20){
                            if !text.isEmpty {
                                highlightedTextView
                                    .padding(.horizontal,18)
                                    .padding(.top,12)
                            } else {
                                emptyView
                            }
                            Color.clear.frame(height:180)
                        }
                    }
                    .onAppear{ scrollProxy = proxy }
                    .onChange(of: tts.currentRange){ _ in
                        guard let r = tts.currentRange else { return }
                        // auto scroll to reading position
                        let loc = r.location
                        if loc % 400 < 20 {
                            withAnimation(.easeOut(duration:0.6)){
                                proxy.scrollTo("reading_\(loc/400)", anchor: .top)
                            }
                        }
                    }
                }
                bottomPlayer
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.navigationBarLeading){
                    Button(action:{showPicker=true}){
                        Image(systemName:"folder.badge.plus").font(.body.bold())
                    }
                }
                ToolbarItem(placement:.navigationBarTrailing){
                    HStack(spacing:12){
                        Button(action:{showTOC=true}){ Image(systemName:"list.bullet") }
                        Menu{
                            Button("작게"){ fontSize=max(14,fontSize-1) }
                            Button("크게"){ fontSize=min(30,fontSize+1) }
                            Divider()
                            Button("느리게 (0.42)"){ tts.rate=0.42 }
                            Button("보통 (0.50)"){ tts.rate=0.50 }
                            Button("빠르게 (0.58)"){ tts.rate=0.58 }
                        } label:{ Image(systemName:"textformat.size") }
                    }
                }
            }
            .sheet(isPresented:$showPicker){ DocumentPicker{ url, content in
                fileName = url.lastPathComponent
                text = content
                chapters = Self.makeChapters(from: content)
                currentChapterIdx = 0
                tts.fullText = content
                tts.updateNowPlaying(title: url.lastPathComponent, chapter: chapters.first?.title ?? "시작")
            }}
            .sheet(isPresented:$showTOC){ TOCSheet(chapters:chapters, currentIdx:currentChapterIdx){ idx in
                currentChapterIdx = idx
                playCurrent()
                showTOC=false
            }}
            .onReceive(NotificationCenter.default.publisher(for: .nextChapter)){ _ in next() }
            .onReceive(NotificationCenter.default.publisher(for: .prevChapter)){ _ in prev() }
            .onReceive(NotificationCenter.default.publisher(for: .ttsFinished)){ _ in
                if currentChapterIdx+1 < chapters.count { next() }
            }
        }
    }
    
    var emptyView: some View {
        VStack(spacing:16){
            Image(systemName:"books.vertical").font(.system(size:54)).foregroundColor(Color(red:0.17,green:0.17,blue:0.16))
            Text("폴더 아이콘으로\n책 파일을 열어보세요").multilineTextAlignment(.center).foregroundColor(.secondary).font(.system(size:16, weight:.medium, design:.serif))
            Text("txt · md · docx · pdf · epub").font(.caption).foregroundColor(.secondary.opacity(0.7))
        }.padding(60).frame(maxWidth:.infinity).padding(.top,80)
    }
    
    // 핵심 수정: UTF16 NSRange를 Swift String.Index로 정확 변환
    var highlightedTextView: some View {
        let nsText = text as NSString
        var attr = AttributedString(text)
        
        if let r = tts.currentRange, r.location != NSNotFound {
            // NSRange -> Swift Range 정확한 변환 (한글 자모, 이모지 대응)
            if let swiftRange = Range(r, in: text) {
                let start = AttributedString.Index(swiftRange.lowerBound, within: attr)
                let end = AttributedString.Index(swiftRange.upperBound, within: attr)
                if let s = start, let e = end {
                    attr[s..<e].backgroundColor = Color.yellow.opacity(0.9)
                    attr[s..<e].foregroundColor = Color.black
                }
            }
            // 문장 단위 살짝 넓게 하이라이트 (읽기 편하게)
            let sentenceRange = nsText.paragraphRange(for: r)
            if let sRange = Range(sentenceRange, in: text) {
                let s = AttributedString.Index(sRange.lowerBound, within: attr)
                let e = AttributedString.Index(sRange.upperBound, within: attr)
                if let ss = s, let ee = e {
                    attr[ss..<ee].backgroundColor = Color.yellow.opacity(0.25)
                }
            }
        }
        return Text(attr).font(.system(size: fontSize, weight:.regular, design:.serif)).lineSpacing(9).textSelection(.enabled)
    }
    
    var bottomPlayer: some View {
        VStack(spacing:0){
            if !chapters.isEmpty {
                HStack{
                    Text("\(currentChapterIdx+1)/\(chapters.count)").font(.caption2.bold()).padding(.horizontal,8).padding(.vertical,4).background(Color.black.opacity(0.07)).clipShape(Capsule())
                    Text(chapters[currentChapterIdx].title).font(.caption).lineLimit(1)
                    Spacer()
                    Button(action:prev){ Image(systemName:"chevron.left") }
                    Button(action:next){ Image(systemName:"chevron.right") }
                }.padding(.horizontal,16).frame(height:36).background(.ultraThinMaterial)
            }
            VStack(spacing:10){
                HStack(spacing:14){
                    Button(action:{ tts.isSpeaking ? tts.pause() : (tts.fullText.isEmpty ? playCurrent() : tts.resume()) }){
                        Image(systemName: tts.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size:40)).foregroundColor(Color(red:0.17,green:0.17,blue:0.16))
                    }
                    VStack(alignment:.leading, spacing:2){
                        Text(fileName).font(.system(size:13, weight:.bold)).lineLimit(1)
                        Text(tts.currentChapter.isEmpty ? "대기 중" : tts.currentChapter).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                        if tts.isSpeaking {
                            HStack(spacing:3){
                                ForEach(0..<3){ i in
                                    RoundedRectangle(cornerRadius:1).frame(width:2, height:8).opacity(0.6)
                                        .animation(.easeInOut(duration:0.4).repeatForever().delay(Double(i)*0.15), value: tts.isSpeaking)
                                }
                            }
                        }
                    }
                    Spacer()
                    Button(action:{ tts.stop() }){ Image(systemName:"stop.circle").font(.title3).foregroundColor(.secondary) }
                }
                if tts.isSpeaking {
                    GeometryReader{ geo in
                        let progress = tts.currentRange.map{ Double($0.location)/Double(max(1,(text as NSString).length)) } ?? 0
                        ZStack(alignment:.leading){
                            Capsule().fill(Color.black.opacity(0.08)).frame(height:4)
                            Capsule().fill(Color(red:0.17,green:0.17,blue:0.16)).frame(width: geo.size.width*progress, height:4)
                                .animation(.linear(duration:0.2), value: progress)
                        }
                    }.frame(height:4)
                }
            }.padding(14).background(Color(.systemBackground)).shadow(color:.black.opacity(0.08), radius:12, y:-4)
        }
    }
    
    func playCurrent(){
        guard !chapters.isEmpty else { tts.speak(text, title: fileName, chapter: "전체"); return }
        tts.speakChapter(at: currentChapterIdx, chapters: chapters, fullText: text, fileName: fileName)
    }
    func next(){ if currentChapterIdx+1 < chapters.count { currentChapterIdx+=1; playCurrent() } }
    func prev(){ if currentChapterIdx>0 { currentChapterIdx-=1; playCurrent() } }
    
    static func makeChapters(from txt:String)->[(id:String,title:String,offset:Int)]{
        var res:[(String,String,Int)]=[]
        let lines = txt.components(separatedBy: .newlines)
        var seen = Set<String>()
        for (i,line) in lines.enumerated(){
            let t = line.trimmingCharacters(in:.whitespaces)
            if t.count<2||t.count>40 {continue}
            if t.hasPrefix("\"")||t.hasPrefix("'")||t.hasPrefix("“")||t.hasPrefix("”")||t.hasPrefix("—"){continue}
            if t.hasPrefix("자,")||t.hasPrefix("아,")||t.hasPrefix("어,")||t.hasPrefix("네,"){continue}
            if seen.contains(t){continue}
            if t.range(of:"^(제\\s*\\d+\\s*[장화막]|\\d+\\s*[장화막]|프롤로그|에필로그|외전|후기|서문|Chapter)", options:.regularExpression) != nil {
                res.append((UUID().uuidString,t,i)); seen.insert(t)
            }
        }
        if res.isEmpty {
            let paras = txt.components(separatedBy:"\n\n").filter{ $0.trimmingCharacters(in:.whitespaces).count>20 }
            let chunk = max(12, paras.count/16)
            var idx=0
            for i in stride(from:0,to:paras.count,by:chunk){
                let preview = String(paras[i].prefix(25)).replacingOccurrences(of:"\n",with:" ")
                res.append((UUID().uuidString,"\(idx+1). \(preview)...", i))
                idx+=1
            }
        }
        return res
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL,String)->Void
    func makeUIViewController(context:Context)->UIDocumentPickerViewController{
        let types: [UTType] = [.plainText, .text, .pdf, .rtf, .html, UTType(filenameExtension:"md")!, UTType(filenameExtension:"docx")!, UTType(filenameExtension:"epub")!].compactMap{$0}
        let p = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy:true)
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
            let txt = BookParser.parse(url: url)
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
            List{ ForEach(Array(chapters.enumerated()), id:\.element.id){ idx,ch in
                HStack{
                    Text(ch.title).font(idx==currentIdx ? .headline : .body)
                    if idx==currentIdx { Spacer(); Image(systemName:"speaker.wave.2.fill") }
                }.contentShape(Rectangle()).onTapGesture{ onSelect(idx) }
            }}.navigationTitle("목차 - \(chapters.count)개")
        }
    }
}
