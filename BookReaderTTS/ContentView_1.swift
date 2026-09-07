
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var text = ""
    @State private var chapters: [(id:String, title:String, offset:Int)] = []
    @State private var fileName = "파일을 선택하세요"
    @StateObject private var tts = TTSManager.shared
    @State private var showPicker = false
    @State private var fontSize: CGFloat = 18
    @State private var selectedRange: NSRange?
    
    var body: some View {
        NavigationView {
            VStack(spacing:0) {
                // Reader
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment:.leading, spacing:16) {
                            ForEach(chapters, id:\.id) { ch in
                                Text(ch.title).font(.headline).padding(.top,20).id(ch.id)
                            }
                            if !text.isEmpty {
                                Text(attributedText).font(.system(size: fontSize)).lineSpacing(8).padding(.horizontal,16).textSelection(.enabled)
                            } else {
                                Text("왼쪽 상단 폴더 아이콘으로 .txt .md 파일을 여세요.\n모험 없는 스마샤 같은 한글 소설도 자동 인코딩 됩니다.").padding(40).foregroundColor(.secondary)
                            }
                        }.padding(.bottom,120)
                    }
                }
                
                // Bottom TOC Sheet Button
                if !chapters.isEmpty {
                    HStack {
                        Text("목차 \(chapters.count)개").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Button("목차 열기") { showTOC = true }
                    }.padding(.horizontal).frame(height:44).background(.ultraThinMaterial)
                }
                
                // TTS Control Bar - background capable
                VStack(spacing:8) {
                    HStack {
                        Button(action:{ tts.isSpeaking ? tts.pause() : tts.resume() }){
                            Image(systemName: tts.isSpeaking ? "pause.fill" : "play.fill").font(.title2)
                        }.disabled(text.isEmpty)
                        Button("정지"){ tts.stop() }.font(.caption)
                        Spacer()
                        Text("iPhone TTS • 백그라운드 재생").font(.caption2).foregroundColor(.secondary)
                        Picker("속도", selection:$tts.rate){ Text("느리게").tag(Float(0.42)); Text("보통").tag(Float(0.52)); Text("빠르게").tag(Float(0.62)) }.pickerStyle(.menu)
                    }
                    if tts.isSpeaking {
                        ProgressView().tint(.black)
                    }
                }.padding().background(Color(.systemBackground)).shadow(radius:4)
            }
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading){ Button(action:{showPicker=true}){ Image(systemName:"folder") } }
                ToolbarItem(placement:.navigationBarTrailing){
                    Menu {
                        Button("글자 작게"){ fontSize = max(12,fontSize-1) }
                        Button("글자 크게"){ fontSize = min(28,fontSize+1) }
                        Button("한국어 음성"){ tts.voiceLang="ko-KR" }
                        Button("영어 음성"){ tts.voiceLang="en-US" }
                    } label:{ Image(systemName:"textformat.size") }
                }
            }
            .sheet(isPresented:$showPicker){ DocumentPicker { url, content in
                self.fileName = url.lastPathComponent
                self.text = content
                self.chapters = Self.makeChapters(from: content)
                if !content.isEmpty { DispatchQueue.main.asyncAfter(deadline:.now()+0.3){ tts.speak(String(content.prefix(5000))) } }
            }}
            .sheet(isPresented:$showTOC){ TOCSheet(chapters:chapters) { id in
                showTOC=false
                // scroll handled via proxy if needed
            }}
        }
    }
    
    @State private var showTOC = false
    
    var attributedText: AttributedString {
        var attr = AttributedString(text)
        if let r = tts.currentRange, r.location+ r.length < text.count {
            let start = attr.index(attr.startIndex, offsetByCharacters: r.location)
            let end = attr.index(start, offsetByCharacters: r.length)
            attr[start..<end].backgroundColor = .yellow
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
            if t.hasPrefix("\"")||t.hasPrefix("'")||t.hasPrefix("\"")||t.hasPrefix("—")||t.hasPrefix("-"){continue}
            if t.hasSuffix("요.\"")||t.hasSuffix("요.")&&t.contains("\""){continue}
            if seen.contains(t){continue}
            // explicit
            if t.range(of:"^(제\\s*\\d+\\s*[장화막]|\\d+\\s*[장화막]|프롤로그|에필로그|외전|Chapter)", options:.regularExpression) != nil {
                res.append((UUID().uuidString,t,i)); seen.insert(t)
            } else if t.count<=20 && !t.contains(".") && !t.contains("?") && !t.contains("!") {
                // isolated check: need blank around
                let prev = i>0 ? lines[i-1].trimmingCharacters(in:.whitespaces) : ""
                let next = i+1<lines.count ? lines[i+1].trimmingCharacters(in:.whitespaces) : ""
                if prev.isEmpty && next.isEmpty && t.count>=2 {
                    if txt.components(separatedBy:t).count <= 3 {
                        res.append((UUID().uuidString,t,i)); seen.insert(t)
                    }
                }
            }
        }
        // fallback paragraph based
        if res.isEmpty {
            let paras = txt.components(separatedBy:"\n\n").filter{ $0.trimmingCharacters(in:.whitespaces).count>20 }
            let n = paras.count
            let chunk = max(10, n/18)
            var idx=0
            for i in stride(from:0,to:n,by:chunk){
                let preview = String(paras[i].prefix(25)).replacingOccurrences(of:"\n",with:" ")
                res.append((UUID().uuidString,"\(idx+1). \(preview)...",i))
                idx+=1
            }
        }
        return res
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL,String)->Void
    func makeUIViewController(context:Context)->UIDocumentPickerViewController{
        let p = UIDocumentPickerViewController(forOpeningContentTypes:[.plainText,.text,UTType(filenameExtension:"md")!], asCopy:true)
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
            // try encodings
            for enc in [String.Encoding.utf8, String.Encoding.windowsCP949, .eucKR]{
                if let s = try? String(contentsOf:url, encoding:enc){ txt=s; break }
            }
            if txt.isEmpty { txt = (try? String(contentsOf:url)) ?? "" }
            onPick(url,txt)
        }
    }
}

struct TOCSheet: View {
    var chapters:[(id:String,title:String,offset:Int)]
    var onSelect:(String)->Void
    var body: some View {
        NavigationView{
            List(chapters, id:\.id){ ch in
                Button(ch.title){ onSelect(ch.id) }
            }.navigationTitle("목차 \(chapters.count)개 - 단락 기반")
        }
    }
}
