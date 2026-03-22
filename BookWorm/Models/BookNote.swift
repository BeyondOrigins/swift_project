import Foundation
import SwiftData

@Model
final class BookNote {
    var id: UUID
    var book: Book?
    var title: String
    var content: String
    var pageReference: Int?
    var createdAt: Date
    var updatedAt: Date
    var colorHex: String
    
    // For node graph — position on canvas
    @Relationship(deleteRule: .cascade, inverse: \NoteNode.note)
    var nodes: [NoteNode]?
    
    init(
        book: Book? = nil,
        title: String,
        content: String = "",
        pageReference: Int? = nil,
        colorHex: String = "#6366F1"
    ) {
        self.id = UUID()
        self.book = book
        self.title = title
        self.content = content
        self.pageReference = pageReference
        self.createdAt = Date()
        self.updatedAt = Date()
        self.colorHex = colorHex
    }
}

@Model
final class NoteNode {
    var id: UUID
    var note: BookNote?
    var label: String
    var content: String
    var positionX: Double
    var positionY: Double
    var colorHex: String
    var connectedNodeIDs: [UUID]
    var createdAt: Date
    
    init(
        note: BookNote? = nil,
        label: String,
        content: String = "",
        positionX: Double = 100,
        positionY: Double = 100,
        colorHex: String = "#8B5CF6"
    ) {
        self.id = UUID()
        self.note = note
        self.label = label
        self.content = content
        self.positionX = positionX
        self.positionY = positionY
        self.colorHex = colorHex
        self.connectedNodeIDs = []
        self.createdAt = Date()
    }
}
