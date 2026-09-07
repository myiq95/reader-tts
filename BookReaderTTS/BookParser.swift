
import Foundation
import PDFKit
import UniformTypeIdentifiers

class BookParser {
    static func parse(url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "docx": return parseDocx(url: url)
        case "pdf": return parsePDF(url: url)
        case "epub": return parseEpub(url: url)
        case "rtf": return parseRTF(url: url)
        case "html","htm": return parseHTML(url: url)
        default: return parseText(url: url)
        }
    }
    
    static func parseText(url: URL) -> String {
        // utf8 then try cp949 via raw value
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        let cp949 = String.Encoding(rawValue: 0x80000422) // kCFStringEncodingDOSKorean
        let eucKR = String.Encoding(rawValue: 0x80000840)
        for enc in [cp949, eucKR, .utf16, .ascii] {
            if let s = try? String(contentsOf: url, encoding: enc) { return s }
        }
        return (try? String(contentsOf: url)) ?? "읽을 수 없는 파일"
    }
    
    static func parseDocx(url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return parseText(url: url) }
        if let text = extractDocxText(from: data) { return text }
        return parseText(url: url)
    }
    
    static func extractDocxText(from data: Data) -> String? {
        guard let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else { return nil }
        var result = ""
        var searchRange = str.startIndex..<str.endIndex
        while let start = str.range(of: "<w:t", options: [], range: searchRange) {
            guard let endOfTag = str.range(of: ">", range: start.upperBound..<str.endIndex),
                  let close = str.range(of: "</w:t>", range: endOfTag.upperBound..<str.endIndex) else { break }
            let content = str[endOfTag.upperBound..<close.lowerBound]
            result += content + " "
            searchRange = close.upperBound..<str.endIndex
        }
        return result.isEmpty ? nil : result.replacingOccurrences(of: "  ", with: "\n")
    }
    
    static func parsePDF(url: URL) -> String {
        guard let pdf = PDFDocument(url: url) else { return "PDF 열기 실패" }
        var full = ""
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i), let txt = page.string { full += txt + "\n\n" }
        }
        return full.isEmpty ? "PDF 텍스트 추출 불가 (이미지 PDF)" : full
    }
    
    static func parseEpub(url: URL) -> String {
        guard let data = try? Data(contentsOf: url), let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else { return parseText(url: url) }
        var result = ""
        var range = str.startIndex..<str.endIndex
        while let s = str.range(of: "<p", range: range) {
            guard let gt = str.range(of: ">", range: s.upperBound..<str.endIndex),
                  let close = str.range(of: "</p>", range: gt.upperBound..<str.endIndex) else { break }
            result += str[gt.upperBound..<close.lowerBound] + "\n\n"
            range = close.upperBound..<str.endIndex
        }
        if result.isEmpty { return parseText(url: url) }
        return result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    
    static func parseRTF(url: URL) -> String {
        if let data = try? Data(contentsOf: url),
           let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            return attr.string
        }
        return parseText(url: url)
    }
    
    static func parseHTML(url: URL) -> String {
        if let data = try? Data(contentsOf: url),
           let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            return attr.string
        }
        return parseText(url: url)
    }
}
