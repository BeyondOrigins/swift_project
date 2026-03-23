import Foundation
import SwiftData

@Observable
final class GoalsViewModel {
    var goals: [ReadingGoal] = []
    var errorMessage: String?
    
    func fetchGoals(context: ModelContext) {
        let descriptor = FetchDescriptor<ReadingGoal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            goals = try context.fetch(descriptor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createGoal(
        title: String,
        type: GoalType,
        target: Int,
        periodDays: Int,
        notificationFrequency: Int,
        notificationHour: Int,
        notificationMinute: Int,
        context: ModelContext
    ) {
        let goal = ReadingGoal(
            title: title,
            goalType: type,
            targetValue: target,
            periodDays: periodDays,
            notificationFrequencyDays: notificationFrequency,
            notificationHour: notificationHour,
            notificationMinute: notificationMinute
        )
        
        context.insert(goal)
        try? context.save()
        
        NotificationService.shared.scheduleGoalNotifications(for: goal)
        fetchGoals(context: context)
    }
    
    func updateProgress(for goal: ReadingGoal, newValue: Int, context: ModelContext) {
        goal.currentValue = newValue
        try? context.save()
        
        if goal.currentValue >= goal.targetValue {
            NotificationService.shared.scheduleOneTimeReminder(
                title: "\(goal.title)",
                body: "🎉 Goal completed! You did it — \(goal.targetValue) \(goal.goalType.unitLabel)!",
                after: 1
            )
            deleteGoal(goal, context: context)
        } else {
            NotificationService.shared.updateGoalNotification(for: goal)
        }
    }
    
    func incrementProgress(for goal: ReadingGoal, by amount: Int = 1, context: ModelContext) {
        goal.currentValue += amount
        try? context.save()
        
        if goal.currentValue >= goal.targetValue {
            NotificationService.shared.scheduleOneTimeReminder(
                title: "\(goal.title)",
                body: "🎉 Goal completed! You did it — \(goal.targetValue) \(goal.goalType.unitLabel)!",
                after: 1
            )
            deleteGoal(goal, context: context)
        } else {
            NotificationService.shared.updateGoalNotification(for: goal)
        }
    }
    
    func toggleGoal(_ goal: ReadingGoal, context: ModelContext) {
        goal.isActive.toggle()
        try? context.save()
        
        if goal.isActive {
            NotificationService.shared.scheduleGoalNotifications(for: goal)
        } else {
            NotificationService.shared.removeNotifications(for: goal.id)
        }
    }
    
    func toggleNotification(for goal: ReadingGoal, context: ModelContext) {
        goal.notificationEnabled.toggle()
        try? context.save()
        
        if goal.notificationEnabled {
            NotificationService.shared.scheduleGoalNotifications(for: goal)
        } else {
            NotificationService.shared.removeNotifications(for: goal.id)
        }
    }
    
    func deleteGoal(_ goal: ReadingGoal, context: ModelContext) {
        NotificationService.shared.removeNotifications(for: goal.id)
        context.delete(goal)
        try? context.save()
        goals.removeAll { $0.id == goal.id }
    }
}
