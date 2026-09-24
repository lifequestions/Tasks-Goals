import Foundation

/// A person, place, theme or activity attached to an entry by hand.
/// Stored on the entry as "kind|Name" so it survives re-reads.
struct Tag: Hashable, Identifiable {
    let name: String
    let kind: EntityKind

    var key: String { Entity.makeKey(name: name, kind: kind) }
    var id: String { key }
    var stored: String { "\(kind.rawValue)|\(name)" }

    init(name: String, kind: EntityKind) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = kind
    }

    init(_ entity: Entity) {
        self.init(name: entity.name, kind: entity.kind)
    }

    init?(stored: String) {
        let parts = stored.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, let kind = EntityKind(rawValue: parts[0]) else { return nil }
        self.init(name: parts[1], kind: kind)
    }
}

extension Entry {
    var chosenTags: [Tag] {
        get { (pinnedTags ?? []).compactMap(Tag.init(stored:)) }
        set { pinnedTags = newValue.map(\.stored) }
    }
}
