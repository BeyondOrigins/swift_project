import Foundation

@Observable
final class DiscoveryViewModel {
    var searchQuery: String = ""
    var selectedSource: OnlineSource = .googleBooks
    var searchResults: [OnlineBook] = []
    var isSearching: Bool = false
    var errorMessage: String?
    var hasSearched: Bool = false
    
    func search() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        hasSearched = true
        
        do {
            searchResults = try await APIService.shared.searchBooks(
                query: searchQuery,
                source: selectedSource
            )
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
        }
        
        isSearching = false
    }
    
    func searchAllSources() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        hasSearched = true
        
        var allResults: [OnlineBook] = []
        
        for source in OnlineSource.allCases {
            do {
                let results = try await APIService.shared.searchBooks(
                    query: searchQuery,
                    source: source
                )
                allResults.append(contentsOf: results)
            } catch {
                print("Error searching \(source.rawValue): \(error)")
            }
        }
        
        searchResults = allResults
        isSearching = false
    }
}
