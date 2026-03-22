import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Bindable var viewModel: NotesViewModel
    let context: ModelContext
    let note: BookNote?
    let book: Book?
    
    @State private var title: String
    @State private var content: String
    @State private var selectedColor: String
    @Environment(\.dismiss) private var dismiss
    
    private let colorOptions = [
        "#6366F1", // indigo
        "#EC4899", // pink
        "#F59E0B", // amber
        "#10B981", // emerald
        "#3B82F6", // blue
        "#8B5CF6", // violet
        "#EF4444", // red
        "#06B6D4", // cyan
    ]
    
    init(viewModel: NotesViewModel, context: ModelContext, note: BookNote?, book: Book?) {
        self.viewModel = viewModel
        self.context = context
        self.note = note
        self.book = book
        self._title = State(initialValue: note?.title ?? "")
        self._content = State(initialValue: note?.content ?? "")
        self._selectedColor = State(initialValue: note?.colorHex ?? "#6366F1")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Note title", text: $title)
                        .font(.headline)
                    
                    if let book = book ?? note?.book {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(.blue)
                            Text(book.title)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
                
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(colorOptions, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if selectedColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .onTapGesture {
                                        selectedColor = hex
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 250)
                        .font(.body)
                }
            }
            .navigationTitle(note == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveNote() {
        if let note = note {
            viewModel.updateNote(note, title: title, content: content, context: context)
            note.colorHex = selectedColor
            try? context.save()
        } else {
            let newNote = BookNote(
                book: book,
                title: title,
                content: content,
                colorHex: selectedColor
            )
            context.insert(newNote)
            try? context.save()
            viewModel.fetchNotes(context: context)
        }
    }
}
