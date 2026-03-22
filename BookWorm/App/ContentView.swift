import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .library
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    enum Tab: String, CaseIterable {
        case library = "Library"
        case discover = "Discover"
        case goals = "Goals"
        case notes = "Notes"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .library: return "books.vertical.fill"
            case .discover: return "globe"
            case .goals: return "target"
            case .notes: return "note.text"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label(Tab.library.rawValue, systemImage: Tab.library.icon)
                }
                .tag(Tab.library)
            
            DiscoveryView()
                .tabItem {
                    Label(Tab.discover.rawValue, systemImage: Tab.discover.icon)
                }
                .tag(Tab.discover)
            
            GoalsView()
                .tabItem {
                    Label(Tab.goals.rawValue, systemImage: Tab.goals.icon)
                }
                .tag(Tab.goals)
            
            NotesListView()
                .tabItem {
                    Label(Tab.notes.rawValue, systemImage: Tab.notes.icon)
                }
                .tag(Tab.notes)
            
            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(.indigo)
        .preferredColorScheme(appTheme.colorScheme)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("readerFontSize") private var readerFontSize: Double = 18
    @AppStorage("readerLineSpacing") private var readerLineSpacing: Double = 8
    @AppStorage("darkModeReader") private var darkModeReader: Bool = false
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Label(theme.rawValue, systemImage: theme.icon)
                                .tag(theme)
                        }
                    }
                }
                Section("Reader defaults") {
                    HStack {
                        Text("Font size")
                        Spacer()
                        Text("\(Int(readerFontSize))pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $readerFontSize, in: 12...32, step: 1)
                    
                    HStack {
                        Text("Line spacing")
                        Spacer()
                        Text("\(Int(readerLineSpacing))pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $readerLineSpacing, in: 2...20, step: 1)
                    
                    Toggle("Dark reader background", isOn: $darkModeReader)
                }
                
                Section("Notifications") {
                    Button("Reset notification permissions") {
                        NotificationService.shared.requestPermission()
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
