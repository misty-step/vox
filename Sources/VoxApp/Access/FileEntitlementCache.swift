import Foundation
import VoxCore

/// File-backed entitlement cache with TTL.
actor FileEntitlementCache: EntitlementCacheStore {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let voxDir = appSupport.appendingPathComponent("Vox", isDirectory: true)
        do {
            try fileManager.createDirectory(at: voxDir, withIntermediateDirectories: true)
        } catch {
            Diagnostics.warning("Failed to create Vox app support dir: \(String(describing: error))")
        }
        fileURL = voxDir.appendingPathComponent("entitlement-cache.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func get() async -> (status: AccessEntitlementStatus, expiresAt: Date)? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            Diagnostics.warning("Failed to read entitlement cache: \(String(describing: error))")
            return nil
        }

        do {
            let cached = try decoder.decode(CachedEntitlement.self, from: data)
            let status = cached.status.toAccessStatus(graceUntil: cached.graceUntil, fallback: cached.expiresAt)
            return (status, cached.expiresAt)
        } catch {
            Diagnostics.warning("Failed to decode entitlement cache: \(String(describing: error))")
            return nil
        }
    }

    func save(_ status: AccessEntitlementStatus, ttl: TimeInterval) async {
        let expiresAt = Date().addingTimeInterval(ttl)
        let stored = StoredStatus.from(status)
        let cached = CachedEntitlement(status: stored.kind, graceUntil: stored.graceUntil, expiresAt: expiresAt)

        do {
            let data = try encoder.encode(cached)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Diagnostics.warning("Failed to write entitlement cache: \(String(describing: error))")
        }
    }

    func clear() async {
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            Diagnostics.warning("Failed to clear entitlement cache: \(String(describing: error))")
        }
    }
}

// MARK: - Codable wrappers

private struct CachedEntitlement: Codable {
    let status: StoredStatus.Kind
    let graceUntil: Date?
    let expiresAt: Date
}

private struct StoredStatus {
    enum Kind: String, Codable {
        case entitled
        case gracePeriod
        case expired
    }

    let kind: Kind
    let graceUntil: Date?

    static func from(_ status: AccessEntitlementStatus) -> StoredStatus {
        switch status {
        case .entitled:
            return StoredStatus(kind: .entitled, graceUntil: nil)
        case .gracePeriod(let until):
            return StoredStatus(kind: .gracePeriod, graceUntil: until)
        case .expired:
            return StoredStatus(kind: .expired, graceUntil: nil)
        }
    }
}

private extension StoredStatus.Kind {
    func toAccessStatus(graceUntil: Date?, fallback: Date) -> AccessEntitlementStatus {
        switch self {
        case .entitled:
            return .entitled
        case .gracePeriod:
            return .gracePeriod(until: graceUntil ?? fallback)
        case .expired:
            return .expired
        }
    }
}
