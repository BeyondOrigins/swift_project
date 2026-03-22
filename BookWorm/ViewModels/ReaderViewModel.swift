import Foundation
import SwiftData

@Observable
final class ReaderViewModel {
    var book: Book
    var currentPageIndex: Int
    var pages: [String]
    var fontSize: Double
    var lineSpacing: Double
    var isShowingSettings: Bool = false
    var isShowingNoteEditor: Bool = false
        
    // to track the pages read
    private var sessionStartPage: Int
    var pagesReadInSession: Int { max(currentPageIndex - sessionStartPage, 0) }
    private(set) var onPageRead: ((Int, Book) -> Void)?
    init(book: Book) {
        self.book = book
        let startPage = max(book.currentPage - 1, 0)
        self.currentPageIndex = startPage
        self.sessionStartPage = startPage
        self.pages = book.parsedContent ?? ["No content available."]
        self.fontSize = UserDefaults.standard.double(forKey: "readerFontSize").clamped(to: 12...32, default: 18)
        self.lineSpacing = UserDefaults.standard.double(forKey: "readerLineSpacing").clamped(to: 2...20, default: 8)
    }
    
    var currentPageText: String {
        guard currentPageIndex >= 0, currentPageIndex < pages.count else {
            return "No content."
        }
        return pages[currentPageIndex]
    }
    
    var pageLabel: String {
        "\(currentPageIndex + 1) / \(pages.count)"
    }
    
    var progressPercent: Int {
        guard pages.count > 0 else { return 0 }
        return Int((Double(currentPageIndex + 1) / Double(pages.count)) * 100)
    }
    
    func goToNextPage() {
        guard currentPageIndex < pages.count - 1 else { return }
        currentPageIndex += 1
        updateBookProgress()
    }
    
    func goToPreviousPage() {
        guard currentPageIndex > 0 else { return }
        currentPageIndex -= 1
        updateBookProgress()
    }
    
    func goToPage(_ page: Int) {
        let clamped = max(0, min(page, pages.count - 1))
        currentPageIndex = clamped
        updateBookProgress()
    }
        
    func setOnPageRead(_ handler: @escaping (Int, Book) -> Void) {
        self.onPageRead = handler
    }

    private func updateBookProgress() {
        let oldPage = book.currentPage
        book.currentPage = currentPageIndex + 1
        book.lastOpened = Date()
        
        let pagesAdvanced = book.currentPage - oldPage
        if pagesAdvanced > 0 {
            onPageRead?(pagesAdvanced, book)
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(fontSize, forKey: "readerFontSize")
        UserDefaults.standard.set(lineSpacing, forKey: "readerLineSpacing")
    }
}

// MARK: - Double Clamped Extension

extension Double {
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        if self == 0 { return defaultValue }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
