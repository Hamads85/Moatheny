import Foundation
import UserNotifications

/// Manages Adhan and Azkar reminders.
final class NotificationService {
    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleAdhan(for prayer: Prayer) {
        let content = UNMutableNotificationContent()
        content.title = "حان وقت \(prayer.arabicName)"
        content.body = "It's time for \(prayer.name) prayer"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("adhan.mp3"))
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.hour, .minute], from: prayer.time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "prayer-\(prayer.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleAzkarReminder(hour: Int, minute: Int, category: AzkarCategory) {
        let content = UNMutableNotificationContent()
        content.title = category == .morning ? "أذكار الصباح" : "أذكار المساء"
        content.body = "Time for \(category.rawValue) azkar"
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "azkar-\(category.rawValue)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

