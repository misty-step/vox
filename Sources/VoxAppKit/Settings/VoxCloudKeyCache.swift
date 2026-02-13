import Foundation
import VoxCore
import VoxMac

/// Thread-safe cache for Vox Cloud API keys with TTL support.
public actor VoxCloudKeyCache {
    private var cachedKeys: VoxCloudKeys?
    private var expiresAt: Date?
    
    public init() {}
    
    /// Checks if the cache has valid (non-expired) keys.
    public var isCacheValid: Bool {
        guard let expiresAt = expiresAt else { return false }
        return cachedKeys != nil && expiresAt > Date()
    }
    
    /// Returns the cached keys if valid, nil otherwise.
    public func getKeys() -> VoxCloudKeys? {
        guard isCacheValid else { return nil }
        return cachedKeys
    }
    
    /// Stores keys with expiration time.
    public func setKeys(_ keys: VoxCloudKeys, expiresAt: Date) {
        self.cachedKeys = keys
        self.expiresAt = expiresAt
    }
    
    /// Clears the cache.
    public func clear() {
        cachedKeys = nil
        expiresAt = nil
    }
}
