//
//  LocationSyncManager.swift
//  HoopMeInApp
//
//  Created by Sakshi on 21/11/25.
//  Copyright © 2025 HoopMeInAppOrganizationName. All rights reserved.
//

import Foundation
import Network
import UIKit
import CoreLocation

private final class LocationBackgroundTaskBox {
    var id: UIBackgroundTaskIdentifier = .invalid
    private let lock = NSLock()

    func end() {
        lock.lock()
        let taskId = id
        id = .invalid
        lock.unlock()
        guard taskId != .invalid else { return }
        DispatchQueue.main.async {
            UIApplication.shared.endBackgroundTask(taskId)
        }
    }
}

class LocationSyncManager {
    let webRequest = BaseWebService()
    let locationTable = LocationTable()
    let endPoint = EndPoints()
    let customDateFormatter = CustomDateFormatter()
    let monitor = NWPathMonitor()
    let queue = DispatchQueue.global(qos: .utility)
    /// Serializes save work so concurrent GPS callbacks cannot race lastSaved / geocode.
    private let saveQueue = DispatchQueue(label: "com.hoopMeIn.locationSave")
    private let syncStateQueue = DispatchQueue(label: "com.hoopMeIn.locationSyncState")
    static let shared = LocationSyncManager()
    private var isAPIRunning: Bool = false
    private var syncStartedAt: Date?
    /// Bumped when a sync attempt is invalidated (e.g. network drop) so stale API callbacks are ignored.
    private var syncAttemptId: Int = 0
    /// If an upload hangs after background suspend, unblock after this.
    private let syncStuckTimeoutSeconds: TimeInterval = 45
    /// Retry delay when a row fails but network/identity are still valid.
    private let syncRetryDelaySeconds: TimeInterval = 2.5
    /// After this many failures for the same row, skip it so newer points can still upload.
    private let maxFailuresPerRow = 8
    private var failureCountsByLocationId: [Int: Int] = [:]
    private var pendingRetryWorkItem: DispatchWorkItem?

    /// Fallback Salesforce REST path (relative to instance). Must match an object the org exposes to the Mobile SDK user.
    private let salesforceLocationCompositeTreePath = "/services/data/v63.0/composite/tree/User_Location_Track__c"

    /// Prevents uploads with blank user/org (the usual cause of “anonymous” rows after logout or session loss).
    func hasValidIdentityForSync() -> Bool {
        guard let uid = Defaults.userId?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty else { return false }
        let token = (Defaults.accessToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let org = (Defaults.instanceUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !token.isEmpty && !org.isEmpty
    }

    /// Recording only needs a Salesforce user id (token may refresh while queued rows wait).
    func hasValidUserContextForRecording() -> Bool {
        guard let uid = Defaults.userId?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty else { return false }
        return true
    }

    private func isNetworkAvailable() -> Bool {
        // Prefer a live check — AppDelegate path flag can stay stale while suspended in background.
        if InternetConnectionManager.isConnectedToNetwork() {
            return true
        }
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            return appDelegate.isInternetReachable
        }
        return false
    }

    /// Starts a new sync attempt. Returns attempt id, or nil if another attempt is still in progress.
    private func beginSyncIfAllowed() -> Int? {
        syncStateQueue.sync {
            if isAPIRunning {
                if let started = syncStartedAt,
                   Date().timeIntervalSince(started) > syncStuckTimeoutSeconds {
                    print("⚠️ Sync lock stuck > \(Int(syncStuckTimeoutSeconds))s — resetting")
                    // Invalidate in-flight attempt so its late callback cannot resume twice / corrupt state.
                    syncAttemptId += 1
                    isAPIRunning = false
                    syncStartedAt = nil
                } else {
                    return nil
                }
            }
            isAPIRunning = true
            syncAttemptId += 1
            syncStartedAt = Date()
            return syncAttemptId
        }
    }

    private func endSyncLock(attemptId: Int? = nil) {
        syncStateQueue.sync {
            if let attemptId, attemptId != syncAttemptId {
                return
            }
            isAPIRunning = false
            syncStartedAt = nil
        }
    }

    private func isCurrentSyncAttempt(_ attemptId: Int) -> Bool {
        syncStateQueue.sync { attemptId == syncAttemptId && isAPIRunning }
    }

    /// Clears hung/in-flight sync so a new drain can start (network restore / GPS wake).
    func forceUnlockSync() {
        syncStateQueue.sync {
            syncAttemptId += 1
            isAPIRunning = false
            syncStartedAt = nil
        }
    }

    /// Call when app returns to foreground so a hung background upload cannot block forever.
    func resetStuckSyncStateIfNeeded() {
        syncStateQueue.sync {
            guard isAPIRunning else { return }
            if let started = syncStartedAt,
               Date().timeIntervalSince(started) > syncStuckTimeoutSeconds {
                print("⚠️ Clearing stuck sync lock on foreground")
                syncAttemptId += 1
                isAPIRunning = false
                syncStartedAt = nil
            }
        }
    }

    /// Network lost or restored while traveling in background.
    func handleConnectivityChange(isOnline: Bool) {
        if isOnline {
            print("🌐 Network restored — unlock + drain pending locations")
            forceUnlockSync()
            startPendingLocationSync()
        } else {
            print("📴 Network lost — unlock hung sync so queue can resume later")
            cancelScheduledRetry()
            forceUnlockSync()
        }
    }

    private func cancelScheduledRetry() {
        syncStateQueue.sync {
            pendingRetryWorkItem?.cancel()
            pendingRetryWorkItem = nil
        }
    }

    /// Keep trying until the pending queue is empty (or offline / logged out).
    private func scheduleDrainRetry(after delay: TimeInterval, completion: (() -> Void)?) {
        let work = DispatchWorkItem { [weak self] in
            self?.startPendingLocationSync(completion: completion)
        }
        syncStateQueue.sync {
            pendingRetryWorkItem?.cancel()
            pendingRetryWorkItem = work
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func recordFailure(for locationId: Int) -> Int {
        syncStateQueue.sync {
            let next = (failureCountsByLocationId[locationId] ?? 0) + 1
            failureCountsByLocationId[locationId] = next
            return next
        }
    }

    private func clearFailure(for locationId: Int) {
        syncStateQueue.sync {
            failureCountsByLocationId.removeValue(forKey: locationId)
        }
    }

    func clearPendingUnsyncedLocations() {
        locationTable.deleteAllPendingUnsynced()
    }

    /// Logout-only cleanup: drop unsynced queue and local last-point cache so nothing uploads under a blank/new user.
    /// Do not call this from checkout / punch-out.
    func prepareForLogout() {
        cancelScheduledRetry()
        forceUnlockSync()
        clearPendingUnsyncedLocations()
        UserDefaults.standard.removeObject(forKey: "lastSavedLocation")
        UserDefaults.standard.removeObject(forKey: "lastSavedTime")
        UserDefaults.standard.synchronize()
    }

    /// Single entry point: check pending rows in DB and sync them continuously (one by one, oldest first).
    /// Safe to call often — no-op if already syncing, offline, or queue empty.
    /// - Parameter forceUnlock: clear hung lock first (use after network restore / location wake).
    func startPendingLocationSync(forceUnlock: Bool = false, completion: (() -> Void)? = nil) {
        if forceUnlock {
            forceUnlockSync()
        } else {
            resetStuckSyncStateIfNeeded()
        }
        syncOfflineLocationsToServer(completion: completion)
    }

    /// Uploads pending locations **one at a time, oldest first**, until none remain.
    /// On success, schedules the next upload asynchronously (never deep recursion / stack overflow).
    func syncOfflineLocationsToServer(completion: (() -> Void)? = nil) {
        guard hasValidIdentityForSync() else {
            completion?()
            return
        }
        guard isNetworkAvailable() else {
            completion?()
            return
        }
        guard let attemptId = beginSyncIfAllowed() else {
            // Another drain is already running — it will continue until empty.
            completion?()
            return
        }
        guard let location = locationTable.getLocation(),
              let locationId = location.id else {
            let remaining = locationTable.pendingUnsyncedCount()
            if remaining > 0 {
                // Rare race / query mismatch — keep draining.
                print("⚠️ Pending count \(remaining) but getLocation nil — retry drain")
                endSyncLock(attemptId: attemptId)
                scheduleDrainRetry(after: syncRetryDelaySeconds, completion: completion)
                return
            }
            print("✅ Location sync queue empty — all pending rows uploaded")
            cancelScheduledRetry()
            endSyncLock(attemptId: attemptId)
            completion?()
            return
        }
        print("⬆️ Syncing location id=\(locationId) (oldest pending first); remaining≈\(locationTable.pendingUnsyncedCount())")
        sendLocationToServer(location) { [weak self] success in
            guard let self = self else {
                completion?()
                return
            }
            // Ignore callbacks from an invalidated attempt (e.g. network dropped mid-request).
            guard self.isCurrentSyncAttempt(attemptId) else {
                // Lock was cleared (network drop / force unlock). Retry so nothing is left idle.
                self.scheduleDrainRetry(after: 1.0, completion: nil)
                completion?()
                return
            }
            if success {
                self.locationTable.updateSyncStatus(id: locationId, isSynced: "1")
                self.clearFailure(for: locationId)
                self.endSyncLock(attemptId: attemptId)
                // Continue on next run-loop turn to avoid stack overflow with large queues.
                DispatchQueue.global(qos: .utility).async {
                    self.syncOfflineLocationsToServer(completion: completion)
                }
            } else {
                print("Failed to sync location \(locationId)")
                if !self.hasUploadableCoordinates(location) {
                    print("Skipping invalid coordinates for location \(locationId)")
                    self.locationTable.updateSyncStatus(id: locationId, isSynced: "1")
                    self.clearFailure(for: locationId)
                    self.endSyncLock(attemptId: attemptId)
                    DispatchQueue.global(qos: .utility).async {
                        self.syncOfflineLocationsToServer(completion: completion)
                    }
                    return
                }
                let failures = self.recordFailure(for: locationId)
                self.endSyncLock(attemptId: attemptId)
                if failures >= self.maxFailuresPerRow {
                    // Poison row — skip so the rest of the ordered queue can finish.
                    print("⚠️ Skipping location \(locationId) after \(failures) failures so remaining rows can sync")
                    self.locationTable.updateSyncStatus(id: locationId, isSynced: "1")
                    self.clearFailure(for: locationId)
                    DispatchQueue.global(qos: .utility).async {
                        self.syncOfflineLocationsToServer(completion: completion)
                    }
                } else {
                    // Keep retrying the same oldest row until it uploads (FIFO).
                    print("🔁 Retry location \(locationId) in \(self.syncRetryDelaySeconds)s (\(failures)/\(self.maxFailuresPerRow))")
                    self.scheduleDrainRetry(after: self.syncRetryDelaySeconds, completion: completion)
                }
            }
        }
    }

    private func hasUploadableCoordinates(_ location: LocationModel?) -> Bool {
        guard let latitude = location?.latitude, let longitude = location?.longitude,
              !latitude.isEmpty, !longitude.isEmpty,
              let lat = Double(latitude), let lon = Double(longitude),
              lat.isFinite, lon.isFinite,
              abs(lat) > 0.0001 || abs(lon) > 0.0001 else {
            return false
        }
        return true
    }
    
    func sendLocationToServer(_ location: LocationModel, completion: @escaping (Bool) -> Void) {
        guard hasValidIdentityForSync() else {
            completion(false)
            return
        }
        guard let latitude = location.latitude, let longitude = location.longitude,
              !latitude.isEmpty, !longitude.isEmpty else {
            completion(false)
            return
        }
        guard let lat = Double(latitude), let lon = Double(longitude),
              lat.isFinite, lon.isFinite,
              abs(lat) > 0.0001 || abs(lon) > 0.0001 else {
            completion(false)
            return
        }
        let isOfflineRecordBool = (location.isOfflineRecord == "1")
        let locationPayload: [String: Any] = [
            "Address": location.address ?? "Unknown Address",
            "BatteryPercentage": location.batteryPercentage ?? "0",
            "DateTime": location.dateTime ?? CustomDateFormatter.getCurrentDateTime(),
            "DeviceManufacturer": "Apple",
            "DeviceModel": UIDevice.current.model,
            "DeviceType": "iOS",
            "IsFakeLocation": false,
            "IsOfflineRecord": isOfflineRecordBool,
            "Latitude": latitude,
            "Longitude": longitude,
            "MobileDistanceKm": {
                if let value = location.diffrenceBetweenCurrentAndLastLatLong,
                   let doubleValue = Double(value) {
                    return String(format: "%.2f", doubleValue)
                } else {
                    return "0.00"
                }
            }(),
            "OrgUrl": Defaults.instanceUrl ?? "",
            "UserId": Defaults.userId ?? "",
            "UserName": Defaults.userName ?? ""
        ]
        
        let fallbackPayload: [String: Any] = [
            "attributes": [
                "type": "User_Location_Track__c",
                "referenceId": "ref1"
            ],
            "OwnerId": Defaults.userId ?? "",
            "Date_Time__c": location.dateTime ?? CustomDateFormatter.getCurrentDateTime(),
            "User_Lat_Long__Longitude__s": longitude,
            "User_Lat_Long__Latitude__s": latitude,
            "Is_Mock_Location__c": location.isMockLocation ?? "0",
            "Battery_Percentage__c": location.batteryPercentage ?? "0",
            "Address__c": location.address ?? "Unknown Address",
            "Developer_Option__c": "false"
        ]
        
        let payload: [String: Any] = [
            "records": [locationPayload]
        ]
        let fallbackBody: [String: Any] = ["records": [fallbackPayload]]
        Task {
            // Ensure completion runs at most once (avoids rare double-callback races).
            let finishLock = NSLock()
            var didFinish = false
            func finish(_ success: Bool) {
                finishLock.lock()
                defer { finishLock.unlock() }
                guard !didFinish else { return }
                didFinish = true
                completion(success)
            }

            // Location uploads use URLSession only — never Salesforce RestClient
            // (queryParams + nested arrays → __SwiftDeferredNSArray crash; send() can double-resume).
            do {
                _ = try await self.postJSONToAbsoluteURL(
                    synctoServerUrl,
                    body: payload,
                    includeFieldblazeSecret: true
                )
                print("First API success (URLSession)")
                finish(true)
            } catch {
                // This catch = Fieldblaze create failed (network / non-2xx / bad URL / encode).
                print("Primary API failed:", error.localizedDescription)
                if let urlErr = error as? URLError {
                    print("Primary URLError code:", urlErr.code.rawValue, urlErr.failureURLString ?? "")
                }
                do {
                    guard let instance = Defaults.instanceUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !instance.isEmpty else {
                        throw URLError(.badURL)
                    }
                    let base = instance.hasSuffix("/") ? String(instance.dropLast()) : instance
                    let fallbackURL = base + salesforceLocationCompositeTreePath
                    _ = try await self.postJSONToAbsoluteURL(
                        fallbackURL,
                        body: fallbackBody,
                        includeFieldblazeSecret: false
                    )
                    print("Fallback API success (URLSession)")
                    finish(true)
                } catch {
                    print("Both APIs failed:", error.localizedDescription)
                    finish(false)
                }
            }
        }
    }

    /// POST JSON via URLSession (no Salesforce RestClient).
    private func postJSONToAbsoluteURL(
        _ urlString: String,
        body: [String: Any],
        includeFieldblazeSecret: Bool
    ) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = Defaults.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if includeFieldblazeSecret {
            request.setValue(
                "a9F3kL8M2Qw7Xc5R0E6N1ZP4JYHUTbsvDArCneomxGiKfdWqLSp",
                forHTTPHeaderField: "API-SECRET-TOKEN"
            )
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? -1
        let bodyText = String(data: data, encoding: .utf8) ?? ""
        let bodyPreview = String(bodyText.prefix(400))

        // Fieldblaze unique key: user + lat + long + date.
        // Re-upload of an already-synced / duplicate point returns HTTP 400 "Duplicate entry".
        // That means the server already has it — treat as success so the local queue can move on.
        if isFieldblazeDuplicateResponse(statusCode: status, body: bodyText) {
            print("ℹ️ Fieldblaze duplicate (already on server) — treating as synced. HTTP \(status)")
            return data
        }

        if !(200...299).contains(status) {
            print("❌ POST \(urlString) HTTP \(status) body: \(bodyPreview)")
            throw NSError(
                domain: "LocationSync",
                code: status,
                userInfo: [
                    NSLocalizedDescriptionKey: "HTTP \(status): \(bodyPreview)"
                ]
            )
        }

        // Some Fieldblaze responses may be HTTP 200 with status:"error" in JSON.
        if includeFieldblazeSecret,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let apiStatus = obj["status"] as? String,
           apiStatus.lowercased() == "error" {
            if isFieldblazeDuplicateResponse(statusCode: status, body: bodyText) {
                print("ℹ️ Fieldblaze duplicate in 200 body — treating as synced")
                return data
            }
            print("❌ Fieldblaze status=error body: \(bodyPreview)")
            throw NSError(
                domain: "LocationSync",
                code: status,
                userInfo: [NSLocalizedDescriptionKey: "Fieldblaze error: \(bodyPreview)"]
            )
        }

        print("✅ POST \(urlString) HTTP \(status)")
        return data
    }

    /// True when Fieldblaze rejects because the point is already stored.
    private func isFieldblazeDuplicateResponse(statusCode: Int, body: String) -> Bool {
        let lower = body.lowercased()
        if lower.contains("duplicate entry") || lower.contains("uniq_user_location") {
            return true
        }
        // HTTP 400 + failed summary often means duplicate for this API.
        if statusCode == 400 && lower.contains("failed") && lower.contains("duplicate") {
            return true
        }
        return false
    }
    
    func stringify(_ value: Any) -> String {
        if let dict = value as? [String: Any] {
            // Convert dictionary to JSON string
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        } else if let array = value as? [Any] {
            // Convert array to JSON string
            if let data = try? JSONSerialization.data(withJSONObject: array, options: []),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return "\(value)"
    }
    
    func saveLocationToDatabase(_ location: CLLocation, isMockLocation: Int, lastLocation: CLLocation?) {
        saveQueue.async { [weak self] in
            self?.performSaveLocationToDatabase(location, isMockLocation: isMockLocation)
        }
    }

    private func performSaveLocationToDatabase(_ location: CLLocation, isMockLocation: Int) {
        guard hasValidUserContextForRecording() else { return }
        if location.horizontalAccuracy < 0 { return }
        let timeDate = CustomDateFormatter.getCurrentDateTime()
        var timeDifference = "0"
        var distance: Double = 0.0
        // Only compare against last *successfully saved* point.
        if let previous = getLastLocation() {
            distance = previous.distance(from: location)
            timeDifference = getTimeDifference(
                dateStr1: getLastTime() ?? "",
                dateStr2: timeDate
            )
            if distance < 50 { return }
        }

        let batteryPercentage = getBatteryPercentage()
        let deviceModel = UIDevice.current.model
        let deviceManufacturer = "Apple"
        let isOffline = InternetConnectionManager.isConnectedToNetwork() ? "0" : "1"

        let taskBox = LocationBackgroundTaskBox()
        // beginBackgroundTask is safe from any thread; avoid main.sync (deadlock) and main.async (race).
        taskBox.id = UIApplication.shared.beginBackgroundTask(withName: "LocationSaveAndSync") {
            taskBox.end()
        }

        // No reverse geocode — save lat/long immediately so background tracking is reliable.
        let model = LocationModel(
            id: 0,
            isOfflineRecord: isOffline,
            latitude: "\(location.coordinate.latitude)",
            longitude: "\(location.coordinate.longitude)",
            diffrenceBetweenCurrentAndLastLatLong: String(format: "%.2f", distance / 1000),
            address: "Unknown",
            isMockLocation: "\(isMockLocation)",
            dateTime: timeDate,
            batteryPercentage: "\(batteryPercentage)",
            deviceModel: deviceModel,
            deviceManufacturer: deviceManufacturer,
            isSyncToServer: "0",
            timeDifference: timeDifference
        )

        if locationTable.saveLocation(model) {
            saveLastLocation(location)
            saveLastTime(timeDate)
            startPendingLocationSync {
                taskBox.end()
            }
        } else {
            taskBox.end()
        }   
    }
    
    func saveLastLocation(_ location: CLLocation) {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let data: [String: Double] = ["lat": lat, "lon": lon]
        
        UserDefaults.standard.set(data, forKey: "lastSavedLocation")
        UserDefaults.standard.synchronize()
    }
    
    func getLastLocation() -> CLLocation? {
        if let data = UserDefaults.standard.dictionary(forKey: "lastSavedLocation") as? [String: Double],
           let lat = data["lat"],
           let lon = data["lon"] {
            return CLLocation(latitude: lat, longitude: lon)
        }
        return nil
    }
    
    func saveLastTime(_ time: String) {
        UserDefaults.standard.set(time, forKey: "lastSavedTime")
        UserDefaults.standard.synchronize()
    }
    
    func getLastTime() -> String? {
        if let data = UserDefaults.standard.string(forKey: "lastSavedTime") {
            return data
        }
        return ""
    }
    
    func getBatteryPercentage() -> Int {
        let level = UIDevice.current.batteryLevel
        
        if level < 0.0 {
            print("Battery info unavailable.")
            return 0
        }
        
        return Int(level * 100)
    }
    
    func getTimeDifference(dateStr1: String, dateStr2: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date1 = dateFormatter.date(from: dateStr1),
           let date2 = dateFormatter.date(from: dateStr2) {
            let differenceInSeconds = abs(date2.timeIntervalSince(date1))
            let differenceInMinutes = differenceInSeconds / 60
            return String(format: "%.2f", differenceInMinutes)
        }
        return ""
    }
}

