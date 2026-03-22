import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Permission
    
    func requestPermission() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            print("Notifications \(granted ? "granted" : "denied")")
        }
    }
    
    // MARK: - Schedule Goal Notifications
    
    func scheduleGoalNotifications(for goal: ReadingGoal) {
        // Remove old notifications for this goal
        removeNotifications(for: goal.id)
        
        guard goal.notificationEnabled, goal.isActive else { return }
        
        let progressPercent = Int(goal.progress * 100)
        let message = goal.motivationalMessage
        
        let body: String
        switch goal.goalType {
        case .dailyPages:
            body = "📖 Today's goal: \(goal.targetValue) pages. " +
                   "Progress: \(goal.currentValue)/\(goal.targetValue) (\(progressPercent)%). " +
                   message
        case .periodBooks:
            body = "📚 Goal: \(goal.targetValue) books. " +
                   "Read so far: \(goal.currentValue). " +
                   "\(goal.daysRemaining) days remaining. " +
                   message
        }
        
        // Schedule repeating notifications
        let content = UNMutableNotificationContent()
        content.title = goal.title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "READING_GOAL"
        
        if goal.goalType == .dailyPages {
            // Daily notification at specified time
            var dateComponents = DateComponents()
            dateComponents.hour = goal.notificationHour
            dateComponents.minute = goal.notificationMinute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "goal-\(goal.id.uuidString)-daily",
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Failed to schedule daily notification: \(error)")
                }
            }
        } else {
            // Periodic notification every N days
            let intervalSeconds = TimeInterval(goal.notificationFrequencyDays * 24 * 60 * 60)
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(intervalSeconds, 60),
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: "goal-\(goal.id.uuidString)-periodic",
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Failed to schedule periodic notification: \(error)")
                }
            }
        }
    }
    
    // MARK: - Update Notification Content
    
    func updateGoalNotification(for goal: ReadingGoal) {
        // Re-schedule with updated progress
        scheduleGoalNotifications(for: goal)
    }
    
    // MARK: - Remove Notifications
    
    func removeNotifications(for goalID: UUID) {
        let identifiers = [
            "goal-\(goalID.uuidString)-daily",
            "goal-\(goalID.uuidString)-periodic"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func removeAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Schedule One-Time Reminder
    
    func scheduleOneTimeReminder(title: String, body: String, after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        center.add(request, withCompletionHandler: nil)
    }
}
