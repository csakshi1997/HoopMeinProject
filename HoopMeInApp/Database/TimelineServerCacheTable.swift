//
//  TimelineServerCacheTable.swift
//  HoopMeInApp
//
//  Timeline-only cache of server tracking rows (by date).
//  Does not touch LocationTable / sync pipeline.
//

import Foundation
import SQLite

final class TimelineServerCacheTable: Database {

    func createTables() {
        Database.perform {
            createTablesUnlocked()
        }
    }

    /// Caller must already be on `Database.dbQueue`.
    func createTablesUnlocked() {
        guard let db = Database.db else { return }
        do {
            try db.run("""
                CREATE TABLE IF NOT EXISTS TimelineServerCache (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    trackingDate TEXT NOT NULL,
                    serverId TEXT,
                    isOfflineRecord TEXT,
                    latitude TEXT,
                    longitude TEXT,
                    diffrenceBetweenCurrentAndLastLatLong TEXT,
                    address TEXT,
                    isMockLocation TEXT,
                    dateTime TEXT,
                    batteryPercentage TEXT,
                    deviceModel TEXT,
                    deviceManufacturer TEXT,
                    isSyncToServer TEXT,
                    timeDifference TEXT
                );
            """)
            // Existing installs may have created the table before serverId existed.
            if !Database.columnExists(in: "TimelineServerCache", column: "serverId") {
                try db.run("ALTER TABLE TimelineServerCache ADD COLUMN serverId TEXT")
            }
            try db.run("""
                CREATE TABLE IF NOT EXISTS TimelineServerCacheMeta (
                    trackingDate TEXT PRIMARY KEY,
                    totalDistance TEXT,
                    totalRecord INTEGER
                );
            """)
            try db.run("""
                CREATE INDEX IF NOT EXISTS idx_timeline_server_cache_date
                ON TimelineServerCache(trackingDate);
            """)
            // One row per server record id for a given date.
            try db.run("""
                CREATE UNIQUE INDEX IF NOT EXISTS idx_timeline_server_cache_server_id
                ON TimelineServerCache(trackingDate, serverId)
                WHERE serverId IS NOT NULL AND serverId != '';
            """)
        } catch {
            print("Failed to create TimelineServerCache tables: \(error)")
        }
    }

    /// Replaces all cached rows for `trackingDate` with the latest server payload.
    /// Skips duplicate `serverRecordId` values within the payload.
    func replaceCache(
        for trackingDate: String,
        locations: [LocationModel],
        totalDistance: String,
        totalRecord: Int
    ) {
        Database.perform {
            guard let db = Database.db else { return }
            let date = trackingDate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !date.isEmpty else { return }
            let uniqueLocations = Self.deduplicatedByServerId(locations)
            do {
                try db.run("DELETE FROM TimelineServerCache WHERE trackingDate = ?", date)
                try db.run(
                    """
                    INSERT OR REPLACE INTO TimelineServerCacheMeta
                    (trackingDate, totalDistance, totalRecord)
                    VALUES (?, ?, ?)
                    """,
                    date,
                    totalDistance,
                    totalRecord
                )

                let insertSQL = """
                INSERT OR IGNORE INTO TimelineServerCache (
                    trackingDate,
                    serverId,
                    isOfflineRecord,
                    latitude,
                    longitude,
                    diffrenceBetweenCurrentAndLastLatLong,
                    address,
                    isMockLocation,
                    dateTime,
                    batteryPercentage,
                    deviceModel,
                    deviceManufacturer,
                    isSyncToServer,
                    timeDifference
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """

                for item in uniqueLocations {
                    try db.run(
                        insertSQL,
                        date,
                        item.serverRecordId,
                        item.isOfflineRecord,
                        item.latitude,
                        item.longitude,
                        item.diffrenceBetweenCurrentAndLastLatLong,
                        item.address,
                        item.isMockLocation,
                        item.dateTime,
                        item.batteryPercentage,
                        item.deviceModel,
                        item.deviceManufacturer,
                        item.isSyncToServer,
                        item.timeDifference
                    )
                }
            } catch {
                print("Failed to replace TimelineServerCache: \(error)")
            }
        }
    }

    /// Keeps first occurrence of each non-empty server record id.
    static func deduplicatedByServerId(_ locations: [LocationModel]) -> [LocationModel] {
        var seenIds = Set<String>()
        var result: [LocationModel] = []
        result.reserveCapacity(locations.count)
        for item in locations {
            if let serverId = item.serverRecordId?.trimmingCharacters(in: .whitespacesAndNewlines),
               !serverId.isEmpty {
                if seenIds.contains(serverId) {
                    continue
                }
                seenIds.insert(serverId)
            }
            result.append(item)
        }
        return result
    }

    /// Returns cached server timeline for a date, if this date was ever stored online.
    func cache(for trackingDate: String) -> (locations: [LocationModel], totalDistance: String, totalRecord: Int)? {
        Database.perform {
            guard let db = Database.db else { return nil }
            let date = trackingDate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !date.isEmpty else { return nil }

            do {
                var totalDistance = "0"
                var totalRecord = 0
                var hasMeta = false
                let metaQuery = """
                SELECT totalDistance, totalRecord
                FROM TimelineServerCacheMeta
                WHERE trackingDate = ?
                LIMIT 1
                """
                for row in try db.prepare(metaQuery, date) {
                    hasMeta = true
                    totalDistance = stringValue(row[0]) ?? "0"
                    if let value = row[1] as? Int64 {
                        totalRecord = Int(value)
                    } else if let value = row[1] as? Int {
                        totalRecord = value
                    }
                }
                guard hasMeta else { return nil }

                var items: [LocationModel] = []
                let rowsQuery = """
                SELECT
                    id,
                    serverId,
                    isOfflineRecord,
                    latitude,
                    longitude,
                    diffrenceBetweenCurrentAndLastLatLong,
                    address,
                    isMockLocation,
                    dateTime,
                    batteryPercentage,
                    deviceModel,
                    deviceManufacturer,
                    isSyncToServer,
                    timeDifference
                FROM TimelineServerCache
                WHERE trackingDate = ?
                ORDER BY dateTime DESC, id DESC
                """
                for row in try db.prepare(rowsQuery, date) {
                    items.append(mapRow(row))
                }
                return (Self.deduplicatedByServerId(items), totalDistance, totalRecord)
            } catch {
                print("Failed to read TimelineServerCache: \(error)")
                return nil
            }
        }
    }

    private func mapRow(_ row: Statement.Element) -> LocationModel {
        var model = LocationModel()
        if let idValue = row[0] as? Int64 {
            model.id = Int(idValue)
        } else if let idValue = row[0] as? Int {
            model.id = idValue
        }
        model.serverRecordId = stringValue(row[1])
        model.isOfflineRecord = stringValue(row[2])
        model.latitude = stringValue(row[3])
        model.longitude = stringValue(row[4])
        model.diffrenceBetweenCurrentAndLastLatLong = stringValue(row[5])
        model.address = stringValue(row[6])
        model.isMockLocation = stringValue(row[7])
        model.dateTime = stringValue(row[8])
        model.batteryPercentage = stringValue(row[9])
        model.deviceModel = stringValue(row[10])
        model.deviceManufacturer = stringValue(row[11])
        model.isSyncToServer = stringValue(row[12])
        model.timeDifference = stringValue(row[13])
        return model
    }

    private func stringValue(_ value: Binding?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? Int64 { return "\(value)" }
        if let value = value as? Int { return "\(value)" }
        if let value = value as? Double { return "\(value)" }
        return nil
    }
}
