import Foundation
import SwiftData
import SwiftUI

@Observable
final class LibraryViewModel {
    var books: [Book] = []
    var searchText: String = ""
    var selectedFilter: LibraryFilter = .all
    var isImporting: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var sortOrder: SortOrder = .dateAdded
    
    enum LibraryFilter: String, CaseIterable {
        case all = "All"
        case reading = "Reading"
        case finished = "Finished"
        case fromOnline = "Online"
        case local = "Local"
    }
    
    enum SortOrder: String, CaseIterable {
        case dateAdded = "Date added"
        case title = "Title"
        case author = "Author"
        case progress = "Progress"
    }
    
    var filteredBooks: [Book] {
        var result = books
        
        // Apply filter
        switch selectedFilter {
        case .all: break
        case .reading:
            result = result.filter { !$0.isFinished && $0.currentPage > 0 }
        case .finished:
            result = result.filter { $0.isFinished }
        case .fromOnline:
            result = result.filter { $0.isFromOnline }
        case .local:
            result = result.filter { !$0.isFromOnline }
        }
        
        // Apply search
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sort
        switch sortOrder {
        case .dateAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .title:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .author:
            result.sort { $0.author.localizedCompare($1.author) == .orderedAscending }
        case .progress:
            result.sort { $0.progress > $1.progress }
        }
        
        return result
    }
    
    // MARK: - Import Local Book
    
    func importBook(from url: URL, context: ModelContext) async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let format = FileImportService.shared.detectFormat(from: url) else {
                errorMessage = "Unsupported file format"
                isLoading = false
                return
            }
            
            // Copy file to app documents
            let localURL = try FileImportService.shared.copyToDocuments(from: url)
            
            // Parse the book
            let parsed = try await BookParserService.shared.parseBook(at: localURL, format: format)
            
            // Create Book model
            let book = Book(
                title: parsed.title,
                author: parsed.author,
                localFilePath: localURL.path,
                fileFormat: format,
                totalPages: parsed.totalPages,
                isFromOnline: false
            )
            book.parsedContent = parsed.content
            
            context.insert(book)
            try context.save()
            
            await fetchBooks(context: context)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Add Online Book to Library
    
    func addOnlineBook(_ onlineBook: OnlineBook, context: ModelContext) async {
        isLoading = true
        
        let book = Book(
            title: onlineBook.title,
            author: onlineBook.author,
            coverURL: onlineBook.coverURL,
            fileFormat: .txt,
            totalPages: max(onlineBook.pageCount, 1),
            isFromOnline: true,
            onlineSource: onlineBook.source,
            onlineIdentifier: onlineBook.id,
            bookDescription: onlineBook.description
        )
        
        var downloadedText: String?
        
        switch onlineBook.source {
        case .gutenberg:
            // Gutenberg — straightforward text downloading
            if let downloadURL = onlineBook.downloadURL {
                do {
                    downloadedText = try await APIService.shared.downloadBookText(from: downloadURL)
                } catch {
                    // Try alt URL
                    let altURL = "https://www.gutenberg.org/cache/epub/\(onlineBook.id)/pg\(onlineBook.id).txt"
                    downloadedText = try? await APIService.shared.downloadBookText(from: altURL)
                }
            } else {
                // If no downloadURL — construct it manually
                let altURL = "https://www.gutenberg.org/cache/epub/\(onlineBook.id)/pg\(onlineBook.id).txt"
                downloadedText = try? await APIService.shared.downloadBookText(from: altURL)
            }
            
        case .openLibrary:
            // OpenLibrary — try Internet Archive
            downloadedText = try? await APIService.shared.fetchOpenLibraryText(workKey: onlineBook.id)
            
        case .googleBooks:
            // Google Books — try available formats
            downloadedText = try? await APIService.shared.fetchGoogleBooksContent(volumeID: onlineBook.id)
        }
        
        if let text = downloadedText, !text.isEmpty {
            let pages = BookParserService.shared.splitIntoPages(text)
            book.parsedContent = pages
            book.totalPages = pages.count
        } else {
            // Fallback — desc + web-reader link
            let fallbackContent: String
            switch onlineBook.source {
            case .googleBooks:
                fallbackContent = """
                Full text is not available through Google Books API (DRM-protected).
                
                \(onlineBook.description ?? "No description.")
                
                You can read this book via Google's web reader:
                \(onlineBook.previewURL ?? "https://books.google.com")
                """
            case .openLibrary:
                fallbackContent = """
                Full text is not available on Open Library for this edition.
                
                \(onlineBook.description ?? "No description.")
                
                Try borrowing it at:
                https://openlibrary.org\(onlineBook.id)
                """
            case .gutenberg:
                fallbackContent = """
                Could not download text from Project Gutenberg.
                
                Try visiting: https://www.gutenberg.org/ebooks/\(onlineBook.id)
                """
            }
            
            book.parsedContent = BookParserService.shared.splitIntoPages(fallbackContent)
            book.totalPages = book.parsedContent?.count ?? 1
        }
        
        context.insert(book)
        try? context.save()
        
        await fetchBooks(context: context)
        isLoading = false
    }
    
    // MARK: - Fetch
    
    func fetchBooks(context: ModelContext) async {
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        do {
            books = try context.fetch(descriptor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Delete
    
    func deleteBook(_ book: Book, context: ModelContext) {
        // Remove local file if exists
        if let path = book.localFilePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        context.delete(book)
        try? context.save()
        books.removeAll { $0.id == book.id }
    }
}
