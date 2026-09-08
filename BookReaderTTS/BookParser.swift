
import Foundation
import UniformTypeIdentifiers
struct BookParser {
    static func parse(url: URL)->String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        if let s = String(data: data, encoding: .utf8), !s.isEmpty { return s }
        if let s = String(data: data, encoding: .utf16), !s.isEmpty { return s }
        if let s = String(data: data, encoding: .init(rawValue: 0x80000632)), !s.isEmpty { return s } // euc-kr
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
