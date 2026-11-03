// L04 — Rolls as albums: open-ended, named collections of shots
// State machine: shooting → developing → ready → archived

import Foundation

/// A Roll is one named album of shots. No hard frame limit.
public struct Roll: Codable, Identifiable {
    public let id: UUID
    public var name: String          // e.g. "Saturday Evening", auto-generated from date
    public let createdAt: Date
    public var closedAt: Date?       // nil = still shooting
    public var state: RollState
    public var shotIDs: [UUID]       // ordered capture sequence
    public var coverShotID: UUID?    // first developed shot by default
    
    public enum RollState: String, Codable {
        case shooting    // active: captures go here
        case developing  // closed, render queue running
        case ready       // all shots developed
        case archived    // dismissed from main view
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        state: RollState = .shooting,
        shotIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.state = state
        self.shotIDs = shotIDs
    }
    
    public var frameCount: Int { shotIDs.count }
    
    /// Auto-name from date if user hasn't renamed
    public static func autoName(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f.string(from: date)
    }
}

/// Durable roll store — single source of truth for all rolls
@MainActor
public final class RollStore: ObservableObject {
    public static let shared = RollStore()
    
    @Published public var rolls: [Roll] = []
    @Published public var activeRoll: Roll?
    
    private let storeURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("rolls.json")
    }()
    
    private init() {
        load()
        ensureActiveRoll()
    }
    
    // MARK: - Active roll management
    
    /// Start a new roll (closes the current one into developing)
    public func newRoll(name: String? = nil) {
        if let active = activeRoll, active.frameCount > 0 {
            close(roll: active)
        }
        let roll = Roll(name: name ?? Roll.autoName())
        rolls.insert(roll, at: 0)
        activeRoll = roll
        save()
    }
    
    /// Add a captured shot to the active roll (creates one if needed)
    public func addShot(_ shotID: UUID) {
        ensureActiveRoll()
        guard let idx = rolls.firstIndex(where: { $0.id == activeRoll?.id }) else { return }
        rolls[idx].shotIDs.append(shotID)
        if rolls[idx].coverShotID == nil {
            rolls[idx].coverShotID = shotID
        }
        activeRoll = rolls[idx]
        save()
    }
    
    /// Close the active roll and move it to developing
    public func closeActiveRoll() {
        guard let active = activeRoll else { return }
        close(roll: active)
        activeRoll = nil
        ensureActiveRoll()
    }
    
    /// Mark a roll as ready (all shots developed)
    public func markReady(rollID: UUID) {
        guard let idx = rolls.firstIndex(where: { $0.id == rollID }) else { return }
        rolls[idx].state = .ready
        save()
    }
    
    public func rename(rollID: UUID, to name: String) {
        guard let idx = rolls.firstIndex(where: { $0.id == rollID }) else { return }
        rolls[idx].name = name
        save()
    }
    
    public func archive(rollID: UUID) {
        guard let idx = rolls.firstIndex(where: { $0.id == rollID }) else { return }
        rolls[idx].state = .archived
        save()
    }
    
    // MARK: - Private
    
    private func close(roll: Roll) {
        guard let idx = rolls.firstIndex(where: { $0.id == roll.id }) else { return }
        rolls[idx].state = .developing
        rolls[idx].closedAt = Date()
        save()
    }
    
    private func ensureActiveRoll() {
        if activeRoll != nil && rolls.contains(where: { $0.id == activeRoll!.id && $0.state == .shooting }) {
            return
        }
        if let existing = rolls.first(where: { $0.state == .shooting }) {
            activeRoll = existing
        } else {
            let roll = Roll(name: Roll.autoName())
            rolls.insert(roll, at: 0)
            activeRoll = roll
            save()
        }
    }
    
    // MARK: - Persistence
    
    private func save() {
        guard let data = try? JSONEncoder().encode(rolls) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([Roll].self, from: data) else { return }
        rolls = decoded
        activeRoll = decoded.first(where: { $0.state == .shooting })
    }
}
