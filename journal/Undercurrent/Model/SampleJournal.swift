import Foundation
import SwiftData

/// Three months of made-up entries, so the map, patterns and reflections have
/// something to show on day one. Jordan is written to weigh on the writer,
/// Maya to lift them, Sundays run heavy and running helps — the finder
/// should spot all of it. Erase it from Settings when you start for real.
enum SampleJournal {
    static let heavyWithJordan = [
        "Coffee with Jordan again. I came away feeling drained and a bit small, like everything I said was wrong.",
        "Jordan cancelled at the last minute. Annoyed at myself for being so annoyed about it.",
        "Jordan texted about the weekend and I felt a knot in my stomach before I even opened it.",
        "Long call with Jordan. They talked about their promotion for an hour and I felt invisible.",
        "Saw Jordan at the party. Stayed too long, drank too much, felt worse for it.",
    ]
    static let lightWithMaya = [
        "Long walk with Maya along the river. We laughed about nothing and I felt properly light.",
        "Dinner at Maya's. Warm, easy, fun. I want more evenings like this.",
        "Maya sent me a voice note that made me cry laughing. Grateful for her.",
        "Went to the market in Brighton with Maya. Sunshine, good bread, no rush at all.",
    ]
    static let running = [
        "Went for a run before work. Clear head all morning, even the meeting was fine.",
        "Ran along the seafront in Brighton. Legs heavy but mind quiet. Worth it.",
        "Short run in the rain. Felt ridiculous and brilliant.",
    ]
    static let work = [
        "Deadline at work is crushing me. Slept badly and felt anxious about the meeting with my boss.",
        "Another long day at the office. The project keeps changing and nobody decides anything.",
        "Good meeting today, actually. My manager liked the plan. Small win.",
    ]
    static let sunday = [
        "Sunday evening dread again. Already thinking about the week ahead and everything I haven't done.",
        "Quiet Sunday, but that low hum of worry about Monday never really went away.",
    ]
    static let other = [
        "Slept nine hours. Feel like a different person.",
        "Called Mum. She sounded tired but happy. I should visit soon.",
        "Read for two hours in the bath. Nothing happened and it was perfect.",
        "Spent too long scrolling on my phone tonight and feel scattered.",
        "Cooked a proper meal for once. Felt like looking after myself.",
        "Money is tight this month. Rent went up and I keep checking my account.",
    ]

    static func load(into context: ModelContext, intelligence: Intelligence) {
        var rng = SeededRandom(seed: 7)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        for daysAgo in stride(from: 95, through: 1, by: -1) {
            guard rng.next() % 100 < 62,
                  let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let roll = rng.next() % 100
            let pool: [String]
            if weekday == 1 && rng.next() % 3 != 0 {
                pool = sunday
            } else {
                switch roll {
                case 0..<18: pool = heavyWithJordan
                case 18..<34: pool = lightWithMaya
                case 34..<50: pool = running
                case 50..<68: pool = work
                default: pool = other
                }
            }
            var text = pool[Int(rng.next() % UInt64(pool.count))]
            if rng.next() % 4 == 0 {
                text += " " + other[Int(rng.next() % UInt64(other.count))]
            }
            let hour = 7 + Int(rng.next() % 15)
            let date = calendar.date(byAdding: .hour, value: hour, to: day) ?? day
            let entry = Entry(text: text, createdAt: date)
            context.insert(entry)
            Store.apply(LocalReader().read(text), to: entry, by: "device", in: context)
        }
        context.insert(Insight(text: "I think I keep saying yes to Jordan out of guilt, not because I want to.", source: .mine,
                               entityKeys: [Entity.makeKey(name: "Jordan", kind: .person)]))
        try? context.save()
        intelligence.refreshPatterns(in: context)
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 33
    }
}
