import Foundation
import UserNotifications

enum Reminders {
    static let id = "daily-prompt"

    /// One gentle nudge a day, carrying that day's question.
    static func schedule(at time: Date) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "A minute for yourself"
        content.body = DailyQuestion.today
        content.sound = .default

        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

enum DailyQuestion {
    static let all = [
        "What's taking up the most room in your head today?",
        "Who did you think about today, and how did it feel?",
        "What gave you energy today? What took it?",
        "What are you avoiding, and why?",
        "When did you feel most like yourself this week?",
        "What would you tell a friend who had your day?",
        "What's something small that went right?",
        "What conversation is still replaying in your head?",
        "Where did your body hold today — shoulders, jaw, stomach?",
        "What do you want more of? Less of?",
        "Who do you feel lighter around lately?",
        "What did you learn about yourself today?",
        "What are you looking forward to?",
        "What's a feeling you haven't named yet?",
        "If today had a title, what would it be?",
        "What's been quietly bothering you?",
        "What did you need today that you didn't get?",
        "What surprised you about how you reacted to something?",
        "Which part of today would you happily live again?",
        "What story are you telling yourself right now? Is it true?",
        "What are you grateful for that you usually overlook?",
        "Where did you spend your attention today?",
        "Who do you miss?",
        "What would make tomorrow ten percent better?",
        "What's changed in you over the last month?",
        "What did you say yes to that you wish you hadn't?",
        "What drained you — and was it worth it?",
        "What would you do if no one would ever know?",
    ]

    static var today: String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return all[day % all.count]
    }
}
