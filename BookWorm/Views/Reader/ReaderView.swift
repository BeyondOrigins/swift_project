import SwiftUI
import SwiftData

struct ReaderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    let book: Book
    @State private var viewModel: ReaderViewModel
    @State private var notesVM = NotesViewModel()
    @State private var showNoteCreator = false
    @GestureState private var dragOffset: CGFloat = 0
    
    init(book: Book) {
        self.book = book
        self._viewModel = State(initialValue: ReaderViewModel(book: book))
    }
    
    var body: some View {
        ZStack {
            
            VStack(spacing: 0) {
                // Content area
                ScrollView {
                    if viewModel.currentPageText.hasPrefix("[DJVU_PAGE:") {
                        DjVuPageView(
                            book: book,
                            pageIndex: viewModel.currentPageIndex
                        )
                        .padding(8)
                    } else if viewModel.currentPageText.hasPrefix("[PDF_PAGE:") {
                        PDFPageImageView(
                            book: book,
                            pageIndex: viewModel.currentPageIndex
                        )
                        .padding(8)
                    } else {
                        Text(viewModel.currentPageText)
                            .font(.system(size: viewModel.fontSize))
                            .lineSpacing(viewModel.lineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            if value.translation.width < -50 {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    viewModel.goToNextPage()
                                }
                            } else if value.translation.width > 50 {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    viewModel.goToPreviousPage()
                                }
                            }
                        }
                )
                
                Divider()
                
                bottomBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(book.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text("\(viewModel.progressPercent)%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showNoteCreator = true
                    } label: {
                        Image(systemName: "note.text.badge.plus")
                    }
                    
                    Button {
                        viewModel.isShowingSettings.toggle()
                    } label: {
                        Image(systemName: "textformat.size")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingSettings) {
            ReaderSettingsView(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showNoteCreator) {
            NoteCreatorSheet(
                book: book,
                pageReference: viewModel.currentPageIndex + 1,
                notesVM: notesVM,
                context: context
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            viewModel.setOnPageRead { pagesRead, book in
                // Update all dailyPages-goals
                let descriptor = FetchDescriptor<ReadingGoal>()
                if let goals = try? context.fetch(descriptor) {
                    let goalsVM = GoalsViewModel()
                    for goal in goals where goal.isActive && goal.goalType == .dailyPages {
                        goalsVM.incrementProgress(for: goal, by: pagesRead, context: context)
                    }
                    // If book is finished - update periodBooks-goals
                    if book.isFinished {
                        for goal in goals where goal.isActive && goal.goalType == .periodBooks {
                            goalsVM.incrementProgress(for: goal, by: 1, context: context)
                        }
                    }
                }
            }
        }
        .onDisappear {
            try? context.save()
            if book.fileFormat == .djvu {
                Task { await DjVuRenderService.shared.closeDocument() }
            }
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Page slider
            Slider(
                value: Binding(
                    get: { Double(viewModel.currentPageIndex) },
                    set: { viewModel.goToPage(Int($0)) }
                ),
                in: 0...Double(max(viewModel.pages.count - 1, 1)),
                step: 1
            )
            .tint(.indigo)
            .padding(.horizontal)
            
            // Navigation buttons
            HStack {
                Button {
                    withAnimation { viewModel.goToPreviousPage() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .frame(width: 44, height: 36)
                }
                .disabled(viewModel.currentPageIndex == 0)
                
                Spacer()
                
                Text(viewModel.pageLabel)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    withAnimation { viewModel.goToNextPage() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .frame(width: 44, height: 36)
                }
                .disabled(viewModel.currentPageIndex >= viewModel.pages.count - 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Reader Settings

struct ReaderSettingsView: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Typography") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font size")
                            Spacer()
                            Text("\(Int(viewModel.fontSize))pt")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $viewModel.fontSize, in: 12...32, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Line spacing")
                            Spacer()
                            Text("\(Int(viewModel.lineSpacing))pt")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $viewModel.lineSpacing, in: 2...20, step: 1)
                    }
                }
                
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Quick Note Creator Sheet

struct NoteCreatorSheet: View {
    let book: Book
    let pageReference: Int
    @State var notesVM: NotesViewModel
    let context: ModelContext
    
    @State private var noteTitle = ""
    @State private var noteContent = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Note title", text: $noteTitle)
                    
                    HStack {
                        Text("Page")
                        Spacer()
                        Text("\(pageReference)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Content") {
                    TextEditor(text: $noteContent)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !noteTitle.isEmpty else { return }
                        _ = notesVM.createNote(
                            for: book,
                            title: noteTitle,
                            content: noteContent,
                            pageReference: pageReference,
                            context: context
                        )
                        dismiss()
                    }
                    .disabled(noteTitle.isEmpty)
                }
            }
        }
    }
}
