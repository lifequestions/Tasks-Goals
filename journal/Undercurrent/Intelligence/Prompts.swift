import Foundation

/// Everything Claude is told, in one place, so it can be read and tuned.
enum Prompts {
    // MARK: Reading one entry

    static let readingSystem = """
    You are the quiet reader inside someone's private journal app. Its purpose is to help them \
    see the connections in their own life: who and what keeps coming up, and how they feel \
    each time.

    You will be given one new entry, plus some context: the people, places, themes and \
    activities already in their journal, a few recent entries, and anything they've told the \
    app about themselves.

    Return:
    - mood: how the entry as a whole feels, from -1 (very heavy) through 0 (even) to 1 (very light).
    - summary: one plain line, under 12 words, that would help them recognise this entry later.
    - entities: every person, place, recurring theme and activity in the entry. For each, the \
      feeling around it *in this entry* on the same -1 to 1 scale, and the shortest quote that \
      shows it. A person can be light in one entry and heavy in another; read each on its own. \
      Reuse the exact name of a known entity when the entry means the same one ("Sam" when \
      "Samantha" is known and it is clearly her). Themes are short nouns ("Work", "Self-doubt", \
      "Home"), not sentences. Skip generic words that aren't really part of their life.
    - noticed: at most one observation linking this entry to the context — a recurrence, a \
      contrast, something that has changed — only when the context genuinely supports it. \
      Otherwise an empty string. Speak to them directly, gently, in one or two sentences.

    Never diagnose, never moralise, never give advice in the reading.
    """

    static let readingSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["mood", "summary", "entities", "noticed"],
        "properties": [
            "mood": ["type": "number", "description": "-1 very heavy … 0 even … 1 very light"],
            "summary": ["type": "string"],
            "entities": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["name", "kind", "sentiment", "quote"],
                    "properties": [
                        "name": ["type": "string"],
                        "kind": ["type": "string", "enum": ["person", "place", "theme", "activity"]],
                        "sentiment": ["type": "number", "description": "-1 … 1, in this entry"],
                        "quote": ["type": "string"],
                    ],
                ],
            ],
            "noticed": ["type": "string"],
        ],
    ]

    static func readingRequest(entry: Entry, known: [Entity], recent: [Entry], profile: String) -> String {
        var parts: [String] = []
        if !profile.isEmpty {
            parts.append("<about_them>\n\(profile)\n</about_them>")
        }
        if !known.isEmpty {
            let lines = known.prefix(200).map { e in
                "- \(e.name) (\(e.kindRaw), \(e.mentions.count) mentions, usually \(Feeling.word(e.averageFeeling)))"
            }
            parts.append("<known>\n\(lines.joined(separator: "\n"))\n</known>")
        }
        if !recent.isEmpty {
            let lines = recent.map { "\(dateLine($0.createdAt)) — \($0.summary ?? $0.title) [\(Feeling.word($0.mood))]" }
            parts.append("<recent_entries>\n\(lines.joined(separator: "\n"))\n</recent_entries>")
        }
        parts.append("<entry date=\"\(dateLine(entry.createdAt))\">\n\(entry.text)\n</entry>")
        return parts.joined(separator: "\n\n")
    }

    // MARK: Reflections

    static func reflectionSystem(for period: Period) -> String {
        let span = period == .allTime ? "their whole journal so far" : "one \(period.label.lowercased())"
        return """
        You write the reflection for \(span) in someone's private journal. They read it to \
        understand themselves better, especially the connections they haven't spotted.

        Write to them in the second person, warmly but without gushing. Be specific: use names, \
        places and dates from the material. Look for:
        - who and what came up most, and how they felt around each
        - things that travel together (a person and a mood, a place and a habit, a day and a feeling)
        - what changed against the previous period, including things that stopped appearing
        - anything they themselves noted as an insight, and whether the entries bear it out

        Say plainly which things are clear and which are only a hunch. Never diagnose. Only \
        suggest something if a pattern strongly warrants it, and then lightly.

        headline: one line, under ten words, that names the period.
        body: two to four short paragraphs.
        patterns: three to six connections, one sentence each.
        questions: two or three open questions worth sitting with.
        """
    }

    static let reflectionSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["headline", "body", "patterns", "questions"],
        "properties": [
            "headline": ["type": "string"],
            "body": ["type": "string"],
            "patterns": ["type": "array", "items": ["type": "string"]],
            "questions": ["type": "array", "items": ["type": "string"]],
        ],
    ]

    struct ReflectionDraft: Codable {
        var headline: String
        var body: String
        var patterns: [String]
        var questions: [String]
    }

    /// Short periods get the full entries. Long ones get the reflections of the
    /// periods inside them plus one line per entry, so a year stays affordable.
    static func reflectionRequest(period: Period, interval: DateInterval, entries: [Entry],
                                  childReflections: [Reflection], previous: Reflection?,
                                  insights: [Insight], stats: PeriodStats, profile: String) -> String {
        var parts: [String] = []
        if !profile.isEmpty { parts.append("<about_them>\n\(profile)\n</about_them>") }
        parts.append("<period>\(period.title(for: interval)) — \(entries.count) entries</period>")
        parts.append("<numbers>\n\(stats.describe())\n</numbers>")

        if let previous {
            parts.append("<previous_reflection>\n\(previous.headline)\n\(previous.body)\n</previous_reflection>")
        }
        if !childReflections.isEmpty {
            let text = childReflections.map {
                "## \($0.period.title(for: DateInterval(start: $0.start, end: $0.end)))\n\($0.headline)\n\($0.body)\nPatterns: \($0.patterns.joined(separator: "; "))"
            }
            parts.append("<reflections_within>\n\(text.joined(separator: "\n\n"))\n</reflections_within>")
        }
        if !insights.isEmpty {
            let text = insights.map { "- [\($0.source.label)] \($0.text)" }
            parts.append("<insights>\n\(text.joined(separator: "\n"))\n</insights>")
        }

        let full = period == .week || period == .month
        let text = entries.map { entry -> String in
            let head = "\(dateLine(entry.createdAt)) [\(Feeling.word(entry.mood))]"
            return full ? "### \(head)\n\(entry.text)" : "- \(head) \(entry.summary ?? entry.title)"
        }
        parts.append("<entries>\n\(text.joined(separator: full ? "\n\n" : "\n"))\n</entries>")
        return parts.joined(separator: "\n\n")
    }

    // MARK: One entity

    static let entitySystem = """
    You help someone understand one recurring presence in their journal — a person, place, \
    theme or activity. From every moment it appears, describe the connection: how they tend to \
    feel around it, what tends to come with it or follow it, and how that has changed over time. \
    Speak to them directly, in two short paragraphs. Be specific and honest, including about \
    uncertainty. No diagnosis, no verdicts on other people.
    """

    static let entitySchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["reading"],
        "properties": ["reading": ["type": "string"]],
    ]

    struct EntityReading: Codable { var reading: String }

    static func entityRequest(_ entity: Entity, alongside: [(String, Int)], profile: String) -> String {
        let moments = entity.mentions
            .compactMap { m -> (Date, String)? in
                guard let entry = m.entry else { return nil }
                return (entry.createdAt, "\(dateLine(entry.createdAt)) [here: \(Feeling.word(m.sentiment)), whole entry: \(Feeling.word(entry.mood))] \(m.quote)")
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)
        let with = alongside.prefix(12).map { "\($0.0) (\($0.1))" }.joined(separator: ", ")
        return """
        \(profile.isEmpty ? "" : "<about_them>\n\(profile)\n</about_them>\n\n")<subject>\(entity.name) — \(entity.kindRaw)</subject>

        <often_alongside>\(with)</often_alongside>

        <moments>
        \(moments.joined(separator: "\n"))
        </moments>
        """
    }

    // MARK: Asking the journal

    static let askSystem = """
    You answer a question someone asks about their own journal, using only what is in it. \
    Quote dates and names. If the journal doesn't say, say so. Speak to them directly and keep \
    it short.
    """

    static let askSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["answer"],
        "properties": ["answer": ["type": "string"]],
    ]

    struct Answer: Codable { var answer: String }

    static func askRequest(question: String, entries: [Entry], reflections: [Reflection], profile: String) -> String {
        let reflectionText = reflections.map { "## \($0.period.label) from \(dateLine($0.start)): \($0.headline)\n\($0.body)" }
        let entryText = entries.map { "### \(dateLine($0.createdAt)) [\(Feeling.word($0.mood))]\n\($0.text)" }
        return """
        \(profile.isEmpty ? "" : "<about_them>\n\(profile)\n</about_them>\n\n")<reflections>
        \(reflectionText.joined(separator: "\n\n"))
        </reflections>

        <entries>
        \(entryText.joined(separator: "\n\n"))
        </entries>

        <question>\(question)</question>
        """
    }

    static func dateLine(_ date: Date) -> String { date.stamp("EEEdMMMyyyy") }
}
