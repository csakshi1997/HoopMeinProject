//
//  Defaults.swift
//  FRATELLI
//
//  Created by Sakshi on 21/10/24.
//

import Foundation
import UIKit

class Defaults {
    static var accessToken: String? {
        get {
            return UserDefaults.standard.object(forKey: "accessToken") as? String ?? EMPTY
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "accessToken")
            UserDefaults.standard.synchronize()
        }
    }
    
    
    static var punchInAddress: String? {
        get {
            return UserDefaults.standard.object(forKey: "PunchInAddress") as? String ?? EMPTY
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "PunchInAddress")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var isTrackingStart: Bool? {
        get {
            return UserDefaults.standard.object(forKey: "IsTrackingStart") as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "IsTrackingStart")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var isCheckIn: Bool? {
        get {
            return UserDefaults.standard.object(forKey: "IsCheckIn") as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "IsCheckIn")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var isCheckout: Bool? {
        get {
            return UserDefaults.standard.object(forKey: "IsCheckout") as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "IsCheckout")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var isfromSalesforce: Bool? {
        get {
            return UserDefaults.standard.object(forKey: "IsFromSalesforce") as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "IsFromSalesforce")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var isDifferentUserDetected: Bool? {
        get {
            return UserDefaults.standard.object(forKey: "IsDifferentUserDetected") as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "IsDifferentUserDetected")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var wasAutoStopped: Bool? {
        get {
            return UserDefaults.standard.object(forKey: "WasAutoStopped") as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "WasAutoStopped")
            UserDefaults.standard.synchronize()
        }
    }

    static var punchInDate: Date? {
        get {
            return UserDefaults.standard.object(forKey: "PunchInDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "PunchInDate")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var refreshToken: String? {
        get {
            return UserDefaults.standard.object(forKey: "refreshToken") as? String ?? EMPTY
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "refreshToken")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var domain: String? {
        get {
            return UserDefaults.standard.object(forKey: "domain") as? String ?? EMPTY
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "domain")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var instanceUrl: String? {
        get {
            return UserDefaults.standard.object(forKey: "Instance_Url") as? String ?? EMPTY
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "Instance_Url")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var userId: String? {
        get {
            return UserDefaults.standard.string(forKey: "UserId")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "UserId")
        }
    }
    
    static var deepLinkUserId: String? {
        get {
            return UserDefaults.standard.string(forKey: "DeepLinkUserId")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "DeepLinkUserId")
        }
    }
    
    static var isSalesforceTrue: Bool? {
        get {
            return UserDefaults.standard.object(forKey: "IsSalesforceTrue") as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "IsSalesforceTrue")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var userName: String? {
        get {
            return UserDefaults.standard.object(forKey: "UserName") as? String ?? EMPTY
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "UserName")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var name: String? {
        get {
            return UserDefaults.standard.object(forKey: "Name") as? String ?? EMPTY
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "Name")
            UserDefaults.standard.synchronize()
        }
    }
    
    static var userEmail: String? {
        get {
            return UserDefaults.standard.object(forKey: "UserEmail") as? String ?? EMPTY
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "UserEmail")
            UserDefaults.standard.synchronize()
        }
    }
    static var todaysTotalDistance: String? {
        get {
            return UserDefaults.standard.object(forKey: "TodaysTotalDistance") as? String ?? EMPTY
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "TodaysTotalDistance")
            UserDefaults.standard.synchronize()
        }
    }

    /// Caches server `total_distance` per date so Home/Timeline can show it offline.
    static func saveTotalDistance(_ distance: String, for date: String) {
        let trimmedDate = date.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDistance = distance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDate.isEmpty, !trimmedDistance.isEmpty else { return }
        UserDefaults.standard.set(trimmedDistance, forKey: "TotalDistance_\(trimmedDate)")
        todaysTotalDistance = trimmedDistance
        UserDefaults.standard.synchronize()
    }

    static func cachedTotalDistance(for date: String) -> String? {
        let trimmedDate = date.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDate.isEmpty else { return nil }
        guard let value = UserDefaults.standard.string(forKey: "TotalDistance_\(trimmedDate)")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}

