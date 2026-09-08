import Foundation
import CoreFoundation

struct BookParser {
    static func parse(url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        var raw = data
        
        // BOM 제거 (UTF-8 BOM: EF BB BF)
        if raw.count >= 3 && raw[0] == 0xEF && raw[1] == 0xBB && raw[2] == 0xBF {
            raw = raw.dropFirst(3) as Data
        }
        
        // 1순위: UTF-8 먼저 시도 (D坂 같은 UTF-8 파일)
        // CP949 파일은 UTF-8로 디코딩하면 nil이 나오므로 자연스럽게 구분됨
        if let utf8Str = String(data: raw, encoding: .utf8) {
            // �가 없고, 한글이 조금이라도 있거나 전체가 정상이면 UTF-8로 인정
            if !utf8Str.contains("�") {
                let score = koreanScore(utf8Str)
                // 한글이 5자 이상 있거나, 한글이 없어도 UTF-8로 유효하면 반환
                // (일본어 섞인 파일도 위해)
                if score >= 5 || utf8Str.count > 0 {
                    print("UTF-8 success, Korean score \(score)")
                    return utf8Str
                }
            }
        }
        
        // 2순위: 시스템 자동 감지
        var used: String.Encoding = .utf8
        if let auto = try? String(contentsOf: url, usedEncoding: &used) {
            if !auto.contains("�") && koreanScore(auto) >= 5 {
                print("Auto detect success: \(used), score \(koreanScore(auto))")
                return auto
            }
        }
        
        // 3순위: CP949/EUC-KR 관대하게 읽기 (이상한 사건.txt 같은 ANSI 파일)
        // 깨진 장식문자 0xAD 0xA2 등은 버리고 한글만 살림
        if let cp949Str = decodeCP949Lenient(data: raw) {
            print("CP949 lenient success, score \(koreanScore(cp949Str))")
            return cp949Str
        }
        
        // 최후: 그냥 UTF-8로 강제
        return String(decoding: raw, as: UTF8.self)
    }
    
    // 깨진 바이트는 건너뛰고 한글은 살리는 CP949 디코더
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
            // 실패하면 1바이트 버림 (장식문자 등)
            idx += 1
        }
        return result.isEmpty ? nil : result
    }
    
    static func koreanScore(_ s: String) -> Int {
        s.unicodeScalars.filter { (0xAC00 ... 0xD7A3).contains($0.value) }.count
    }
}
