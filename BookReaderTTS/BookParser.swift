import Foundation
import CoreFoundation

struct BookParser {
    static func parse(url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        var raw = data
        if data.count >= 3 && data[0]==0xEF && data[1]==0xBB && data[2]==0xBF {
            raw = data.dropFirst(3) as Data
        }

        // 1. CP949 / EUC-KR로 관대하게 읽기 (깨진 장식문자는 버림)
        if let s = decodeCP949Lenient(data: raw) {
            if koreanScore(s) > 10 {
                print("CP949 lenient success, Korean \(koreanScore(s))")
                return s
            }
        }

        // 2. 자동 감지
        var used: String.Encoding =.utf8
        if let auto = try? String(contentsOf: url, usedEncoding: &used) {
            if koreanScore(auto) > 5 {
                return auto
            }
        }

        // 3. UTF-8 시도
        if let s = String(data: raw, encoding:.utf8) {
            if!s.contains("�") { return s }
        }

        // 4. 최후: CP949로 강제 (손상 무시)
        return decodeCP949Lenient(data: raw)?? String(decoding: raw, as: UTF8.self)
    }

    // 핵심: 깨진 바이트는 건너뛰고 한글은 살리는 CP949 디코더
    static func decodeCP949Lenient(data: Data) -> String? {
        let cfEnc: CFStringEncoding = 0x0422 // CP949
        var result = ""
        var idx = 0
        let bytes = [UInt8](data)

        while idx < bytes.count {
            // 1바이트 ASCII는 그대로
            if bytes[idx] < 0x80 {
                result.append(Character(UnicodeScalar(bytes[idx])))
                idx += 1
                continue
            }
            // 2바이트 한글 시도
            if idx + 1 < bytes.count {
                let twoBytes = Array(bytes[idx..<idx+2])
                if let cfStr = CFStringCreateWithBytes(nil, twoBytes, 2, cfEnc, false) {
                    result.append(cfStr as String)
                    idx += 2
                    continue
                }
            }
            // 실패하면 1바이트 버림 (장식문자 0xAD 0xA2 같은 것)
            idx += 1
        }
        return result.isEmpty? nil : result
    }

    static func koreanScore(_ s: String) -> Int {
        s.unicodeScalars.filter { (0xAC00...0xD7A3).contains($0.value) }.count
    }
}
