import Foundation
import Compression
import PDFKit

// MARK: - EPUB Container Parser (reads META-INF/container.xml)

final class EPUBContainerParser: NSObject, XMLParserDelegate {
    private let data: Data
    var opfPath: String?
    
    init(data: Data) { self.data = data }
    
    func parse() {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if elementName == "rootfile" || elementName.hasSuffix(":rootfile") {
            opfPath = attributes["full-path"]
        }
    }
}

// MARK: - EPUB OPF Parser (reads content.opf → metadata, manifest, spine)

final class EPUBOPFParser: NSObject, XMLParserDelegate {
    private let data: Data
    
    var title: String?
    var author: String?
    var manifestItems: [String: String] = [:]  // id → href
    var spineIdrefs: [String] = []
    
    private var currentElement = ""
    private var currentText = ""
    private var inMetadata = false
    
    init(data: Data) { self.data = data }
    
    func parse() {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        let name = elementName.components(separatedBy: ":").last ?? elementName
        currentElement = name
        currentText = ""
        
        switch name {
        case "metadata":
            inMetadata = true
        case "item":
            if let id = attributes["id"], let href = attributes["href"] {
                let mediaType = attributes["media-type"] ?? ""
                // Только XHTML и HTML файлы
                if mediaType.contains("html") || mediaType.contains("xml")
                    || href.hasSuffix(".xhtml") || href.hasSuffix(".html") || href.hasSuffix(".htm") {
                    manifestItems[id] = href
                }
            }
        case "itemref":
            if let idref = attributes["idref"] {
                spineIdrefs.append(idref)
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let name = elementName.components(separatedBy: ":").last ?? elementName
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if inMetadata && !trimmed.isEmpty {
            switch name {
            case "title":
                if title == nil { title = trimmed }
            case "creator":
                if author == nil { author = trimmed }
            default:
                break
            }
        }
        
        if name == "metadata" {
            inMetadata = false
        }
    }
}
