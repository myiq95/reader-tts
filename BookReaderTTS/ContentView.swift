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
    
    // 행 단위
    @State private var lines: [(id:String, text:String, startOffset:Int)] = []
    @State private var currentPageStart = 0
    private let pageSize = 17 // 화면상 17행마다 페이지 넘김
    
    var body: some View {
        NavigationView {
            ZStack(alignment:.bottom){
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment:.leading, spacing:6){
                            if text.isEmpty { emptyView }
                            else {
                                ForEach(Array(lines.enumerated()), id:\.element.id) { idx, line in
                                    lineView(line: line)
                                        .id("line-\(idx)")
                                        .padding(.horizontal, 20)
                                }
                            }
                            Color.clear.frame(height:240).id("bottomSpacer")
                        }
                        .padding(.top, 20)
                    }
                    .onChange(of: tts.currentRange) { newRange in
                        guard autoScroll, let r = newRange else { return }
                        guard let lineIdx = lineIndex(for: r.location) else { return }
                        
                        // 현재 보이는 페이지: currentPageStart ~ currentPageStart+pageSize-1
                        // 하이라이트가 페이지를 벗어나면 다음 페이지로 탁 넘김
                        if lineIdx >= currentPageStart + pageSize {
                            let nextPageStart = (lineIdx / pageSize) * pageSize
                            currentPageStart = nextPageStart
                            print("Page scroll to \(nextPageStart) from line \(lineIdx)")
                            withAnimation(.easeOut(duration: 0.5)) {
                                proxy.scrollTo("line-\(nextPageStart)", anchor: .top)
                            }
                        } else if lineIdx < currentPageStart {
                            let prevPageStart = (lineIdx / pageSize) * pageSize
                            currentPageStart = prevPageStart
                            withAnimation(.easeOut(duration: 0.5)) {
                                proxy.scrollTo("line-\(prevPageStart)", anchor: .top)
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
                            Toggle(isOn: $autoScroll){ Label(autoScroll ? "17행마다 자동 넘김" : "자유 스크롤", systemImage: autoScroll ? "book.pages.fill" : "book.pages") }
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
                lines = Self.makeLines(from: content)
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
    
    func lineIndex(for globalOffset: Int) -> Int? {
        // globalOffset이 속한 행 찾기
        for (i, line) in lines.enumerated() {
            let start = line.startOffset
            let end = start + (line.text as NSString).length
            // 빈 줄도 포함, 마지막 줄은 +1 범위까지 허용
            if globalOffset >= start && globalOffset <= end + 1 {
                return i
            }
        }
        // 못 찾으면 가장 가까운 행
        return lines.last.map { _ in lines.count - 1 }
    }
    
    func lineView(line: (id:String, text:String, startOffset:Int)) -> some View {
        let lineStart = line.startOffset
        let lineEnd = lineStart + (line.text as NSString).length
        
        // 빈 줄이면 높이만
        if line.text.trimmingCharacters(in: .whitespaces).isEmpty {
            return AnyView(Color.clear.frame(height: fontSize * 0.6))
        }
        
        var attr = AttributedString(line.text)
        
        if let r = tts.currentRange, r.location != NSNotFound {
            let overlapStart = max(r.location, lineStart)
            let overlapEnd = min(r.location + r.length, lineEnd)
            if overlapStart < overlapEnd {
                let localStart = overlapStart - lineStart
                let localEnd = overlapEnd - lineStart
                if localStart >= 0 && localEnd <= (line.text as NSString).length {
                    if let swiftRange = Range(NSRange(location: localStart, length: localEnd - localStart), in: line.text) {
                        if let s = AttributedString.Index(swiftRange.lowerBound, within: attr),
                           let e = AttributedString.Index(swiftRange.upperBound, within: attr) {
                            attr[s..<e].backgroundColor = Color.yellow
                            attr[s..<e].foregroundColor = Color.black
                        }
                    }
                }
            }
        }
        
        return AnyView(
            Text(attr)
                .font(.system(size: fontSize))
                .lineSpacing(8)
                .textSelection(.enabled)
                .frame(maxWidth:.infinity, alignment:.leading)
        )
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
                    Text("\(currentPageStart/ pageSize + 1)페이지").font(.caption2).foregroundColor(.secondary)
                    Button(action:{ autoScroll.toggle() }){
                        HStack(spacing:4){
                            Image(systemName: autoScroll ? "book.pages.fill" : "book.pages")
                            Text(autoScroll ? "자동" : "수동").font(.caption2)
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
    
    func playCurrent(){
        if chapters.isEmpty { tts.speakFull(text, title: fileName) }
        else { tts.speakChapter(at: currentChapterIdx, chapters: chapters, fullText: text, fileName: fileName) }
    }
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
    
    // 핵심: 17행마다 넘기기 위해 모든 행(빈 줄 포함)의 오프셋을 정확히 계산
    static func makeLines(from txt:String)->[(id:String,text:String,startOffset:Int)]{
        var res:[(String,String,Int)]=[]
        // \n으로 정확히 분리, NSString length로 오프셋 계산 (TTS가 NSString 기준이므로)
        let nsTxt = txt as NSString
        var offset = 0
        // components가 \n을 버리므로, nsTxt로 직접 행을 찾기
        let lines = txt.components(separatedBy: .newlines)
        for line in lines {
            res.append((UUID().uuidString, line, offset))
            // +1 for \n (NSString 기준)
            offset += (line as NSString).length + 1
            if offset > nsTxt.length { break }
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
