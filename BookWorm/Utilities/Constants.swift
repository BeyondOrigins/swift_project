import Foundation

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
