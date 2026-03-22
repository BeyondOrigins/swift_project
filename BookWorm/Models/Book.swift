import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var author: String
    var coverURL: String?
    var localFilePath: String?
    var fileFormat: BookFormat
    var totalPages: Int
    var currentPage: Int
    var dateAdded: Date
    var lastOpened: Date?
    var isFromOnline: Bool
    var onlineSource: OnlineSource?
    var onlineIdentifier: String?
    var bookDescription: String?
    
    // Content stored as parsed text (chapters)
    var parsedContent: [String]?
    
    @Relationship(deleteRule: .cascade, inverse: \BookNote.book)
    var notes: [BookNote]?
    
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
    
    var isFinished: Bool {
        currentPage >= totalPages && totalPages > 0
    }
    
    init(
        title: String,
        author: String,
        coverURL: String? = nil,
        localFilePath: String? = nil,
        fileFormat: BookFormat = .txt,
        totalPages: Int = 0,
        currentPage: Int = 0,
        isFromOnline: Bool = false,
        onlineSource: OnlineSource? = nil,
        onlineIdentifier: String? = nil,
        bookDescription: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.coverURL = coverURL
        self.localFilePath = localFilePath
        self.fileFormat = fileFormat
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.dateAdded = Date()
        self.lastOpened = nil
        self.isFromOnline = isFromOnline
        self.onlineSource = onlineSource
        self.onlineIdentifier = onlineIdentifier
        self.bookDescription = bookDescription
    }
}

// MARK: - Enums

enum BookFormat: String, Codable, CaseIterable {
    case fb2 = "fb2"
    case epub = "epub"
    case txt = "txt"
    case djvu = "djvu"
    case pdf = "pdf"
    
    var displayName: String {
        rawValue.uppercased()
    }
    
    var utType: String {
        switch self {
        case .fb2: return "public.xml"
        case .epub: return "org.idpf.epub-container"
        case .txt: return "public.plain-text"
        case .djvu: return "public.data"
        case .pdf: return "com.adobe.pdf"
        }
    }
}

enum OnlineSource: String, Codable {
    case googleBooks = "Google Books"
    case openLibrary = "Open Library"
    case gutenberg = "Project Gutenberg"
}
