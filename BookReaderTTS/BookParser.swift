import Foundation
import CoreFoundation

struct BookParser {
    static func parse(url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        var raw = data
        if data.count >= 3 && data[0]==0xEF && data[1]==0xBB && data[2]==0xBF {
            raw = data.dropFirst(3) as Data
        }
        
        // 0. 자동 감지 - iOS가 제일 잘함
        var used: String.Encoding = .utf8
        if let auto = try? String(contentsOf: url, usedEncoding: &used) {
            if koreanScore(auto) > 5 {
                print("Auto OK \(used.rawValue) score \(koreanScore(auto))")
                return auto
            }
        }
        
        // 1. CP949 / EUC-KR 강제 - CoreFoundation로 직접 (String(data:encoding:)보다 강력)
        if let s = decodeWithCF(data: raw, cfEncoding: 0x0422) { // CP949
            if koreanScore(s) > 0 { print("CF CP949 success"); return s }
        }
        if let s = decodeWithCF(data: raw, cfEncoding: 0x0840) { // EUC-KR
            if koreanScore(s) > 0 { return s }
        }
        
        // 2. NSString rawValue로
        let encodings: [UInt] = [0x80000422, 0x80000840, 0x80000430, 0x80000632]
        for rv in encodings {
            let enc = String.Encoding(rawValue: rv)
            if let s = String(data: raw, encoding: enc), koreanScore(s) > 0 {
                print("RawValue \(rv) success")
                return s
            }
        }
        
        // 3. UTF-8, UTF-16
        if let s = String(data: raw, encoding: .utf8), koreanScore(s) > 0 || !s.contains("�") {
            return s
        }
        if let s = String(data: raw, encoding: .utf16) { return s }
        if let s = String(data: raw, encoding: .utf16BigEndian) { return s }
        
        // 4. 최후: CP949로 lossy하게라도 읽기 (� 안 나오게)
        // CF로 non-lossy false로 시도
        return decodeWithCF(data: raw, cfEncoding: 0x0422, lossy: true) ?? String(decoding: raw, as: UTF8.self)
    }
    
    static func decodeWithCF(data: Data, cfEncoding: CFStringEncoding, lossy: Bool = false) -> String? {
        let nsEnc = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        // CFStringCreateWithBytes는 String(data:encoding:)보다 관대함
        var bytes = [UInt8](data)
        let cfStr = CFStringCreateWithBytes(nil, &bytes, data.count, cfEncoding, false)
        if let cfStr = cfStr {
            return cfStr as String
        }
        // 실패하면 NSString 방식으로 재시도
        if let s = String(data: data, encoding: String.Encoding(rawValue: nsEnc)) {
            return s
        }
        return nil
    }
    
    static func koreanScore(_ s: String) -> Int {
        s.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) }.count
    }
}
