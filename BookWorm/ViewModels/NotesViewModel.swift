import Foundation
import SwiftData

@Observable
final class NotesViewModel {
    var notes: [BookNote] = []
    var selectedNote: BookNote?
    var errorMessage: String?
    
    func fetchNotes(for book: Book? = nil, context: ModelContext) {
        var descriptor = FetchDescriptor<BookNote>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        if let book = book {
            let bookID = book.id
            descriptor.predicate = #Predicate<BookNote> { note in
                note.book?.id == bookID
            }
        }
        
        do {
            notes = try context.fetch(descriptor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createNote(
        for book: Book?,
        title: String,
        content: String,
        pageReference: Int? = nil,
        context: ModelContext
    ) -> BookNote {
        let note = BookNote(
            book: book,
            title: title,
            content: content,
            pageReference: pageReference
        )
        context.insert(note)
        try? context.save()
        fetchNotes(for: book, context: context)
        return note
    }
    
    func updateNote(_ note: BookNote, title: String, content: String, context: ModelContext) {
        note.title = title
        note.content = content
        note.updatedAt = Date()
        try? context.save()
    }
    
    func deleteNote(_ note: BookNote, context: ModelContext) {
        context.delete(note)
        try? context.save()
        notes.removeAll { $0.id == note.id }
    }
    
    // MARK: - Node Graph Operations
    
    func addNode(
        to note: BookNote,
        label: String,
        content: String = "",
        x: Double,
        y: Double,
        context: ModelContext
    ) -> NoteNode {
        let node = NoteNode(
            note: note,
            label: label,
            content: content,
            positionX: x,
            positionY: y
        )
        context.insert(node)
        try? context.save()
        return node
    }
    
    func connectNodes(_ nodeA: NoteNode, to nodeB: NoteNode, context: ModelContext) {
        if !nodeA.connectedNodeIDs.contains(nodeB.id) {
            nodeA.connectedNodeIDs.append(nodeB.id)
        }
        if !nodeB.connectedNodeIDs.contains(nodeA.id) {
            nodeB.connectedNodeIDs.append(nodeA.id)
        }
        try? context.save()
    }
    
    func disconnectNodes(_ nodeA: NoteNode, from nodeB: NoteNode, context: ModelContext) {
        nodeA.connectedNodeIDs.removeAll { $0 == nodeB.id }
        nodeB.connectedNodeIDs.removeAll { $0 == nodeA.id }
        try? context.save()
    }
    
    func deleteNode(_ node: NoteNode, allNodes: [NoteNode], context: ModelContext) {
        // Remove references from connected nodes
        for otherNode in allNodes where otherNode.connectedNodeIDs.contains(node.id) {
            otherNode.connectedNodeIDs.removeAll { $0 == node.id }
        }
        context.delete(node)
        try? context.save()
    }
    
    func updateNodePosition(_ node: NoteNode, x: Double, y: Double, context: ModelContext) {
        node.positionX = x
        node.positionY = y
        try? context.save()
    }
}
