import Foundation
import SwiftData

@Model
final class ReadingGoal {
    var id: UUID
    var title: String
    var goalType: GoalType
    var targetValue: Int          // Pages per day OR books per period
    var currentValue: Int         // Pages read today OR books finished
    var periodDays: Int           // Duration in days (1 for daily, 30 for monthly, etc.)
    var startDate: Date
    var endDate: Date
    var notificationEnabled: Bool
    var notificationFrequencyDays: Int  // How often to send reminders
    var notificationHour: Int           // Hour of day to send (0-23)
    var notificationMinute: Int
    var isActive: Bool
    var createdAt: Date
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }
    
    var isOnTrack: Bool {
        let totalDays = max(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1, 1)
        let elapsedDays = max(Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0, 1)
        let expectedProgress = Double(elapsedDays) / Double(totalDays)
        return progress >= expectedProgress * 0.8
    }
    
    var daysRemaining: Int {
        max(Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0, 0)
    }
    
    var motivationalMessage: String {
        if progress >= 1.0 {
            return "🎉 Goal completed! Amazing work!"
        } else if isOnTrack {
            let messages = [
                "Great pace! Keep it up!",
                "You're on track — don't stop now!",
                "Solid progress, keep reading!",
                "Right on schedule. Excellent discipline!"
            ]
            return messages.randomElement() ?? messages[0]
        } else {
            let messages = [
                "A bit behind — a few extra pages today can fix that!",
                "Time to catch up — grab your book!",
                "Every page counts. Let's get back on track!",
                "Don't worry, there's still time to reach your goal!"
            ]
            return messages.randomElement() ?? messages[0]
        }
    }
    
    init(
        title: String,
        goalType: GoalType,
        targetValue: Int,
        periodDays: Int = 1,
        startDate: Date = Date(),
        notificationFrequencyDays: Int = 1,
        notificationHour: Int = 10,
        notificationMinute: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.goalType = goalType
        self.targetValue = targetValue
        self.currentValue = 0
        self.periodDays = periodDays
        self.startDate = startDate
        self.endDate = Calendar.current.date(byAdding: .day, value: periodDays, to: startDate) ?? startDate
        self.notificationEnabled = true
        self.notificationFrequencyDays = notificationFrequencyDays
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.isActive = true
        self.createdAt = Date()
    }
}
