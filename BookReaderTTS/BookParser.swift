import Foundation
import CoreFoundation

struct BookParser {
    static func parse(url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        var raw = data
        
        // BOM 제거
        if raw.count >= 3 && raw[0] == 0xEF && raw[1] == 0xBB && raw[2] == 0xBF {
            raw = raw.dropFirst(3) as Data
        }
        
        // 1. UTF-8이 유효하면 무조건 UTF-8 (D坂의 살인 사건.txt)
        // CP949 한글은 UTF-8로 디코딩하면 nil이 나오므로 자동 구분됨
        if let s = String(data: raw, encoding: .utf8) {
            print("✅ UTF-8로 읽기 성공: \(s.prefix(30))")
            return s
        }
        
        // 2. 시스템 자동 감지 시도
        var used: String.Encoding = .utf8
        if let s = try? String(contentsOf: url, usedEncoding: &used), !s.contains("�") {
            print("✅ 자동 감지로 읽기 성공: \(used)")
            return s
        }
        
        // 3. CP949 / EUC-KR 관대하게 읽기 (이상한 사건.txt)
        if let s = decodeCP949Lenient(data: raw) {
            print("✅ CP949 관대하게 읽기 성공")
            return s
        }
        
        // 4. 최후
        return String(decoding: raw, as: UTF8.self)
    }
    
    static func decodeCP949Lenient(data: Data) -> String? {
        let cfEnc: CFStringEncoding = 0x0422 // CP949
        var result = ""
        var idx = 0
        let bytes = [UInt8](data)
        
        while idx < bytes.count {
            if bytes[idx] < 0x80 {
                result.append(Character(UnicodeScalar(bytes[idx])))
                idx += 1
                continue
            }
            if idx + 1 < bytes.count {
                let twoBytes = Array(bytes[idx ..< idx + 2])
                if let cfStr = CFStringCreateWithBytes(nil, twoBytes, 2, cfEnc, false) {
                    result.append(cfStr as String)
                    idx += 2
                    continue
                }
            }
            idx += 1
        }
        return result.isEmpty ? nil : result
    }
}
