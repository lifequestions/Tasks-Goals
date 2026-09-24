import Foundation

/// What the app asks. One plain opening question that changes with the time of
/// day, then — once you've written — a second, smaller one. With Claude on,
/// that second question comes from what you actually wrote.
enum Questions {
    struct Question: Equatable {
        let text: String
        var hint: String? = nil
    }

    static func opener(at date: Date = .now) -> Question {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<12: Question(text: "What's on your mind today?", hint: "How did you sleep? What's ahead?")
        case 12..<18: Question(text: "What's on your mind today?", hint: "Anything at all — big or small.")
        default: Question(text: "How was today?", hint: "What stood out? Anything still on your mind?")
        }
    }

    static let morning = [
        "What are you looking forward to?",
        "Is anything stressing you out?",
        "How did you sleep?",
        "What would make today a good day?",
        "Who are you seeing today?",
    ]

    static let evening = [
        "What are you looking forward to?",
        "Is anything stressing you out?",
        "Who did you spend time with today?",
        "What gave you energy today?",
        "What drained you today?",
        "What went well today?",
        "Anything you'd do differently tomorrow?",
    ]

    /// Everyday follow-ups, in an order that changes each day. `skip` moves through them.
    static func followUp(at date: Date = .now, skip: Int = 0) -> String {
        let pool = Calendar.current.component(.hour, from: date) < 12 ? morning : evening
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return pool[(day + skip) % pool.count]
    }
}
