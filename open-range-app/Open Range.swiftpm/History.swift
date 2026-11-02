import Foundation

/// One change the app made to the bike, kept on the phone so the rider can look back.
struct ModeChange: Codable, Identifiable {
    var id = UUID()
    let date: Date
    /// Same values as the on/off status: "legal", "unleashed", "unleashedKept" or "refused".
    let mode: String
    let boost: Int
    /// Commands sent, and how many the bike answered with "accepted".
    var sent = 0
    var accepted = 0
    /// Highest GPS speed seen while this setting was the latest one (only while the app was open).
    var topKmh: Double = 0
}

/// A saved list of changes, newest first.
final class History: ObservableObject {
    @Published private(set) var entries: [ModeChange] = []

    private let key = "modeHistory"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([ModeChange].self, from: data) {
            entries = saved
        }
    }

    func add(mode: String, boost: Int, sent: Int, accepted: Int) {
        entries.insert(ModeChange(date: Date(), mode: mode, boost: boost, sent: sent, accepted: accepted), at: 0)
        if entries.count > 200 { entries.removeLast() }
        save()
    }

    func recordSpeed(_ kmh: Double) {
        guard !entries.isEmpty, kmh > entries[0].topKmh else { return }
        entries[0].topKmh = kmh
        save()
    }

    func clear() {
        entries = []
        save()
    }

    /// When this change stopped being the latest one, or nil if it still is.
    func end(of entry: ModeChange) -> Date? {
        guard let i = entries.firstIndex(where: { $0.id == entry.id }), i > 0 else { return nil }
        return entries[i - 1].date
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
