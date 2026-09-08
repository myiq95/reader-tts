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
    @State private var autoScroll = true
    @State private var paragraphs: [(id:String, text:String, startOffset:Int)] = []
    @State private var currentPageStart = 0
    private let pageSize = 8

    var body: some View {
        NavigationView {
            ZStack(alignment:.bottom){
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment:.leading, spacing:12){
                            if text.isEmpty { emptyView }
                            else {
                                ForEach(Array(paragraphs.enumerated()), id:\.element.id) { idx, para in
                                    paragraphView(para: para).id("para-\(idx)").padding(.horizontal, 20)
                                }
                            }
                            Color.clear.frame(height:220).id("bottomSpacer")
                        }.padding(.top, 20)
                    }
                    .onChange(of: tts.currentRange) { newRange in
                        guard autoScroll, let r = newRange else { return }
                        guard let paraIdx = paragraphIndex(for: r.location) else { return }
                        if paraIdx >= currentPageStart + pageSize || paraIdx < currentPageStart {
                            let nextPageStart = (paraIdx / pageSize) * pageSize
                            currentPageStart = nextPageStart
                            withAnimation(.easeOut(duration: 0.6)) {
                                proxy.scrollTo("para-\(nextPageStart)", anchor: .top)
                            }
                        }
                    }
                }
                bottomPlayer
            }
            .navigationTitle(fileName).navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.navigationBarLeading){
                    Button(action:{showPicker=true}){ Image(systemName:"folder.badge.plus").font(.system(size:17, weight:.bold)) }
                }
                ToolbarItem(placement:.navigationBarTrailing){
                    HStack(spacing:14){
                        if !chapters.isEmpty { Button(action:{showTOC=true}){ Image(systemName:"list.bullet").foregroundColor(.blue) } }
                        Menu{
                            Button("작게"){ fontSize=max(14,fontSize-1) }
                            Button("크게"){ fontSize=min(28,fontSize+1) }
                            Divider()
                            Toggle(isOn: $autoScroll){ Label(autoScroll ? "페이지 자동 넘김 켜짐" : "꺼짐", systemImage: autoScroll ? "book.pages.fill" : "book.pages") }
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
                paragraphs = Self.makeParagraphs(from: content)
                currentPageStart = 0
                currentChapterIdx = 0
            }}
            .sheet(isPresented:$showTOC){ TOCSheet(chapters:chapters, currentIdx:currentChapterIdx){ idx in
                currentChapterIdx = idx
                currentPageStart = 0
                playCurrent()
                showTOC=false
            }}
            .onReceive(NotificationCenter.default.publisher(for: .nextChapter)){ _ in next() }
            .onReceive(NotificationCenter.default.publisher(for: .prevChapter)){ _ in prev() }
            .onReceive(NotificationCenter.default.publisher(for: .ttsFinished)){ _ in if currentChapterIdx+1 < chapters.count { next() } }
        }
    }

    func paragraphIndex(for globalOffset: Int) -> Int? {
        for (i, para) in paragraphs.enumerated() {
            let start = para.startOffset
            let end = start + (para.text as NSString).length
            if globalOffset >= start && globalOffset < end { return i }
        }
        return nil
    }

    func paragraphView(para: (id:String, text:String, startOffset:Int)) -> some View {
        let paraStart = para.startOffset
        let paraEnd = paraStart + (para.text as NSString).length
        var attr = AttributedString(para.text)
        if let r = tts.currentRange, r.location != NSNotFound {
            let overlapStart = max(r.location, paraStart)
            let overlapEnd = min(r.location + r.length, paraEnd)
            if overlapStart < overlapEnd {
                let localStart = overlapStart - paraStart
                let localEnd = overlapEnd - paraStart
                if let swiftRange = Range(NSRange(location: localStart, length: localEnd - localStart), in: para.text) {
                    if let s = AttributedString.Index(swiftRange.lowerBound, within: attr),
                       let e = AttributedString.Index(swiftRange.upperBound, within: attr) {
                        attr[s..<e].backgroundColor = Color.yellow
                        attr[s..<e].foregroundColor = Color.black
                    }
                }
            }
        }
        return Text(attr).font(.system(size: fontSize)).lineSpacing(10).textSelection(.enabled).frame(maxWidth:.infinity, alignment:.leading).padding(.vertical, 2)
    }

    var emptyView: some View {
        VStack(spacing:16){
            Spacer().frame(height:80)
            Image(systemName:"book.closed").font(.system(size:48)).foregroundColor(.secondary.opacity(0.5))
            Text("파일을 선택하세요").font(.headline).foregroundColor(.secondary)
            Text("왼쪽 위 폴더 아이콘을 눌러주세요").font(.caption).foregroundColor(.secondary)
        }.frame(maxWidth:.infinity)
    }

    var bottomPlayer: some View {
        VStack(spacing:0){
            if !chapters.isEmpty && !text.isEmpty {
                HStack{
                    Text("\(currentChapterIdx+1)/\(chapters.count)").font(.caption2.bold()).padding(.horizontal,8).padding(.vertical,4).background(Color(.systemGray5)).clipShape(Capsule())
                    Text(chapters[currentChapterIdx].title).font(.caption).lineLimit(1).foregroundColor(.secondary)
                    Spacer()
                    Button(action:{ autoScroll.toggle() }){
                        HStack(spacing:4){
                            Image(systemName: autoScroll ? "book.pages.fill" : "book.pages")
                            Text(autoScroll ? "페이지" : "자유").font(.caption2)
                        }.foregroundColor(autoScroll ? .blue : .secondary)
                    }
                    Button(action:prev){ Image(systemName:"chevron.left").font(.caption) }.disabled(currentChapterIdx==0)
                    Button(action:next){ Image(systemName:"chevron.right").font(.caption) }.disabled(currentChapterIdx+1>=chapters.count)
                }.padding(.horizontal,16).frame(height:36).background(.ultraThinMaterial)
            }
            HStack(spacing:12){
                Button(action:{ tts.isSpeaking ? tts.pause() : playCurrent() }){
                    Image(systemName: tts.isSpeaking ? "pause.circle.fill" : "play.circle.fill").font(.system(size:42)).foregroundColor(.primary)
                }.disabled(text.isEmpty)
                VStack(alignment:.leading, spacing:2){
                    Text(fileName).font(.system(size:13, weight:.bold)).lineLimit(1)
                    if !chapters.isEmpty { Text(chapters[currentChapterIdx].title).font(.system(size:11)).foregroundColor(.secondary).lineLimit(1) }
                    else { Text(text.isEmpty ? "파일을 선택하세요" : "읽기 준비 완료").font(.system(size:11)).foregroundColor(.secondary) }
                }
                Spacer()
                if tts.isSpeaking { Button(action:{ tts.stop() }){ Image(systemName:"stop.fill").font(.system(size:14)).foregroundColor(.secondary).padding(8).background(Color(.systemGray5)).clipShape(Circle()) } }
            }.padding(.horizontal,14).padding(.vertical,10).background(Color(.systemBackground)).shadow(color:.black.opacity(0.08), radius:10, y:-2)
        }
    }

    func playCurrent(){ if chapters.isEmpty { tts.speakFull(text, title: fileName) } else { tts.speakChapter(at: currentChapterIdx, chapters: chapters, fullText: text, fileName: fileName) } }
    func next(){ if currentChapterIdx+1 < chapters.count { currentChapterIdx+=1; currentPageStart=0; playCurrent() } }
    func prev(){ if currentChapterIdx>0 { currentChapterIdx-=1; currentPageStart=0; playCurrent() } }

    static func makeChapters(from txt:String)->[(id:String,title:String,offset:Int)]{
        var res:[(String,String,Int)]=[]
        let lines = txt.components(separatedBy: .newlines)
        var seen = Set<String>()
        for (i,line) in lines.enumerated(){
            let t = line.trimmingCharacters(in:.whitespaces)
            if t.count<2||t.count>40 {continue}
            if seen.contains(t){continue}
            if t.range(of:"^(제\\s*\\d+|\\d+\\s*[장화막]|프롤로그|에필로그|Chapter)", options:.regularExpression) != nil { res.append((UUID().uuidString,t,i)); seen.insert(t) }
        }
        if res.isEmpty && !txt.isEmpty { res.append((UUID().uuidString,"1. ...",0)) }
        return res
    }
    static func makeParagraphs(from txt:String)->[(id:String,text:String,startOffset:Int)]{
        var res:[(String,String,Int)]=[]
        let lines = txt.components(separatedBy: .newlines)
        var offset = 0
        for line in lines {
            let nsLen = (line as NSString).length + 1
            if line.trimmingCharacters(in:.whitespaces).isEmpty { offset += nsLen; continue }
            res.append((UUID().uuidString, line, offset))
            offset += nsLen
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
                    if idx==currentIdx { Spacer(); Image(systemName:"speaker.wave.2.fill").foregroundColor(.blue) }
                }.contentShape(Rectangle()).onTapGesture{ onSelect(idx) }
            }}.navigationTitle("목차")
        }
    }
}
