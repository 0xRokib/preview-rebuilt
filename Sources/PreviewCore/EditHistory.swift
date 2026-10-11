import Foundation

/// Tracks exact history identity, not just depth (different branches can have equal lengths).
public final class EditHistory {
    private struct Entry { let identity: UUID; let undo: () -> Void }
    private var entries: [Entry] = []
    private var base = UUID()
    private var saved: UUID
    public init() { saved = base }
    private var current: UUID { entries.last?.identity ?? base }
    public var isEmpty: Bool { entries.isEmpty }
    public var isDirty: Bool { current != saved }
    public func append(_ undo: @escaping () -> Void) { entries.append(Entry(identity: UUID(), undo: undo)) }
    public func popLast() -> (() -> Void)? { entries.popLast()?.undo }
    public func markSaved() { saved = current }
    public func removeAll() { entries.removeAll(); base = UUID(); saved = base }
}
