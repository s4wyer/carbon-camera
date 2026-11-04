// R11 — Recovery metadata and originals
// Authority: NF REF §5 (negative mode / master tape): retain original sensor data
// under a stable capture ID with versioned edit parameters so effects can be removed
// and exposure recovered within the original capture's real headroom.
//
// This file adds the audit layer over CaptureJournal (SET04):
//   - verify every journaled original still matches its recorded SHA-256
//   - classify recoverable vs. damaged vs. interrupted captures
//   - surface a report the UI can present, instead of silently dropping entries

import Foundation
import CryptoKit
import os.log

/// One verified (or damaged) capture in the recovery audit.
public struct RecoveryRecord: Identifiable {
    public let id: UUID              // journal entry id
    public let captureID: String
    public let timestamp: Date
    public let state: RecoveryState
    public let useableSourceURL: URL?   // best remaining original (RAW preferred)
    public let recipeVersionID: UUID
    
    public enum RecoveryState: String {
        /// Both originals present and hashes match.
        case intact
        /// RAW is gone but the processed HEVC original still verifies.
        case processedOnly
        /// Files exist but a hash does not match — data was altered or truncated.
        case damaged
        /// Journal says committed, but no original file survived.
        case missing
        /// Entry was written but never marked committed (interrupted capture).
        case interrupted
        
        public var isRecoverable: Bool {
            switch self {
            case .intact, .processedOnly, .interrupted: return true
            case .damaged, .missing: return false
            }
        }
        
        public var displayName: String {
            switch self {
            case .intact: return "Intact"
            case .processedOnly: return "Processed only"
            case .damaged: return "Damaged"
            case .missing: return "Missing"
            case .interrupted: return "Interrupted"
            }
        }
    }
    
    public init(
        id: UUID,
        captureID: String,
        timestamp: Date,
        state: RecoveryState,
        useableSourceURL: URL?,
        recipeVersionID: UUID
    ) {
        self.id = id
        self.captureID = captureID
        self.timestamp = timestamp
        self.state = state
        self.useableSourceURL = useableSourceURL
        self.recipeVersionID = recipeVersionID
    }
}

/// Aggregate result of a launch-time recovery audit.
public struct RecoveryReport {
    public let records: [RecoveryRecord]
    public let scannedAt: Date
    
    public var intact: [RecoveryRecord] { records.filter { $0.state == .intact } }
    public var processedOnly: [RecoveryRecord] { records.filter { $0.state == .processedOnly } }
    public var interrupted: [RecoveryRecord] { records.filter { $0.state == .interrupted } }
    public var damaged: [RecoveryRecord] { records.filter { $0.state == .damaged } }
    public var missing: [RecoveryRecord] { records.filter { $0.state == .missing } }
    
    /// Captures the user can still open, edit, and export.
    public var recoverable: [RecoveryRecord] { records.filter { $0.state.isRecoverable } }
    
    /// Whether the UI needs to say anything at all.
    public var needsUserAttention: Bool {
        !interrupted.isEmpty || !damaged.isEmpty || !missing.isEmpty
    }
    
    /// Plain-language summary for the recovery banner.
    public var summary: String? {
        guard needsUserAttention else { return nil }
        var parts: [String] = []
        if !interrupted.isEmpty {
            parts.append("\(interrupted.count) interrupted")
        }
        if !damaged.isEmpty {
            parts.append("\(damaged.count) damaged")
        }
        if !missing.isEmpty {
            parts.append("\(missing.count) missing")
        }
        let detail = parts.joined(separator: ", ")
        let recovered = recoverable.count
        return "Recovered \(recovered) photos. \(detail)."
    }
}

/// Verifies journaled originals against their recorded hashes.
public actor CaptureRecoveryAuditor {
    public static let shared = CaptureRecoveryAuditor()
    
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "app.carbon", category: "RecoveryAudit")
    
    private init() {}
    
    /// Audit every journal entry. Never deletes anything; reports only.
    public func audit() async -> RecoveryReport {
        let journal = CaptureJournal.shared
        
        let entries: [JournalEntry]
        do {
            entries = try await journal.recoverAllEntries()
        } catch {
            logger.error("Journal unreadable during audit: \(error.localizedDescription)")
            return RecoveryReport(records: [], scannedAt: Date())
        }
        
        var records: [RecoveryRecord] = []
        records.reserveCapacity(entries.count)
        
        for entry in entries {
            records.append(await classify(entry: entry))
        }
        
        // Interrupted captures are written but uncommitted; include them explicitly.
        let committed = Set(entries.map(\.id))
        let orphans = await journal.uncommittedEntries().filter { !committed.contains($0.id) }
        for entry in orphans {
            records.append(await classify(entry: entry, forceInterrupted: true))
        }
        
        let report = RecoveryReport(records: records, scannedAt: Date())
        logger.info(
            "Recovery audit: \(report.intact.count) intact, \(report.processedOnly.count) processed-only, \(report.interrupted.count) interrupted, \(report.damaged.count) damaged, \(report.missing.count) missing"
        )
        return report
    }
    
    // MARK: - Classification
    
    private func classify(entry: JournalEntry, forceInterrupted: Bool = false) async -> RecoveryRecord {
        let journal = CaptureJournal.shared
        
        // Resolve and verify each original independently.
        let rawURL = entry.rawFilename.map { journal.fileURL(for: $0) }
        let hevcURL = entry.hevcFilename.map { journal.fileURL(for: $0) }
        
        let rawOK = verify(url: rawURL, expectedHash: entry.rawSHA256)
        let hevcOK = verify(url: hevcURL, expectedHash: entry.hevcSHA256)
        
        // Damaged: a file is present but its bytes no longer match the recorded hash.
        if rawOK == .mismatch || hevcOK == .mismatch {
            let survivor = rawOK == .ok ? rawURL : (hevcOK == .ok ? hevcURL : nil)
            return RecoveryRecord(
                id: entry.id,
                captureID: entry.captureID,
                timestamp: entry.timestamp,
                state: .damaged,
                useableSourceURL: survivor,
                recipeVersionID: entry.recipeVersionID
            )
        }
        
        // Prefer RAW for the useable source (R11: recover within real headroom).
        if rawOK == .ok {
            return RecoveryRecord(
                id: entry.id,
                captureID: entry.captureID,
                timestamp: entry.timestamp,
                state: forceInterrupted ? .interrupted : .intact,
                useableSourceURL: rawURL,
                recipeVersionID: entry.recipeVersionID
            )
        }
        
        if hevcOK == .ok {
            return RecoveryRecord(
                id: entry.id,
                captureID: entry.captureID,
                timestamp: entry.timestamp,
                state: forceInterrupted ? .interrupted : .processedOnly,
                useableSourceURL: hevcURL,
                recipeVersionID: entry.recipeVersionID
            )
        }
        
        // Nothing verifiable survived.
        return RecoveryRecord(
            id: entry.id,
            captureID: entry.captureID,
            timestamp: entry.timestamp,
            state: .missing,
            useableSourceURL: nil,
            recipeVersionID: entry.recipeVersionID
        )
    }
    
    private enum FileStatus { case absent, ok, mismatch }
    
    private func verify(url: URL?, expectedHash: String?) -> FileStatus {
        guard let url, fileManager.fileExists(atPath: url.path) else { return .absent }
        guard let expectedHash else {
            // No hash recorded — file exists, cannot prove integrity.
            return .ok
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }

            var hasher = SHA256()
            while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            let digest = hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
            return digest == expectedHash ? .ok : .mismatch
        } catch {
            return .mismatch
        }
    }
}