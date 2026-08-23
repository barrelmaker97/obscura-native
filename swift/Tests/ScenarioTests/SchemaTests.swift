import GRDB
import XCTest
@testable import ObscuraKit

final class SchemaTests: XCTestCase {
    private func tableNames(in db: DatabaseQueue) throws -> Set<String> {
        try db.read { db in
            let names = try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master
                 WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
            """)
            return Set(names).subtracting(["grdb_migrations"])
        }
    }

    private func columns(of table: String, in db: DatabaseQueue) throws -> [String] {
        try db.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(\(table))")
                .map { "\($0["name"] as String):\($0["type"] as String)" }
        }
    }

    func testMigratedDatabaseHasExactlyTheDeclaredTables() throws {
        let db = try DatabaseQueue()
        try ObscuraSchema.migrate(db)
        XCTAssertEqual(try tableNames(in: db), ObscuraSchema.expectedTables)
    }

    func testIrreplaceableTableColumnsAreFrozen() throws {
        let db = try DatabaseQueue()
        try ObscuraSchema.migrate(db)

        XCTAssertEqual(try columns(of: "model_entries", in: db), [
            "model_name:TEXT", "id:TEXT", "data:TEXT", "timestamp:INTEGER",
            "author_device_id:TEXT",
        ])
        XCTAssertEqual(try columns(of: "inbox_rows", in: db), [
            "id:INTEGER", "envelope_id:TEXT", "kind:TEXT", "received_at:INTEGER",
            "sender_user_id:TEXT", "sender_device_id:TEXT", "sender_display_name:TEXT",
            "model_key:TEXT", "entry_id:TEXT", "op:TEXT", "sent_at:INTEGER", "payload:BLOB",
        ])
    }

    func testMigrationIsIdempotent() throws {
        let db = try DatabaseQueue()
        for _ in 0..<5 { try ObscuraSchema.migrate(db) }
        XCTAssertEqual(
            try db.read { try ObscuraSchema.migrator.appliedMigrations($0) },
            ["v1"]
        )
    }

    func testConstructingOneStoreCreatesTheWholeSchema() throws {
        let db = try DatabaseQueue()
        _ = try FriendActor(db: db)
        XCTAssertEqual(try tableNames(in: db), ObscuraSchema.expectedTables)
    }

    func testEntryPrimaryKeyMakesUpsertReplace() throws {
        let db = try DatabaseQueue()
        try ObscuraSchema.migrate(db)
        try db.write { db in
            for value in ["first", "second"] {
                try db.execute(sql: """
                    INSERT OR REPLACE INTO model_entries
                        (model_name, id, data, timestamp, author_device_id)
                    VALUES ('story', 'e1', ?, 1, 'device-a')
                """, arguments: [value])
            }
        }

        let values = try db.read { db in
            try String.fetchAll(db, sql: """
                SELECT data FROM model_entries WHERE model_name = 'story' AND id = 'e1'
            """)
        }
        XCTAssertEqual(values, ["second"])
    }
}
