// SET04 — Durable capture and local recovery
// Implements transactional write-ahead journaling for camera captures.
// Invariant (Roadmap §6): A durable acknowledgment means recoverable source
// bytes exist on disk. Thumbnails and renders are derived and never replace RAW.

import Foundation
import CryptoKit
import os.log

public extension Notification.Name {
    static let carbonCapturePersisted = Notification.Name("app.carbon.capturePersisted")
}

/// Durable capture entry on disk
public struct JournalEntry: Codable, Identifiable {
    public let id: UUID
    public let captureID: String
    public let timestamp: Date
    public let rawFilename: String?
    public let hevcFilename: String?
    public let rawSHA256: String?
    public let hevcSHA256: String?
    public let recipeVersionID: UUID
    public var isCommitted: Bool
    
    public init(
        id: UUID = UUID(),
        captureID: String,
        timestamp: Date = Date(),
        rawFilename: String? = nil,
        hevcFilename: String? = nil,
        rawSHA256: String? = nil,
        hevcSHA256: String? = nil,
        recipeVersionID: UUID,
        isCommitted: Bool = false
    ) {
        self.id = id
        self.captureID = captureID
        self.timestamp = timestamp
        self.rawFilename = rawFilename
        self.hevcFilename = hevcFilename
        self.rawSHA256 = rawSHA256
        self.hevcSHA256 = hevcSHA256
        self.recipeVersionID = recipeVersionID
        self.isCommitted = isCommitted
    }
}

/// Actor managing durable writes to the app container
public actor CaptureJournal {
    public static let shared = CaptureJournal()
    
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "app.carbon", category: "CaptureJournal")
    
    private nonisolated var baseDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("CarbonCaptures", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private var journalURL: URL {
        baseDirectory.appendingPathComponent("journal.json")
    }
    
    // MARK: - Transactional Write
    
    /// Persists captured photo bytes atomically to disk before acknowledging capture.
    public func persist(
        captureID: String,
        rawBytes: Data?,
        hevcBytes: Data?,
        recipe: RecipeVersion
    ) throws -> JournalEntry {
        let entryID = UUID()
        var rawName: String?
        var rawHash: String?
        var hevcName: String?
        var hevcHash: String?
        
        // Write RAW if present
        if let raw = rawBytes {
            let filename = "\(captureID)_\(entryID.uuidString).dng"
            let targetURL = baseDirectory.appendingPathComponent(filename)
            try raw.write(to: targetURL, options: .atomic)
            rawName = filename
            rawHash = SHA256.hash(data: raw).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        // Write HEVC if present
        if let hevc = hevcBytes {
            let filename = "\(captureID)_\(entryID.uuidString).heic"
            let targetURL = baseDirectory.appendingPathComponent(filename)
            try hevc.write(to: targetURL, options: .atomic)
            hevcName = filename
            hevcHash = SHA256.hash(data: hevc).compactMap { String(format: "%02x", $0) }.joined()
        }
        
        var entry = JournalEntry(
            id: entryID,
            captureID: captureID,
            rawFilename: rawName,
            hevcFilename: hevcName,
            rawSHA256: rawHash,
            hevcSHA256: hevcHash,
            recipeVersionID: recipe.id,
            isCommitted: true
        )
        
        try appendToJournal(entry: entry)
        NotificationCenter.default.post(name: .carbonCapturePersisted, object: nil)
        logger.info("Persisted capture \(captureID) with raw=\(rawName ?? "nil"), hevc=\(hevcName ?? "nil")")
        return entry
    }
    
    // MARK: - Recovery on Launch
    
    /// Recovers all committed captures from disk on launch.
    public func recoverAll() throws -> [JournalEntry] {
        guard fileManager.fileExists(atPath: journalURL.path) else { return [] }
        let data = try Data(contentsOf: journalURL)
        let entries = try JSONDecoder().decode([JournalEntry].self, from: data)
        
        // Filter only valid entries where files exist
        let valid = entries.filter { entry in
            if let hevc = entry.hevcFilename {
                let url = baseDirectory.appendingPathComponent(hevc)
                return fileManager.fileExists(atPath: url.path)
            }
            if let raw = entry.rawFilename {
                let url = baseDirectory.appendingPathComponent(raw)
                return fileManager.fileExists(atPath: url.path)
            }
            return false
        }
        
        logger.info("Recovered \(valid.count) valid capture entries from journal")
        return valid
    }
    
    /// All committed entries regardless of file state (for auditor).
    public func recoverAllEntries() throws -> [JournalEntry] {
        guard fileManager.fileExists(atPath: journalURL.path) else { return [] }
        let data = try Data(contentsOf: journalURL)
        return try JSONDecoder().decode([JournalEntry].self, from: data)
    }
    
    /// Entries written but not committed (interrupted before didFinishCapture).
    public func uncommittedEntries() -> [JournalEntry] {
        // Currently we write committed=true atomically, so this is always empty.
        // Future: if two-phase write is added, return pending entries here.
        return []
    }
    
    public nonisolated func fileURL(for filename: String) -> URL {
        baseDirectory.appendingPathComponent(filename)
    }
    
    private func appendToJournal(entry: JournalEntry) throws {
        var entries: [JournalEntry] = []
        if fileManager.fileExists(atPath: journalURL.path) {
            if let data = try? Data(contentsOf: journalURL),
               let existing = try? JSONDecoder().decode([JournalEntry].self, from: data) {
                entries = existing
            }
        }
        entries.append(entry)
        let data = try JSONEncoder().encode(entries)
        try data.write(to: journalURL, options: .atomic)
    }
}
