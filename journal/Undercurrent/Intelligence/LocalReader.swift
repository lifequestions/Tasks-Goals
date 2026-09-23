import Foundation
import NaturalLanguage

/// Reads an entry entirely on the phone with Apple's NaturalLanguage framework:
/// names of people and places, a handful of common themes and activities, and
/// how each sentence feels. It is quick, free and private, and good enough to
/// draw the map and find patterns. Claude, when switched on, reads more deeply.
struct LocalReader {
    // A starter vocabulary. Claude finds themes freely; this only has to catch the common ones.
    static let lexicon: [(name: String, kind: EntityKind, words: [String])] = [
        ("Work", .theme, ["work", "job", "boss", "meeting", "meetings", "office", "deadline", "project", "career", "colleague", "colleagues", "manager", "client"]),
        ("Sleep", .theme, ["sleep", "slept", "tired", "insomnia", "nap", "exhausted", "awake", "bed"]),
        ("Family", .theme, ["family", "mum", "mom", "dad", "mother", "father", "sister", "brother", "parents", "son", "daughter", "kids"]),
        ("Money", .theme, ["money", "rent", "bills", "salary", "debt", "savings", "spent", "budget", "mortgage"]),
        ("Health", .theme, ["health", "sick", "ill", "doctor", "pain", "headache", "injury", "hospital"]),
        ("Anxiety", .theme, ["anxious", "anxiety", "worried", "worry", "nervous", "panic", "stress", "stressed", "dread", "overwhelmed"]),
        ("Gratitude", .theme, ["grateful", "thankful", "gratitude", "appreciate", "lucky"]),
        ("Love", .theme, ["love", "partner", "date", "relationship", "girlfriend", "boyfriend", "wife", "husband"]),
        ("Creativity", .theme, ["write", "writing", "draw", "drawing", "paint", "painting", "music", "guitar", "piano", "idea", "ideas"]),
        ("Drinking", .activity, ["drinking", "drunk", "wine", "beer", "hungover", "hangover", "pub"]),
        ("Running", .activity, ["run", "running", "ran", "jog", "jogging"]),
        ("Walking", .activity, ["walk", "walked", "walking", "hike", "hiking"]),
        ("Gym", .activity, ["gym", "lifting", "workout", "weights", "training"]),
        ("Yoga", .activity, ["yoga", "stretching", "pilates"]),
        ("Meditation", .activity, ["meditate", "meditated", "meditation", "breathing", "breathwork"]),
        ("Reading", .activity, ["read", "reading", "book", "novel"]),
        ("Cooking", .activity, ["cook", "cooked", "cooking", "baking", "baked"]),
        ("Social media", .activity, ["instagram", "tiktok", "twitter", "scrolling", "doomscrolling", "phone"]),
    ]

    func read(_ text: String) -> EntryAnalysis {
        let sentences = Self.sentences(in: text)
        guard !sentences.isEmpty else { return EntryAnalysis(mood: 0, summary: "", entities: [], noticed: "") }

        var found: [String: (name: String, kind: EntityKind, scores: [Double], quote: String)] = [:]
        var weighted = 0.0, weight = 0.0

        for sentence in sentences {
            let score = Self.sentiment(of: sentence)
            let w = Double(max(sentence.count, 12))
            weighted += score * w
            weight += w

            var here: [(String, EntityKind)] = Self.names(in: sentence)
            let words = Set(sentence.lowercased().split { !$0.isLetter }.map(String.init))
            for item in Self.lexicon where !words.isDisjoint(with: item.words) {
                here.append((item.name, item.kind))
            }
            for (name, kind) in here {
                let key = Entity.makeKey(name: name, kind: kind)
                var slot = found[key] ?? (name, kind, [], sentence)
                slot.scores.append(score)
                found[key] = slot
            }
        }

        // How you feel about someone often shows in the sentences around their
        // name rather than the one it's in ("Coffee with Jordan. I felt small."),
        // so blend each entity's own sentences with the entry as a whole.
        let mood = weight > 0 ? weighted / weight : 0
        let entities = found.values.map { item in
            EntryAnalysis.Found(name: item.name,
                                kind: item.kind.rawValue,
                                sentiment: 0.5 * item.scores.reduce(0, +) / Double(item.scores.count) + 0.5 * mood,
                                quote: item.quote.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let first = sentences[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = first.count > 90 ? String(first.prefix(88)) + "…" : first
        return EntryAnalysis(mood: mood, summary: summary, entities: entities, noticed: "")
    }

    static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).map { String(text[$0]) }
    }

    static func sentiment(of sentence: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = sentence
        let (tag, _) = tagger.tag(at: sentence.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(tag?.rawValue ?? "0") ?? 0
    }

    static func names(in sentence: String) -> [(String, EntityKind)] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = sentence
        var out: [(String, EntityKind)] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            switch tag {
            case .personalName?: out.append((String(sentence[range]), .person))
            case .placeName?: out.append((String(sentence[range]), .place))
            default: break
            }
            return true
        }
        return out
    }
}
