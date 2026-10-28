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
    - insights: zero to two things this entry shows that they probably haven't seen for \
      themselves. Never restate, summarise or paraphrase what they wrote — if they said it, \
      it is not an insight. An insight connects this entry to something outside it: earlier \
      entries (the third time this month, a change since the summer, a contradiction with \
      something they said before), the patterns already counted, their health that day, or \
      the things they've realised about themselves. Name the evidence briefly ("the last three \
      times Jordan came up, the next entry was heavier too"). Speak to them directly, one or \
      two plain sentences each. If nothing reaches that bar, return an empty list — for most \
      short entries that is the right answer.
    - followUp: one short, friendly question to ask them next, grounded in something specific \
      they wrote here or recently — something to check back on ("You mentioned the deadline — \
      how did it go?") or a gentle nudge to say more about a person or feeling that came up. \
      Plain everyday words, under 15 words, nothing clinical or deep for its own sake. It may be \
      shown later that day or the next morning, so phrase it to make sense then.

    If <health_that_day> is given, it's what their Health dashboard knows about that day \
    and the night before (sleep, HRV, workouts, tags like alcohol or sauna). Where it plainly \
    bears on the entry, say so in an insight — "you wrote this after five hours' sleep" — \
    plainly, as context, never as advice.

    Never diagnose, never moralise, never give advice in the reading.
    """

    static let readingSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["mood", "summary", "entities", "insights", "followUp"],
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
            "insights": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["text", "kind"],
                    "properties": [
                        "text": ["type": "string"],
                        "kind": ["type": "string", "enum": ["connection"]],
                    ],
                ],
            ],
            "followUp": ["type": "string"],
        ],
    ]

    static func readingRequest(entry: Entry, known: [Entity], recent: [Entry], profile: String,
                               feedback: String = "", health: HealthData? = nil, patterns: [String] = []) -> String {
        var parts: [String] = []
        if !patterns.isEmpty {
            parts.append("<patterns_so_far>\nCounted across their journal so far:\n"
                + patterns.map { "- \($0)" }.joined(separator: "\n") + "\n</patterns_so_far>")
        }
        if !profile.isEmpty {
            parts.append("<about_them>\n\(profile)\n</about_them>")
        }
        if !feedback.isEmpty { parts.append(feedback) }
        if !known.isEmpty {
            let lines = known.prefix(200).map { e in
                "- \(e.name) (\(e.kindRaw), \(e.mentions.count) mentions, usually \(Feeling.word(e.averageFeeling)))"
            }
            parts.append("<known>\n\(lines.joined(separator: "\n"))\n</known>")
        }
        if !recent.isEmpty {
            let lines = recent.map { "\(dateLine($0.createdAt)) — \($0.summary ?? $0.title) [\(Feeling.word($0.mood))\(Energy.note($0.energy))]" }
            parts.append("<recent_entries>\n\(lines.joined(separator: "\n"))\n</recent_entries>")
        }
        if !entry.chosenTags.isEmpty {
            let tags = entry.chosenTags.map { "- \($0.name) (\($0.kind.rawValue))" }.joined(separator: "\n")
            parts.append("<tags_they_chose>\n\(tags)\nThey tagged the entry with these themselves: include each in entities, with its feeling here.\n</tags_they_chose>")
        }
        if let health, let block = healthThatDay(entry.createdAt, health: health) {
            parts.append(block)
        }
        let asked = (entry.question.map { " answering=\"\($0)\"" } ?? "")
            + (entry.energy.map { " energy=\"\($0)/5 (\(Energy.word($0)))\"" } ?? "")
        parts.append("<entry date=\"\(dateLine(entry.createdAt))\"\(asked)>\n\(entry.text)\n</entry>")
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
        - what goes with higher or lower energy, where they rated it (1 drained … 5 full of it)
        - how their body lined up with what they wrote, where <health_by_day> is given: sleep, \
          HRV, workouts, and tags like alcohol or sauna — e.g. heavier entries following alcohol \
          days. Sleep and HRV are filed under the morning they woke up.
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
                                  insights: [Insight], stats: PeriodStats, profile: String,
                                  feedback: String = "", health: HealthData? = nil) -> String {
        var parts: [String] = []
        if !profile.isEmpty { parts.append("<about_them>\n\(profile)\n</about_them>") }
        if !feedback.isEmpty { parts.append(feedback) }
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
        if let health, full, let block = healthByDay(interval, health: health) {
            parts.append(block)
        }
        if let health, let block = healthPatterns(health) { parts.append(block) }
        let text = entries.map { entry -> String in
            let head = "\(dateLine(entry.createdAt)) [\(Feeling.word(entry.mood))\(Energy.note(entry.energy))]"
            return full ? "### \(head)\n\(entry.text)" : "- \(head) \(entry.summary ?? entry.title)"
        }
        parts.append("<entries>\n\(text.joined(separator: full ? "\n\n" : "\n"))\n</entries>")
        return parts.joined(separator: "\n\n")
    }

    // MARK: Connections across the journal

    static let connectionsSystem = """
    You look across someone's whole private journal, their daily check-ins and their health \
    numbers, and tell them the few things that matter most. They have told you the long lists \
    of correlations were too much to make sense of — so pick, don't list.

    You're given the patterns their phone has already counted (many are noise: small samples, \
    coincidences, the same effect seen twice), the numbers, their health by day, and a line \
    for each recent entry.

    Return:
    - findings: at most three, the most important first. Each is something they can act on or \
      watch for, not a statistic. Merge counted patterns that are really one story ("alcohol, \
      late bedtimes and heavy Mondays are the same thing"). Prefer findings that hold across \
      many days; leave out anything resting on two or three. For each:
      - headline: under 12 words, plain, about their life ("Late nights cost you the next day").
      - evidence: one sentence with the numbers that back it, rounded and readable \
        ("Your energy is about 1 point lower after bedtimes past midnight — 9 of the last 12 times").
      - strength: "clear" (holds across many days), "emerging" (consistent but early) or \
        "hunch" (worth watching).
      - experiment: one small, concrete thing they could try for a week to test it, or an empty \
        string if none fits. Never medical advice.
      Don't repeat anything they've marked not helpful. Fewer is better than padded.
    - summary: two or three sentences, under 60 words, on what it all adds up to. Warm and \
      plain, no diagnosis.
    """

    static let connectionsSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["findings", "summary"],
        "properties": [
            "findings": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["headline", "evidence", "strength", "experiment"],
                    "properties": [
                        "headline": ["type": "string"],
                        "evidence": ["type": "string"],
                        "strength": ["type": "string", "enum": ["clear", "emerging", "hunch"]],
                        "experiment": ["type": "string"],
                    ],
                ],
            ],
            "summary": ["type": "string"],
        ],
    ]

    struct ConnectionsDraft: Codable {
        struct Finding: Codable {
            var headline: String
            var evidence: String
            var strength: String
            var experiment: String
        }
        var findings: [Finding]
        var summary: String
    }

    static func connectionsRequest(patterns: [FoundPattern], stats: PeriodStats, entries: [Entry],
                                   profile: String, feedback: String, health: HealthData? = nil) -> String {
        var parts: [String] = []
        if !profile.isEmpty { parts.append("<about_them>\n\(profile)\n</about_them>") }
        if !feedback.isEmpty { parts.append(feedback) }
        parts.append("<numbers>\n\(stats.describe())\n</numbers>")
        if !patterns.isEmpty {
            parts.append("<counted_patterns>\n\(patterns.prefix(15).map { "- \($0.text)" }.joined(separator: "\n"))\n</counted_patterns>")
        }
        if let health {
            let end = Date.now
            let start = Calendar.current.date(byAdding: .day, value: -60, to: end) ?? end
            if let block = healthByDay(DateInterval(start: start, end: end), health: health) { parts.append(block) }
            if let block = healthPatterns(health) { parts.append(block) }
        }
        let lines = entries.suffix(120).map { entry -> String in
            let names = entry.entities.map(\.name).joined(separator: ", ")
            return "- \(dateLine(entry.createdAt)) [\(Feeling.word(entry.mood))\(Energy.note(entry.energy))] \(entry.summary ?? entry.title)\(names.isEmpty ? "" : " — \(names)")"
        }
        parts.append("<entries>\n\(lines.joined(separator: "\n"))\n</entries>")
        return parts.joined(separator: "\n\n")
    }

    // MARK: Health, from the dashboard

    /// The day an entry was written and the day before: body numbers and what they did.
    static func healthThatDay(_ date: Date, health: HealthData) -> String? {
        let before = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        var lines: [String] = []
        for (label, day) in [("This day", date), ("The day before", before)] {
            var parts: [String] = []
            if let known = health.describe(Energy.day(day)) { parts.append(known) }
            let did = CheckIn.done(on: day)
            if !did.isEmpty { parts.append("checked in: " + did.joined(separator: ", ")) }
            if !parts.isEmpty { lines.append("- \(label) (\(dateLine(day))): " + parts.joined(separator: "; ")) }
        }
        guard !lines.isEmpty else { return nil }
        return "<health_that_day>\nSleep, HRV and bedtime are for the night before each day.\n"
            + lines.joined(separator: "\n") + "\n</health_that_day>"
    }

    static func healthByDay(_ interval: DateInterval, health: HealthData) -> String? {
        var lines: [String] = []
        var day = Calendar.current.startOfDay(for: interval.start)
        while day < interval.end {
            var parts: [String] = []
            if let known = health.describe(Energy.day(day)) { parts.append(known) }
            let did = CheckIn.done(on: day)
            if !did.isEmpty { parts.append("checked in: " + did.joined(separator: ", ")) }
            if !parts.isEmpty { lines.append("- \(dateLine(day)): " + parts.joined(separator: "; ")) }
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        guard !lines.isEmpty else { return nil }
        return "<health_by_day>\nSleep, HRV and bedtime are for the night before each day.\n"
            + lines.joined(separator: "\n") + "\n</health_by_day>"
    }

    static func healthPatterns(_ health: HealthData) -> String? {
        guard !health.journalPatterns.isEmpty else { return nil }
        let lines = health.journalPatterns.prefix(15).map { pattern -> String in
            let days = pattern.days.map { ", over \($0) days" } ?? ""
            return "- \(pattern.sentence)\(days)"
        }
        return "<health_patterns>\nWhat their Health dashboard has found between their body and the journal:\n"
            + lines.joined(separator: "\n") + "\n</health_patterns>"
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
        let entryText = entries.map { "### \(dateLine($0.createdAt)) [\(Feeling.word($0.mood))\(Energy.note($0.energy))]\n\($0.text)" }
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
