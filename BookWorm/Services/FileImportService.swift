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
        .djvu,                // .djvu
        .data                 // fallback binary
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
        
        let fileName = sourceURL.lastPathComponent
        let destURL = booksDir.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        
        return destURL
    }

    static func resolveBookPath(_ savedPath: String) -> URL? {
        // If global path is saved — take the last 2 components
        // "Books/filename.pdf"
        let components = savedPath.components(separatedBy: "/")
        let relativePath: String
        
        if let booksIndex = components.lastIndex(of: "Books"),
           booksIndex + 1 < components.count {
            relativePath = components[booksIndex...].joined(separator: "/")
        } else {
            relativePath = components.last ?? savedPath
        }
        
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullURL = documentsDir.appendingPathComponent(relativePath)
        
        if FileManager.default.fileExists(atPath: fullURL.path) {
            return fullURL
        }
        
        // Fallback
        let justFileName = components.last ?? savedPath
        let fallbackURL = documentsDir
            .appendingPathComponent("Books")
            .appendingPathComponent(justFileName)
        
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            return fallbackURL
        }
        
        return nil
    }
}

// MARK: - UTType extension for EPUB

extension UTType {
    static let epub = UTType(importedAs: "org.idpf.epub-container")
    static let djvu = UTType(filenameExtension: "djvu") ?? .data
}
