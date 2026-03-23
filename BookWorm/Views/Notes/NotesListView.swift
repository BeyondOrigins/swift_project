import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = NotesViewModel()
    @State private var showingEditor = false
    @State private var selectedNote: BookNote?
    @State private var graphNote: BookNote?
    @State private var searchText = ""
    
    var filteredNotes: [BookNote] {
        if searchText.isEmpty {
            return viewModel.notes
        }
        return viewModel.notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.notes.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle("Notes")
            .searchable(text: $searchText, prompt: "Search notes...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                NoteEditorView(viewModel: viewModel, context: context, note: nil)
            }
            .sheet(item: $selectedNote) { note in
                NoteEditorView(viewModel: viewModel, context: context, note: note)
            }
            .fullScreenCover(item: $graphNote) { note in
                NodeGraphView(note: note, viewModel: viewModel, context: context)
            }
            .onChange(of: graphNote) {
                if graphNote == nil {
                    viewModel.fetchNotes(context: context)
                }
            }
            .task {
                viewModel.fetchNotes(context: context)
            }
        }
    }
    
    // MARK: - Notes List
    
    private var notesList: some View {
        List {
            ForEach(filteredNotes) { note in
                VStack(spacing: 0) {
                    NoteRowView(note: note)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedNote = note
                        }
                    Button {
                        graphNote = note
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .font(.caption)
                            Text("Open Graph")
                                .font(.caption)
                            
                            Spacer()
                            
                            if let nodeCount = note.nodes?.count, nodeCount > 0 {
                                Text("\(nodeCount) nodes")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.purple.opacity(0.08))
                        .foregroundStyle(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteNote(note, context: context)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            
            Text("No notes yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create text notes or visual node graphs for your books")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingEditor = true
            } label: {
                Label("Create Note", systemImage: "note.text.badge.plus")
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

// MARK: - Note Row

struct NoteRowView: View {
    let note: BookNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color(hex: note.colorHex) ?? .indigo)
                    .frame(width: 10, height: 10)
                
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
            }
            
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 12) {
                if let book = note.book {
                    Label(book.title, systemImage: "book.closed")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
                
                if let page = note.pageReference {
                    Label("Page \(page)", systemImage: "doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(note.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
