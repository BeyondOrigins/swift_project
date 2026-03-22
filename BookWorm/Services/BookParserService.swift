import Foundation
import djvu
import struct Foundation.Data
import Compression
import PDFKit

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
        
        // 1. Распаковываем ZIP
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epub_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try unzipFile(at: url, to: tempDir)
        
        // 2. Читаем container.xml → путь к .opf
        let containerURL = tempDir
            .appendingPathComponent("META-INF")
            .appendingPathComponent("container.xml")
        
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw ParserError.parsingFailed("No META-INF/container.xml found")
        }
        
        let containerData = try Data(contentsOf: containerURL)
        let containerParser = EPUBContainerParser(data: containerData)
        containerParser.parse()
        
        guard let opfPath = containerParser.opfPath else {
            throw ParserError.parsingFailed("Could not find OPF path in container.xml")
        }
        
        // 3. Читаем .opf → metadata + spine + manifest
        let opfURL = tempDir.appendingPathComponent(opfPath)
        let opfDir = opfURL.deletingLastPathComponent()
        let opfData = try Data(contentsOf: opfURL)
        let opfParser = EPUBOPFParser(data: opfData)
        opfParser.parse()
        
        // 4. Читаем главы в порядке spine
        var fullText = ""
        for spineIdref in opfParser.spineIdrefs {
            guard let href = opfParser.manifestItems[spineIdref] else { continue }
            let chapterURL = opfDir.appendingPathComponent(href)
            
            guard FileManager.default.fileExists(atPath: chapterURL.path),
                  let chapterData = try? Data(contentsOf: chapterURL),
                  let chapterHTML = String(data: chapterData, encoding: .utf8) else {
                continue
            }
            
            let chapterText = stripHTMLTags(chapterHTML)
            if !chapterText.isEmpty {
                fullText += "\n\n" + chapterText
            }
        }
        
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ParserError.parsingFailed("EPUB contains no readable text")
        }
        
        let pages = splitIntoPages(fullText)
        
        return ParsedBook(
            title: opfParser.title ?? url.deletingPathExtension().lastPathComponent,
            author: opfParser.author ?? "Unknown",
            content: pages,
            coverData: nil
        )
    }

    // MARK: - ZIP Extraction (Foundation-only, no external deps)

    private func unzipFile(at sourceURL: URL, to destURL: URL) throws {
        // Используем Process/FileHandle нельзя на iOS,
        // поэтому используем встроенный Archive из Apple
        // Через FileManager + координатор
        
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        
        coordinator.coordinate(
            readingItemAt: sourceURL,
            options: [.forUploading],
            error: &coordinatorError
        ) { tempURL in
            // .forUploading автоматически разархивирует
            // Не работает для EPUB, используем ручной метод
        }
        
        // Ручная распаковка ZIP через libz (доступна на iOS)
        // Foundation не даёт прямого API, но можно через shell-free метод:
        // Читаем ZIP и извлекаем через Archive (iOS 16+)
        
        if #available(iOS 16.0, *) {
            try unzipWithAppleArchive(at: sourceURL, to: destURL)
        } else {
            try unzipManually(at: sourceURL, to: destURL)
        }
    }

    @available(iOS 16.0, *)
    private func unzipWithAppleArchive(at sourceURL: URL, to destURL: URL) throws {
        // Используем простой подход: копируем как .zip и извлекаем
        // через Foundation's built-in ZIP support
        
        guard let archive = try? Data(contentsOf: sourceURL) else {
            throw ParserError.parsingFailed("Cannot read EPUB file")
        }
        
        try extractZipData(archive, to: destURL)
    }

    private func unzipManually(at sourceURL: URL, to destURL: URL) throws {
        guard let archive = try? Data(contentsOf: sourceURL) else {
            throw ParserError.parsingFailed("Cannot read EPUB file")
        }
        try extractZipData(archive, to: destURL)
    }

    /// Минимальный ZIP-экстрактор без внешних зависимостей
    private func extractZipData(_ data: Data, to directory: URL) throws {
        let fm = FileManager.default
        var offset = 0
        
        while offset + 30 <= data.count {
            // Ищем Local File Header signature: PK\x03\x04
            let sig = data.subdata(in: offset..<offset+4)
            guard sig == Data([0x50, 0x4B, 0x03, 0x04]) else { break }
            
            let flags = data.subdata(in: offset+6..<offset+8)
                .withUnsafeBytes { $0.load(as: UInt16.self) }
            let compressionMethod = data.subdata(in: offset+8..<offset+10)
                .withUnsafeBytes { $0.load(as: UInt16.self) }
            let compressedSize = Int(data.subdata(in: offset+18..<offset+22)
                .withUnsafeBytes { $0.load(as: UInt32.self) })
            let uncompressedSize = Int(data.subdata(in: offset+22..<offset+26)
                .withUnsafeBytes { $0.load(as: UInt32.self) })
            let fileNameLength = Int(data.subdata(in: offset+26..<offset+28)
                .withUnsafeBytes { $0.load(as: UInt16.self) })
            let extraFieldLength = Int(data.subdata(in: offset+28..<offset+30)
                .withUnsafeBytes { $0.load(as: UInt16.self) })
            
            let fileNameStart = offset + 30
            let fileNameData = data.subdata(in: fileNameStart..<fileNameStart+fileNameLength)
            guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                offset = fileNameStart + fileNameLength + extraFieldLength + compressedSize
                continue
            }
            
            let dataStart = fileNameStart + fileNameLength + extraFieldLength
            
            let destPath = directory.appendingPathComponent(fileName)
            
            if fileName.hasSuffix("/") {
                // Это директория
                try fm.createDirectory(at: destPath, withIntermediateDirectories: true)
            } else {
                // Это файл
                try fm.createDirectory(
                    at: destPath.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                
                let fileData: Data
                if compressionMethod == 0 {
                    // Stored (без сжатия)
                    fileData = data.subdata(in: dataStart..<dataStart+compressedSize)
                } else if compressionMethod == 8 {
                    // Deflate
                    let compressed = data.subdata(in: dataStart..<dataStart+compressedSize)
                    if let decompressed = decompressDeflate(compressed, expectedSize: uncompressedSize) {
                        fileData = decompressed
                    } else {
                        fileData = Data()
                    }
                } else {
                    fileData = Data()
                }
                
                try fileData.write(to: destPath)
            }
            
            offset = dataStart + compressedSize
        }
    }

    /// Deflate-декомпрессия через встроенный zlib (всегда есть на iOS)
    private func decompressDeflate(_ data: Data, expectedSize: Int) -> Data? {
        
        // Используем Compression framework (встроен в iOS)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: max(expectedSize, 1))
        defer { buffer.deallocate() }
        
        let result = data.withUnsafeBytes { rawPtr -> Int in
            guard let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                buffer, max(expectedSize, 1),
                ptr, data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        guard result > 0 else { return nil }
        return Data(bytes: buffer, count: result)
    }

    // MARK: - HTML Stripping

    private func stripHTMLTags(_ html: String) -> String {
        // Заменяем блочные элементы переносами строк
        var text = html
        let blockTags = ["</p>", "</div>", "</h1>", "</h2>", "</h3>",
                         "</h4>", "</h5>", "</h6>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        
        // Убираем все оставшиеся теги
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        
        // Декодируем HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#039;", with: "'")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        text = text.replacingOccurrences(of: "&#x27;", with: "'")
        text = text.replacingOccurrences(of: "&#8211;", with: "–")
        text = text.replacingOccurrences(of: "&#8212;", with: "—")
        text = text.replacingOccurrences(of: "&#8216;", with: "'")
        text = text.replacingOccurrences(of: "&#8217;", with: "'")
        text = text.replacingOccurrences(of: "&#8220;", with: "\u{201C}")
        text = text.replacingOccurrences(of: "&#8221;", with: "\u{201D}")
        
        // Убираем множественные пробелы и пустые строки
        text = text.replacingOccurrences(
            of: "[ \t]+",
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        guard let document = PDFDocument(url: url) else {
            throw ParserError.invalidFile
        }
        
        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw ParserError.parsingFailed("PDF has no pages")
        }
        
        // Try to extract text
        var fullText = ""
        for i in 0..<pageCount {
            if let page = document.page(at: i), let text = page.string {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    fullText += trimmed + "\n\n"
                }
            }
        }
        
        // If there is text - do everything as usual
        if !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let pages = splitIntoPages(fullText)
            return ParsedBook(
                title: extractPDFTitle(from: document) ?? url.deletingPathExtension().lastPathComponent,
                author: extractPDFAuthor(from: document) ?? "Unknown",
                content: pages,
                coverData: nil
            )
        }
        
        // If no text — same as DjVu
        var pages: [String] = []
        for i in 0..<pageCount {
            pages.append("[PDF_PAGE:\(i)]")
        }
        
        return ParsedBook(
            title: extractPDFTitle(from: document) ?? url.deletingPathExtension().lastPathComponent,
            author: extractPDFAuthor(from: document) ?? "Unknown",
            content: pages,
            coverData: nil
        )
    }

    // MARK: - PDF Metadata Helpers

    private func extractPDFTitle(from document: PDFDocument) -> String? {
        guard let attributes = document.documentAttributes else { return nil }
        return attributes[PDFDocumentAttribute.titleAttribute] as? String
    }

    private func extractPDFAuthor(from document: PDFDocument) -> String? {
        guard let attributes = document.documentAttributes else { return nil }
        return attributes[PDFDocumentAttribute.authorAttribute] as? String
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
