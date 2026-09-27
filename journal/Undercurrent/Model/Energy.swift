import SwiftUI

/// How much energy you had when you wrote, 1 (drained) to 5 (full of it). Optional
/// on every entry; the pattern finder, Claude and the Health dashboard all use it.
enum Energy {
    static let levels = Array(1...5)

    static func word(_ level: Int) -> String {
        switch level {
        case ...1: "drained"
        case 2: "low"
        case 3: "steady"
        case 4: "good"
        default: "full of it"
        }
    }

    /// For Claude's context lines: ", energy 2/5 (low)", or nothing.
    static func note(_ level: Int?) -> String {
        level.map { ", energy \($0)/5 (\(word($0)))" } ?? ""
    }

    static func mean(_ levels: [Int]) -> Double? {
        levels.isEmpty ? nil : Double(levels.reduce(0, +)) / Double(levels.count)
    }

    // MARK: Check-ins from Today, one per day, kept even when you don't write

    private static let checkInsKey = "energy.checkIns"

    /// Every day's check-in, by "yyyy-MM-dd".
    static var checkIns: [String: Int] {
        (UserDefaults.standard.dictionary(forKey: checkInsKey) as? [String: Int]) ?? [:]
    }

    static func checkIn(on date: Date) -> Int? {
        checkIns[day(date)]
    }

    static func setCheckIn(_ level: Int?, on date: Date) {
        var all = checkIns
        all[day(date)] = level
        UserDefaults.standard.set(all, forKey: checkInsKey)
    }

    static func clearCheckIns() {
        UserDefaults.standard.removeObject(forKey: checkInsKey)
    }

    /// An entry's own energy, or failing that the day's check-in.
    static func level(of entry: Entry, checkIns: [String: Int]) -> Int? {
        entry.energy ?? checkIns[day(entry.createdAt)]
    }

    /// The local calendar day as "yyyy-MM-dd".
    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// Five steps from drained to full of it. Tap the chosen one again to clear it.
struct EnergyPicker: View {
    @Binding var level: Int?

    var body: some View {
        HStack(spacing: 10) {
            Text("Energy").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink2)
            HStack(spacing: 6) {
                ForEach(Energy.levels, id: \.self) { value in
                    let on = level.map { value <= $0 } ?? false
                    Button {
                        withAnimation(.snappy) { level = level == value ? nil : value }
                    } label: {
                        Capsule()
                            .fill(on ? Palette.accent : Palette.raised)
                            .frame(width: 26, height: 10 + CGFloat(value) * 3)
                            .frame(height: 26, alignment: .bottom)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value) — \(Energy.word(value))")
                    .accessibilityAddTraits(level == value ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: level)
            Text(level.map(Energy.word) ?? "how's your energy?")
                .font(.footnote)
                .foregroundStyle(level == nil ? Palette.ink3 : Palette.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }
}
