import Foundation

/// Structured security logger for ObscuraKit.
/// Consumers can provide their own implementation; the default is a no-op.
/// Security-sensitive events are logged through this interface so they
/// never go unnoticed in production.
public protocol ObscuraLogger: Sendable {
    func log(_ message: String)
    func decryptFailed(sourceUserId: String, error: String)
    func ackFailed(envelopeId: String, error: String)
    func frameParseFailed(byteCount: Int, error: String)
    func sessionEstablishFailed(userId: String, error: String)
    func tokenRefreshFailed(attempt: Int, error: String)
    func identityChanged(address: String)
    func databaseError(store: String, operation: String, error: String)
}

/// Thread-safe bounded log recorder that also forwards to the host-provided logger.
final class RecordingLogger: ObscuraLogger, @unchecked Sendable {
    private let lock = NSLock()
    private var delegate: ObscuraLogger
    private var entries: [String] = []
    private let capacity: Int

    init(delegate: ObscuraLogger, capacity: Int = 200) {
        self.delegate = delegate
        self.capacity = capacity
    }

    func setDelegate(_ delegate: ObscuraLogger) {
        guard (delegate as AnyObject) !== self else { return }
        lock.lock()
        self.delegate = delegate
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    private func record(_ message: String) -> ObscuraLogger {
        lock.lock()
        entries.insert(message, at: 0)
        if entries.count > capacity {
            entries.removeLast(entries.count - capacity)
        }
        let current = delegate
        lock.unlock()
        return current
    }

    func log(_ message: String) {
        record(message).log(message)
    }

    func decryptFailed(sourceUserId: String, error: String) {
        record("decrypt failed from \(sourceUserId): \(error)")
            .decryptFailed(sourceUserId: sourceUserId, error: error)
    }

    func ackFailed(envelopeId: String, error: String) {
        record("ack failed for \(envelopeId): \(error)")
            .ackFailed(envelopeId: envelopeId, error: error)
    }

    func frameParseFailed(byteCount: Int, error: String) {
        record("frame parse failed (\(byteCount) bytes): \(error)")
            .frameParseFailed(byteCount: byteCount, error: error)
    }

    func sessionEstablishFailed(userId: String, error: String) {
        record("session establish failed for \(userId): \(error)")
            .sessionEstablishFailed(userId: userId, error: error)
    }

    func tokenRefreshFailed(attempt: Int, error: String) {
        record("token refresh failed (attempt \(attempt)): \(error)")
            .tokenRefreshFailed(attempt: attempt, error: error)
    }

    func identityChanged(address: String) {
        record("identity changed for \(address)").identityChanged(address: address)
    }

    func databaseError(store: String, operation: String, error: String) {
        record("db error in \(store).\(operation): \(error)")
            .databaseError(store: store, operation: operation, error: error)
    }
}

/// Default implementation that prints to stderr. Replace with your own for production.
public final class PrintLogger: ObscuraLogger, @unchecked Sendable {
    public init() {}

    public func log(_ message: String) {
        NSLog("[ObscuraKit] %@", message)
    }

    public func decryptFailed(sourceUserId: String, error: String) {
        log("decrypt failed from \(sourceUserId): \(error)")
    }
    public func ackFailed(envelopeId: String, error: String) {
        log("ack failed for \(envelopeId): \(error)")
    }
    public func frameParseFailed(byteCount: Int, error: String) {
        log("frame parse failed (\(byteCount) bytes): \(error)")
    }
    public func sessionEstablishFailed(userId: String, error: String) {
        log("session establish failed for \(userId): \(error)")
    }
    public func tokenRefreshFailed(attempt: Int, error: String) {
        log("token refresh failed (attempt \(attempt)): \(error)")
    }
    public func identityChanged(address: String) {
        log("identity changed for \(address)")
    }
    public func databaseError(store: String, operation: String, error: String) {
        log("db error in \(store).\(operation): \(error)")
    }
}

/// Silent logger for tests or when no logging is desired.
public final class NoOpLogger: ObscuraLogger, @unchecked Sendable {
    public init() {}
    public func log(_ message: String) {}
    public func decryptFailed(sourceUserId: String, error: String) {}
    public func ackFailed(envelopeId: String, error: String) {}
    public func frameParseFailed(byteCount: Int, error: String) {}
    public func sessionEstablishFailed(userId: String, error: String) {}
    public func tokenRefreshFailed(attempt: Int, error: String) {}
    public func identityChanged(address: String) {}
    public func databaseError(store: String, operation: String, error: String) {}
}
