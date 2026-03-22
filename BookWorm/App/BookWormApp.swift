import SwiftUI
import SwiftData

@main
struct BookWormApp: App {
    
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                Book.self,
                ReadingGoal.self,
                BookNote.self,
                NoteNode.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
        
        NotificationService.shared.requestPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
