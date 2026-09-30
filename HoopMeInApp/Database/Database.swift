//
//  Database.swift
//  HoopMeInApp
//
//  Created by Sakshi on 21/11/25.
//  Copyright © 2025 HoopMeInAppOrganizationName. All rights reserved.
//

import Foundation
import SQLite

class Database {
    static var db: Connection?
    /// All SQLite access must run on this queue — Connection is not thread-safe.
    static let dbQueue = DispatchQueue(label: "com.hoopMeIn.sqlite")

    static var databaseConnection: OpaquePointer? {
        guard let db = db else { return nil }
        return db.handle
    }

    @discardableResult
    static func perform<T>(_ work: () throws -> T) rethrows -> T {
        try dbQueue.sync(execute: work)
    }

    class func createDatabase() {
        dbQueue.sync {
            do {
                db = try Connection(getDBPath())
                db?.busyTimeout = 5
                db?.busyHandler({ _ in return true })
                print("DB Opened at path: \(getDBPath())")

                let locationTable = LocationTable()
                locationTable.createLocationTableUnlocked()

                let timelineCacheTable = TimelineServerCacheTable()
                timelineCacheTable.createTablesUnlocked()
            } catch {
                print("Failed to open database: \(error.localizedDescription)")
            }
        }
    }
    
    class func getDBPath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentDirectory = paths[0]
        return "\(documentDirectory)/HoopMeIn.sqlite3"
    }
    
    class func columnExists(in table: String, column: String) -> Bool {
        guard let db = db else { return false }
        
        do {
            let pragma = try db.prepare("PRAGMA table_info(\(table))")
            for row in pragma {
                if let colName = row[1] as? String, colName == column {
                    return true
                }
            }
        } catch {
            print("Error checking column existence: \(error)")
        }
        return false
    }
    
    class func deleteTable(named table: String) {
        guard let db = db else { return }
        do {
            try db.run("DELETE FROM \(table)")
            print("Cleared table \(table)")
        } catch {
            print("Failed to delete table: \(error)")
        }
    }
    
    class func alterTable(tableName: String, dictArray: [[String: String]]) {
        guard let db = db else { return }
        
        for columnDict in dictArray {
            guard let column = columnDict["column"], let defaultValue = columnDict["defaultValue"] else { continue }
            
            if !columnExists(in: tableName, column: column) {
                let alterSQL = "ALTER TABLE \(tableName) ADD COLUMN \(column) TEXT DEFAULT '\(defaultValue)'"
                do {
                    try db.run(alterSQL)
                    print("Added column \(column) to \(tableName)")
                } catch {
                    print("Error altering table: \(error)")
                }
            } else {
                print("Column '\(column)' already exists in '\(tableName)'")
            }
        }
    }
}

