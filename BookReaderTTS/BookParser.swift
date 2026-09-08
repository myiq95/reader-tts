import Foundation

struct BookParser {
    static func parse(url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        var raw = data
        if data.count >= 3 && data[0]==0xEF && data[1]==0xBB && data[2]==0xBF {
            raw = data.dropFirst(3) as Data
        }
        
        // 1. UTF-8이 한글이면 바로 성공
        if let str = String(data: raw, encoding: .utf8) {
            let k = koreanCount(str)
            if k > 10 { return str }
            // 한글이 없는데 유럽문자(¾, Æ, À, ³ 등)가 많으면 CP949가 깨진 것 -> CP949로 재시도
            if str.contains("¾") || str.contains("À") || str.contains("Æ") || str.contains("³") || str.contains("¼") {
                // fall through to CP949
            } else if !str.contains("¿") && !str.contains("´") {
                // 정상 UTF-8일 수도 있음
                return str
            }
        }
        
        // 2. CP949 강제 - 네메아의 사자.txt 같은 경우
        let cfEnc: CFStringEncoding = 0x0422 // DOSKorean = CP949
        let nsEnc = CFStringConvertEncodingToNSStringEncoding(cfEnc)
        let cp949 = String.Encoding(rawValue: nsEnc)
        if let str = String(data: raw, encoding: cp949) {
            if koreanCount(str) > 5 {
                print("Parsed as CP949 - Korean count \(koreanCount(str))")
                return str
            }
        }
        
        // 3. 다른 한글 인코딩들
        let others: [UInt] = [0x80000840, 0x80000430, 0x80000632]
        for rv in others {
            if let str = String(data: raw, encoding: String.Encoding(rawValue: rv)) {
                if koreanCount(str) > 5 { return str }
            }
        }
        
        // 4. UTF-16
        if let str = String(data: raw, encoding: .utf16) { return str }
        if let str = String(data: raw, encoding: .utf16BigEndian) { return str }
        
        // 5. 최후 fallback - UTF8로 강제 디코딩
        return String(decoding: raw, as: UTF8.self)
    }
    
    static func koreanCount(_ s: String) -> Int {
        s.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) }.count
    }
}
