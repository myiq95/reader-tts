
import Foundation

struct BookParser {
    static func parse(url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        
        // 1. BOM 제거
        let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]
        var rawData = data
        if data.starts(with: utf8BOM) {
            rawData = data.dropFirst(3) as Data
        }
        
        // 2. 인코딩 시도 순서: UTF-8 -> UTF-16 -> CP949(EUC-KR) -> EUC-KR
        let encodingsToTry: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16BigEndian,
            .utf16LittleEndian,
            String.Encoding(rawValue: 0x80000422), // windows CP949 - 한글 윈도우 기본
            String.Encoding(rawValue: 0x80000840), // EUC-KR
            .init(rawValue: 0x80000430), // euc-kr alternative
        ]
        
        // CFString으로 CP949 명시적 시도
        for encoding in encodingsToTry {
            if let str = String(data: rawData, encoding: encoding), !str.isEmpty {
                // 한글이 10% 이상 포함되면 성공으로 간주 (깨진 중국어 방지)
                if containsKorean(str) || encoding == .utf8 {
                    // 중국어 문자가 비정상적으로 많으면 CP949로 재시도
                    if !looksLikeBrokenChinese(str) {
                        print("Parsed with encoding: \(encoding.rawValue)")
                        return str
                    }
                }
            }
        }
        
        // 3. NSString으로 CP949 강제 시도 (가장 확실한 한글 ANSI)
        let cfEncodings: [CFStringEncoding] = [
            CFStringEncoding(0x0422), // kCFStringEncodingDOSKorean = CP949
            CFStringEncoding(0x0840), // kCFStringEncodingEUC_KR
        ]
        for cfEnc in cfEncodings {
            let nsEnc = CFStringConvertEncodingToNSStringEncoding(cfEnc)
            let encoding = String.Encoding(rawValue: nsEnc)
            if let str = String(data: rawData, encoding: encoding), !str.isEmpty {
                print("Parsed with CF encoding: \(cfEnc)")
                return str
            }
        }
        
        // 4. 마지막 fallback: NSString이 자동 감지하게
        if let str = String(data: rawData, encoding: .isoLatin1) {
            return str
        }
        
        return String(data: rawData, encoding: .utf8) ?? ""
    }
    
    static func containsKorean(_ s: String) -> Bool {
        let koreanCount = s.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) || (0x3130...0x318F).contains($0.value) }.count
        return koreanCount > s.count / 10
    }
    
    static func looksLikeBrokenChinese(_ s: String) -> Bool {
        // 한글이어야 하는데 중국어 한자만 많으면 깨진 것
        let chineseCount = s.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        let koreanCount = s.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) }.count
        return chineseCount > koreanCount * 2 && chineseCount > 20
    }
}
