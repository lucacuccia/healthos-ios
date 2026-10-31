import Foundation
import UserNotifications

/// Reminds the user to come back and save a workout they left in progress.
/// Scheduled when the app is backgrounded with unsaved workout data, cancelled
/// as soon as the app comes back to the foreground or the workout is saved.
enum UnsavedWorkoutNotifier {
    static let notificationId = "unsaved_workout_reminder"
    private static let delay: TimeInterval = 5 * 60

    static func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { _, _ in }
    }

    static func schedule() {
        let content = UNMutableNotificationContent()
        content.title = "Unsaved workout"
        content.body = "You left a workout in progress, open HealthOS to save it."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        center.add(request)
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        center.removeDeliveredNotifications(withIdentifiers: [notificationId])
    }
}
