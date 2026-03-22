import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = LibraryViewModel()
    @State private var showingImporter = false
    @State private var selectedBook: Book?
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.books.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    ScrollView {
                        filterBar
                        
                        if viewModel.filteredBooks.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.tertiary)
                                Text("No books match this filter")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button("Show all") {
                                    withAnimation(.snappy) {
                                        viewModel.selectedFilter = .all
                                        viewModel.searchText = ""
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.indigo)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(viewModel.filteredBooks) { book in
                                    BookCardView(book: book)
                                        .onTapGesture {
                                            selectedBook = book
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                viewModel.deleteBook(book, context: context)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                        }
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Library")
            .searchable(text: $viewModel.searchText, prompt: "Search books...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(LibraryViewModel.SortOrder.allCases, id: \.self) { order in
                            Button {
                                viewModel.sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if viewModel.sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: FileImportService.supportedTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await viewModel.importBook(from: url, context: context)
                        }
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .navigationDestination(item: $selectedBook) { book in
                ReaderView(book: book)
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                await viewModel.fetchBooks(context: context)
            }
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryViewModel.LibraryFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.snappy) {
                            viewModel.selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(viewModel.selectedFilter == filter ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                viewModel.selectedFilter == filter
                                    ? Color.indigo.opacity(0.15)
                                    : Color(.systemGray6)
                            )
                            .foregroundStyle(
                                viewModel.selectedFilter == filter
                                    ? .indigo
                                    : .secondary
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            
            Text("No books yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Import a book or discover one online")
                .foregroundStyle(.secondary)
            
            Button {
                showingImporter = true
            } label: {
                Label("Import Book", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Book Card

struct BookCardView: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: coverGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                
                if let coverURL = book.coverURL, let url = URL(string: coverURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        default:
                            bookPlaceholder
                        }
                    }
                } else {
                    bookPlaceholder
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            
            // Title & Author
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            // Progress bar
            HStack(spacing: 6) {
                ProgressView(value: book.progress)
                    .tint(book.isFinished ? .green : .indigo)
                
                Text("\(Int(book.progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            
            // Format badge
            HStack(spacing: 4) {
                Text(book.fileFormat.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                
                if book.isFromOnline {
                    Image(systemName: "globe")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
            }
        }
    }
    
    private var bookPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.8))
            
            Text(book.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 8)
        }
    }
    
    private var coverGradient: [Color] {
        // Generate a consistent gradient based on the book title hash
        let hash = abs(book.title.hashValue)
        let gradients: [[Color]] = [
            [.indigo, .purple],
            [.blue, .cyan],
            [.orange, .red],
            [.green, .teal],
            [.pink, .orange],
            [.purple, .blue],
            [.teal, .green],
            [.red, .pink],
        ]
        return gradients[hash % gradients.count]
    }
}
