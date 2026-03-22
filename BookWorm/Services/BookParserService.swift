import Foundation
import djvu

// MARK: - Book Parser Service

final class BookParserService {
    static let shared = BookParserService()
    private init() {}
    
    func parseBook(at url: URL, format: BookFormat) async throws -> ParsedBook {
        switch format {
        case .fb2:
            return try await parseFB2(at: url)
        case .epub:
            return try await parseEPUB(at: url)
        case .txt:
            return try await parseTXT(at: url)
        case .pdf:
            return try await parsePDF(at: url)
        case .djvu:
            return try await parseDjVu(at: url)
        }
    }
    
    // MARK: - FB2 Parser (XML-based)
    
    private func parseFB2(at url: URL) async throws -> ParsedBook {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        let data = try Data(contentsOf: url)
        let parser = FB2Parser(data: data)
        return parser.parse()
    }
    
    // MARK: - EPUB Parser (ZIP with XHTML)
    
    private func parseEPUB(at url: URL) async throws -> ParsedBook {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        // EPUB is a ZIP file — we extract and read the XHTML content
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Simple unzip using Foundation
        let data = try Data(contentsOf: url)
        
        // For a production app, use a proper ZIP library
        // Here we do a basic text extraction from the raw data
        let rawText = extractTextFromXHTML(data: data)
        let pages = splitIntoPages(rawText)
        
        return ParsedBook(
            title: url.deletingPathExtension().lastPathComponent,
            author: "Unknown",
            content: pages,
            coverData: nil
        )
    }
    
    // MARK: - TXT Parser
    
    private func parseTXT(at url: URL) async throws -> ParsedBook {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        let text = try String(contentsOf: url, encoding: .utf8)
        let pages = splitIntoPages(text)
        
        return ParsedBook(
            title: url.deletingPathExtension().lastPathComponent,
            author: "Unknown",
            content: pages,
            coverData: nil
        )
    }
    
    // MARK: - PDF Parser (basic text extraction)
    
    private func parsePDF(at url: URL) async throws -> ParsedBook {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        guard let document = CGPDFDocument(url as CFURL) else {
            throw ParserError.invalidFile
        }
        
        var fullText = ""
        for i in 1...document.numberOfPages {
            guard let page = document.page(at: i) else { continue }
            // Basic PDF text extraction using CGPDFPage
            // For production, use PDFKit's PDFDocument.string
            let _ = page.getBoxRect(.mediaBox)
            fullText += "[Page \(i)]\n\n"
        }
        
        // Use PDFKit for better extraction
        if let pdfDoc = PDFDocumentWrapper(url: url) {
            fullText = pdfDoc.extractText()
        }
        
        let pages = splitIntoPages(fullText)
        return ParsedBook(
            title: url.deletingPathExtension().lastPathComponent,
            author: "Unknown",
            content: pages.isEmpty ? ["Could not extract text from PDF."] : pages,
            coverData: nil
        )
    }
    
    // MARK: - DjVu Parser

    private func parseDjVu(at url: URL) async throws -> ParsedBook {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        let djvu = try Djvu(url: url)
        let pageCount = djvu.numberOfPages
        
        guard pageCount > 0 else {
            throw ParserError.parsingFailed("DjVu file has no pages")
        }
        
        var pages: [String] = []
        for i in 0..<pageCount {
            pages.append("[DJVU_PAGE:\(i)]")
        }
        
        let coverImage = try? djvu.getImage(page: 0, dpi: 150, maxSideSize: 640)
        let coverData = coverImage?.jpegData(compressionQuality: 0.7)
        
        return ParsedBook(
            title: url.deletingPathExtension().lastPathComponent,
            author: "Unknown",
            content: pages,
            coverData: coverData
        )
    }
    
    // MARK: - Helpers
    
    func splitIntoPages(_ text: String, charsPerPage: Int = 2000) -> [String] {
        guard !text.isEmpty else { return [""] }
        
        var pages: [String] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            let endOffset = text.index(currentIndex, offsetBy: charsPerPage, limitedBy: text.endIndex) ?? text.endIndex
            
            // Try to break at paragraph or sentence boundary
            var breakIndex = endOffset
            if endOffset < text.endIndex {
                let searchRange = currentIndex..<endOffset
                if let lastNewline = text[searchRange].lastIndex(of: "\n") {
                    breakIndex = text.index(after: lastNewline)
                } else if let lastPeriod = text[searchRange].lastIndex(of: ".") {
                    breakIndex = text.index(after: lastPeriod)
                }
            }
            
            let page = String(text[currentIndex..<breakIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !page.isEmpty {
                pages.append(page)
            }
            currentIndex = breakIndex
        }
        
        return pages.isEmpty ? [""] : pages
    }
    
    private func extractTextFromXHTML(data: Data) -> String {
        // Simplified: strip XML/HTML tags from the data
        guard let rawString = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .ascii) else {
            return ""
        }
        
        // Remove XML/HTML tags
        let cleaned = rawString
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func getDjVuPageImage(fileURL: URL, page: Int, dpi: Int = 300) -> UIImage? {
        guard let djvu = try? Djvu(url: fileURL) else { return nil }
        return try? djvu.getImage(page: page, dpi: dpi)
    }
}

// MARK: - FB2 XML Parser

final class FB2Parser: NSObject, XMLParserDelegate {
    private let data: Data
    private var title = ""
    private var author = ""
    private var bodyText = ""
    private var currentElement = ""
    private var isInBody = false
    private var isInTitle = false
    private var isInAuthor = false
    private var depth = 0
    
    init(data: Data) {
        self.data = data
    }
    
    func parse() -> ParsedBook {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        let pages = BookParserService.shared.splitIntoPages(bodyText)
        return ParsedBook(
            title: title.isEmpty ? "Untitled" : title,
            author: author.isEmpty ? "Unknown" : author,
            content: pages,
            coverData: nil
        )
    }
    
    // XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String : String] = [:]) {
        currentElement = elementName.lowercased()
        
        switch currentElement {
        case "body":
            isInBody = true
        case "book-title":
            isInTitle = true
        case "first-name", "last-name", "middle-name":
            if !isInBody { isInAuthor = true }
        case "section":
            if isInBody { bodyText += "\n\n" }
        case "p":
            if isInBody { bodyText += "\n" }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if isInTitle {
            title += trimmed
        } else if isInAuthor {
            if !author.isEmpty { author += " " }
            author += trimmed
        } else if isInBody {
            bodyText += trimmed
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let name = elementName.lowercased()
        
        switch name {
        case "body":
            isInBody = false
        case "book-title":
            isInTitle = false
        case "first-name", "last-name", "middle-name":
            isInAuthor = false
        default:
            break
        }
    }
}

// MARK: - PDF Wrapper

import PDFKit

struct PDFDocumentWrapper {
    private let document: PDFDocument
    
    init?(url: URL) {
        guard let doc = PDFDocument(url: url) else { return nil }
        self.document = doc
    }
    
    func extractText() -> String {
        var text = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                text += pageText + "\n\n"
            }
        }
        return text
    }
}

// MARK: - Data Types

struct ParsedBook {
    let title: String
    let author: String
    let content: [String]   // Array of page strings
    let coverData: Data?
    
    var totalPages: Int { content.count }
}

enum ParserError: LocalizedError {
    case invalidFile
    case unsupportedFormat
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFile: return "The file could not be read."
        case .unsupportedFormat: return "This file format is not supported."
        case .parsingFailed(let msg): return "Parsing failed: \(msg)"
        }
    }
}
