
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
                        VStack(alignment:.leading, spacing:0){
                            if text.isEmpty {
                                emptyView
                            } else {
                                // 책 내용
                                highlightedTextView
                                    .padding(.horizontal,20)
                                    .padding(.top,20)
                                    .id("top")
                            }
                            Color.clear.frame(height:180)
                        }
                    }
                    .onChange(of: tts.currentRange) { _ in
                        // 읽는 위치 따라 스크롤은 필요하면
                    }
                }
                bottomPlayer
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.navigationBarLeading){
                    Button(action:{showPicker=true}){
                        Image(systemName:"folder.badge.plus").font(.system(size:17, weight:.bold))
                    }
                }
                ToolbarItem(placement:.navigationBarTrailing){
                    HStack(spacing:14){
                        if !chapters.isEmpty {
                            Button(action:{showTOC=true}){
                                Image(systemName:"list.bullet").foregroundColor(.blue)
                            }
                        }
                        Menu{
                            Button("작게"){ fontSize=max(14,fontSize-1) }
                            Button("크게"){ fontSize=min(28,fontSize+1) }
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
            Spacer().frame(height:80)
            Image(systemName:"book.closed").font(.system(size:48)).foregroundColor(.secondary.opacity(0.5))
            Text("파일을 선택하세요").font(.headline).foregroundColor(.secondary)
            Text("왼쪽 위 폴더 아이콘을 눌러주세요").font(.caption).foregroundColor(.secondary)
        }.frame(maxWidth:.infinity)
    }
    
    var highlightedTextView: some View {
        var attr = AttributedString(text)
        if let r = tts.currentRange, r.location != NSNotFound, r.location < text.count {
            if let swiftRange = Range(r, in: text) {
                if let s = AttributedString.Index(swiftRange.lowerBound, within: attr),
                   let e = AttributedString.Index(swiftRange.upperBound, within: attr) {
                    attr[s..<e].backgroundColor = Color.yellow
                    attr[s..<e].foregroundColor = Color.black
                }
            }
        }
        return Text(attr)
            .font(.system(size: fontSize, design:.default))
            .lineSpacing(10)
            .textSelection(.enabled)
    }
    
    // 사진에 있는 디자인 - 하단에 미니멀 플레이어
    var bottomPlayer: some View {
        VStack(spacing:0){
            if !chapters.isEmpty && !text.isEmpty {
                HStack{
                    Text("\(currentChapterIdx+1)/\(chapters.count)").font(.caption2.bold())
                        .padding(.horizontal,8).padding(.vertical,4)
                        .background(Color(.systemGray5)).clipShape(Capsule())
                    Text(chapters[currentChapterIdx].title).font(.caption).lineLimit(1).foregroundColor(.secondary)
                    Spacer()
                    Button(action:prev){ Image(systemName:"chevron.left").font(.caption) }
                        .disabled(currentChapterIdx==0)
                    Button(action:next){ Image(systemName:"chevron.right").font(.caption) }
                        .disabled(currentChapterIdx+1>=chapters.count)
                }
                .padding(.horizontal,16)
                .frame(height:36)
                .background(.ultraThinMaterial)
            }
            HStack(spacing:12){
                // 야간 모드 대응: primary 색상 사용
                Button(action:{ tts.isSpeaking ? tts.pause() : playCurrent() }){
                    Image(systemName: tts.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size:42))
                        .foregroundColor(.primary) // 검정 대신 primary -> 다크모드에서 흰색으로 보임
                }
                .disabled(text.isEmpty)
                
                VStack(alignment:.leading, spacing:2){
                    Text(fileName).font(.system(size:13, weight:.bold)).lineLimit(1)
                    if !chapters.isEmpty {
                        Text(chapters[currentChapterIdx].title).font(.system(size:11)).foregroundColor(.secondary).lineLimit(1)
                    } else {
                        Text(text.isEmpty ? "파일을 선택하세요" : "읽기 준비 완료").font(.system(size:11)).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if tts.isSpeaking {
                    Button(action:{ tts.stop() }){
                        Image(systemName:"stop.fill").font(.system(size:14))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal,14)
            .padding(.vertical,10)
            .background(Color(.systemBackground))
            .shadow(color:.black.opacity(0.08), radius:10, y:-2)
        }
    }
    
    func playCurrent(){
        if chapters.isEmpty {
            tts.speakFull(text, title: fileName)
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
        if res.isEmpty && !txt.isEmpty {
            res.append((UUID().uuidString,"1. ...",0))
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
