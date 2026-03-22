import UIKit
import djvu

actor DjVuRenderService {
    static let shared = DjVuRenderService()
    
    private var openDocument: Djvu?
    private var openFilePath: String?
    private var cache: [Int: UIImage] = [:]
    private let maxCachedPages = 5
    
    private init() {}
    
    func renderPage(fileURL: URL, page: Int, dpi: Int = 200) -> UIImage? {
        // Reopen document only if file has changed
        if openFilePath != fileURL.path {
            openDocument = try? Djvu(url: fileURL)
            openFilePath = fileURL.path
            cache.removeAll()
        }
        
        guard let doc = openDocument else { return nil }
        if let cached = cache[page] {
            return cached
        }
        
        guard let image = try? doc.getImage(page: page, dpi: dpi, maxSideSize: 1600) else {
            return nil
        }
        
        if cache.count >= maxCachedPages {
            let sortedKeys = cache.keys.sorted { abs($0 - page) > abs($1 - page) }
            if let farthest = sortedKeys.first {
                cache.removeValue(forKey: farthest)
            }
        }
        cache[page] = image
        
        return image
    }
    
    func closeDocument() {
        openDocument = nil
        openFilePath = nil
        cache.removeAll()
    }
}
