import Foundation

struct BookParser {
    static func parse(url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        var raw = data
        if data.count >= 3 && data[0]==0xEF && data[1]==0xBB && data[2]==0xBF {
            raw = data.dropFirst(3) as Data
        }
        
        // 모든 인코딩 후보 시도해서 한글이 가장 많이 나오는 것을 선택
        var bestString: String = ""
        var bestKoreanScore = -1
        
        // 후보 인코딩들 (CP949를 가장 먼저!)
        let cfKorean: [CFStringEncoding] = [0x0422, 0x0840] // CP949, EUC-KR
        var candidates: [String.Encoding] = []
        
        // CP949, EUC-KR 먼저 추가
        for cf in cfKorean {
            let ns = CFStringConvertEncodingToNSStringEncoding(cf)
            candidates.append(String.Encoding(rawValue: ns))
        }
        // 그 다음 rawValue들
        candidates.append(contentsOf: [
            String.Encoding(rawValue: 0x80000422),
            String.Encoding(rawValue: 0x80000840),
            .utf8,
            .utf16,
            .utf16BigEndian,
            .utf16LittleEndian
        ])
        
        for enc in candidates {
            if let str = String(data: raw, encoding: enc) {
                let score = koreanScore(str)
                // 깨진 유럽문자(¾, Æ, ³)나 다이아몬드(�)가 많으면 감점
                let brokenPenalty = brokenScore(str)
                let finalScore = score - brokenPenalty
                if finalScore > bestKoreanScore {
                    bestKoreanScore = finalScore
                    bestString = str
                }
                // 한글이 50개 이상이면 바로 성공
                if score > 50 && brokenPenalty == 0 {
                    print("Best encoding found: \(enc.rawValue) with score \(score)")
                    return str
                }
            }
        }
        
        // 자동 감지도 시도
        var used: String.Encoding = .utf8
        if let auto = try? String(contentsOf: url, usedEncoding: &used) {
            if koreanScore(auto) > bestKoreanScore {
                return auto
            }
        }
        
        if !bestString.isEmpty {
            return bestString
        }
        
        // 최후
        return String(decoding: raw, as: UTF8.self)
    }
    
    static func koreanScore(_ s: String) -> Int {
        s.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) }.count
    }
    
    static func brokenScore(_ s: String) -> Int {
        // 유럽 깨짐 문자, 다이아몬드 물음표, 중국어 한자가 많으면 깨진 것
        var penalty = 0
        penalty += s.filter { $0 == "�" }.count * 10
        penalty += s.filter { ["¾","Æ","³","¼","Å","Ç","À","¿"].contains(String($0)) }.count * 2
        // 한자는 있어도 괜찮지만 한글보다 3배 많으면 깨진 것
        let chinese = s.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        let korean = koreanScore(s)
        if chinese > korean * 2 && chinese > 20 {
            penalty += chinese
        }
        return penalty
    }
}
