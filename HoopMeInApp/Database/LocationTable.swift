//
//  LocationTable.swift
//  HoopMeInApp
//
//  Created by Sakshi on 21/11/25.
//  Copyright © 2025 HoopMeInAppOrganizationName. All rights reserved.
//

import Foundation
import SQLite

class LocationTable: Database {
    func createLocationTable() {
        Database.perform {
            createLocationTableUnlocked()
        }
    }

    /// Caller must already be on `Database.dbQueue`.
    func createLocationTableUnlocked() {
        guard let db = Database.db else { return }
        do {
            try db.run("""
                CREATE TABLE IF NOT EXISTS LocationTable (                    
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    isOfflineRecord INTEGER,
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
                    timeDifference  TEXT
                );
            """)
        } catch {
            print("Failed to create location  Table: \(error)")
        }
    }

    func saveLocation(_ c: LocationModel) -> Bool {
        Database.perform {
            guard let db = Database.db else { return false }
            let sql = """
            INSERT INTO LocationTable (
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
            timeDifference) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

            let values: [Binding?] = [
                c.isOfflineRecord,
                c.latitude,
                c.longitude,
                c.diffrenceBetweenCurrentAndLastLatLong,
                c.address,
                c.isMockLocation,
                c.dateTime,
                c.batteryPercentage,
                c.deviceModel,
                c.deviceManufacturer,
                c.isSyncToServer,
                c.timeDifference
            ]

            do {
                try db.run(sql, values)
                print("Location saved successfully.")
                return true
            } catch {
                print("Failed to save location: \(error.localizedDescription)")
                return false
            }
        }
    }

    /// Any row not explicitly marked synced (`'1'`).
    private static let pendingWhereSQL = "COALESCE(isSyncToServer, '0') != '1'"

    func getLocation() -> LocationModel? {
        Database.perform {
            guard let db = Database.db else { return nil }
            do {
                // FIFO: lowest autoincrement id = saved first → sync first.
                let query = """
                SELECT * FROM LocationTable
                WHERE \(Self.pendingWhereSQL)
                ORDER BY id ASC, dateTime ASC
                LIMIT 1
                """
                for row in try db.prepare(query) {
                    return mapRow(row)
                }
            } catch {
                print("Fetch error: \(error)")
            }
            return nil
        }
    }

    /// How many rows still need upload (used to keep draining until empty).
    func pendingUnsyncedCount() -> Int {
        Database.perform {
            guard let db = Database.db else { return 0 }
            do {
                let query = "SELECT COUNT(*) FROM LocationTable WHERE \(Self.pendingWhereSQL)"
                if let count = try db.scalar(query) as? Int64 {
                    return Int(count)
                }
            } catch {
                print("Pending count error: \(error)")
            }
            return 0
        }
    }

    func getAllLocation(date: String) -> [LocationModel] {
        Database.perform {
            guard let db = Database.db else { return [] }
            var locationModels: [LocationModel] = []
            do {
                // date is app-controlled (picker); keep existing filter style.
                for row in try db.prepare("SELECT * FROM LocationTable WHERE dateTime LIKE '\(date)%' ORDER BY id DESC") {
                    locationModels.append(mapRow(row))
                }
            } catch {
                print("Fetch error: \(error)")
            }
            return locationModels
        }
    }

    func updateSyncStatus(id: Int, isSynced: String) {
        Database.perform {
            guard let db = Database.db else { return }
            do {
                let query = "UPDATE LocationTable SET isSyncToServer = ? WHERE id = ?"
                try db.run(query, isSynced, id)
            } catch {
                print("Update error: \(error)")
            }
        }
    }

    /// Timeline display only — updates address text, never touches sync flags.
    func updateAddress(id: Int, address: String) {
        Database.perform {
            guard let db = Database.db else { return }
            do {
                let query = "UPDATE LocationTable SET address = ? WHERE id = ?"
                try db.run(query, address, id)
            } catch {
                print("Update address error: \(error)")
            }
        }
    }

    /// Removes rows that were never uploaded. Call on logout so they are not synced later with an empty user id.
    func deleteAllPendingUnsynced() {
        Database.perform {
            guard let db = Database.db else { return }
            do {
                try db.run("DELETE FROM LocationTable WHERE \(Self.pendingWhereSQL)")
            } catch {
                print("Delete pending locations error: \(error)")
            }
        }
    }

    func deleteLocationById(
        id: Int,
        completion: @escaping (Bool, String?) -> Void
    ) {
        Database.dbQueue.async {
            guard let db = Database.db else {
                DispatchQueue.main.async { completion(false, "Database not available.") }
                return
            }
            do {
                let table = Table("LocationTable")
                let idColumn = Expression<String>(value: "id")
                let record = table.filter(idColumn == "\(id)")
                if try db.run(record.delete()) > 0 {
                    DispatchQueue.main.async { completion(true, nil) }
                } else {
                    DispatchQueue.main.async { completion(false, "No record found.") }
                }
            } catch {
                let errorMsg = "Delete failed: \(error.localizedDescription)"
                DispatchQueue.main.async { completion(false, errorMsg) }
            }
        }
    }

    private func mapRow(_ row: Statement.Element) -> LocationModel {
        var locationModel = LocationModel()
        if let idValue = row[0] as? Int64 {
            locationModel.id = Int(idValue)
        } else if let idValue = row[0] as? Int {
            locationModel.id = idValue
        }
        locationModel.isOfflineRecord = stringValue(row[1])
        locationModel.latitude = stringValue(row[2])
        locationModel.longitude = stringValue(row[3])
        locationModel.diffrenceBetweenCurrentAndLastLatLong = stringValue(row[4])
        locationModel.address = stringValue(row[5])
        locationModel.isMockLocation = stringValue(row[6])
        locationModel.dateTime = stringValue(row[7])
        locationModel.batteryPercentage = stringValue(row[8])
        locationModel.deviceModel = stringValue(row[9])
        locationModel.deviceManufacturer = stringValue(row[10])
        locationModel.isSyncToServer = stringValue(row[11])
        locationModel.timeDifference = stringValue(row[12])
        return locationModel
    }

    private func stringValue(_ value: Binding?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? Int64 { return "\(value)" }
        if let value = value as? Int { return "\(value)" }
        if let value = value as? Double { return "\(value)" }
        return nil
    }
}
