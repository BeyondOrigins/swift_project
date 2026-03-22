import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = GoalsViewModel()
    @State private var showingEditor = false
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.goals.isEmpty {
                    emptyState
                } else {
                    goalsList
                }
            }
            .navigationTitle("Goals")
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
                GoalEditorView(viewModel: viewModel, context: context)
            }
            .task {
                viewModel.fetchGoals(context: context)
            }
        }
    }
    
    // MARK: - Goals List
    
    private var goalsList: some View {
        List {
            ForEach(viewModel.goals) { goal in
                GoalCardView(goal: goal, viewModel: viewModel, context: context)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteGoal(viewModel.goals[index], context: context)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            
            Text("No reading goals")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Set daily page goals or periodic book targets with smart reminders")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingEditor = true
            } label: {
                Label("Create Goal", systemImage: "plus.circle.fill")
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

// MARK: - Goal Card

struct GoalCardView: View {
    let goal: ReadingGoal
    @Bindable var viewModel: GoalsViewModel
    let context: ModelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: goal.goalType.icon)
                    .font(.title3)
                    .foregroundStyle(.indigo)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.headline)
                    
                    Text(goal.goalType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Active toggle
                Button {
                    viewModel.toggleGoal(goal, context: context)
                } label: {
                    Image(systemName: goal.isActive ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(goal.isActive ? .orange : .green)
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: goal.progress)
                    .tint(progressColor)
                
                HStack {
                    Text("\(goal.currentValue) / \(goal.targetValue) \(goal.goalType.unitLabel)")
                        .font(.caption)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text("\(Int(goal.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            }
            
            // Stats row
            HStack(spacing: 16) {
                if goal.goalType == .periodBooks {
                    Label("\(goal.daysRemaining) days left", systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Label(
                    goal.notificationEnabled ? "Notifications on" : "Notifications off",
                    systemImage: goal.notificationEnabled ? "bell.fill" : "bell.slash"
                )
                .font(.caption2)
                .foregroundStyle(goal.notificationEnabled ? .indigo : .secondary)
                .onTapGesture {
                    viewModel.toggleNotification(for: goal, context: context)
                }
                
                Spacer()
                
//                // Quick increment
//                Button {
//                    viewModel.incrementProgress(for: goal, context: context)
//                } label: {
//                    Label("+1", systemImage: "plus")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .padding(.horizontal, 10)
//                        .padding(.vertical, 4)
//                        .background(Color.indigo.opacity(0.1))
//                        .foregroundStyle(.indigo)
//                        .clipShape(Capsule())
//                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var progressColor: Color {
        if goal.progress >= 1.0 { return .green }
        if goal.isOnTrack { return .indigo }
        return .orange
    }
}

// MARK: - Goal Editor

struct GoalEditorView: View {
    @Bindable var viewModel: GoalsViewModel
    let context: ModelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var goalType: GoalType = .dailyPages
    @State private var targetValue: Int = 30
    @State private var periodDays: Int = 30
    @State private var notificationFrequency: Int = 1
    @State private var notificationHour: Int = 10
    @State private var notificationMinute: Int = 0
    
    private var notificationTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = notificationHour
                components.minute = notificationMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notificationHour = components.hour ?? 10
                notificationMinute = components.minute ?? 0
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Goal details") {
                    TextField("Goal name", text: $title)
                    
                    Picker("Type", selection: $goalType) {
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
                
                Section("Target") {
                    Stepper(
                        "\(targetValue) \(goalType.unitLabel)",
                        value: $targetValue,
                        in: 1...1000
                    )
                    
                    if goalType == .periodBooks {
                        Stepper(
                            "Period: \(periodDays) days",
                            value: $periodDays,
                            in: 7...365,
                            step: 7
                        )
                    }
                }
                
                Section("Notifications") {
                    if goalType == .dailyPages {
                        DatePicker("Reminder time", selection: notificationTime, displayedComponents: .hourAndMinute)
                    } else {
                        Stepper(
                            "Every \(notificationFrequency) day(s)",
                            value: $notificationFrequency,
                            in: 1...14
                        )
                        
                        DatePicker("Time", selection: notificationTime, displayedComponents: .hourAndMinute)
                    }
                }
                
//                Section {
//                    previewNotification
//                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard !title.isEmpty else { return }
                        viewModel.createGoal(
                            title: title,
                            type: goalType,
                            target: targetValue,
                            periodDays: goalType == .dailyPages ? 1 : periodDays,
                            notificationFrequency: goalType == .dailyPages ? 1 : notificationFrequency,
                            notificationHour: notificationHour,
                            notificationMinute: notificationMinute,
                            context: context
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Preview
    
//    private var previewNotification: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("Notification preview")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//            
//            HStack(alignment: .top, spacing: 10) {
//                Image(systemName: "bell.fill")
//                    .foregroundStyle(.indigo)
//                
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(title.isEmpty ? "My Reading Goal" : title)
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                    
//                    Text(previewBody)
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
//            }
//            .padding(12)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .background(Color(.systemGray6))
//            .clipShape(RoundedRectangle(cornerRadius: 12))
//        }
//    }
    
    private var previewBody: String {
        switch goalType {
        case .dailyPages:
            return "📖 Today's goal: \(targetValue) pages. Progress: 0/\(targetValue) (0%). Great pace! Keep it up!"
        case .periodBooks:
            return "📚 Goal: \(targetValue) books. Read so far: 0. \(periodDays) days remaining. Every page counts. Let's get back on track!"
        }
    }
}
