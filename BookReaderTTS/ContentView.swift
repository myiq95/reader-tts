
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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack(alignment:.bottom){
                ScrollView {
                    VStack(alignment:.leading, spacing:20){
                        if text.isEmpty {
                            emptyView
                        } else {
                            // 파일 있으면 바로 읽기 버튼 크게
                            VStack(spacing:12){
                                HStack{
                                    Image(systemName:"doc.text.fill")
                                    Text(fileName).font(.headline).lineLimit(1)
                                    Spacer()
                                    Text("\(text.count)자").font(.caption2).foregroundColor(.secondary)
                                }.padding(.horizontal,18)
                                
                                Button(action: { tts.isSpeaking ? tts.pause() : playCurrent() }){
                                    HStack(spacing:10){
                                        Image(systemName: tts.isSpeaking ? "pause.fill" : "play.fill").font(.system(size:18, weight:.bold))
                                        Text(tts.isSpeaking ? "일시정지" : "▶ 읽기 시작").font(.system(size:17, weight:.bold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth:.infinity)
                                    .padding(.vertical,16)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius:14))
                                    .shadow(color:.blue.opacity(0.3), radius:8, y:4)
                                }.padding(.horizontal,18)
                            }.padding(.top,12)
                            
                            highlightedTextView
                                .padding(.horizontal,18)
                        }
                        Color.clear.frame(height:220)
                    }
                }
                bottomPlayer
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.navigationBarLeading){
                    Button(action:{showPicker=true}){ 
                        HStack{ Image(systemName:"folder.badge.plus"); Text("파일") }
                        .font(.body.bold()).foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement:.navigationBarTrailing){
                    HStack(spacing:14){
                        if !chapters.isEmpty {
                            Button(action:{showTOC=true}){ Image(systemName:"list.bullet") }
                        }
                        Menu{
                            Button("글자 작게"){ fontSize=max(14,fontSize-1) }
                            Button("글자 크게"){ fontSize=min(30,fontSize+1) }
                            Divider()
                            Button("느리게"){ tts.rate=0.42 }
                            Button("보통"){ tts.rate=0.50 }
                            Button("빠르게"){ tts.rate=0.58 }
                        } label:{ Image(systemName:"textformat.size") }
                    }
                }
            }
            .sheet(isPresented:$showPicker){ DocumentPicker{ url, content in
                print("Loaded \(content.count) chars")
                fileName = url.lastPathComponent
                text = content.isEmpty ? "파일을 읽을 수 없습니다. 다른 파일을 시도하세요." : content
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
        VStack(spacing:20){
            Image(systemName:"books.vertical.fill").font(.system(size:60)).foregroundColor(.blue)
            Text("책 파일을 열어보세요").font(.title3.bold())
            Text("txt, md, pdf, docx, epub 지원").font(.caption).foregroundColor(.secondary)
            Button(action:{showPicker=true}){
                Text("파일 선택하기").bold().padding(.horizontal,24).padding(.vertical,12)
                    .background(Color.blue).foregroundColor(.white).clipShape(Capsule())
            }.padding(.top,8)
        }.padding(60).frame(maxWidth:.infinity).padding(.top,60)
    }
    
    var highlightedTextView: some View {
        var attr = AttributedString(text)
        // 다크모드 대응 색상
        let textColor: Color = colorScheme == .dark ? .white : .black
        attr.foregroundColor = textColor
        
        if let r = tts.currentRange, r.location != NSNotFound {
            if let swiftRange = Range(r, in: text) {
                if let s = AttributedString.Index(swiftRange.lowerBound, within: attr),
                   let e = AttributedString.Index(swiftRange.upperBound, within: attr) {
                    attr[s..<e].backgroundColor = Color.yellow
                    attr[s..<e].foregroundColor = Color.black
                }
            }
        }
        return Text(attr).font(.system(size: fontSize, design:.serif)).lineSpacing(8).textSelection(.enabled)
    }
    
    var bottomPlayer: some View {
        VStack(spacing:0){
            if !chapters.isEmpty && !text.isEmpty {
                HStack{
                    Text("\(currentChapterIdx+1)/\(chapters.count)").font(.caption2.bold()).padding(6).background(Color.primary.opacity(0.08)).clipShape(Capsule())
                    Text(chapters[currentChapterIdx].title).font(.caption).lineLimit(1)
                    Spacer()
                    Button(action:prev){ Image(systemName:"chevron.left") }
                    Button(action:next){ Image(systemName:"chevron.right") }
                }.padding(.horizontal,16).frame(height:36).background(.ultraThinMaterial)
            }
            HStack(spacing:14){
                Button(action:{ tts.isSpeaking ? tts.pause() : playCurrent() }){
                    Image(systemName: tts.isSpeaking ? "pause.circle.fill" : "play.circle.fill").font(.system(size:44)).foregroundColor(.blue)
                }.disabled(text.isEmpty)
                VStack(alignment:.leading, spacing:2){
                    Text(fileName).font(.caption.bold()).lineLimit(1)
                    Text(tts.currentChapter.isEmpty ? (text.isEmpty ? "파일을 선택하세요" : "읽기 준비 완료") : tts.currentChapter)
                        .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                if tts.isSpeaking {
                    Button(action:{ tts.stop() }){ Image(systemName:"stop.fill").foregroundColor(.secondary) }
                }
            }.padding(14).background(Color(.systemBackground)).shadow(color:.black.opacity(0.1), radius:12, y:-4)
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
        if res.isEmpty {
            let paras = txt.components(separatedBy:"\n\n").filter{ $0.trimmingCharacters(in:.whitespaces).count>20 }
            let chunk = max(10, paras.count/16)
            var chapNum = 1
            for i in stride(from:0,to:paras.count,by:chunk){
                let preview = String(paras[i].prefix(22)).replacingOccurrences(of:"\n",with:" ")
                res.append((UUID().uuidString,"\(chapNum). \(preview)...", i))
                chapNum+=1
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
