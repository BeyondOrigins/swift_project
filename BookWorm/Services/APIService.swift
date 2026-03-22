import Foundation

// MARK: - API Service

final class APIService {
    static let shared = APIService()
    private init() {}
    
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    
    // MARK: - Unified Search
    
    func searchBooks(query: String, source: OnlineSource) async throws -> [OnlineBook] {
        switch source {
        case .googleBooks:
            return try await searchGoogleBooks(query: query)
        case .openLibrary:
            return try await searchOpenLibrary(query: query)
        case .gutenberg:
            return try await searchGutenberg(query: query)
        }
    }
    
    // MARK: - Google Books API
    
    private func searchGoogleBooks(query: String) async throws -> [OnlineBook] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.googleapis.com/books/v1/volumes?q=\(encoded)&maxResults=20"
        
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        
        let result = try decoder.decode(GoogleBooksResponse.self, from: data)
        
        return (result.items ?? []).map { item in
            OnlineBook(
                id: item.id,
                title: item.volumeInfo.title,
                author: item.volumeInfo.authors?.joined(separator: ", ") ?? "Unknown",
                description: item.volumeInfo.description,
                coverURL: item.volumeInfo.imageLinks?.thumbnail?.replacingOccurrences(of: "http://", with: "https://"),
                pageCount: item.volumeInfo.pageCount ?? 0,
                source: .googleBooks,
                downloadURL: nil,
                previewURL: item.volumeInfo.previewLink,
                language: item.volumeInfo.language ?? "en"
            )
        }
    }
    
    // MARK: - Google Books Extended Preview

    func fetchGoogleBooksContent(volumeID: String) async throws -> String? {
        // Get all available pages
        let urlString = "https://www.googleapis.com/books/v1/volumes/\(volumeID)"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await session.data(from: url)
        
        struct VolumeDetail: Decodable {
            let volumeInfo: VolumeInfo
            struct VolumeInfo: Decodable {
                let description: String?
                let subtitle: String?
                let categories: [String]?
                let previewLink: String?
            }
            let accessInfo: AccessInfo?
            struct AccessInfo: Decodable {
                let epub: FormatInfo?
                let pdf: FormatInfo?
                struct FormatInfo: Decodable {
                    let isAvailable: Bool?
                    let downloadLink: String?
                    let acsTokenLink: String?
                }
                let webReaderLink: String?
            }
        }
        
        let detail = try decoder.decode(VolumeDetail.self, from: data)
        
        // Try to download EPUB if available without DRM
        if let epubLink = detail.accessInfo?.epub?.downloadLink {
            if let text = try? await downloadBookText(from: epubLink) {
                return text
            }
        }
        
        // Try to download PDF
        if let pdfLink = detail.accessInfo?.pdf?.downloadLink {
            if let text = try? await downloadBookText(from: pdfLink) {
                return text
            }
        }
        
        return nil
    }
    
    // MARK: - Open Library API
    
    private func searchOpenLibrary(query: String) async throws -> [OnlineBook] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://openlibrary.org/search.json?q=\(encoded)&limit=20"
        
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        
        let result = try decoder.decode(OpenLibraryResponse.self, from: data)
        
        return result.docs.prefix(20).map { doc in
            let coverId = doc.coverI
            let coverURL = coverId != nil ? "https://covers.openlibrary.org/b/id/\(coverId!)-M.jpg" : nil
            
            return OnlineBook(
                id: doc.key,
                title: doc.title,
                author: doc.authorName?.first ?? "Unknown",
                description: doc.firstSentence?.value,
                coverURL: coverURL,
                pageCount: doc.numberOfPagesMedian ?? 0,
                source: .openLibrary,
                downloadURL: nil,
                previewURL: doc.key.hasPrefix("/works/")
                    ? "https://openlibrary.org\(doc.key)" : nil,
                language: doc.language?.first ?? "en"
            )
        }
    }
    
    // MARK: - Open Library Full Text (via Internet Archive)

    func fetchOpenLibraryText(workKey: String) async throws -> String? {
        // Try to get the tetx edition
        let editionsURL = "https://openlibrary.org\(workKey)/editions.json?limit=5"
        guard let url = URL(string: editionsURL) else { return nil }
        
        let (data, _) = try await session.data(from: url)
        
        struct EditionsResponse: Decodable {
            let entries: [Edition]?
            struct Edition: Decodable {
                let ocaid: String?  // Internet Archive identifier
            }
        }
        
        let editions = try? decoder.decode(EditionsResponse.self, from: data)
        
        guard let ocaid = editions?.entries?.compactMap({ $0.ocaid }).first else {
            return nil
        }
        
        // Download text from Internet Archive
        let iaURL = "https://archive.org/download/\(ocaid)/\(ocaid)_djvu.txt"
        return try? await downloadBookText(from: iaURL)
    }
    
    // MARK: - Project Gutenberg API
    
    private func searchGutenberg(query: String) async throws -> [OnlineBook] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://gutendex.com/books/?search=\(encoded)"
        
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        
        let result = try decoder.decode(GutenbergResponse.self, from: data)
        
        return result.results.prefix(20).map { book in
            let author = book.authors.first
            let authorName = author != nil ? "\(author!.name)" : "Unknown"
            let coverURL = book.formats["image/jpeg"]
            let downloadURL = book.formats["text/plain; charset=utf-8"]
                ?? book.formats["text/plain; charset=us-ascii"]
                ?? book.formats["text/plain"]
                ?? book.formats["text/html; charset=utf-8"]
                ?? book.formats["text/html"]

            // Gutenberg might return zip - plain text needed
            let cleanDownloadURL: String? = {
                guard let url = downloadURL else { return nil }
                if url.hasSuffix(".zip") { return nil }
                return url
            }()
            
            return OnlineBook(
                id: String(book.id),
                title: book.title,
                author: authorName,
                description: book.subjects.prefix(3).joined(separator: ", "),
                coverURL: coverURL,
                pageCount: 0,
                source: .gutenberg,
                downloadURL: downloadURL,
                previewURL: cleanDownloadURL,
                language: book.languages.first ?? "en"
            )
        }
    }
    
    // MARK: - Download Book Text
    
    func downloadBookText(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        
        guard let text = String(data: data, encoding: .utf8) else {
            throw APIError.decodingFailed
        }
        return text
    }
    
    // MARK: - Validation
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - Online Book DTO

struct OnlineBook: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let description: String?
    let coverURL: String?
    let pageCount: Int
    let source: OnlineSource
    let downloadURL: String?
    let previewURL: String?
    let language: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(source)
    }
    
    static func == (lhs: OnlineBook, rhs: OnlineBook) -> Bool {
        lhs.id == rhs.id && lhs.source == rhs.source
    }
}

// MARK: - API Response Models

// Google Books
struct GoogleBooksResponse: Decodable {
    let items: [GoogleBookItem]?
}

struct GoogleBookItem: Decodable {
    let id: String
    let volumeInfo: GoogleVolumeInfo
}

struct GoogleVolumeInfo: Decodable {
    let title: String
    let authors: [String]?
    let description: String?
    let pageCount: Int?
    let imageLinks: GoogleImageLinks?
    let previewLink: String?
    let language: String?
}

struct GoogleImageLinks: Decodable {
    let thumbnail: String?
    let smallThumbnail: String?
}

// Open Library
struct OpenLibraryResponse: Decodable {
    let docs: [OpenLibraryDoc]
}

struct OpenLibraryDoc: Decodable {
    let key: String
    let title: String
    let authorName: [String]?
    let coverI: Int?
    let firstSentence: OpenLibraryText?
    let numberOfPagesMedian: Int?
    let language: [String]?
    
    enum CodingKeys: String, CodingKey {
        case key, title, language
        case authorName = "author_name"
        case coverI = "cover_i"
        case firstSentence = "first_sentence"
        case numberOfPagesMedian = "number_of_pages_median"
    }
}

struct OpenLibraryText: Decodable {
    let value: String?
    
    init(from decoder: Decoder) throws {
        // Can be string or object with "value" key
        if let container = try? decoder.singleValueContainer(),
           let str = try? container.decode(String.self) {
            self.value = str
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.value = try container.decodeIfPresent(String.self, forKey: .value)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case value
    }
}

// Gutenberg
struct GutenbergResponse: Decodable {
    let results: [GutenbergBook]
}

struct GutenbergBook: Decodable {
    let id: Int
    let title: String
    let authors: [GutenbergAuthor]
    let subjects: [String]
    let languages: [String]
    let formats: [String: String]
}

struct GutenbergAuthor: Decodable {
    let name: String
    let birthYear: Int?
    let deathYear: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case birthYear = "birth_year"
        case deathYear = "death_year"
    }
}

// MARK: - Errors

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
