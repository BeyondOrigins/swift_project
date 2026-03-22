import SwiftUI
import SwiftData

struct DiscoveryView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = DiscoveryViewModel()
    @State private var libraryVM = LibraryViewModel()
    @State private var selectedBook: OnlineBook?
    @State private var addedBookIDs: Set<String> = []
    @Query private var libraryBooks: [Book]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Source picker
                sourcePicker
                
                // Results
                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Searching \(viewModel.selectedSource.rawValue)...")
                    Spacer()
                } else if viewModel.searchResults.isEmpty && viewModel.hasSearched {
                    Spacer()
                    emptyResults
                    Spacer()
                } else if viewModel.searchResults.isEmpty {
                    Spacer()
                    welcomeState
                    Spacer()
                } else {
                    resultsList
                }
            }
            .navigationTitle("Discover")
            .searchable(text: $viewModel.searchQuery, prompt: "Search books online...")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.searchAllSources() }
                    } label: {
                        Label("Search all", systemImage: "magnifyingglass")
                    }
                    .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(item: $selectedBook) { book in
                OnlineBookDetailView(
                    book: book,
                    isAdded: addedBookIDs.contains(book.id),
                    onAdd: {
                        Task {
                            await libraryVM.addOnlineBook(book, context: context)
                            addedBookIDs.insert(book.id)
                        }
                    },
                    onRemove: {
                        removeOnlineBook(book)
                    }
                )
                .presentationDetents([.large])
            }
            .onAppear {
                syncAddedIDs()
            }
            .onChange(of: libraryBooks.count) {
                syncAddedIDs()
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Sync online books
    
    private func syncAddedIDs() {
        addedBookIDs = Set(
            libraryBooks
                .filter { $0.isFromOnline }
                .compactMap { $0.onlineIdentifier }
        )
    }
    
    private func removeOnlineBook(_ onlineBook: OnlineBook) {
        if let bookToDelete = libraryBooks.first(where: { $0.onlineIdentifier == onlineBook.id }) {
            libraryVM.deleteBook(bookToDelete, context: context)
            addedBookIDs.remove(onlineBook.id)
        }
    }
    
    // MARK: - Source Picker
    
    private var sourcePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(OnlineSource.allCases, id: \.self) { source in
                    Button {
                        viewModel.selectedSource = source
                        if viewModel.hasSearched {
                            Task { await viewModel.search() }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: sourceIcon(source))
                                .font(.caption)
                            Text(source.rawValue)
                                .font(.subheadline)
                        }
                        .fontWeight(viewModel.selectedSource == source ? .semibold : .regular)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedSource == source
                            ? Color.indigo.opacity(0.15)
                            : Color(.systemGray6)
                        )
                        .foregroundStyle(
                            viewModel.selectedSource == source ? .indigo : .secondary
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Results List
    
    private var resultsList: some View {
        List(viewModel.searchResults) { book in
            OnlineBookRow(book: book, isAdded: addedBookIDs.contains(book.id))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedBook = book
                }
        }
        .listStyle(.plain)
    }
    
    // MARK: - States
    
    private var welcomeState: some View {
        VStack(spacing: 14) {
            Image(systemName: "globe.americas")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            
            Text("Find your next read")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Search across Google Books, Open Library, and Project Gutenberg")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var emptyResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No results found")
                .font(.headline)
            
            Text("Try a different search or source")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func sourceIcon(_ source: OnlineSource) -> String {
        switch source {
        case .googleBooks: return "g.circle.fill"
        case .openLibrary: return "building.columns.fill"
        case .gutenberg: return "scroll.fill"
        }
    }
}

// MARK: - Online Book Row

struct OnlineBookRow: View {
    let book: OnlineBook
    let isAdded: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            // Cover
            if let coverURL = book.coverURL, let url = URL(string: coverURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    default:
                        coverPlaceholder
                    }
                }
            } else {
                coverPlaceholder
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Label(book.source.rawValue, systemImage: "globe")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    
                    if book.pageCount > 0 {
                        Text("\(book.pageCount) pages")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                if isAdded {
                    Text("In library")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(.systemGray5))
            .frame(width: 56, height: 80)
            .overlay {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Online Book Detail

struct OnlineBookDetailView: View {
    let book: OnlineBook
    let isAdded: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Cover
                    if let coverURL = book.coverURL, let url = URL(string: coverURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 8)
                            default:
                                largeCoverPlaceholder
                            }
                        }
                    } else {
                        largeCoverPlaceholder
                    }
                    
                    // Info
                    VStack(spacing: 8) {
                        Text(book.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(book.author)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 16) {
                            Label(book.source.rawValue, systemImage: "globe")
                            
                            if book.pageCount > 0 {
                                Label("\(book.pageCount) pages", systemImage: "doc")
                            }
                            
                            Label(book.language.uppercased(), systemImage: "character.bubble")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    // Description
                    if let description = book.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(nil)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                    
                    // Add button
                    Button {
                        if isAdded {
                            onRemove()
                        } else {
                            onAdd()
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: isAdded ? "trash" : "plus")
                            Text(isAdded ? "Remove from Library" : "Add to Library")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isAdded ? Color.red : Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    
                    // Preview link
                    if let previewURL = book.previewURL, let url = URL(string: previewURL) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "safari")
                                Text("Open in Browser")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var largeCoverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [.indigo.opacity(0.6), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 180, height: 260)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(book.title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 16)
                }
            }
    }
}
