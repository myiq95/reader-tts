
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
                                // 중앙 큰 읽기 버튼 - 여기 있어요!
                                Button(action: { tts.isSpeaking ? tts.pause() : playCurrent() }){
                                    HStack(spacing:10){
                                        Image(systemName: tts.isSpeaking ? "pause.fill" : "play.fill")
                                        Text(tts.isSpeaking ? "일시정지" : "여기서부터 읽기 시작")
                                            .font(.system(size:16, weight:.bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal,22)
                                    .padding(.vertical,12)
                                    .background(Color(red:0.17,green:0.17,blue:0.16))
                                    .clipShape(Capsule())
                                    .shadow(radius:4)
                                }.padding(.top,8).frame(maxWidth:.infinity)
                            } else {
                                emptyView
                            }
                            Color.clear.frame(height:200)
                        }
                    }
                    .onChange(of: tts.currentRange){ _ in
                        guard let r = tts.currentRange else { return }
                        if r.location % 300 < 15 {
                            withAnimation(.easeOut(duration:0.5)){
                                proxy.scrollTo("pos_\(r.location/300)", anchor: .top)
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
                        Label("파일 열기", systemImage:"folder.badge.plus").font(.body.bold())
                    }
                }
                ToolbarItem(placement:.navigationBarTrailing){
                    HStack(spacing:12){
                        Button(action:{showTOC=true}){ Image(systemName:"list.bullet") }
                        Menu{
                            Button("작게"){ fontSize=max(14,fontSize-1) }
                            Button("크게"){ fontSize=min(30,fontSize+1) }
                            Divider()
                            Button("느리게"){ tts.rate=0.42 }
                            Button("보통"){ tts.rate=0.50 }
                            Button("빠르게"){ tts.rate=0.58 }
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
            Button(action:{showPicker=true}){
                Text("파일 선택하기").bold().padding(.horizontal,20).padding(.vertical,10).background(Color.black).foregroundColor(.white).clipShape(Capsule())
            }.padding(.top,8)
        }.padding(60).frame(maxWidth:.infinity).padding(.top,80)
    }
    
    var highlightedTextView: some View {
        let nsText = text as NSString
        var attr = AttributedString(text)
        if let r = tts.currentRange, r.location != NSNotFound {
            if let swiftRange = Range(r, in: text) {
                if let s = AttributedString.Index(swiftRange.lowerBound, within: attr),
                   let e = AttributedString.Index(swiftRange.upperBound, within: attr) {
                    attr[s..<e].backgroundColor = Color.yellow
                    attr[s..<e].foregroundColor = Color.black
                }
            }
            let para = nsText.paragraphRange(for: r)
            if let pr = Range(para, in: text),
               let s = AttributedString.Index(pr.lowerBound, within: attr),
               let e = AttributedString.Index(pr.upperBound, within: attr) {
                attr[s..<e].backgroundColor = Color.yellow.opacity(0.22)
            }
        }
        return Text(attr).font(.system(size: fontSize, design:.serif)).lineSpacing(9).textSelection(.enabled)
    }
    
    var bottomPlayer: some View {
        VStack(spacing:0){
            if !chapters.isEmpty {
                HStack{
                    Text("\(currentChapterIdx+1)/\(chapters.count)").font(.caption2.bold()).padding(6).background(Color.black.opacity(0.06)).clipShape(Capsule())
                    Text(chapters[currentChapterIdx].title).font(.caption).lineLimit(1)
                    Spacer()
                    Button(action:prev){ Image(systemName:"chevron.left") }
                    Button(action:next){ Image(systemName:"chevron.right") }
                }.padding(.horizontal,16).frame(height:36).background(.ultraThinMaterial)
            }
            HStack(spacing:14){
                Button(action:{ tts.isSpeaking ? tts.pause() : (tts.isSpeaking ? tts.resume() : playCurrent()) }){
                    Image(systemName: tts.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size:42)).foregroundColor(.black)
                }
                VStack(alignment:.leading, spacing:2){
                    Text(fileName).font(.caption.bold()).lineLimit(1)
                    Text(tts.currentChapter.isEmpty ? (tts.isSpeaking ? "읽는 중..." : "읽기 준비 완료") : tts.currentChapter).font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Button(action:{ tts.stop() }){ Image(systemName:"stop.fill").foregroundColor(.secondary) }
            }.padding(14).background(Color(.systemBackground)).shadow(color:.black.opacity(0.08), radius:12, y:-4)
        }
    }
    
    func playCurrent(){
        if chapters.isEmpty {
            tts.speak(text, title: fileName, chapter: "전체")
        } else {
            tts.speakChapter(at: currentChapterIdx, chapters: chapters, fullText: text, fileName: fileName)
        }
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
            if seen.contains(t){continue}
            if t.range(of:"^(제\\s*\\d+|\\d+\\s*[장화막]|프롤로그|에필로그|Chapter)", options:.regularExpression) != nil {
                res.append((UUID().uuidString,t,i)); seen.insert(t)
            }
        }
        if res.isEmpty {
            let paras = txt.components(separatedBy:"\n\n").filter{ $0.trimmingCharacters(in:.whitespaces).count>20 }
            let chunk = max(10, paras.count/16)
            for i in stride(from:0,to:paras.count,by:chunk){
                let preview = String(paras[i].prefix(22)).replacingOccurrences(of:"\n",with:" ")
                let chapterNum = i / chunk + 1
                res.append((UUID().uuidString,"\(chapterNum). \(preview)...", i))
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
            }}.navigationTitle("목차")
        }
    }
}
