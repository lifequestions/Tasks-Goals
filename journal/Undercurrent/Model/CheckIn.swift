import Foundation

/// The things you track every day with one tap on Today — strength training, sauna,
/// meds, alcohol… Kept per day whether or not you write, sent to the Health dashboard,
/// and looked at against your mood, energy, sleep and the rest.
enum CheckIn {
    static let defaultHabits = [
        "Strength training", "Sauna", "ADHD meds", "Psyllium husk", "Supplements", "Alcohol", "Socialising",
    ]

    private static let habitsKey = "checkIn.habits"
    private static let doneKey = "checkIn.done"

    /// The list shown on Today, in order.
    static var habits: [String] {
        get { UserDefaults.standard.stringArray(forKey: habitsKey) ?? defaultHabits }
        set { UserDefaults.standard.set(newValue, forKey: habitsKey) }
    }

    static func add(_ habit: String) {
        let name = habit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !habits.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        habits.append(name)
    }

    static func remove(_ habit: String) {
        habits.removeAll { $0 == habit }
    }

    /// Every day's ticked habits, by "yyyy-MM-dd". A day is in here once you've
    /// ticked anything, even if you later untick it all.
    static var done: [String: [String]] {
        (UserDefaults.standard.dictionary(forKey: doneKey) as? [String: [String]]) ?? [:]
    }

    static func done(on date: Date) -> [String] {
        done[Energy.day(date)] ?? []
    }

    static func toggle(_ habit: String, on date: Date) {
        var all = done
        let day = Energy.day(date)
        var today = all[day] ?? []
        if let i = today.firstIndex(of: habit) { today.remove(at: i) } else { today.append(habit) }
        all[day] = today
        UserDefaults.standard.set(all, forKey: doneKey)
    }

    /// Days you checked in at all (a habit or your energy). On those days a habit
    /// you didn't tick counts as not done; other days say nothing either way.
    static var loggedDays: Set<String> {
        Set(done.keys).union(Energy.checkIns.keys)
    }

    /// For the dashboard: every habit on the list, done or not, for a logged day.
    static func habitMap(for day: String) -> [String: Bool]? {
        guard loggedDays.contains(day) else { return nil }
        let ticked = Set(done[day] ?? [])
        var map: [String: Bool] = [:]
        for habit in Set(habits).union(ticked) { map[habit] = ticked.contains(habit) }
        return map
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: doneKey)
    }
}
