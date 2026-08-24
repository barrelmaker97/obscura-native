import Foundation
import GRDB

public struct DeviceIdentity: Codable, Sendable, Equatable {
    public var deviceId: String

    public init(deviceId: String) {
        self.deviceId = deviceId
    }
}

public struct OwnDevice: Codable, Sendable, Equatable {
    public var deviceId: String
    public var deviceName: String

    public init(deviceId: String, deviceName: String) {
        self.deviceId = deviceId
        self.deviceName = deviceName
    }
}

public actor DeviceStore {
    private let db: DatabaseQueue

    public nonisolated var dbQueue: DatabaseQueue { db }

    public init(db: DatabaseQueue) throws {
        self.db = db
        try ObscuraSchema.migrate(db)
    }

    public init() throws {
        self.db = try DatabaseQueue()
        try db.write { db in try db.execute(sql: "PRAGMA secure_delete = ON") }
        try ObscuraSchema.migrate(db)
    }

    // MARK: - Reactive Streams

    /// Stream of own devices. Emits on every change.
    public nonisolated func observeOwnDevices() -> AsyncValueObservation<[OwnDevice]> {
        let observation = ValueObservation.tracking { db -> [OwnDevice] in
            try Row.fetchAll(db, sql: "SELECT * FROM own_devices").map { row in
                OwnDevice(deviceId: row["device_id"], deviceName: row["device_name"])
            }
        }
        return AsyncValueObservation(observation: observation, in: db)
    }

    public func storeIdentity(_ identity: DeviceIdentity) async {
        try? await db.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO device_identity (id, device_id)
                VALUES (1, ?)
            """, arguments: [identity.deviceId])
        }
    }

    public func getIdentity() async -> DeviceIdentity? {
        try? await db.read { db -> DeviceIdentity? in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM device_identity WHERE id = 1") else { return nil }
            return DeviceIdentity(deviceId: row["device_id"])
        }
    }

    public func hasIdentity() async -> Bool {
        await getIdentity() != nil
    }

    public func addOwnDevice(_ device: OwnDevice) async {
        try? await db.write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO own_devices (device_id, device_name)
                VALUES (?, ?)
            """, arguments: [device.deviceId, device.deviceName])
        }
    }

    public func getOwnDevices() async -> [OwnDevice] {
        (try? await db.read { db -> [OwnDevice] in
            try Row.fetchAll(db, sql: "SELECT * FROM own_devices").map { row in
                OwnDevice(deviceId: row["device_id"], deviceName: row["device_name"])
            }
        }) ?? []
    }

    public func clearAll() async {
        try? await db.write { db in
            try db.execute(sql: "DELETE FROM device_identity")
            try db.execute(sql: "DELETE FROM own_devices")
        }
    }
}
