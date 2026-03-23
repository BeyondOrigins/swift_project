import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

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

enum GoalType: String, Codable, CaseIterable {
    case dailyPages = "Daily pages"
    case periodBooks = "Books in period"
    
    var icon: String {
        switch self {
        case .dailyPages: return "doc.text"
        case .periodBooks: return "book.closed.fill"
        }
    }
    
    var unitLabel: String {
        switch self {
        case .dailyPages: return "pages"
        case .periodBooks: return "books"
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case networkError(String)
    case httpError(Int)
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let msg): return "Network error: \(msg)"
        case .httpError(let code): return "HTTP error: \(code)"
        case .decodingFailed: return "Failed to decode response"
        }
    }
}

enum Constants {
    enum App {
        static let name = "BookWorm"
        static let version = "1.0.0"
    }
    
    enum Reader {
        static let defaultFontSize: Double = 18
        static let minFontSize: Double = 12
        static let maxFontSize: Double = 32
        static let defaultLineSpacing: Double = 8
        static let charsPerPage: Int = 2000
    }
    
    enum API {
        static let googleBooksBase = "https://www.googleapis.com/books/v1/volumes"
        static let openLibraryBase = "https://openlibrary.org/search.json"
        static let gutenbergBase = "https://gutendex.com/books"
        static let maxSearchResults = 20
    }
    
    enum Notifications {
        static let defaultHour = 10
        static let defaultMinute = 0
        static let categoryID = "READING_GOAL"
    }
    
    enum NodeGraph {
        static let defaultNodeWidth: CGFloat = 120
        static let defaultNodeHeight: CGFloat = 60
        static let minScale: CGFloat = 0.3
        static let maxScale: CGFloat = 3.0
        static let connectionThreshold: CGFloat = 60
    }
}
