import Foundation
import UniformTypeIdentifiers
import SwiftUI

// MARK: - File Import Service

final class FileImportService {
    static let shared = FileImportService()
    private init() {}
    
    static let supportedTypes: [UTType] = [
        .plainText,           // .txt
        .xml,                 // .fb2 (XML-based)
        .pdf,                 // .pdf
        .epub,                // .epub
        .data                 // .djvu and other binary
    ]
    
    static let supportedExtensions: Set<String> = [
        "fb2", "epub", "txt", "pdf", "djvu"
    ]
    
    func detectFormat(from url: URL) -> BookFormat? {
        let ext = url.pathExtension.lowercased()
        return BookFormat(rawValue: ext)
    }
    
    func copyToDocuments(from sourceURL: URL) throws -> URL {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
        
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let booksDir = documentsDir.appendingPathComponent("Books", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: booksDir.path) {
            try FileManager.default.createDirectory(at: booksDir, withIntermediateDirectories: true)
        }
        
        let destURL = booksDir.appendingPathComponent(sourceURL.lastPathComponent)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        return destURL
    }
}

// MARK: - UTType extension for EPUB

extension UTType {
    static let epub = UTType(importedAs: "org.idpf.epub-container")
}
